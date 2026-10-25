# ODIBO PDF M3.7 — quality and beta preparation

Status: implementation and isolated verification in progress, 2026-10-26.
Base main `8e0cd08b44819a0a6e9c932b96eb257655e925a6` contains merged PR #7.
Product branch: `feature/odibo-beta-readiness`; independent documentation worktree/branch:
`feature/odibo-readme-showcase`. No merge, official release or stage 4 work.

## Actual team

Four genuine Codex subagents were spawned with the collaboration runtime:
`/root/pdf_reliability`, `/root/ux_accessibility`, `/root/performance_security`,
`/root/documentation_showcase`. The runtime allows three concurrent subagents; the fourth
started after the first audit completed. New role TOMLs were added, preserving the existing
three roles and configuration. No claim is made that the client hot-reloaded new role files.

The first three agents independently inspected code read-only and then reviewed the draft fixes.
They did not build/run applications locally, install software, edit files or dispatch CI.
The documentation agent edits only the assigned isolated worktree. The lead alone integrates
product changes and coordinates manifests/generated files and GitHub checks.

## Findings, reproduction and disposition

| Priority | Agent | Evidence and reproduction | Change / verification |
|---|---|---|---|
| P0 | Reliability | `files.rs::extract_selection`: separate extraction into an existing destination, including Windows `Report.pdf` alias of source `report.pdf`, atomically replaces it without asking | Existing no-clobber writer and batch preflight; deletion callback only after successful publication; source/output byte regressions and Windows alias test |
| P0 | Performance/security | `ocr_ui.rs::ocr_files_to`: batch OCR chooses original folder, writes same names through replace-capable writer | Preflight plain filenames and existing outputs, then no-clobber publication; model-independent source collision test |
| P1 | Reliability, final review | `ocr_ui.rs::poll_ocr`: background job recognizes old page indexes, then applies after a user edit/reorder | Capture edit generation with the job and refuse stale/closed-document results with a localized persistent message; model-free injected completion checks unchanged, edited, undone and closed cases; production-guard negative control |
| P1 | UX/accessibility | `print_ui.rs::body`, `dialogs.rs`: fixed 820-point settings+preview exceed 820x520 window | Bounded scrolling, stacked compact preview, footer outside scroll; RU/EN themes/DPI matrix and genuine captures |
| P2 | Reliability | `files.rs::split_active`: valid long source/bookmark names generate overlong components; truncation can merge names | Existing Unicode-safe 200-byte stem helper, then case-insensitive deduplication; long Cyrillic output regression |
| P2 | Performance/security | `ocr_ui.rs`: spawn error discarded or worker panic never publishes completion | Spawn error returns without storing a run; guarded worker publishes failure; injected panic regression |
| P2 | Performance/security | `ocr::recognize`: `width*height*4` overflows before hostile-dimension validation | Checked dimension/channel validation and 64-megapixel bound before allocation/backend; model-free regression |
| P2 | UX/accessibility | `palette.rs`: Tab focus repeatedly stolen by search, result focus and arrow selection diverge | Initial focus only, visible row focus, synchronized keyboard selection and concrete command acceptance |
| P2 | UX/accessibility | `panels.rs::outline_item`: bookmark/disclosure focus invisible, disclosure unlabeled | Shared focus rings, localized disclosure action/state, arrow expansion/collapse without editing PDF |
| P3 defensive | Reliability | Non-separate extraction ignores result-open failure before delete-pages action | Gate deletion on `try_open_created`; no naturally occurring source producing this failure was established |
| Documentation | Showcase | README points only to old rebranding run and has no permanent current gallery | Separate EN/RU product README, genuine cloud egui captures with manifest/provenance, honest test download instructions |

These are initially source-level findings, not a claim that all were manually reproduced on Windows.
Passing and failing-before-fix runtime evidence will be linked in the final PR reports.

Independent draft reviews caught a duplicate visibility token, an incorrect test command ID,
and a palette focus/arrow regression; those were corrected before the first CI submission.
The full CI then detected eight existing wide Print interaction regressions and a missing
Enter activation on a focused custom palette row. The wide layout now keeps its original
bounded `horizontal_top` behavior; compact scrolling is isolated from it. Custom rows
explicitly handle Enter/Space. Existing test assertions were retained; rerun results are pending.

## Preservation and limits

No PDF engine rewrite, public CLI/MCP command change, saved settings schema/recovery change,
new paid service, dependency, font or proprietary image. Existing MIT/Apache notices and separate
ODIBO brand terms remain. `deny.toml` retains its five inherited advisory exceptions; no new exception.

No-clobber publication requires hard-link support, such as local NTFS. This limitation now also
applies to separate page extraction and batch OCR. Multi-file operations are not all-or-nothing:
completed new files may remain after a later failure; existing files are never silently replaced.
Split remains synchronous; Combine cancellation drains its current engine step; Undo retains
100 recent actions. Large files still use full-buffer paths; a broader engine redesign is deferred.
Batch OCR has no cancellation; no user-facing invocation of the existing single-job
`cancel_ocr` helper was found. No new UI cancellation capability is claimed.

Russian UI/paths/comments are distinct from OCR: shipped models cover English/basic Latin and
do not recognize Cyrillic. Russian OCR requires a separately evaluated model/backend, quality,
licensing and performance work. No nonfunctional language option was added.

## Evidence plan

- Windows/Linux Rust, Clippy, WASM, source safety, external qpdf/Poppler, security/licence gates.
- CLI scenarios A–C already cover source-preserving open/render/combine/split/save/reopen and
  errors; added D/E cover move/rotate/delete, Cyrillic filenames/comments/typed visual signature,
  save/reopen/render. A visual signature is not a cryptographic signing certificate.
- Targeted egui regressions include real controls, RU/EN, both themes and scale variants.
- Reproducible diagnostics: fresh release CLI processes, one warm-up + five samples, fixed
  50/500-page synthetic vector PDFs, elapsed time, Linux max RSS, all raw samples and source hashes.
  These are shared-runner CLI observations, not native GUI latency or an improvement claim;
  Windows memory is not measured by this harness. Large scanned/gigabyte files are not covered.
- A separate debug-profile headless egui/wgpu diagnostic records one warm-up and five fresh
  settled captures of a font/image-free 500-page vector fixture. It requires a successful page
  raster and no page errors. The interval includes harness/GPU/font setup and settling frames,
  excludes Cargo/process startup and PNG encoding/writing, and is not native Windows first paint.
  Retained raster surfaces are reported separately and are not process RSS.
- Genuine Linux egui screenshots and separate Windows package identity/startup captures;
  never label Linux captures as native Windows. Permanent README PNGs receive SHA-256 and
  attribution, generated `ATTRIBUTION.md`, asset and link checks in the documentation branch.
- [Limited beta user test plan](ODIBO_BETA_USER_TEST_PLAN.md): 20–30 volunteers, synthetic data,
  voluntary feedback, no private PDF uploads, balanced PDF24/PDFgear comparison. No participants
  or results have been invented; owner recruits and decides acceptance.

Final counts, skips, measurement values, unresolved issues, screenshots, ZIP hashes and both
PR links will be recorded after actual GitHub Actions results. Nothing is installed locally.
