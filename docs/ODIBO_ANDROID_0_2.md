# ODIBO PDF Android 0.2 — PDF Tools

Status: implemented with passing Android emulator and ARM64 packaging evidence.
Current-head checks and download links are maintained in
[PR #14](https://github.com/imranOdiboev/pdfcraft/pull/14). No physical ARM64 phone
acceptance or public Android release is claimed.

## Baseline and scope

PR #13 merged as `01b35eb23bc12a2a6037f637d2c541f2e7e5c8e9`.
[Android 0.1 CI](https://github.com/imranOdiboev/pdfcraft/actions/runs/41134714016)
passed ARM64 packaging and the x86_64 API 35 emulator checks. This is evidence for
the tested worker/rendering/UI scenarios, not physical-phone or universal SAF
provider acceptance. Android 0.1 has not yet been manually accepted on a phone.

Android 0.2 is developed in `feature/odibo-android-pdf-tools`. It extends the
existing Kotlin/Compose → argument-only ProcessBuilder → safe Rust worker bridge.
Windows Beta 1, its tag, assets and binaries remain unchanged.

## Tool semantics

- Combine: select at least two PDF documents through SAF, inspect each, arrange
  their order and build a verified private output before selecting a new export.
- Split: partition the whole document into ascending, contiguous, nonoverlapping
  ranges. This is not arbitrary extraction. Export every verified part as a new
  document and report partial provider failures honestly.
- Reorder: preview pages, move them using accessible controls, then apply a full
  permutation and save a new copy. Duplicating or omitting pages is not Reorder.

No clouds, accounts, analytics, JNI, unsafe code or broad storage permissions are
introduced. Existing file/page/object/rendering budgets remain rejection limits,
not guarantees against every low-memory condition. Combine inputs share the
16 MiB budget. New tools cap each result at 16 MiB so that the unchanged
import/inspect path can reopen it; the complete Split batch is capped at 32 MiB.
At most 32 input documents or Split parts are accepted. Compressed non-image
content is additionally bounded before invoking existing organize operations.

## Safety and limits

Original provider documents are read-only. Native outputs use fresh private paths,
are reopened before success, and are exported with read-back verification. Signed,
encrypted, reconstructed, over-budget and malformed PDFs must be refused according
to the existing Android security policy. No failure may silently replace the
current working document or claim a partial export succeeded.

SAF providers do not offer a universal atomic multi-file transaction. A failed
Split export can leave some complete new files and a partial new file. Keep the
original and private verified outputs; do not delete unrelated provider files as
rollback. Storage exhaustion, grant revocation and cancellation must be reported
separately from successful completion.

## Real agent responsibilities

Three worker slots are available concurrently; the fourth role is queued.

| Agent | Responsibility | Evidence status |
|---|---|---|
| `android02_core` | Rust worker commands, bounds, source preservation and native tests | Candidate integrated; CI pending |
| `android02_ui` | Mobile screens, RU/EN, themes, previews and accessible ordering | Candidate integrated; CI pending |
| `android02_integration` | Bridge, SAF, state, Kotlin tests, build and APK verification | Candidate integrated; CI pending |
| `android02_qa` | Independent security/functional review, device tests and test plan | Audit and tests integrated; additional provider tests in progress |

Agents use isolated worktrees. Only the orchestrator integrates into the primary
working directory. No SDK, Gradle, Rust toolchain or application is installed or
built on the owner's PC; compilation and execution belong in GitHub Actions.

Core review identified compressed-content amplification and shared multi-document
budgets; the candidate adds conservative decoding limits and aggregate checks.
UI review chose labeled up/down controls instead of drag-only reordering; this is
the supported accessible ordering mechanism, not a claim of drag-and-drop.
Integration review added protected source identities, fresh SAF names and read-back
hash verification; blocking provider I/O can still delay cancellation. Independent
QA found stale Split result provenance after a document switch: a separate batch
source label now distinguishes prepared results from the current viewer document.
See [QA findings](ODIBO_ANDROID_0_2_QA_REPORT.md) and the
[test plan](ODIBO_ANDROID_0_2_TEST_PLAN.md).

Tool queues and prepared Split results survive ordinary background/rotation through
the ViewModel, but are not promised to survive process death. The working document
retains the existing restoration path. No universal ENOSPC, hard-OOM or malicious
provider guarantee is claimed. Arbitrary extraction, drag ordering and new PDF
engine capabilities were deliberately excluded from this stage.

## Acceptance evidence

[Run 41174958886](https://github.com/imranOdiboev/pdfcraft/actions/runs/41174958886)
on source `c0ac2d3b39711eee07b4128cd7e709e3c85646d4` passed 16 Rust tests,
Clippy with warnings denied, formatting, four Kotlin JVM tests, Android lint,
ARM64 assembly/verification and nine API 35 x86_64 instrumentation tests.
JUnit reports contain zero failures, errors or skips. Evidence includes actual
rendered page order, original SHA-256, native reopen, SAF export/read-back,
failure/cancellation cases and Compose tool actions with orientation/recreation.
The orchestrator and QA independently inspected downloaded reports, APK hashes
and five genuine PNGs. Updated results after the export-retry counter regression
are recorded in the PR; use the current verified artifact rather than assuming a
historical APK belongs to a newer source commit.

Screenshots cover Home EN/light and RU/dark, Combine and Split EN/light, and
Reorder RU/dark. They are real emulator app-content captures, not phone testing
or a complete device/font-scale/theme matrix. Windows/Linux CI, advisories and
licence gates are reported separately in the PR. The existing nightly fuzz job
is schedule-only and is skipped by its normal condition on pull requests; it was
not disabled by this stage.

No PR merge, Android release, Google Play upload or Android 0.3 work is authorized.

Revision history: 2026-10-31 — baseline verified; implementation and four-agent
verification plan started.
