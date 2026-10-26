"""Validate permanent README images, local links, anchors and asset digests."""
import hashlib
import json
from pathlib import Path
import re
import tomllib
from urllib.parse import unquote, urlsplit

root = Path(__file__).resolve().parent.parent
manifest = tomllib.loads((root / "ATTRIBUTION.toml").read_text(encoding="utf-8"))
assets = {a["path"]: a for a in manifest["asset"]}
documents = [root / "README.md", root / "README.ru.md", root / "docs/screenshots/odibo/PROVENANCE.md"]
documents += sorted((root / 'docs').glob('ODIBO_WINDOWS*.md'))
documents += [root / 'docs' / name for name in ['ODIBO_M4_0_MANUAL_CHECKLIST.md',
              'ODIBO_RELEASE_NOTES_TEMPLATE.md', 'ODIBO_BUG_REPORT.md']
              if (root / 'docs' / name).is_file()]
checked = []; external = set(); images = set()
for document in documents:
    text = document.read_text(encoding="utf-8")
    targets = re.findall(r'\]\(([^\s)]+)(?:\s+"[^"]*")?\)', text)
    targets += re.findall(r'<img\b[^>]*\bsrc="([^"]+)"', text)
    for target in targets:
        parsed = urlsplit(target)
        if parsed.scheme:
            assert parsed.scheme == "https", f"Unexpected link scheme: {target}"
            external.add(target); continue
        path = (document.parent / unquote(parsed.path)).resolve() if parsed.path else document
        assert path.is_relative_to(root), f"Link escapes repository: {target}"
        assert path.is_file(), f"Missing local link from {document.name}: {target}"
        if parsed.fragment and path.suffix == ".md":
            headings = re.findall(r'^#{1,6}\s+(.+?)\s*#*$', path.read_text(encoding="utf-8"), re.M)
            slugs = {re.sub(r'[^\w\s-]', '', h.lower()).strip().replace(' ', '-') for h in headings}
            assert unquote(parsed.fragment) in slugs, f"Missing heading: {path.name}#{parsed.fragment}"
        if path.suffix.lower() == ".png":
            relative = path.relative_to(root).as_posix(); images.add(relative)
            assert relative in assets, f"Missing attribution: {relative}"
            assert hashlib.sha256(path.read_bytes()).hexdigest() == assets[relative]["sha256"], relative
            if relative.startswith("docs/screenshots/odibo/"):
                assert path.read_bytes().startswith(b"\x89PNG\r\n\x1a\n"), relative
                assert "actions/runs/" in assets[relative]["source"], f"Missing capture source: {relative}"
        checked.append({"document": document.relative_to(root).as_posix(), "target": target})
assert len([p for p in images if p.startswith("docs/screenshots/odibo/")]) == 5
print(json.dumps({"checked_local_references": len(checked), "images": sorted(images),
                  "external_links_for_review": sorted(external), "result": "passed"}, ensure_ascii=False, indent=2))
