"""Inspect the actual APK and native ELF without executing it on the owner PC."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument("apk", type=Path)
parser.add_argument("--aapt", type=Path, required=True)
parser.add_argument("--apksigner", type=Path, required=True)
parser.add_argument("--abi", choices=["arm64-v8a", "x86_64"], default="arm64-v8a")
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
badging = subprocess.run([str(args.aapt), "dump", "badging", str(args.apk)], check=True, capture_output=True, text=True).stdout
if "name='com.odibo.pdf'" not in badging or "versionName='0.1.0-debug'" not in badging:
    raise ValueError("Unexpected application identity")
if "sdkVersion:'26'" not in badging or "targetSdkVersion:'36'" not in badging:
    raise ValueError("Unexpected SDK configuration")
permissions = subprocess.run([str(args.aapt), "dump", "permissions", str(args.apk)], check=True, capture_output=True, text=True).stdout
for permission in ("android.permission.INTERNET", "android.permission.MANAGE_EXTERNAL_STORAGE",
                   "android.permission.READ_EXTERNAL_STORAGE", "android.permission.WRITE_EXTERNAL_STORAGE"):
    if permission in permissions:
        raise ValueError("Forbidden unnecessary permission: " + permission)
subprocess.run([str(args.apksigner), "verify", "--verbose", "--print-certs", str(args.apk)], check=True)
with zipfile.ZipFile(args.apk) as apk:
    native = [n for n in apk.namelist() if n.startswith("lib/") and n.endswith(".so")]
    expected = f"lib/{args.abi}/libodibo_core_exec.so"
    if native != [expected]:
        raise ValueError("Unexpected native payload: " + repr(native))
    elf = apk.read(expected)
    if elf[:6] != b"\x7fELF\x02\x01" or struct.unpack_from("<H", elf, 16)[0] != 3:
        raise ValueError("Expected a 64-bit little-endian PIE ELF")
    if struct.unpack_from("<H", elf, 18)[0] != {"arm64-v8a": 183, "x86_64": 62}[args.abi]:
        raise ValueError("ELF architecture mismatch")
    offset = struct.unpack_from("<Q", elf, 32)[0]
    size, count = struct.unpack_from("<HH", elf, 54)
    loads = []
    for index in range(count):
        entry = offset + size * index
        if struct.unpack_from("<I", elf, entry)[0] == 1:
            loads.append(struct.unpack_from("<Q", elf, entry + 48)[0])
    if not loads or any(alignment < 16384 for alignment in loads):
        raise ValueError("Native LOAD segments lack 16KB alignment")
    required = ["NOTICE", "LICENSE-MIT", "LICENSE-APACHE", "LICENSE-ODIBO-BRAND.txt",
                "THIRD_PARTY_NOTICES.txt", "OFL-Inter.txt"]
    for name in required:
        if not apk.read("assets/legal/" + name):
            raise ValueError("Empty licence notice: " + name)
result = {"result": "passed", "package": "com.odibo.pdf", "version": "0.1.0-debug", "min_sdk": 26,
          "target_sdk": 36, "abi": args.abi, "native_entry": expected, "elf_load_alignment": loads,
          "apk_sha256": hashlib.sha256(args.apk.read_bytes()).hexdigest(), "debug_only": True,
          "physical_device_tested": False}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps(result))
