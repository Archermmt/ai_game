"""Fail on empty, skipped or failed W11 validator tests; write machine-readable counts."""
import json
from pathlib import Path
import sys
import unittest

root = Path(__file__).resolve().parents[2]
suite = unittest.defaultTestLoader.discover(str(Path(__file__).parent), pattern='test_*.py')
result = unittest.TextTestRunner(verbosity=2).run(suite)
summary = {'tests': result.testsRun, 'failures': len(result.failures),
           'errors': len(result.errors), 'skipped': len(result.skipped)}
(root / 'reports/week_11_python.json').write_text(json.dumps(summary, indent=2) + '\n')
sys.exit(0 if result.wasSuccessful() and result.testsRun >= 6 and not result.skipped else 1)
