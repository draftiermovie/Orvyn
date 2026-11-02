"""Atomic status report for the in-app dashboard; no training side effects."""
import json
import os
import time
class Progress:
    def __init__(self, path):
        self.path = path
        self.state = {'pid': os.getpid(), 'started_at': time.time(), 'step': 0}
    def update(self, phase, **fields):
        self.state.update(fields)
        self.state.update(phase=phase, updated_at=time.time())
        temp = self.path.with_suffix(f'.{os.getpid()}.tmp')
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            temp.write_text(json.dumps(self.state, ensure_ascii=False), encoding='utf-8')
            os.replace(temp, self.path)
        except OSError as error:
            print('Could not update dashboard status: ' + str(error), flush=True)
        finally:
            try: temp.unlink(missing_ok=True)
            except OSError: pass
