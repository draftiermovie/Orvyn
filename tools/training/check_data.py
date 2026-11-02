"""Validate dataset structure, separation, code syntax and Opex action schemas."""
import argparse
import ast
import json
import re
from collections import Counter
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / 'data/training/orvyn-1'

def require(condition, message):
    if not condition: raise ValueError(message)

def directory(version=None):
    version = version or ('v2' if (DATA / 'v2').is_dir() else 'seed')
    require(version in {'seed', 'v2'}, 'Unknown dataset version')
    return DATA / 'v2' if version == 'v2' else DATA

def load(name, version=None):
    return [json.loads(line) for line in (directory(version) / name).read_text(encoding='utf-8-sig').splitlines() if line.strip()]

def action_valid(action):
    require(isinstance(action, dict), 'Opex target must be an object')
    expected = {'read': {'action','path'}, 'write': {'action','path','text'}, 'run': {'action','command'}}
    keys = {'answer'} if 'answer' in action else expected.get(action.get('action'))
    require(keys is not None and set(action) == keys, 'Opex target has missing, mixed or unexpected fields')
    require(all(isinstance(value, str) for value in action.values()), 'Opex fields must be strings')
    for key in ('answer', 'command'):
        if key in action: require(action[key].strip() and len(action[key].encode()) <= 8000 and '\0' not in action[key], 'Empty or invalid answer/command')
    if 'text' in action: require(len(action['text'].encode()) <= 100000, 'Write target too large')
    if 'path' in action:
        path = action['path']
        require(path.strip() and len(path.encode()) <= 500 and not any(ord(c) < 32 for c in path), 'Invalid path')
        for part in re.split(r'[/\\\\]', path):
            require(part not in {'', '.', '..'} and not part.endswith((' ', '.')) and not re.search(r'[:*?"<>|]', part), 'Unsafe relative path')
            require(not re.fullmatch(r'CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9]', part.split('.')[0], re.I), 'Reserved device path')

def validate_rows(train, evaluation, verbose=True):
    ids, questions, counts_by_split = set(), set(), {}
    for split, rows in [('train', train), ('eval', evaluation)]:
        counts = Counter()
        for row in rows:
            require(isinstance(row, dict), 'Example must be an object')
            identity = row.get('id')
            require(isinstance(identity, str) and identity and identity not in ids, 'Missing/duplicate example id')
            ids.add(identity)
            require(row.get('domain') in {'nl', 'code', 'web', 'pc'}, identity + ': unknown domain')
            counts[row['domain']] += 1
            messages = row.get('messages')
            require(isinstance(messages, list) and len(messages) == 3, identity + ': three messages required')
            require([m.get('role') for m in messages] == ['system', 'user', 'assistant'], identity + ': wrong roles')
            require(all(isinstance(m.get('content'), str) and m['content'].strip() for m in messages), identity + ': empty text')
            require(sum(len(m['content']) for m in messages) <= 12000, identity + ': example too large')
            question = ' '.join(messages[1]['content'].casefold().split())
            require(question not in questions, identity + ': duplicate prompt or train/eval overlap')
            questions.add(question)
            answer = messages[-1]['content']
            if row['domain'] == 'pc': action_valid(json.loads(answer))
            fence = chr(96) * 3
            for code in re.findall(fence + r'python\s*\n(.*?)' + fence, answer, re.S): ast.parse(code)
            if 'json' in row.get('tags', []): json.loads(answer)
            if row['domain'] == 'web' and identity.startswith('v2-'):
                cited = set(re.findall(r'\[(\d+)\]', answer))
                supplied = set(re.findall(r'\[(\d+)\]', messages[1]['content']))
                require(cited and cited <= supplied, identity + ': missing or invented citation')
        require(len(counts) == 4, split + ': all four domains required')
        counts_by_split[split] = dict(counts)
        if verbose: print(split, dict(counts))
    if verbose: print('Dataset valid. Structural checks do not establish improved model quality.')
    return counts_by_split

def validate(version=None, verbose=True):
    train, evaluation = load('train.jsonl', version), load('eval.jsonl', version)
    validate_rows(train, evaluation, verbose)
    return train, evaluation

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dataset', choices=['seed','v2'])
    validate(parser.parse_args().dataset)
