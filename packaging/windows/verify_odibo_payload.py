"""Fail-closed inventory verification; stdlib only, never execute package contents."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import tomllib


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def verify(root, repository, source_sha, checkout_sha, version, portable=False):
    root, repository = Path(root).resolve(), Path(repository).resolve()
    manifest = json.loads((root / 'BUILD_MANIFEST.json').read_text(encoding='utf-8-sig'))
    for field, expected in [('schema_version', 1), ('version', version),
                            ('source_sha', source_sha), ('checkout_sha', checkout_sha),
                            ('target', 'x86_64-pc-windows-msvc'), ('unsigned', True)]:
        if manifest.get(field) != expected:
            raise ValueError(f'Unexpected build identity: {field}')
    if not all(re.fullmatch('[0-9a-f]{40}', s) for s in [source_sha, checkout_sha]):
        raise ValueError('Invalid source SHA')
    if not isinstance(manifest.get('build_number'), int) or manifest['build_number'] <= 0:
        raise ValueError('Missing build ordering')
    if not re.fullmatch('[0-9a-f]{40}', manifest.get('checkout_tree', '')):
        raise ValueError('Missing checkout tree')
    required = {'odibo-pdf.exe', 'odibo-pdf-cli.exe', 'LICENSE-MIT', 'LICENSE-APACHE',
                'NOTICE', 'ATTRIBUTION.toml', 'ATTRIBUTION.md', 'THIRD_PARTY_CARGO.html',
                'BUILD_INFO.txt', 'TEST_BUILD.txt', 'BRAND_PROVENANCE.md',
                'licences/assets/odibo/LICENSE-ODIBO-BRAND.txt',
                'licences/installer/INNO-LICENSE.txt',
                'licences/installer/CPL-1.0.txt',
                'licences/installer/INNO_SETUP_PROVENANCE.md', 'models/ATTRIBUTION.txt'}
    # The loader decoder selects upstream's CPL option and linking exception.
    # Supply its complete corresponding source on the same medium, as inert legal
    # material; it is never compiled into the Rust engine or executed by Setup.
    runtime_names = {'CPL-1.0.txt', 'INNO-LICENSE.txt', 'NOTICE.md', 'SOURCES.toml',
                     'compile.bat.txt', 'LzmaDecode.h', 'LzmaDecodeInno.c',
                     'LzmaDecodeSize.c', 'LzmaTypes.h'}
    source_dir = repository / 'packaging/windows/installer-runtime-source/lzma-loader'
    source_inventory = tomllib.loads((source_dir / 'SOURCES.toml').read_text(encoding='utf-8'))
    if source_inventory.get('upstream_commit') != '7d634620f1d1caca6c76e8398da7133153db9e7b':
        raise ValueError('Unexpected installer source revision')
    source_entries = source_inventory.get('files', [])
    if {entry['path'] for entry in source_entries} != runtime_names - {'NOTICE.md', 'SOURCES.toml'}:
        raise ValueError('Incomplete installer source provenance')
    for entry in source_entries:
        if digest(source_dir / entry['path']) != entry['sha256']:
            raise ValueError('Pinned installer source hash mismatch')
    for name in runtime_names:
        path = 'licences/installer/lzma-loader-source/' + name
        required.add(path)
        if digest(root / path) != digest(source_dir / name):
            raise ValueError(f'Installer corresponding source changed: {name}')
    for name in ['CPL-1.0.txt', 'INNO-LICENSE.txt', 'INNO_SETUP_PROVENANCE.md']:
        if digest(root / 'licences/installer' / name) != digest(repository / 'packaging/windows' / name):
            raise ValueError('Installer notice changed')
    attribution = tomllib.loads((repository / 'ATTRIBUTION.toml').read_text(encoding='utf-8'))
    models = [f for f in attribution.get('fetched', []) if f['kind'] == 'model']
    if len(models) != 2:
        raise ValueError('Review model inventory after attribution changes')
    for model in models:
        required.update(['models/' + model['file'], 'models/' + model['file'] + '.LICENCE.txt'])
        if digest(root / 'models' / model['file']) != model['sha256']:
            raise ValueError('OCR model hash mismatch')
        if digest(root / 'models' / (model['file'] + '.LICENCE.txt')) != model['licence_sha256']:
            raise ValueError('OCR licence hash mismatch')
    allowed_models = {p for p in required if p.startswith('models/')}
    for file in ['LICENSE-MIT', 'LICENSE-APACHE', 'NOTICE', 'ATTRIBUTION.toml', 'ATTRIBUTION.md']:
        if digest(root / file) != digest(repository / file):
            raise ValueError(f'Original notice changed: {file}')
    if digest(root / 'licences/assets/odibo/LICENSE-ODIBO-BRAND.txt') != digest(repository / 'assets/odibo/LICENSE-ODIBO-BRAND.txt'):
        raise ValueError('Brand terms changed')
    expected = {}
    for item in manifest['files']:
        path = item['path']
        parts = PurePosixPath(path).parts
        if not parts or '..' in parts or '\\' in path or ':' in path or path.startswith('/'):
            raise ValueError('Unsafe inventory path')
        if path.casefold() in {p.casefold() for p in expected}:
            raise ValueError('Duplicate inventory path')
        if path in {'BUILD_MANIFEST.json', 'SHA256SUMS.txt', 'portable.txt'}:
            raise ValueError('Self-referencing or mode-dependent inventory')
        file = root / path
        if not file.is_file() or file.is_symlink() or file.stat().st_size != item['size'] or digest(file) != item['sha256']:
            raise ValueError(f'Payload mismatch: {path}')
        expected[path] = item['sha256']
    if not required.issubset(expected):
        raise ValueError(f'Missing required files: {sorted(required - expected.keys())}')
    actual = set()
    for file in root.rglob('*'):
        if file.is_symlink():
            raise ValueError('Symlink in payload')
        if not file.is_file():
            continue
        path = file.relative_to(root).as_posix()
        actual.add(path)
        root_files = {p for p in required if '/' not in p} | {
            'LICENSE-document.txt', 'BUILD_MANIFEST.json', 'SHA256SUMS.txt', 'portable.txt'}
        if path not in root_files and not path.startswith(('licences/', 'models/')):
            raise ValueError(f'File outside distribution allowlist: {path}')
        if path.startswith('models/') and path not in allowed_models:
            raise ValueError(f'Unexpected model file: {path}')
        if path not in {'odibo-pdf.exe', 'odibo-pdf-cli.exe'} and file.suffix.lower() in {
            '.exe', '.ps1', '.bat', '.cmd', '.com', '.msi', '.scr', '.vbs', '.js', '.ts', '.py', '.sh', '.dll'}:
            raise ValueError(f'Unexpected executable or script: {path}')
        if path.startswith('licences/'):
            if file.stat().st_size > 2 * 1024 * 1024:
                raise ValueError('Oversized notice')
            notice = file.read_text(encoding='utf-8-sig')
            if '\x00' in notice or re.search(r'(?:-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[A-Z0-9]{16})', notice):
                raise ValueError('Binary data or credential pattern in notice')
        if file.suffix.lower() in {'.pfx', '.pem', '.key', '.pdb', '.wixpdb', '.pdf', '.dll'} or file.name.startswith('.env'):
            raise ValueError(f'Unexpected private/debug/document file: {path}')
        if any(p.lower() in {'.git', 'odibopdfdata'} for p in file.relative_to(root).parts):
            raise ValueError('User or repository data in payload')
        if file.suffix.lower() == '.json' and path != 'BUILD_MANIFEST.json':
            raise ValueError('Unexpected control/metadata JSON')
    allowed = set(expected) | {'BUILD_MANIFEST.json', 'SHA256SUMS.txt'}
    if portable:
        allowed.add('portable.txt')
    if actual != allowed:
        raise ValueError(f'Unexpected file inventory: {sorted(actual ^ allowed)}')
    sums = {}
    for line in (root / 'SHA256SUMS.txt').read_text(encoding='utf-8-sig').splitlines():
        match = re.fullmatch(r'([0-9a-f]{64})  (.+)', line)
        if not match or match[2] in sums:
            raise ValueError('Invalid checksum inventory')
        sums[match[2]] = match[1]
    if set(sums) != actual - {'SHA256SUMS.txt'}:
        raise ValueError('Incomplete checksum inventory')
    for path, expected_hash in sums.items():
        if digest(root / path) != expected_hash:
            raise ValueError(f'Checksum mismatch: {path}')
    return {'result': 'passed', 'files': len(actual), 'source_sha': source_sha,
            'checkout_sha': checkout_sha, 'version': version, 'portable': portable}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('--repository', type=Path, required=True)
    parser.add_argument('--source-sha', required=True)
    parser.add_argument('--checkout-sha', required=True)
    parser.add_argument('--version', required=True)
    parser.add_argument('--portable', action='store_true')
    args = parser.parse_args()
    print(json.dumps(verify(args.root, args.repository, args.source_sha, args.checkout_sha, args.version, args.portable)))
