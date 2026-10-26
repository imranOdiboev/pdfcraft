"""Real mutation tests for the distribution inventory; never run an executable."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from verify_odibo_payload import verify


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name) / 'repo'
        self.payload = Path(self.temp.name) / 'payload'
        self.repo.mkdir()
        self.payload.mkdir()
        self.source = 'a' * 40
        self.checkout = 'b' * 40
        models = []
        for name in ['detect.rten', 'recognize.rten']:
            data, licence = b'synthetic model bytes', b'synthetic model licence'
            for suffix, content in [('', data), ('.LICENCE.txt', licence)]:
                self.write('models/' + name + suffix, content)
            models.append(f'[[fetched]]\nkind="model"\nfile="{name}"\nsha256="{hashlib.sha256(data).hexdigest()}"\nlicence_sha256="{hashlib.sha256(licence).hexdigest()}"\n')
        for name in ['LICENSE-MIT', 'LICENSE-APACHE', 'NOTICE', 'ATTRIBUTION.md']:
            self.write(name, b'synthetic original notice')
            (self.repo / name).write_bytes(b'synthetic original notice')
        attribution = '\n'.join(models).encode()
        self.write('ATTRIBUTION.toml', attribution)
        (self.repo / 'ATTRIBUTION.toml').write_bytes(attribution)
        brand = self.repo / 'assets/odibo/LICENSE-ODIBO-BRAND.txt'
        brand.parent.mkdir(parents=True)
        brand.write_bytes(b'synthetic brand terms')
        self.write('licences/assets/odibo/LICENSE-ODIBO-BRAND.txt', brand.read_bytes())
        for name in ['odibo-pdf.exe', 'odibo-pdf-cli.exe', 'THIRD_PARTY_CARGO.html',
                     'BUILD_INFO.txt', 'TEST_BUILD.txt', 'BRAND_PROVENANCE.md',
                     'licences/installer/INNO-LICENSE.txt',
                     'licences/installer/INNO_SETUP_PROVENANCE.md', 'models/ATTRIBUTION.txt']:
            self.write(name, b'synthetic inventory fixture, never executable')
        self.manifest = dict(schema_version=1, version='0.10.1', source_sha=self.source,
                             checkout_sha=self.checkout, checkout_tree='c' * 40,
                             build_number=7, target='x86_64-pc-windows-msvc', unsigned=True)
        self.publish()

    def write(self, name, data):
        path = self.payload / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def sums(self):
        self.write('SHA256SUMS.txt', '\n'.join(
            f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(self.payload).as_posix()}'
            for p in sorted(self.payload.rglob('*')) if p.is_file() and p.name != 'SHA256SUMS.txt').encode())

    def publish(self):
        self.manifest['files'] = [dict(path=p.relative_to(self.payload).as_posix(), size=p.stat().st_size,
                                      sha256=hashlib.sha256(p.read_bytes()).hexdigest())
                                  for p in sorted(self.payload.rglob('*')) if p.is_file()
                                  and p.name not in ['BUILD_MANIFEST.json', 'SHA256SUMS.txt', 'portable.txt']]
        self.write('BUILD_MANIFEST.json', json.dumps(self.manifest).encode())
        self.sums()

    def check(self, portable=False):
        return verify(self.payload, self.repo, self.source, self.checkout, '0.10.1', portable)

    def test_valid_installed_and_portable_are_distinct(self):
        self.assertEqual(self.check()['result'], 'passed')
        self.write('portable.txt', b'')
        self.sums()
        with self.assertRaises(ValueError):
            self.check()
        self.assertTrue(self.check(True)['portable'])

    def test_corrupted_executable_is_rejected_even_if_outer_sums_regenerated(self):
        self.write('odibo-pdf.exe', b'corrupt executable')
        self.sums()
        with self.assertRaisesRegex(ValueError, 'Payload mismatch'):
            self.check()

    def test_missing_notice_is_rejected_even_with_regenerated_inventory(self):
        (self.payload / 'NOTICE').unlink()
        self.publish()
        with self.assertRaises((FileNotFoundError, ValueError)):
            self.check()

    def test_model_change_rejected_even_with_self_consistent_manifest(self):
        self.write('models/detect.rten', b'tampered model')
        self.publish()
        with self.assertRaisesRegex(ValueError, 'model hash'):
            self.check()

    def test_control_token_and_private_key_rejected_in_self_consistent_manifest(self):
        for name in ['control.json', 'licences/key.pfx', 'licences/extra.exe', 'licences/extra.ps1', 'models/extra.exe']:
            self.write(name, b'dummy not secret')
            self.publish()
            with self.assertRaises(ValueError):
                self.check()
            (self.payload / name).unlink()

    def test_credential_pattern_rejected_in_a_notice(self):
        self.write('licences/unexpected.txt', b'-----BEGIN PRIVATE KEY-----\nnot a real key')
        self.publish()
        with self.assertRaisesRegex(ValueError, 'credential pattern'):
            self.check()

    def test_wrong_version_and_source_rejected(self):
        for field in ['source_sha', 'version']:
            saved = self.manifest[field]
            self.manifest[field] = 'wrong'
            self.publish()
            with self.assertRaisesRegex(ValueError, 'identity'):
                self.check()
            self.manifest[field] = saved

    def test_unknown_file_and_case_alias_rejected(self):
        self.write('unknown.txt', b'extra')
        self.sums()
        with self.assertRaises(ValueError):
            self.check()
        (self.payload / 'unknown.txt').unlink()
        self.manifest['files'].append(dict(self.manifest['files'][0], path=self.manifest['files'][0]['path'].upper()))
        self.write('BUILD_MANIFEST.json', json.dumps(self.manifest).encode())
        self.sums()
        with self.assertRaises(ValueError):
            self.check()


if __name__ == '__main__':
    unittest.main()
