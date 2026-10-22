"""Design-only exports on a disposable Actions runner; no product code is executed."""
from pathlib import Path
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import hashlib
import json
import os
import shutil
import struct
import subprocess
import threading

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'dist' / 'uiux-preview'
SCREENS = [
    ('dashboard-light-ru', 1440, 980), ('dashboard-dark-ru', 1440, 980),
    ('editor-light-ru', 1440, 980), ('editor-dark-ru', 1440, 980),
    ('editor-compact-ru', 960, 800), ('dashboard-light-en', 1440, 980),
    ('combine-light-ru', 1440, 980),
]
requested_fonts = set()


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def log_message(self, *_args):
        pass

    def log_request(self, code='-', size='-'):
        if self.path.endswith('.ttf') and str(code) in ('200', '304'):
            requested_fonts.add(self.path)


def main():
    chrome = shutil.which('google-chrome') or shutil.which('chromium')
    if not chrome:
        raise RuntimeError('Preinstalled Chrome is required; no browser is installed by this task.')
    OUT.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    captures = []
    try:
        for slug, width, height in SCREENS:
            target = OUT / f'{slug}.png'
            url = f'http://127.0.0.1:{server.server_port}/docs/uiux/mockups/{slug}.html'
            result = subprocess.run([
                chrome, '--headless', '--disable-gpu',
                '--disable-background-networking', '--disable-component-update',
                '--no-first-run', '--no-default-browser-check', '--disable-sync',
                '--hide-scrollbars', '--force-device-scale-factor=1',
                '--virtual-time-budget=4000', f'--window-size={width},{height}',
                f'--user-data-dir={os.environ["RUNNER_TEMP"]}/odibo-design-profile',
                f'--screenshot={target}', url,
            ], capture_output=True, text=True, timeout=50)
            if result.returncode or not target.is_file():
                raise RuntimeError(f'Chrome could not render {slug}: {result.stderr[-1000:]}')
            data = target.read_bytes()
            if data[:8] != b'\x89PNG\r\n\x1a\n' or struct.unpack('>II', data[16:24]) != (width, height):
                raise RuntimeError(f'Unexpected screenshot dimensions: {slug}')
            captures.append({'file': target.name, 'width': width, 'height': height,
                             'sha256': hashlib.sha256(data).hexdigest(),
                             'source': f'docs/uiux/mockups/{slug}.html',
                             'licence': 'MIT OR Apache-2.0; ODIBO marks: LicenseRef-ODIBO-Brand; Lucide: ISC; Inter: OFL-1.1'})
            print(f'Rendered {slug}: {width} x {height}')
    finally:
        server.shutdown()
        server.server_close()
    if not any(p.endswith('Inter-Regular.ttf') for p in requested_fonts):
        raise RuntimeError('The approved Inter font was not requested by Chrome.')
    for source, dest in [
        ('assets/odibo/LICENSE-ODIBO-BRAND.txt', 'LICENSE-ODIBO-BRAND.txt'),
        ('assets/fonts/OFL-Inter.txt', 'OFL-Inter.txt'),
        ('assets/icons/LICENSE-lucide.txt', 'LICENSE-lucide.txt'),
        ('LICENSE-MIT', 'LICENSE-MIT'), ('LICENSE-APACHE', 'LICENSE-APACHE'),
        ('NOTICE', 'NOTICE'), ('docs/uiux/UIUX_PLAN.md', 'UIUX_PLAN.md'),
    ]:
        shutil.copyfile(ROOT / source, OUT / dest)
    (OUT / 'PROVENANCE.json').write_text(json.dumps({
        'source_commit': os.environ['GITHUB_SHA'],
        'kind': 'Stage 3.1 static design mockups, not application screenshots',
        'reference_concept': 'Unavailable in the received message; comparison remains pending',
        'fonts_requested': sorted(requested_fonts), 'captures': captures,
    }, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    (OUT / 'README.txt').write_text(
        'ODIBO PDF stage 3.1 design proposals, not an implemented PDF editor.\n'
        'All document content, filenames and recent entries are synthetic.\n'
        'Existing approved ODIBO marks, Lucide icons and Inter fonts are reused.\n'
        'No product code, PDF engine, user documents or settings are changed.\n'
        'The owner-referenced concept was unavailable; comparison remains pending.\n', encoding='utf-8')
    lines = [f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}'
             for p in sorted(OUT.iterdir()) if p.is_file()]
    (OUT / 'SHA256SUMS.txt').write_text('\n'.join(lines) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
