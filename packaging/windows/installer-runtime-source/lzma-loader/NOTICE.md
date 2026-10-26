# Inno loader decoder: corresponding source and original notices

This directory accompanies the ODIBO PDF test installer as its **third-party installer-runtime source material**. These files are not part of the Rust PDF engine, are not compiled by Cargo, and are not automatically executed during application installation, use, or removal. IMR4N distributes this copy; IMR4N does not claim authorship of Igor Pavlov's decoder or the Inno helpers.

For the decoder files offering LGPL or CPL, this distribution selects **CPL-1.0 together with the original linking exception**. The complete licence is included as `CPL-1.0.txt`. The Inno helper `LzmaDecodeInno.c` and original build instructions retain the original Inno licence, included as `INNO-LICENSE.txt`. `LzmaTypes.h` retains its original public-domain notice. Original dual-licence headers are preserved; selecting CPL for this distribution does not delete permissions granted by upstream.

Corresponding source is available **directly from this accompanying directory**, including every local source/header included by the decoder build. No request, account, network connection or third-party source server is needed to obtain these files from the package. `SOURCES.toml` records each original filename, fixed upstream URL, licence choice, byte size, SHA-256 and Git blob identity. Copies of this directory redistributed in source form must keep the applicable licences and notices. No ODIBO changes have been made to the upstream source bytes; the existing Inno helper functions are upstream contributions.

This source copy comes from Inno Setup release `is-7_1_0`, commit `7d634620f1d1caca6c76e8398da7133153db9e7b`, directory `Projects/Src/Compression.LZMA1SmallDecompressor/LzmaDecode/`. The four C/header files retain their original filenames. Original `compile.bat` is stored as **`compile.bat.txt`** with identical bytes to keep the package inert. This filename mapping is also recorded in `SOURCES.toml`; no script was run to prepare these copies.

## Rebuilding the decoder object, if desired

These instructions document the corresponding decoder build; rebuilding is optional and is not part of installing ODIBO PDF. Use a separate working copy, restore `compile.bat.txt` to its original filename `compile.bat`, and follow the original batch file's requirements for an existing Microsoft Visual Studio C/C++ build-tool environment. It requires a local, machine-specific `compilesettings.bat` setting `VSTOOLSROOT` to Visual Studio's `Common7\Tools` directory. That local configuration and Microsoft's toolchain are not redistributed here.

For x64, the original batch file selects the MSVC x64 environment and invokes:

```text
cl.exe /c /O2 /D_LZMA_OUT_READ /D_LZMA_IN_CB LzmaDecodeInno.c /FoLzmaDecodeInno-x64.obj
```

`LzmaDecodeInno.c` includes `LzmaDecodeSize.c`, which includes `LzmaDecode.h`, which includes `LzmaTypes.h`. These are all provided here. The only conditional system header is the standard C toolchain's `stddef.h` if `_LZMA_SYSTEM_SIZE_T` is selected; the recorded original build does not select it. The provided batch instructions also support their original x86/arm64 targets. This builds the corresponding decoder object, not the complete Inno Setup loader or proprietary Delphi toolchain. No bit-for-bit reproducibility of a publisher's compiler output is asserted.

## Original decoder licensing notice

The following is reproduced from the original source header. The entire header remains in both relevant source files:

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

The linking exception does not turn the decoder itself into MIT/Apache code or remove its notices. The Rust ODIBO application retains MIT OR Apache-2.0, its original PdfCraft credits and other applicable component terms. ODIBO brand graphics retain their separate terms. These licences do not restrict rights in unrelated open components.

## Warranty, liability and distributor identity

The decoder is provided under the full CPL agreement supplied here, including sections 5 (no warranty) and 6 (disclaimer of liability) **for all contributors**. No warranty or condition of title, non-infringement, merchantability or fitness is offered on their behalf, and no contributor accepts liability for direct, indirect, incidental, special, exemplary or consequential damages, subject to the agreement and applicable law. Any differing undertaking by IMR4N is IMR4N's alone, not an undertaking by the original contributors. IMR4N makes no new modifications to this decoder and no contrary warranty in this source notice.

The installer also uses RemObjects Pascal Script; its acknowledgement and original notice are in the accompanying `INNO_SETUP_PROVENANCE.md`. This directory contains only the old loader decoder material, not every unrelated optional compiler/IDE dependency. Optional 7-Zip/unRAR extraction DLLs are not included by this packaging design.
