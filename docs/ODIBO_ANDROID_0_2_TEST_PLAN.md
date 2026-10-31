# Android 0.2 verification and owner checklist

Status: tests added for CI execution; no new passing result or physical-device
acceptance is asserted by this document. Android 0.1 baseline run 41134714016
passed on the x86_64 emulator and produced a separately checked ARM64 APK.

## Automated checks

Use only code-generated vector PDFs. No personal documents, third-party artwork
or proprietary fonts are needed.

| Layer | Concrete assertion | Evidence required |
|---|---|---|
| Rust worker | Combine/Split/Reorder use the existing core, reopen, preserve content/order and sources | Actual test log and counts |
| Rust validation | Invalid permutations/cuts, signed/encrypted/corrupt/compression-bomb inputs, size limits and existing destinations fail safely | Actual test log |
| Kotlin unit | Complete 1-based partition parsing, gaps/overlaps/overflow, full permutation and aggregate size validation | JUnit XML; NO-SOURCE is not a pass |
| Native Android instrumentation | `PdfToolsAcceptanceTest` runs the real worker; compares rendered page hashes and original SHA-256 | Emulator JUnit XML |
| Real Compose UI | `ToolsUiAcceptanceTest` imports two provider PDFs, moves inputs, combines, prepares Split, changes order and recreates the activity | Emulator JUnit XML |
| SAF failure/cancel | Same-source export refused; cancellation callback prevents writes; actual read-only provider rejects a destination; source SHA-256 unchanged | Emulator JUnit XML |
| SAF positive/fault contract | `SafToolsAcceptanceTest` exports native Split outputs through real DocumentsContract calls and file descriptors, verifies SHA-256/reopen, rejects old document IDs before write, refuses write denial/read-back mismatch and cancellation after one completed new file | Emulator JUnit XML |
| Screenshots | Application-owned view PNGs, collected before uninstall, validated by signature/chunk CRCs | Actual PNGs, not text error files |
| APK | ARM64 worker, debug identity/signature, ABI/alignment, notices and no storage/network/test-provider exposure | APK verification JSON and SHA-256 |
| Regression | Existing open/view/rotate/save-copy/reopen native acceptance, Home RU/EN themes, Windows/Linux checks | Current-head CI results |

`PdfToolsFixtureProvider` exists **only** in the instrumentation APK. It supplies
synthetic first/second PDFs and denies every write. It is not shipped in the
production debug APK. The UI test injects selected URIs into the real ViewModel;
it does not pretend that Android's system picker was clicked. Processing, native
execution, Compose buttons and rendering remain real.

`PdfToolsSafProvider` is another instrumentation-only ContentProvider implementing
the queried tree/create/open portion of the SAF contract. It deliberately avoids
the framework DocumentsProvider subclass's signature `MANAGE_DOCUMENTS` grant;
no broad permission is added to the app. It is a controlled provider, not proof
that arbitrary third-party providers or the system picker work. Its write-denial
mode refuses opening an output and its mismatch mode returns corrupted read-back
data. These are controlled failure tests, not a real ENOSPC volume experiment.

Expected genuine screenshot files:

- `tools-combine-en-light.png`: ordered input cards before actual Combine.
- `tools-split-en-light.png`: a valid full-document range preview.
- `tools-reorder-ru-dark.png`: real page thumbnails and a changed order.

The existing Home EN/light and RU/dark screenshots remain required as regressions.
Capture only app content with the approved Inter fonts/ODIBO assets; exclude
system picker/status/navigation UI. A failed collector must fail the CI gate.

## Owner's physical ARM64 checklist

Record phone model, Android version, RAM, APK SHA-256/source commit, language,
theme, orientation, font scale, provider and result. Begin with backups/test PDFs.

1. Install the verified ARM64 debug APK, launch, and check the displayed version.
2. Open a local PDF, scroll/zoom/navigate, rotate, save a new copy and reopen it.
3. Combine two PDFs containing distinguishable pages. Move the second above the
   first, remove/re-add one, combine, export, reopen and check exact page order.
4. Split a four-page document using `1-2, 3-4`. Verify two two-page output PDFs.
   Reject `1, 3-4`, `1-3, 3-4`, backwards/empty/out-of-range inputs and a single
   unsupported extraction range. No files should be claimed saved on refusal.
5. Reorder pages using accessible up/down controls, background/resume and rotate
   the phone before Apply. Verify the draft order survives normal recreation;
   apply, inspect and save/reopen a new copy.
6. Cancel open/export pickers and supported in-progress operations. Verify the
   original is unchanged and no partial output is reported as successful.
7. Try a read-only/revoked provider, disconnect removable storage and test limited
   free space on a disposable test volume. Do not fill the owner's normal disk.
8. Compare original SHA-256 hashes after every operation. Inspect complete and
   partial **new** exports after failures; SAF is not an atomic multi-file save.
9. Repeat main paths in RU/EN, light/dark, portrait/landscape, large font/display
   scale, and with TalkBack/keyboard if available. Critical buttons must remain
   reachable; drag-only controls are not required.
10. Test process death separately from ordinary backgrounding. Tool queues/results
    are not currently promised to survive process death. Export important results.

## Explicitly unproven cases

Physical ARM64 execution, manufacturer/provider quirks, real ENOSPC mid-write,
hard OOM/process termination and universal memory guarantees remain separate
manual/stress acceptance. A provider denying writes is genuine failure-path
coverage, but is not a real-full-disk experiment. A cancellation callback test is
not proof of instant interruption of an unresponsive provider.

No public release, Google Play upload, PR merge or Android 0.3 work is authorized.

Revision history: 2026-10-31 — independent QA plan and CI-only instrumentation
candidates prepared; results pending actual execution.
