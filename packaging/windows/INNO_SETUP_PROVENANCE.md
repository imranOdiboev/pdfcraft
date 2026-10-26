# Inno Setup compiler and installer runtime provenance

Status: engineering test packaging, 2026-10-26. No official release or ODIBO signing certificate is implied.

The Windows Setup uses **Inno Setup 7.1.0, x64 compiler**, released by Jordan Russell and Martijn Laan on 2026-08-12. This is a build tool installed only on the disposable GitHub Actions Windows runner. It is not installed on the owner's computer. The generated Setup and its uninstaller include Inno runtime components under the original Inno licence; ODIBO source-code licences do not replace those terms.

## Fixed build input

| Field | Value |
| --- | --- |
| Official immutable release | <https://github.com/jrsoftware/issrc/releases/tag/is-7_1_0> |
| Compiler installer | <https://github.com/jrsoftware/issrc/releases/download/is-7_1_0/innosetup-7.1.0-x64.exe> |
| Size | 14,304,168 bytes |
| SHA-256 | `0362a383ed217d4c4239b5933866dd96d3eb2102737da92f80f6057a4b40df2f` |
| Authenticode requirement | Valid Windows-trusted signature, publisher `Pyrsys B.V.` |
| Compiler engine version | `7.1.0`, verified through ISCC `--version`; the official launcher PE reports `0.0.0.0` |
| Licence text source | <https://github.com/jrsoftware/issrc/blob/is-7_1_0/license.txt> |
| Local licence | `packaging/windows/INNO-LICENSE.txt` |
| Local licence SHA-256 | `0c81595601bce47eeef8d865d5da7f9ca2c6a12235b7482b29f5ab23ed02ee5a` |

Release metadata, including immutable status, size and asset digest, was checked through the official GitHub REST release endpoint. The licence text is copied from the tagged upstream source, with line endings normalized to LF and a final newline. No compiler executable was downloaded or run during the local audit.

`install-inno-toolchain.ps1` requires GitHub Actions on Windows, creates a fresh directory under `RUNNER_TEMP`, verifies size, SHA-256, trusted Authenticode status and publisher **before executing** the compiler installer, then checks the installed compiler version. It records the verification result in `VERIFIED_COMPILER.json` and exports the exact ISCC path. A failure stops packaging. No unpinned package manager or remote script is used.

The publisher documents additional immutable-release attestation verification at <https://jrsoftware.org/isdl-verify.php>. The fixed reviewed hash and Windows certificate-chain verification are mandatory here; SHA-256 alone is not described as proof of publisher identity. These compiler checks do not sign the generated ODIBO Setup.

## Licence and cost

The original licence explicitly permits commercial use. The publisher requests commercial purchases, but its FAQ says purchase is not strictly required: <https://jrsoftware.org/isorder.php>. This engineering workflow makes no purchase and uses no paid service. Preserve the original copyright and website notices; do not present Inno as software authored by IMR4N. Record other bundled runtime-component notices from the pinned compiler distribution where applicable; do not discard its third-party notices.

Copy `INNO-LICENSE.txt` into the shared verified application payload, for example `licences/installer/INNO-LICENSE.txt`, **before** creating the payload hashes. Include it in both Setup and portable ZIP so the delivered package contains the installer acknowledgement and licence. Keep all existing Cargo, font, model, PdfCraft and ODIBO notices unchanged. This file is technical/legal documentation, not permission to add unreviewed graphics or fonts.

### Installer runtime components

**The ODIBO PDF installer is made using RemObjects Pascal Script, available at <https://github.com/remobjects/pascalscript>.** This visible documentation acknowledgement satisfies its original notice requirement; it does not describe the Rust PDF application as a Pascal application.

The pinned upstream [7.1.0 SBOM](https://github.com/jrsoftware/issrc/blob/is-7_1_0/SBOM.spdx.json) distinguishes compiler-only and optional components from Setup/SetupLdr dependencies. Do not assume the whole distribution has one licence:

- Setup includes the public-domain LZMA SDK 26.02 and RemObjects Pascal Script. The latter's original notice is reproduced below from [the tagged source](https://github.com/jrsoftware/issrc/blob/is-7_1_0/Components/UniPs/LICENSE.md).
- SetupLdr includes the older size-optimized LZMA SDK 4.40 decoder, with an express linking exception. Its own LGPL/CPL terms are not changed to MIT/Apache by packaging; the exception preserves separate licensing of linked ODIBO code. We do not modify or copy decoder source into ODIBO. Preserve the original exception notice and the exact upstream source reference below. A distribution should retain applicable runtime notices, not simply declare all embedded runtime code public domain.
- The optional 7-Zip/unRAR extraction DLLs have separate LGPL, BSD and unRAR conditions. This Setup does not enable archive extraction or download functions and must not package `is7z*.dll`, `is7zxa*.dll` or `is7zxr*.dll`. Verify actual compiled output rather than assuming every compiler dependency ships.
- Scintilla is an IDE dependency and is not copied into ODIBO. Optional zlib/bzip2 compression is not selected (`Compression=lzma2`). If compiler options or embedded components change, re-review the pinned SBOM and original notices before distribution.

Original RemObjects notice (text preserved; Markdown fencing and line endings are presentation only):

```text
RemObjects Pascal Script
Created By Carlo Kok
ck@remobjects.com

Copyright (C) 2000-2014 by Carlo Kok and RemObjects Software, LLC

This software is provided 'as-is', without any expressed or implied warranty. In no event will the author be held liable for any damages arising from the use of this software.
Permission is granted to anyone to use this software for any kind of application, and to alter it and redistribute it freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented, you must not claim that you wrote the original software.
2. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
3. You must have a visible line in your programs aboutbox or documentation that it is made using RemObjects Pascal Script and where RemObjects Pascal Script can be found.
4. This notice may not be removed or altered from any source distribution.

If you have any questions concerning this license contact info@remobjects.com

Carlo Kok, RemObjects Software
```

Original LZMA size-decoder notice, from the pinned SBOM's extracted licence and [source header](https://github.com/jrsoftware/issrc/blob/is-7_1_0/Projects/Src/Compression.LZMA1SmallDecompressor/LzmaDecode/LzmaDecodeSize.c):

```text
LZMA Decoder (optimized for Size version)

LZMA SDK 4.40 Copyright (c) 1999-2006 Igor Pavlov (2006-05-01)
http://www.7-zip.org/

LZMA SDK is licensed under two licenses:
1) GNU Lesser General Public License (GNU LGPL)
2) Common Public License (CPL)
It means that you can select one of these two licenses and follow rules of that license.

SPECIAL EXCEPTION:
Igor Pavlov, as the author of this code, expressly permits you to statically or dynamically link your code (or bind by name) to the interfaces of this file without subjecting your linked code to the terms of the CPL or GNU LGPL. Any modifications or additions to this file, however, are subject to the LGPL or CPL terms.
```

This inventory is a documented engineering assessment of the pinned compiler configuration, not a legal guarantee for arbitrary future compiler outputs. Keep the source links and original notices available to recipients; re-review if runtime inspection shows additional components.

## Installation contract

`odibo.iss` takes `PayloadDir`, `OutputDir`, numeric Cargo `AppVersion`, decimal GitHub run `BuildNumber`, and forty-character source `BuildCommit`. Product version remains the Cargo version; the engineering build number and source are recorded separately in the installer and HKCU uninstall entry.

- Stable AppId: `{A7A4DC1B-3255-4BC6-9F6F-1DA0B61B6524}`.
- Default location: `%LOCALAPPDATA%\Programs\ODIBO PDF`.
- Uninstall record: `HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\{A7A4DC1B-3255-4BC6-9F6F-1DA0B61B6524}_is1` (64-bit view).
- Start Menu shortcut is installed; desktop shortcut is unchecked unless selected.
- Existing numeric version/build downgrades are blocked; reinstalling the same build is allowed.
- An existing machine-wide ODIBO installation is detected, not automatically uninstalled or migrated.
- Portable markers, data directories, nonempty unregistered destinations, profile/data roots, document directories, system paths and directory reparse-point ancestors are rejected. An installed product must update its existing directory. After a successful install, `.odibo-install-root` stores the literal AppId and intentionally survives uninstall; an otherwise permitted folder with this exact hint can be reinstalled into even when unknown user files remain. This marker is an identity hint, not cryptographic authentication. If it cannot be written, the setup log records the limitation; reinstalling into a fresh empty directory remains possible.
- Running or otherwise locked destination GUI/CLI files cause a safe failure before copying. Setup does not close processes, restart the application or run MCP. Uninstall also refuses while these executables are locked. A process started after the preflight can still race file replacement; Windows file locking and installer failure/rollback remain the final safeguard, not a guarantee against arbitrary external filesystem changes.
- No custom uninstall deletion, document deletion, settings cleanup, service, scheduled task, PATH change, default PDF takeover, network download or automatic updater exists in this script.
- The shared payload must already contain offline OCR models and their licences. Setup excludes portable markers; the portable ZIP keeps its marker and existing independent `ODIBOPDFData` contract.

Built-in wizard artwork is disabled; the Setup icon is the already approved ODIBO ICO. Dialog and welcome fonts request the existing OFL Inter family through the documented `[LangOptions]` directives. Inno does not embed that font: Windows can substitute its own runtime UI font when Inter is unavailable. Published CI screenshots require the approved Inter face to be present on that disposable runner and its use verified; do not publish screenshots of proprietary fallback typography. The script copies no system font.

## Verification limits

Local validation is static only: PowerShell parsing and source review. Actual compiler execution, Setup generation, install/reinstall/upgrade/downgrade rejection, cancellation, locked-process checks, uninstall, settings preservation and authentic installer captures must run in Windows GitHub Actions. A hosted Windows Server runner does not prove Windows 10/11 desktop, physical DPI or standard-user acceptance; retain those manual checklist items.

Legacy WiX files remain untouched. They require a separate migration decision if reused: WiX v5 is outside community support, its existing MSI is per-machine, and its payload-notice staging differs from the verified engineering ZIP. Current WiX binary commercial maintenance terms and alternatives were checked at <https://docs.firegiant.com/wix/> and <https://www.firegiant.com/>. NSIS is another viable option under its documented licences (<https://nsis.sourceforge.io/Docs/AppendixI.html>), but requires more bespoke lifecycle scripting for this beta.
