# Android 0.1 foundation audit

Status: historical Android 0.1 design audit. PR #13 subsequently merged;
[run 41134714016](https://github.com/imranOdiboev/pdfcraft/actions/runs/41134714016)
passed ARM64 packaging and x86_64 Android emulator checks. Physical ARM64
acceptance remains outstanding. The candidate/risk descriptions below record the
original design review, not a claim that every listed risk was tested on a phone.
Android 0.2 work is tracked in [its stage report](ODIBO_ANDROID_0_2.md).

## Baseline

Windows Beta 1 is published at `v0.10.1-beta.1`, source
`f26ed5860826b5ecff119caa2b0476994000e45e`. Android starts from that main revision in
`feature/odibo-android-foundation`. The release CLI path defect is tracked separately
in PR #12; it is deliberately not folded into Android work.

## Four independent audits

Real agents `android_core`, `android_ui`, `android_build`, and `android_qa` reviewed
the design. Three ran first; QA was queued until a slot became available.

* Core: `cos` and `organize` expose existing open, page-count, rotation and incremental
  save operations without importing the desktop façade's printing, OCR, JS and signing
  dependencies. `render`, `model`, `edit` and `platform` need actual ARM64 compilation;
  audit alone is not evidence of compatibility.
* UI: separate Compose screens, state, SAF access, rendering and native work. First
  vertical slice is open, view, rotate, save a new copy and reopen. Unsupported tools
  stay in backlog rather than appearing as enabled actions.
* Build: isolate Android build files and native workspace; pin tools, inspect the APK
  and ELF architecture/alignment, distinguish ARM64 delivery from x86 emulator tests.
* QA: keep original URIs read-only, reject the same document as export destination,
  bound input/output/rendering, retain work on failed export and test actual PDF output.

## Owner-directed bridge: no JNI and no unsafe

The owner explicitly selected a bridge without JNI and without unsafe. The candidate
is an isolated Rust command process packaged as an extracted native executable in the
APK. Kotlin uses argument-based `ProcessBuilder`, never a shell. The executable's
`.so` packaging name does not make it a shared library: CI must verify it is a real
ARM64 executable and prove Android can start it from `nativeLibraryDir`.

Protocol: `inspect INPUT` returns bounded metadata JSON; `rotate INPUT OUTPUT PAGE`
rotates a zero-based page clockwise by 90 degrees using existing Rust operations and
creates a new private output. Errors have nonzero status and safe messages. A worker
failure must preserve the current working document and original. This approach avoids
native pointer lifetime and JNI unwind boundaries; it still requires runtime proof.

No exception to `unsafe_code = forbid` is being applied. Android Kotlin/Compose was
explicitly authorized by the owner; existing Rust-only guidance does not prohibit it.

## Rendering and storage

The candidate viewer uses Android's platform `PdfRenderer`, not a bundled second PDF
engine. This keeps the first mobile viewing path independent of desktop rendering
configuration while Rust performs edits. It is not a claim that the Rust renderer is
incompatible: cross-compilation is checked separately and future unification remains
possible. See [PdfRenderer](https://developer.android.com/reference/android/graphics/pdf/PdfRenderer).

Use [SAF](https://developer.android.com/training/data-storage/shared/documents-files),
private bounded temporary copies and `CreateDocument`. No broad storage or network
permission is needed. SAF exports are not generally atomic: a failed export can leave
a partial new file, but must never overwrite the original or discard the working copy.
Persist recent access only when a real read grant exists. Exclude documents from backup.

Render only visible pages off the main thread, serialize descriptor/page access and
bound bitmap memory. Stream-limited COS documents cannot be saved by the existing
writer; a lower inspection limit alone must not be advertised as a safe editing budget.
An OOM abort cannot be caught with `catch_unwind`; process isolation and conservative
limits must be tested, and remaining device limitations reported honestly.

## Gates before acceptance

1. Cross-compile selected core components and the safe native worker for ARM64.
2. Run synthetic rotate/save/reopen tests and prove source bytes unchanged.
3. Build APK and verify identity, debug signing, permissions, ABI and required notices.
4. Prove real worker execution, real page rendering and lifecycle behavior on an emulator;
   report its ABI explicitly. An x86 emulator cannot establish ARM64 runtime acceptance.
5. Obtain owner testing on an ARM64 phone; do not label compilation as phone testing.

Reuse only approved ODIBO graphics and Inter fonts as generated build inputs. Their
original licence/provenance files remain required. No proprietary system-font
screenshots, fake viewer screenshots, Google Play publication or public Android release.

Revision history: 2026-10-30 — four-agent audit and owner-directed no-JNI PoC recorded.
