"""Check all dataset targets fit the pilot context, without loading model weights."""
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/training'))
import train_orvyn
from check_data import validate
from transformers import AutoTokenizer
tokenizer=AutoTokenizer.from_pretrained(str(ROOT/'models/desktop-active'),gguf_file='llama32-1b.gguf',local_files_only=True,trust_remote_code=False)
train,evaluation=validate('v2',verbose=False)
longest=(0,'')
for row in train+evaluation:
    prompt=tokenizer.apply_chat_template(row['messages'][:-1],tokenize=False,add_generation_prompt=True,date_string='30 Oct 2026')
    full=tokenizer.apply_chat_template(row['messages'],tokenize=False,add_generation_prompt=False,date_string='30 Oct 2026')
    assert full.startswith(prompt),row['id']
    ids=tokenizer.encode(prompt,add_special_tokens=False)+tokenizer.encode(full[len(prompt):],add_special_tokens=False)
    assert tokenizer.decode(ids,clean_up_tokenization_spaces=False)==full,row['id']
    assert len(ids)<=384,(row['id'],len(ids))
    longest=max(longest,(len(ids),row['id']))
print(f'All {len(train)+len(evaluation)} examples fit 384 tokens. Longest: {longest}')
