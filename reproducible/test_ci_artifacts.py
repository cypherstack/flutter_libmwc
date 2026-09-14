"""Protocol tests use fixtures; they do not claim a real GitHub build matched."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from ci_artifacts import compare, payload


class ComparisonTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.ci = Path(self.temp.name) / 'ci'
        self.local = Path(self.temp.name) / 'local'
        self.commit = 'a' * 40
        for root in (self.ci, self.local):
            root.mkdir()
            artifacts = []
            for mode, suffix in [('dynamic', 'so'), ('static', 'a')]:
                name = f'mwc-test.{suffix}'
                content = f'{mode} fixture'.encode()
                (root / name).write_bytes(content)
                artifacts.append({'file': name, 'target': 'x86_64-unknown-linux-gnu',
                                  'link_mode': mode, 'size': len(content),
                                  'sha256': hashlib.sha256(content).hexdigest()})
            self.write_manifest(root, {'schema_version': 1, 'package': 'flutter_libmwc',
                                      'source_sha256': 'b' * 64, 'artifacts': artifacts})
        self.record(self.ci)

    def write_manifest(self, root, manifest):
        content = (json.dumps(manifest, sort_keys=True) + '\n').encode()
        (root / 'manifest.json').write_bytes(content)
        (root / 'manifest.sha256').write_text(hashlib.sha256(content).hexdigest() + '  manifest.json\n')

    def record(self, root):
        data = {'schema_version': 1, 'source_commit': self.commit, 'repository': 'owner/repo',
                'run_id': '123', 'run_attempt': '1', 'runner': 'fixture', **payload(root)}
        (root / 'ci-evidence.json').write_text(json.dumps(data))

    def check(self, **kwargs):
        return compare(self.ci, self.local, self.commit, 'owner/repo', '123', '1', **kwargs)

    def test_equal_payloads_match(self):
        self.assertEqual(self.check()['status'], 'match')

    def test_ci_pair_requires_both_provenance_records(self):
        with self.assertRaisesRegex(ValueError, 'ci-evidence'):
            self.check(ci_pair=True)
        self.record(self.local)
        self.assertEqual(self.check(ci_pair=True)['comparison'], 'ci-to-ci')

    def test_corruption_cannot_be_hidden_by_equal_manifests(self):
        (self.local / 'mwc-test.so').write_bytes(b'corrupt')
        with self.assertRaisesRegex(ValueError, 'hash/size'):
            self.check()

    def test_rehashed_different_binary_still_fails_comparison(self):
        manifest = json.loads((self.local / 'manifest.json').read_text())
        artifact = manifest['artifacts'][0]
        content = b'different build'
        (self.local / artifact['file']).write_bytes(content)
        artifact.update(size=len(content), sha256=hashlib.sha256(content).hexdigest())
        self.write_manifest(self.local, manifest)
        with self.assertRaisesRegex(ValueError, 'Builds differ'):
            self.check()

    def test_wrong_run_commit_attempt_and_repository_fail(self):
        for key in ('source_commit', 'repository', 'run_id', 'run_attempt'):
            self.record(self.ci)
            record = json.loads((self.ci / 'ci-evidence.json').read_text())
            record[key] = 'wrong'
            (self.ci / 'ci-evidence.json').write_text(json.dumps(record))
            with self.assertRaisesRegex(ValueError, key):
                self.check()

    def test_traversal_and_missing_link_mode_fail(self):
        manifest = json.loads((self.local / 'manifest.json').read_text())
        manifest['artifacts'][0]['file'] = '../escape.so'
        self.write_manifest(self.local, manifest)
        with self.assertRaisesRegex(ValueError, 'Unsafe artifact name'):
            self.check()
        manifest['artifacts'].pop(0)
        self.write_manifest(self.local, manifest)
        with self.assertRaisesRegex(ValueError, 'Missing link mode'):
            self.check()

    def test_manifest_pin_is_checked(self):
        (self.local / 'manifest.sha256').write_text('0' * 64 + '  manifest.json\n')
        with self.assertRaisesRegex(ValueError, 'Manifest pin mismatch'):
            self.check()

    def test_symlink_is_not_accepted_as_a_library(self):
        library = self.local / 'mwc-test.so'
        library.unlink()
        try:
            library.symlink_to(self.ci / 'mwc-test.so')
        except OSError:
            self.skipTest('symlink creation unavailable on this host')
        with self.assertRaisesRegex(ValueError, 'nonregular'):
            self.check()


if __name__ == '__main__':
    unittest.main()
