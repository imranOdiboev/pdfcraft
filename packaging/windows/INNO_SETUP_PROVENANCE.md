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
| Compiler version | `7.1.0` / PE `7.1.0.0` |
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
- SetupLdr includes the older size-optimized LZMA SDK 4.40 decoder, with an express linking exception. This distribution selects its CPL alternative without modifying the source; the exception preserves separate licensing of linked code. Corresponding source accompanies the package solely as installer licence material and is not compiled into the ODIBO Rust application. Preserve the original notices and exception; do not declare all embedded runtime code public domain.
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

### Required decision for redistribution of the loader decoder

The old LZMA decoder's linking exception permits separately licensed linked code; it does **not** erase the decoder's own licence or justify describing the complete Setup as permissive-only. For this unmodified decoder, this distribution selects its offered **CPL-1.0 alternative together with the original linking exception**. ODIBO's Rust application remains MIT OR Apache-2.0 and its approved graphics retain their separate terms. No LZMA source is compiled into the PDF application.

The original [CPL section 3](https://www.eclipse.org/legal/cpl/cpl-v10.html) requires reasonable access to the Program source and preservation of its licensing information. A mere header quotation and an external source URL are not the proposed compliance mechanism. Before distributing Setup, include in the delivered package:

1. `licences/installer/CPL-1.0.txt`, the complete licence copied from [SPDX's pinned licence text](https://github.com/spdx/license-list-data/blob/v3.27.0/text/CPL-1.0.txt). The repository copy `packaging/windows/CPL-1.0.txt` has SHA-256 `9698f2ba346a875a47a9cc6bb602e3d126758774dde1f575b4f3369dc3f2574f` (LF text with final newline).
2. A `licences/installer/lzma-loader-source/` directory holding the exact corresponding decoder source from Inno commit `7d634620f1d1caca6c76e8398da7133153db9e7b`, not merely a link or empty source offer. These materials are prepared under `packaging/windows/installer-runtime-source/lzma-loader/` for copying into that distribution location. Required original files under `Projects/Src/Compression.LZMA1SmallDecompressor/LzmaDecode/` are `LzmaDecodeInno.c`, `LzmaDecodeSize.c`, `LzmaDecode.h`, `LzmaTypes.h` and `compile.bat` (stored inertly as `compile.bat.txt`, with identical bytes and its original filename recorded). Retain the original notices and include both full CPL text and Inno licence text with this source copy. `SOURCES.toml` records original upstream paths, commit, individual SHA-256 values, original Git blob identities and filename mapping. Do not copy precompiled OBJ files or unrelated upstream images/fonts into the application source tree.
3. A plain-text source inventory/readme stating that this is unchanged third-party installer-runtime source, available directly from the accompanying directory, selected under CPL-1.0 with the existing linking exception where applicable; Inno helper files retain their original Inno terms and `LzmaTypes.h` retains its public-domain notice. Identify IMR4N as distributor, not author of those components. If any distinct terms are offered by the distributor, they are offered by that distributor alone, not by original contributors. Preserve the licence's warranty and liability disclaimers for every contributor; make no warranty on their behalf.
4. Original build instructions: the upstream `compile.bat` expects Visual Studio C/C++ build tools and a local `compilesettings.bat` pointing to the user's `VSTOOLSROOT`. Its decoder command is `cl.exe /c /O2 /D_LZMA_OUT_READ /D_LZMA_IN_CB LzmaDecodeInno.c /FoLzmaDecodeInno-x64.obj` after selecting the matching MSVC environment. This rebuilds the decoder object, not the complete Delphi installer; proprietary compiler/toolchain binaries are not part of the source bundle. Keep exact upstream version/build facts rather than promising bit-for-bit reproducibility.

This source directory belongs to the **distribution's licence material**, not a new dependency or copied implementation inside the ODIBO PDF engine. The checked-in source copies were obtained from the official GitHub Git tree/blob API and verified byte-for-byte by recomputing each original Git blob ID; no source or batch file was compiled or executed. Copy only that exact recorded inventory into the canonical payload, verify the reviewed hashes, reject unexpected files, and include them in the canonical payload/checksum inventory before compiling Setup. Keep the same notices/source material in portable ZIP for consistent distribution documentation. Until the full licence and actual source inventory are present in the delivered files and verified, runtime redistribution checks must remain incomplete.

An alternative is `UseSetupLdr=no`, which avoids this old loader decoder, but the [official directive](https://jrsoftware.org/ishelp/topic_setup_usesetupldr.htm) produces at least `Setup.exe`, `Setup-0.bin` and `Setup-1.bin` instead of a single executable and changes loader-dependent version-resource behavior. It is not an interchangeable emergency flag: it requires an explicitly reviewed packaging/UI/download/metadata change and renewed acceptance. It is not enabled by this implementation.

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
