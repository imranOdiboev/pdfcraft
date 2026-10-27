"""Stage only unchanged, manifest-verified OCR build inputs; never execute them."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import tomllib

MODEL_NAMES = {'text-detection.rten', 'text-recognition.rten'}


def checked_file(path, repository, expected, limit):
    if (not re.fullmatch(r'[0-9a-f]{64}', expected)
            or path.is_symlink() or not path.is_file()
            or not path.resolve().is_relative_to(repository)
            or path.stat().st_size > limit):
        raise ValueError('Unsafe or missing model build input')
    with path.open('rb') as stream:
        actual = hashlib.file_digest(stream, 'sha256').hexdigest()
    if actual != expected:
        raise ValueError('Model build input SHA-256 mismatch: ' + path.name)
    return actual


def stage(repository, output):
    repository, output = Path(repository).resolve(), Path(output)
    if output.exists() or output.is_symlink():
        raise ValueError('Model staging requires a new destination')
    with (repository / 'ATTRIBUTION.toml').open('rb') as stream:
        manifest = tomllib.load(stream)
    models = [m for m in manifest['fetched'] if m['kind'] == 'model']
    if len(models) != 2 or {m['file'] for m in models} != MODEL_NAMES:
        raise ValueError('Expected the existing two canonical OCR models')
    cache = repository / 'vendor/ocrs-models'
    licence = cache / 'LICENSE-CC-BY-SA-4.0.txt'
    inputs = []
    for model in models:
        # Validate every input before creating or writing the destination.
        source = cache / model['file']
        checked_file(source, repository, model['sha256'], 20 * 1024**2)
        checked_file(licence, repository, model['licence_sha256'], 1024**2)
        inputs.extend([(source, model['file'], model['sha256']),
                       (licence, model['file'] + '.LICENCE.txt', model['licence_sha256'])])
    output.mkdir(parents=True, exist_ok=False)
    result = []
    for source, name, expected in inputs:
        target = output / name
        with source.open('rb') as src, target.open('xb') as dst:
            shutil.copyfileobj(src, dst, length=1024**2)
        # Also reject any input race/copy corruption. An incomplete stage fails.
        with target.open('rb') as stream:
            if hashlib.file_digest(stream, 'sha256').hexdigest() != expected:
                raise ValueError('Staged model build input changed')
        result.append({'file': name, 'sha256': expected, 'bytes': target.stat().st_size})
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--repository', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if os.environ.get('GITHUB_ACTIONS') != 'true' or os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted':
        raise ValueError('Build-input staging CLI is restricted to disposable GitHub-hosted runners')
    runner_temp = Path(os.environ['RUNNER_TEMP']).resolve()
    output = args.output.resolve()
    if output == runner_temp or not output.is_relative_to(runner_temp):
        raise ValueError('Build-input destination must be beneath runner temp')
    print(json.dumps({'status': 'passed', 'files': stage(args.repository, output)}, indent=2))


if __name__ == '__main__':
    main()
