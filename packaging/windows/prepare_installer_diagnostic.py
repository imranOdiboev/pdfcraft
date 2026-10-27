"""Stage a pinned prior runtime for diagnostics only, never a release candidate.

No executable is launched here. The full current-source build remains mandatory.
The prior runtime's apps/crates/Cargo/assets are unchanged in this packaging PR.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import zipfile

ARCHIVE_SHA = '8219c3db7c8318e2318f3f21ccf6e2b6898ffffc7a53f630ef0bca70869dd0a1'
SOURCE = 'aa9bc135ba6bfcb6b9bc40f09f81f339e9b65c30'
CHECKOUT = 'e7276a010f262a45b8ce22b039e805b37f0f297b'
RUNTIME_SHA = {
    'odibo-pdf.exe': 'b6bbe11b57b3d09e637508ee19a0368624eb83bae2f4a6388bdbd3ebef195e8e',
    'odibo-pdf-cli.exe': '1a24318aacd5d9b1a702e0ae7aa48ba09a4868b1f111a9aeaf2bc3397c1cd500',
}


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    if os.environ.get('GITHUB_ACTIONS') != 'true' or os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted' or os.name != 'nt':
        raise ValueError('Disposable Windows CI only')
    repository = Path(os.environ['GITHUB_WORKSPACE']).resolve()
    output = args.output.resolve()
    if not output.is_relative_to(Path(os.environ['RUNNER_TEMP']).resolve()) or output.exists():
        raise ValueError('Fresh runner-temp destination required')
    if args.archive.stat().st_size > 100 * 1024**2 or digest(args.archive) != ARCHIVE_SHA:
        raise ValueError('Prior diagnostic artifact digest mismatch')
    # A changed engine/runtime would invalidate this shortcut diagnostic input.
    subprocess.run(['git', 'diff', '--exit-code', SOURCE, 'HEAD', '--',
                    'apps', 'crates', 'Cargo.toml', 'Cargo.lock', 'assets', '.cargo',
                    'vendor', ':(exclude)vendor/ocrs-models/**'],
                   cwd=repository, check=True, stdout=subprocess.DEVNULL)
    output.mkdir()
    with zipfile.ZipFile(args.archive) as bundle:
        entries = bundle.infolist()
        if len(entries) > 1000 or sum(e.file_size for e in entries) > 400 * 1024**2:
            raise ValueError('Unexpected prior diagnostic archive size')
        seen = set()
        for entry in entries:
            path = PurePosixPath(entry.filename)
            if (not path.parts or path.is_absolute() or '..' in path.parts
                    or ':' in entry.filename or '\\' in entry.filename
                    or entry.filename.casefold() in seen
                    or stat.S_ISLNK(entry.external_attr >> 16)):
                raise ValueError('Unsafe archive path')
            seen.add(entry.filename.casefold())
            target = output.joinpath(*path.parts)
            if entry.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with target.open('xb') as stream:
                    stream.write(bundle.read(entry))
    for name, expected in RUNTIME_SHA.items():
        if digest(output / name) != expected:
            raise ValueError('Prior runtime pin mismatch')
    sums = {}
    for line in (output / 'SHA256SUMS.txt').read_text(encoding='utf-8-sig').splitlines():
        if not line:
            continue
        match = re.fullmatch(r'([0-9a-f]{64})  ([^\\:]+)', line)
        if not match or match[2] in sums:
            raise ValueError('Invalid prior checksum list')
        sums[match[2]] = match[1]
    actual = {p.relative_to(output).as_posix() for p in output.rglob('*') if p.is_file()}
    if set(sums) != actual - {'SHA256SUMS.txt'}:
        raise ValueError('Incomplete prior checksums')
    for name, expected in sums.items():
        if digest(output / name) != expected:
            raise ValueError('Prior file checksum mismatch')
    # This is our fresh staging area, never an existing installation. Keep every
    # original licence; remove only the portable marker for the Setup fixture.
    (output / 'portable.txt').unlink()
    (output / 'BUILD_INFO.txt').write_text(
        f'Version: 0.10.1\nBuild number: 1\nSource commit: {SOURCE}\n'
        'Diagnostic prior runtime only; never a release candidate.\n', encoding='utf-8')
    installer = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repository, text=True).strip()
    manifest = {'diagnostic_only': True, 'source_sha': SOURCE, 'checkout_sha': CHECKOUT,
                'diagnostic_installer_checkout': installer, 'version': '0.10.1',
                'build_number': 1, 'prior_artifact_id': 12651029055,
                'prior_artifact_sha256': ARCHIVE_SHA, 'runtime_sha256': RUNTIME_SHA}
    (output / 'BUILD_MANIFEST.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    (output / 'SHA256SUMS.txt').write_text(''.join(
        f'{digest(p)}  {p.relative_to(output).as_posix()}\n'
        for p in sorted(output.rglob('*')) if p.is_file() and p.name != 'SHA256SUMS.txt'), encoding='utf-8')
    print(json.dumps(manifest))


if __name__ == '__main__':
    main()
