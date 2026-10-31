# Android 0.2 independent QA review

Status: source audit and test candidates only. This report does not claim that
compilation, instrumentation, screenshots or physical ARM64 acceptance passed.

Reviewer: real `android02_qa` subagent, in a separate worktree. Reviewed the Rust
worker candidate, Kotlin subprocess/SAF/ViewModel, Compose tools, prior Android
0.1 tests and the orchestrator's new rendered-order native tests. No tools or SDKs
were installed, no local builds/tests were run, and no commits or pushes were made.

## Findings

1. **P1 — Split result provenance can become ambiguous after document switching.**
   Files: `ui/ToolsScreen.kt`, `app/OdiboViewModel.kt`. Reproduce: prepare parts for
   A, open B, revisit Split. Existing prepared parts can remain while the header
   shows B. The independent `splitSources` protects against source overwrites but
   does not tell the user which batch they are exporting. Preserve and display
   the original prepared batch title, or explicitly separate retained batches.
   Do not silently delete unsaved outputs. Reported to the orchestrator, who added
   independent `splitSourceName` state and a "Prepared from" batch label in the
   primary working copy. Source fix reviewed by contract; runtime proof awaits CI.
2. **P1 — native-only tests are not whole-UI evidence.** Added actual Compose
   actions through the real ViewModel/resolver/native worker and activity
   recreation. System picker interactions remain manual, explicitly stated.
3. **P1 — source cancellation/provider failure paths need direct evidence.** Added
   same-source refusal, pre-write cancellation, actual read-only provider failure
   and source SHA-256 checks. This does not establish real ENOSPC, unresponsive
   providers or hard OOM handling; these remain honest acceptance limits.
4. **P2 — screenshots must survive test teardown and be actual images.** Tool
   captures use app-only drawing, file-ready/host-collected acknowledgments and
   real PNG validation. Expected filenames are coordinated with the root CI
   collector. Test-only provider must be absent from the distributed APK.
5. **P2 — partial Split exports cannot be described as transactional.** Source
   review confirms no provider-file rollback/deletion and an explicit partial-new-
   file warning. `savedToolCopies` is assigned only on complete success; a failed
   batch may have created new files and must not display an all-success result.

## Safety observations

- ProcessBuilder receives argument lists; no shell/JNI/unsafe bridge is added.
- Native paths use create-new semantics. Shared input/object/decoded-content
  budgets, signed/encrypted refusal and output reopen checks are preserved or
  tightened; no universal OOM guarantee follows from a size threshold.
- SAF source-equivalent URI/document-ID checks run before writable streams.
  Split destinations are newly named, checked against a snapshot of child IDs
  and protected sources, then SHA-256 read back. A malicious provider can alias
  underlying data in ways an app cannot universally detect; do not promise more.
- Current document state is retained on pre-install failures. Split outputs and
  viewer working copies have separate ownership to avoid cleanup deleting a
  currently opened result.
- Blocking provider I/O can delay cancellation. Private outputs or partial new
  exports must not be reported as fully saved on cancellation/failure.

## Delivered test sources

- `androidTest/AndroidManifest.xml`: instrumentation-only provider declaration.
- `PdfToolsFixtureProvider.java`: read-only procedural vector-PDF provider.
- `ToolsUiAcceptanceTest.kt`: real Combine/Split/Reorder, RU/dark, recreation,
  genuine screenshots and source/cancel/failure assertions.
- `PdfToolsSafProvider.java` and `SafToolsAcceptanceTest.kt`: test-only SAF contract
  provider; actual new-document export of native Split outputs, SHA-256 read-back
  and native reopening; pre-write old-document-ID refusal, controlled write-open
  denial, read-back corruption and cancellation after one complete new output.
  No production provider or signature storage permission is introduced.
- Root's `PdfToolsAcceptanceTest.kt`: independently rendered output page order,
  reopen, source SHA-256 and worker validation tests (reviewed, root-owned).

The orchestrator must record actual current-head CI results separately. No phone
was available; physical ARM64 testing was not conducted. No recommendations were
silently dropped: full SAF picker automation and real memory/disk-exhaustion tests
remain explicit limitations rather than fabricated green checks.

Revision history: 2026-10-31 — independent source audit and added instrumentation
test candidates; pending integration and CI.

CI investigation: run 41173947311 passed ARM64 packaging, 16 native tests and four Kotlin JVM tests; emulator execution stopped after a standalone test-provider process could not load the target APK Kotlin runtime. Both instrumentation-only providers were translated to Android/Java APIs without adding dependencies or moving them into production. Full emulator verification remains pending a fresh run.
