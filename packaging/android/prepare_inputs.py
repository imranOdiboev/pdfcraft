"""Generate Android copies only from the existing attributed resources."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tomllib

parser = argparse.ArgumentParser()
parser.add_argument("--native", type=Path, required=True)
parser.add_argument("--abi", choices=["arm64-v8a", "x86_64"], default="arm64-v8a")
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
output = root / "android/app/build/generated/odibo"
manifest = tomllib.loads((root / "ATTRIBUTION.toml").read_text(encoding="utf-8"))
assets = {a.get("path"): a for a in manifest["asset"] if a.get("path")}
copies = {
    "assets/fonts/Inter-Regular.ttf": "res/font/inter_regular.ttf",
    "assets/fonts/Inter-Medium.ttf": "res/font/inter_medium.ttf",
    "assets/fonts/Inter-SemiBold.ttf": "res/font/inter_semibold.ttf",
    "assets/odibo/icon-256.png": "res/drawable/odibo_icon.png",
}
provenance = []
for source, destination in copies.items():
    entry = assets[source]
    data = (root / source).read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest != entry["sha256"]:
        raise ValueError("Attributed asset digest mismatch: " + source)
    target = output / destination
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    provenance.append({"source": source, "generated": destination, "sha256": digest,
                       "licence": entry["licence"], "author": entry["author"]})
legal = output / "assets/legal"
legal.mkdir(parents=True, exist_ok=True)
for source, name in {
    "LICENSE-MIT": "LICENSE-MIT", "LICENSE-APACHE": "LICENSE-APACHE",
    "NOTICE": "NOTICE", "ATTRIBUTION.md": "ATTRIBUTION.md",
    "assets/odibo/LICENSE-ODIBO-BRAND.txt": "LICENSE-ODIBO-BRAND.txt",
    "assets/odibo/PROVENANCE.md": "ODIBO-BRAND-PROVENANCE.md",
    "assets/fonts/OFL-Inter.txt": "OFL-Inter.txt",
}.items():
    shutil.copyfile(root / source, legal / name)
(legal / "ANDROID_GENERATED_ASSETS.json").write_text(json.dumps(provenance, indent=2), encoding="utf-8")
if not args.native.is_file():
    raise ValueError("Compiled real Rust helper is required")
native_target = output / "jniLibs" / args.abi / "libodibo_core_exec.so"
native_target.parent.mkdir(parents=True, exist_ok=True)
shutil.copyfile(args.native, native_target)
print(json.dumps({"generated_assets": len(provenance), "abi": args.abi,
                  "native_sha256": hashlib.sha256(args.native.read_bytes()).hexdigest()}))
