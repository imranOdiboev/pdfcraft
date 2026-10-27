"""Mutation checks for offline build inputs using only synthetic temporary bytes."""
import hashlib
from pathlib import Path
import tempfile
import unittest

from stage_odibo_model_cache import MODEL_NAMES, stage


class ModelCacheTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name) / 'repo'
        self.cache = self.repo / 'vendor/ocrs-models'
        self.cache.mkdir(parents=True)
        self.output = Path(self.temp.name) / 'staged'
        licence = b'synthetic licence, not distributed as a real model licence'
        self.licence = self.cache / 'LICENSE-CC-BY-SA-4.0.txt'
        self.licence.write_bytes(licence)
        rows = []
        for name in sorted(MODEL_NAMES):
            data = b'synthetic test bytes for ' + name.encode()
            (self.cache / name).write_bytes(data)
            rows.append('[[fetched]]\nkind="model"\n'
                        f'file="{name}"\nsha256="{hashlib.sha256(data).hexdigest()}"\n'
                        f'licence_sha256="{hashlib.sha256(licence).hexdigest()}"\n')
        (self.repo / 'ATTRIBUTION.toml').write_text('\n'.join(rows), encoding='utf-8')

    def test_valid_cache_preserves_all_four_exact_inputs(self):
        result = stage(self.repo, self.output)
        self.assertEqual(len(result), 4)
        for name in MODEL_NAMES:
            self.assertEqual((self.output / name).read_bytes(), (self.cache / name).read_bytes())
            self.assertEqual((self.output / (name + '.LICENCE.txt')).read_bytes(), self.licence.read_bytes())

    def test_corrupt_model_fails_before_creating_output(self):
        (self.cache / 'text-detection.rten').write_bytes(b'corrupt')
        with self.assertRaisesRegex(ValueError, 'SHA-256 mismatch'):
            stage(self.repo, self.output)
        self.assertFalse(self.output.exists())

    def test_corrupt_licence_fails_before_creating_output(self):
        self.licence.write_bytes(b'wrong licence')
        with self.assertRaisesRegex(ValueError, 'SHA-256 mismatch'):
            stage(self.repo, self.output)
        self.assertFalse(self.output.exists())

    def test_missing_model_fails_before_creating_output(self):
        (self.cache / 'text-recognition.rten').unlink()
        with self.assertRaisesRegex(ValueError, 'missing model'):
            stage(self.repo, self.output)
        self.assertFalse(self.output.exists())

    def test_existing_destination_is_never_modified(self):
        self.output.mkdir()
        sentinel = self.output / 'user-data'
        sentinel.write_bytes(b'must remain untouched')
        with self.assertRaisesRegex(ValueError, 'new destination'):
            stage(self.repo, self.output)
        self.assertEqual(list(self.output.iterdir()), [sentinel])
        self.assertEqual(sentinel.read_bytes(), b'must remain untouched')


if __name__ == '__main__':
    unittest.main()
