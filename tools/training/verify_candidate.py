"""Check the saved pilot adapter and record USB-relative provenance."""
import argparse
import hashlib
import json
from pathlib import Path
from train_orvyn import ROOT
import numpy as np
from safetensors import safe_open

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('candidate', help='Candidate directory under models/training')
args = parser.parse_args()
candidate = Path(args.candidate).resolve()
if not candidate.is_relative_to((ROOT / 'models/training').resolve()):
    parser.error('The candidate must be inside this USB project.')

def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()

adapter = candidate / 'adapter_model.safetensors'
parameters = 0
updated_b_matrices = 0
with safe_open(str(adapter), framework='np') as saved:
    keys = list(saved.keys())
    assert keys, 'Empty adapter'
    for key in keys:
        tensor = saved.get_tensor(key)
        assert np.isfinite(tensor).all(), 'Non-finite weights: ' + key
        parameters += tensor.size
        if '.lora_B.' in key:
            assert np.any(tensor != 0), 'Untrained zero B matrix: ' + key
            updated_b_matrices += 1
assert updated_b_matrices > 0, 'No trained LoRA matrices'

evaluation = json.loads((candidate / 'evaluation.json').read_text(encoding='utf-8'))
dataset = evaluation.get('dataset', 'data/training/orvyn-1').replace('\\', '/')
if dataset not in {'data/training/orvyn-1', 'data/training/orvyn-1/v2'}:
    raise ValueError('Unknown dataset path in report')
for name, expected_hash in evaluation.get('dataset_sha256', {}).items():
    if name not in {'train.jsonl', 'eval.jsonl'}: raise ValueError('Unknown dataset file')
    assert sha256(ROOT / dataset / name) == expected_hash, 'Dataset changed since training: ' + name
files = [adapter, ROOT / 'models/desktop-active/llama32-1b.gguf',
         ROOT / dataset / 'train.jsonl', ROOT / dataset / 'eval.jsonl']
result = {'verified': True, 'tensor_count': len(keys), 'adapter_parameters': parameters,
          'nonzero_lora_b_matrices': updated_b_matrices,
          'sha256': {str(path.relative_to(ROOT)).replace('\\', '/'): sha256(path) for path in files}}
expected = json.loads((ROOT / 'config/custom-models.json').read_text(encoding='utf-8'))['models']
original = next(row for row in expected if row['id'] == 'orvyn-1')['sha256']
assert result['sha256']['models/desktop-active/llama32-1b.gguf'] == original, 'Base model changed'
(candidate / 'integrity.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result, indent=2))
