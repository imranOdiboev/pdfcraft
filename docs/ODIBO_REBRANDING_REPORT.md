# ODIBO PDF — Windows x64 rebranding

Status: implementation in progress; isolated verification pending. Updated 2026-10-22.

## Scope

Branch `feature/odibo-rebranding` starts at merged foundation `0508b22ce34fbfb842c9d268b307a3a4bf3cdd0a`.
Executable names are `odibo-pdf.exe` and `odibo-pdf-cli.exe`, product ODIBO PDF,
project representative / Manufacturer IMR4N. Internal Rust package names are retained.
No release, payment integration, signing identity or merge is authorized by this work.

UI labels and translation catalogues use ODIBO PDF. ArtCraft graphics and affiliation
claims are excluded. Links point to the real fork and its issues, preserving command IDs.
The existing PDF engine and operations are retained; PDF private keys and compatibility
identifiers are not globally renamed. New-document Producer and new annotation default
author identify ODIBO; existing document authors are not replaced by this work.

## Independent data

Windows per-user storage uses ODIBO PDF; XDG directories use `odibo-pdf`.
Portable data uses `ODIBOPDFData`; logs use `odibo-pdf.log` and rotated names.
Recovery, clipboard and single-instance sockets use ODIBO namespaces. The former
PrintCraft-to-PdfCraft automatic folder move is removed, and upstream preference keys
are not loaded. Opt-in control/MCP authentication and path confinement remain in place.

The future MSI template has separate UpgradeCode, component GUIDs, registry keys,
ProgIDs, executable registrations and shortcuts. This stage packages a portable test
ZIP; it does not certify installation/upgrade/uninstallation or publish an MSI.

There is no configured update service. Manual checks return an explicit disabled
message without querying upstream. The no-source UI path does not open upstream
release pages. No automatic update request is added.

## Brand assets and licences

See `assets/odibo/PROVENANCE.md` and `assets/odibo/LICENSE-ODIBO-BRAND.txt`.
IMR4N reports original generation through ChatGPT/OpenAI. Original PNGs are preserved,
with per-file SHA-256 entries for sources and derivatives. The brand has separate
LicenseRef-ODIBO-Brand terms; code remains under its applicable open licences.
Original PdfCraft authors, MIT/Apache texts and required dependency notices are preserved.
No exclusive AI copyright or trademark registration is asserted.

Windows ICO contains PNG-compressed 16, 32, 48, 64, 128 and 256 px entries; standalone
PNGs also include 512 and 1024 px. No vector master is claimed. Generative cutouts
showed edge artefacts; final visual acceptance, particularly pale details and small
icons, must be checked in the rendered application. The light logo preserves the
original raster; the dark logo uses a navy matte and pale letters for contrast.

The `unbranded` desktop feature excludes ODIBO image includes. CI checks a build
with `assets/odibo/` physically absent; it does not grant permission to distribute a
different product under the ODIBO identity. Original open components remain usable
under their own licences.

## Verification

Results will be filled from completed Actions runs, not inferred from source review.
Planned gates: formatting, clippy, workspace tests, RustSec/licence checks, assets and
layering, WASM compatibility, unbranded build, required Linux PDF oracles, Windows
release acceptance, PE metadata, ICO structure, native Windows startup/control
screenshots and Home/About light/dark headless screenshots.

Synthetic acceptance checks open/combine/split/save/reopen, page order/text and source
byte preservation, Cyrillic paths, invalid ranges and failed writes. No user PDF is
uploaded or used. Tests execute in standard GitHub-hosted runners, not the user's PC.

## Download and manual checks

After a successful run, download the `odibo-rebranding-windows-x64-…` ZIP artifact from
**Actions → ODIBO Windows test build**. Sign in to GitHub; retention is seven days.
Extract the complete archive and run `odibo-pdf.exe`; keep the licence and model files.
Screenshots are separate UI QA artifacts. The final run and PR links are pending.

The owner must still check Explorer/taskbar icon appearance, Windows light/dark and
high-DPI monitors, real GPU/driver behavior, printing, recovery after interruption,
and coexistence with their installed PdfCraft. Automated runner screenshots are not
a manual hardware test. Use copies of disposable PDFs for initial checks.

Before public distribution: finish visual acceptance, verify marks in target markets
and original AI service terms, choose signing/distribution/update arrangements, and
test any eventual MSI install/upgrade/uninstall on a clean VM.

## Later platforms

Web: separate identity/storage/cache, offline behavior, hosting/privacy and notices,
followed by actual browser acceptance; a WASM compile is only compatibility evidence.
Android: choose a UI/runtime integration and Android package identity, sandboxed file
access/lifecycle, rendering performance, notices and a dedicated build/test pipeline.
Neither platform is delivered by this Windows stage.
