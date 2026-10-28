"""G0 migration and tool restoration regressions; temporary Git repositories only."""
import io
from contextlib import redirect_stdout
import json
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/quality'))
from clean_checkout import committed_project_archive, run_verified, validate_summary
from bootstrap import download_metadata, matches_digest


class CleanCheckoutTests(unittest.TestCase):
    def archive_case(self, nested):
        with tempfile.TemporaryDirectory() as folder:
            repository = Path(folder)
            project = repository / 'tiny_glade' if nested else repository
            project.mkdir(exist_ok=True)
            (project / 'project.godot').write_text('project fixture')
            (project / 'owned.txt').write_text('committed')
            if nested:
                (repository / 'project.godot').write_text('wrong sibling project')
                (repository / 'unrelated.txt').write_text('do not archive')
            for command in [['git', 'init', '-q'], ['git', 'add', '.'],
                            ['git', '-c', 'user.name=G0 Test', '-c', 'user.email=g0@example.invalid',
                             'commit', '-qm', 'fixture']]:
                subprocess.run(command, cwd=repository, check=True, capture_output=True)
            (project / 'owned.txt').write_text('uncommitted must not leak')
            revision, relative, archive = committed_project_archive(project)
            self.assertEqual(relative, 'tiny_glade' if nested else '.')
            self.assertEqual(len(revision), 40)
            with tarfile.open(fileobj=io.BytesIO(archive)) as source:
                self.assertEqual(source.extractfile('project.godot').read(), b'project fixture')
                self.assertEqual(source.extractfile('owned.txt').read(), b'committed')
                self.assertNotIn('unrelated.txt', source.getnames())
                self.assertNotIn('.godot', source.getnames())

    def test_standalone_committed_project(self):
        self.archive_case(False)

    def test_monorepo_subproject_excludes_other_projects_and_dirty_files(self):
        self.archive_case(True)

    def test_failed_child_exit_propagates(self):
        with redirect_stdout(io.StringIO()), self.assertRaises(RuntimeError):
            run_verified([sys.executable, '-c', 'raise SystemExit(7)'], ROOT, os.environ.copy(), 10)

    def test_zero_exit_script_error_is_rejected(self):
        with redirect_stdout(io.StringIO()), self.assertRaises(RuntimeError):
            run_verified([sys.executable, '-c', 'print("SCRIPT ERROR: fixture")'], ROOT, os.environ.copy(), 10)

    def test_empty_failed_skipped_or_no_negative_control_summaries_rejected(self):
        valid = {'godot_tests': 1, 'failures': 0, 'skipped': 0, 'negative_control': True}
        validate_summary(valid)
        for change in [{'godot_tests': 0}, {'godot_tests': True}, {'failures': 1},
                       {'skipped': 1}, {'negative_control': False}, {'functional_gate_passed': False}]:
            with self.subTest(change=change), self.assertRaises(RuntimeError):
                validate_summary({**valid, **change})
        with self.assertRaises(RuntimeError):
            validate_summary({})


class BootstrapTests(unittest.TestCase):
    def test_api_limit_uses_exact_official_checksum_entry(self):
        checksum = 'a' * 128
        error = HTTPError('https://api.github.com/', 403, 'rate limit', {}, None)
        with patch('bootstrap.urllib.request.urlopen', side_effect=[error, io.BytesIO(
                (checksum + '  fixture.zip\n').encode())]):
            url, algorithm, digest = download_metadata('4.7.2', 'fixture.zip')
        self.assertEqual(algorithm, 'sha512')
        self.assertEqual(digest, checksum)
        self.assertEqual(url, 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/fixture.zip')

    def test_missing_or_invalid_official_checksum_fails_closed(self):
        for manifest in ['abcd  fixture.zip\n', 'a' * 128 + '  different.zip\n']:
            error = HTTPError('https://api.github.com/', 429, 'limited', {}, None)
            with patch('bootstrap.urllib.request.urlopen', side_effect=[error, io.BytesIO(manifest.encode())]):
                with self.assertRaises(RuntimeError):
                    download_metadata('4.7.2', 'fixture.zip')

    def test_other_http_errors_do_not_trigger_fallback(self):
        with patch('bootstrap.urllib.request.urlopen', side_effect=HTTPError('x', 404, 'missing', {}, None)):
            with self.assertRaises(HTTPError):
                download_metadata('4.7.2', 'fixture.zip')

    def test_download_integrity_rejects_changed_or_missing_cache(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'download'
            digest = hashlib.sha512(b'expected').hexdigest()
            self.assertFalse(matches_digest(path, 'sha512', digest))
            path.write_bytes(b'expected')
            self.assertTrue(matches_digest(path, 'sha512', digest))
            path.write_bytes(b'tampered')
            self.assertFalse(matches_digest(path, 'sha512', digest))


if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    report = {'tests': result.testsRun, 'failures': len(result.failures),
              'errors': len(result.errors), 'skipped': len(result.skipped)}
    output = ROOT / 'reports/week_14/g0/python_checks.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + '\n')
    raise SystemExit(0 if result.wasSuccessful() and result.testsRun >= 9 and not result.skipped else 1)
