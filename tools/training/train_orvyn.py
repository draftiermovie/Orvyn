"""Small, explicit LoRA experiment. Never replaces the app's model."""
import argparse
import importlib.util
import hashlib
import json
import os
import random
import sys
import time
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.dont_write_bytecode = True
for key, relative in {
    'HF_HOME': 'tools/cache/huggingface',
    'TORCH_HOME': 'tools/cache/torch',
    'XDG_CACHE_HOME': 'tools/cache/training',
    'TEMP': 'tools/temp', 'TMP': 'tools/temp',
}.items():
    folder = ROOT / relative
    folder.mkdir(parents=True, exist_ok=True)
    os.environ[key] = str(folder)
os.environ['HF_HUB_OFFLINE'] = '1'
os.environ['HF_HUB_DISABLE_TELEMETRY'] = '1'
os.environ['DO_NOT_TRACK'] = '1'
os.environ['TOKENIZERS_PARALLELISM'] = 'false'
os.environ['PYTHONDONTWRITEBYTECODE'] = '1'

from check_data import validate, directory
from progress import Progress
PROGRESS = None

def main():
    global PROGRESS
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--train', action='store_true', help='Actually run the experiment')
    parser.add_argument('--device', choices=['cpu', 'cuda'], default='cpu')
    parser.add_argument('--steps', type=int, default=24)
    parser.add_argument('--threads', type=int, default=4)
    parser.add_argument('--max-length', type=int, default=384)
    parser.add_argument('--dataset', choices=['seed', 'v2'], default=None)
    args = parser.parse_args()
    if not 1 <= args.steps <= 1000 or not 1 <= args.threads <= 32:
        parser.error('Use 1..1000 steps and 1..32 CPU threads.')
    if args.train:
        PROGRESS = Progress(ROOT / 'logs/training/progress.json')
        PROGRESS.update('loading', total_steps=args.steps, dataset=directory(args.dataset).name)
    train, evaluation = validate(args.dataset)
    source = ROOT / 'models/desktop-active/llama32-1b.gguf'
    missing = [m for m in ['torch', 'transformers', 'peft', 'gguf'] if importlib.util.find_spec(m) is None]
    report = {'training_started': False, 'source_exists': source.is_file(), 'missing_packages': missing,
              'device': args.device, 'train_examples': len(train), 'evaluation_examples': len(evaluation)}
    report['dataset'] = str(directory(args.dataset).relative_to(ROOT))
    data_hashes = {name: hashlib.sha256((directory(args.dataset) / name).read_bytes()).hexdigest() for name in ['train.jsonl', 'eval.jsonl']}
    print(json.dumps(report, indent=2), flush=True)
    if not args.train:
        return
    if missing or not source.is_file():
        raise SystemExit('Prepare the USB training environment and source model first.')

    import torch
    import transformers
    import peft
    from transformers import AutoTokenizer, AutoModelForCausalLM
    from peft import LoraConfig, get_peft_model

    if args.device == 'cuda' and not torch.cuda.is_available():
        raise SystemExit('CUDA GPU unavailable. No training was started.')
    torch.set_num_threads(args.threads)
    torch.manual_seed(2026)
    rng = random.Random(2026)
    print('Loading the existing GGUF into dense float32 weights; the source is read-only.', flush=True)
    tokenizer = AutoTokenizer.from_pretrained(str(source.parent), gguf_file=source.name,
                                             local_files_only=True, trust_remote_code=False)
    if not tokenizer.chat_template:
        raise SystemExit('The source has no chat template; do not train with an assumed format.')
    chat_date = time.strftime('%d %b %Y')
    def encode(row):
        messages = row['messages']
        prompt_text = tokenizer.apply_chat_template(messages[:-1], tokenize=False,
                    add_generation_prompt=True, date_string=chat_date)
        full_text = tokenizer.apply_chat_template(messages, tokenize=False,
                    add_generation_prompt=False, date_string=chat_date)
        if not full_text.startswith(prompt_text):
            raise ValueError('Chat-template prefix mismatch: ' + row['id'])
        # BPE may merge trailing newlines differently once an answer follows.
        # Keep exactly the generation-time prompt tokens, then encode its target.
        prompt = tokenizer.encode(prompt_text, add_special_tokens=False)
        target = tokenizer.encode(full_text[len(prompt_text):], add_special_tokens=False)
        full = prompt + target
        if tokenizer.decode(full, clean_up_tokenization_spaces=False) != full_text:
            raise ValueError('Tokenization round-trip mismatch: ' + row['id'])
        if len(full) > args.max_length or len(full) <= len(prompt):
            raise ValueError('Adjust --max-length; refusing to truncate a target: ' + row['id'])
        return {'input_ids': torch.tensor([full], device=args.device),
                'labels': torch.tensor([[-100] * len(prompt) + full[len(prompt):]], device=args.device)}

    encoded_train = [(row['domain'], encode(row)) for row in train]
    encoded_eval = [(row['domain'], encode(row)) for row in evaluation]
    model = AutoModelForCausalLM.from_pretrained(str(source.parent), gguf_file=source.name,
                local_files_only=True, trust_remote_code=False, dtype=torch.float32).to(args.device)
    model.config.use_cache = False

    def evaluate():
        model.eval()
        losses = defaultdict(list)
        with torch.no_grad():
            for domain, batch in encoded_eval:
                losses[domain].append(float(model(**batch).loss))
        return {domain: sum(values) / len(values) for domain, values in losses.items()}

    def sample_answers():
        model.eval()
        answers = []
        for row in evaluation:
            if not row['id'].endswith('-1'):
                continue
            ids = tokenizer.apply_chat_template(row['messages'][:-1], tokenize=True,
                        return_dict=False, add_generation_prompt=True, date_string=chat_date)
            inputs = torch.tensor([ids], device=args.device)
            with torch.no_grad():
                generated = model.generate(input_ids=inputs, attention_mask=torch.ones_like(inputs),
                            do_sample=False, max_new_tokens=96, use_cache=True,
                            pad_token_id=tokenizer.eos_token_id)
            answer = tokenizer.decode(generated[0, len(ids):], skip_special_tokens=True)
            answers.append({'id': row['id'], 'question': row['messages'][-2]['content'],
                            'reference': row['messages'][-1]['content'], 'answer': answer,
                            'hit_token_limit': generated.shape[1] - len(ids) >= 96})
            print(json.dumps({'probe': row['id'], 'answer': answer}, ensure_ascii=True), flush=True)
        return answers

    started = time.monotonic()
    PROGRESS.update('baseline')
    baseline = evaluate()
    print(json.dumps({'baseline_loss': baseline}), flush=True)
    baseline_answers = sample_answers()
    model = get_peft_model(model, LoraConfig(r=8, lora_alpha=16, lora_dropout=0.05,
                target_modules=['q_proj', 'v_proj'], bias='none', task_type='CAUSAL_LM'))
    model.gradient_checkpointing_enable(gradient_checkpointing_kwargs={'use_reentrant': False})
    optimizer = torch.optim.AdamW((p for p in model.parameters() if p.requires_grad), lr=1e-4)
    groups = defaultdict(list)
    for domain, batch in encoded_train:
        groups[domain].append(batch)
    domains = sorted(groups)
    for values in groups.values():
        rng.shuffle(values)
    model.train()
    PROGRESS.update('training')
    for step in range(args.steps):
        domain = domains[step % len(domains)]
        batch = groups[domain][(step // len(domains)) % len(groups[domain])]
        optimizer.zero_grad(set_to_none=True)
        loss = model(**batch).loss
        if not torch.isfinite(loss):
            raise RuntimeError('Non-finite loss; experiment stopped.')
        loss.backward()
        torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
        optimizer.step()
        PROGRESS.update('training', step=step+1, domain=domain, loss=float(loss.detach()), elapsed_seconds=round(time.monotonic()-started,1))
        print(json.dumps({'step': step + 1, 'domain': domain, 'loss': float(loss.detach()),
                          'elapsed_seconds': round(time.monotonic() - started, 1)}), flush=True)
    PROGRESS.update('evaluating')
    after = evaluate()
    output = ROOT / 'models/training' / ('orvyn1-candidate-' + time.strftime('%Y%m%d-%H%M%S'))
    output.mkdir(parents=True, exist_ok=False)
    PROGRESS.update('saving', output=str(output.relative_to(ROOT)))
    model.save_pretrained(output, safe_serialization=True)
    tokenizer.save_pretrained(output)
    candidate_answers = sample_answers()
    (output / 'answers.json').write_text(json.dumps({'baseline': baseline_answers,
        'candidate': candidate_answers}, indent=2, ensure_ascii=False), encoding='utf-8')
    result = {'status': 'trained_candidate_not_deployed', 'steps': args.steps,
              'dataset': report['dataset'], 'train_examples': len(train), 'evaluation_examples': len(evaluation),
              'dataset_sha256': data_hashes,
              'threads': args.threads, 'seed': 2026, 'learning_rate': 1e-4,
              'chat_template_date': chat_date,
              'lora': {'rank': 8, 'alpha': 16, 'target_modules': ['q_proj', 'v_proj']},
              'baseline_loss': baseline, 'candidate_loss': after,
              'elapsed_seconds': time.monotonic() - started,
              'versions': {'torch': torch.__version__, 'transformers': transformers.__version__, 'peft': peft.__version__},
              'limitation': 'Small synthetic seed set. Loss alone does not establish improved answers or computer skills.'}
    (output / 'evaluation.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    PROGRESS.update('completed', output=str(output.relative_to(ROOT)))
    print(json.dumps({'candidate': str(output), **result}, indent=2), flush=True)

if __name__ == '__main__':
    try:
        main()
    except BaseException as error:
        if PROGRESS is not None: PROGRESS.update('failed', error=str(error) or type(error).__name__)
        raise
