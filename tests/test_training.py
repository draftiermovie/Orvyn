"""Behavioral checks for the dataset, authored reference code and progress file."""
import ast
import copy
import json
import re
import sys
import tempfile
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/training'))
from check_data import validate, validate_rows, action_valid
from progress import Progress

class TrainingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.train,cls.evaluation=validate('v2',verbose=False)
    def test_separate_balanced_sets(self):
        self.assertEqual(len(self.train),112)
        self.assertEqual(len(self.evaluation),48)
        counts=validate_rows(self.train,self.evaluation,verbose=False)
        self.assertEqual(set(counts['train'].values()),{28})
        self.assertEqual(set(counts['eval'].values()),{12})
    def test_duplicate_and_leaked_questions_rejected(self):
        row=copy.deepcopy(self.train[0]);row['id']='different-id'
        row['messages'][1]['content']='  '+row['messages'][1]['content'].upper()+'  '
        with self.assertRaisesRegex(ValueError,'overlap'):validate_rows(self.train,self.evaluation+[row],False)
    def test_model_cannot_supply_approval(self):
        for value in [[],{'action':'run','command':'echo x','approved':True},{'action':'read','path':'../secret'}, {'answer':'ok','action':'run','command':'echo x'},{'action':'write','path':'x'}, {'action':'read','path':'NUL.txt'}]:
            with self.subTest(value=value),self.assertRaises(ValueError):action_valid(value)
        action_valid({'action':'write','path':'empty.txt','text':''})
    def test_invented_citations_rejected(self):
        rows=copy.deepcopy(self.evaluation)
        row=next(r for r in rows if r['id']=='v2-eval-web-1')
        row['messages'][2]['content']='13:45. [99]'
        with self.assertRaisesRegex(ValueError,'citation'):validate_rows(self.train,rows,False)
    def test_authored_python_reference_answers(self):
        # Execute only the deliberately limited pure reference functions in this set.
        builtins={'sum':sum,'max':max,'min':min,'sorted':sorted,'len':len}
        methods={'strip','split','lower','join','count'}
        checked=cases=0
        for row in self.train+self.evaluation:
            if 'python_tests' not in row:continue
            code=re.search(r'```python\n(.*?)```',row['messages'][2]['content'],re.S).group(1)
            tree=ast.parse(code)
            self.assertEqual(len(tree.body),1)
            self.assertIsInstance(tree.body[0],ast.FunctionDef)
            self.assertEqual(tree.body[0].name,'solve')
            for node in ast.walk(tree):
                self.assertNotIsInstance(node,(ast.Import,ast.ImportFrom,ast.While,ast.For,ast.With,ast.Global,ast.Nonlocal,ast.ClassDef,ast.Lambda))
                if isinstance(node,ast.Name):self.assertFalse(node.id.startswith('__'))
                if isinstance(node,ast.Attribute):self.assertIn(node.attr,methods)
                if isinstance(node,ast.Call):
                    self.assertTrue((isinstance(node.func,ast.Name) and node.func.id in builtins) or (isinstance(node.func,ast.Attribute) and node.func.attr in methods))
            scope={'__builtins__':builtins}
            exec(compile(tree,'<reviewed-reference>','exec'),scope)
            for case in row['python_tests']:
                args=copy.deepcopy(case['args'])
                self.assertEqual(scope['solve'](*args),case['expected'],row['id'])
                self.assertEqual(args,case['args'],'Reference modified input: '+row['id'])
                cases+=1
            checked+=1
        self.assertEqual(checked,24)
        print(f'{checked} reference functions passed {cases} examples')
    def test_progress_updates_keep_steps_and_report_failure(self):
        with tempfile.TemporaryDirectory(dir=ROOT/'tools/temp') as directory:
            path=Path(directory)/'progress.json'
            progress=Progress(path);progress.update('training',total_steps=24,step=6)
            progress.update('failed',error='Example failure')
            value=json.loads(path.read_text())
            self.assertEqual(value['step'],6);self.assertEqual(value['phase'],'failed')
            self.assertEqual(value['error'],'Example failure')
            self.assertEqual(list(Path(directory).glob('*.tmp')),[])

if __name__=='__main__':unittest.main()
