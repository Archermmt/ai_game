import json
import unittest
from pathlib import Path

root = Path(__file__).resolve().parents[2]
suite = unittest.defaultTestLoader.discover(str(Path(__file__).parent), pattern='test_*.py')
result = unittest.TextTestRunner(verbosity=2).run(suite)
report = {'tests': result.testsRun, 'failures': len(result.failures), 'errors': len(result.errors),
          'skipped': len(result.skipped), 'synthetic_only': True}
(root / 'reports').mkdir(exist_ok=True)
(root / 'reports/week_12_python.json').write_text(json.dumps(report, indent=2) + '\n')
if result.testsRun < 17 or not result.wasSuccessful() or result.skipped: raise SystemExit(1)
