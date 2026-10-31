# Android 0.1 verification plan

Status: **planned; results must be recorded from actual CI/device runs**.
Tests present in source are not marked passed until their run succeeds.

Use only procedurally generated synthetic PDFs: coloured vector rectangles and
standard PDF objects, no third-party fonts, images or personal documents.

## Automated proof

`NativeWorkerAcceptanceTest` runs the actual packaged Rust worker via
`ProcessBuilder`, including executable discovery and permission checks. It requires
real inspect/rotate/save/reopen behavior, original SHA-256 preservation and Android
`PdfRenderer` rasterization of nonblank pages. A missing worker fails the test; no
fake bridge, JNI substitution or ignored native-load assertion is allowed.

Its failure scenario checks corrupt input, invalid page index and refusal to
overwrite an existing destination. Test timeout cleanup is not counted as a
successful operation. The test deletes only its own UUID-named cache directory.

Run it through `:app:connectedDebugAndroidTest` on the CI emulator. The accelerated
x86_64 native worker tests Android process/render behavior; it does not establish
that the separately built ARM64 APK runs on a physical ARM64 device. Inspect that
APK's ABI, native PIE, package, API level, permissions, ELF and ZIP alignment,
debug signing and SHA-256 independently.

Host Rust tests must also exercise actual incremental saving, password/encryption
refusal, signed-PDF refusal, compressed metadata limits, unchanged source and
existing-destination rejection. Rust formatting/Clippy, licence and asset gates
remain required; Windows/Linux checks must stay enabled.

## Manual/provider and lifecycle matrix

Every entry starts **Not tested**. Record actual device/Android/ABI/build SHA and
pass/fail evidence separately; do not infer these from host tests or APK assembly.

| Scenario | Expected behavior | Initial status |
|---|---|---|
| Physical ARM64 install/launch | Correct brand and version; functional Home | Not tested |
| SAF local provider open | Pages/count correct; original opened read-only | Not tested |
| Open from file manager ACTION_VIEW | Granted content URI opens; missing grant gives useful error | Not tested |
| Cancel open/export pickers | Working state and original unchanged | Not tested |
| Revoked/deleted/moved URI | Recoverable choose-again action, no crash | Not tested |
| Unknown size/nonseekable provider | Bounded import into private file or useful refusal | Not tested |
| Save new copy with colliding filename | Provider creates new output; original not truncated | Not tested |
| Provider returns source-equivalent URI | Export refused before opening writable stream | Not tested |
| Read-only provider/output fails after N bytes | Error; source/work preserved; partial new result identified | Not tested |
| Rotate selected page and reopen export | Correct page rotated; others unchanged | Not tested |
| Repeated open/close and rapid scrolling | Bounded caches; no leaked pages/descriptors/processes | Not tested |
| RU/EN × light/dark | Readable labels, errors and licences | Not tested |
| Small portrait/landscape, large font scale | Reachable controls; no clipped critical actions | Not tested |
| Pinch/pan plus list scrolling | Real page scale/pan, predictable vertical navigation | Not tested |
| Background/resume and rotation | State restored without duplicate operation/export | Not tested |
| Process death and storage pressure | Safe recovery or explanation; original preserved | Not tested |
| 16 MiB/2,000-page boundaries, huge pages | Clear limits; no uncontrolled bitmap allocation | Not tested |
| Corrupt/encrypted/signed PDFs | Clear refusal as appropriate, no permission bypass | Not tested |
| No network / merged manifest audit | No INTERNET, analytics, broad storage permission or document logging | Not tested |
| Backup/device-transfer rules | Private documents not unintentionally included | Not tested |

Android's normal `ACTION_CREATE_DOCUMENT` does not overwrite an existing named
file, but custom providers and partial-write failures still require defensive tests.
SAF export should not be described as universally atomic. See
[Android storage guidance](https://developer.android.com/training/data-storage/shared/documents-files).

## Independent agent audit record

Four responsibilities are required: Rust compatibility, Android UI/UX, Android
build/integration and QA/security/documentation. Record each agent's real returned
audit in the PR. The QA audit identified source/export safety, JNI/process memory
duplication, bounded decoded metadata, renderer lifetimes, grant revocation and
honest ABI/device evidence as priority checks. Their presence here is a test plan,
not proof that the risks have all been eliminated.

For screenshots, capture the real app with synthetic documents and approved Inter
typography. Avoid system picker/status-bar artwork or unapproved fonts; do not use
HTML or generated mockups as evidence of a working Android interface.

## Results log

Populate only after actual execution: run URL, source SHA, toolchain/API/ABI,
native tests, Kotlin/lint tests, instrumentation totals, APK filename/hash, real
screenshots, failed/skipped checks and remaining physical-phone acceptance.

## Revision history

- 2026-10-31: first independent QA plan and real-worker instrumentation scenarios.
