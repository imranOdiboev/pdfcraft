"""Collect the exact locked native dependency inventory and licence texts."""
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[2]
result = subprocess.run(["cargo", "metadata", "--locked", "--format-version", "1", "--manifest-path",
                         str(root / "android/native/Cargo.toml")], check=True, capture_output=True, text=True)
metadata = json.loads(result.stdout)
output = root / "android/app/build/generated/odibo/assets/legal"
output.mkdir(parents=True, exist_ok=True)
lines = ["Exact Rust native dependency inventory and preserved licence texts\n"]
for package in sorted(metadata["packages"], key=lambda p: (p["name"], p["version"])):
    licence = package.get("license")
    if not licence:
        raise ValueError("Unidentified Rust licence: " + package["name"])
    lines.append(f"\n{package['name']} {package['version']}\nLicence: {licence}\nSource: {package.get('source') or 'ODIBO/PdfCraft repository'}\n")
    folder = Path(package["manifest_path"]).parent
    legal = [p for p in folder.iterdir() if p.is_file() and
             p.name.upper().startswith(("LICENSE", "LICENCE", "COPYING", "NOTICE"))]
    if not legal and folder.is_relative_to(root):
        legal = [root / "LICENSE-MIT", root / "LICENSE-APACHE", root / "NOTICE"]
    if not legal:
        raise ValueError("Rust licence text missing: " + package["name"])
    for path in sorted(legal):
        lines.extend([f"\n--- {path.name} ---\n", path.read_text(encoding="utf-8", errors="strict")])
(output / "RUST_DEPENDENCIES.txt").write_text("".join(lines), encoding="utf-8")
print(f"Collected notices for {len(metadata['packages'])} Rust packages")
