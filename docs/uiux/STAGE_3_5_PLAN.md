# ODIBO PDF stage 3.5: core tools UX

Base: main 7ccaaf966e9ef7837f9ce4950cb2df4a3f5fa67c (merged PR #5).
Branch: feature/odibo-core-ux. No engine, CLI/MCP, settings schema, recovery or brand/licence changes.

Combine already supports multi-pick/drop, reorder, remove, thumbnails, expanded-page preview,
range checking, password warnings and undo/redo. Keep these paths; improve discoverability and
explain the new-document / Save As flow. Organize uses the existing selection/Edit pipeline;
make move/rotate/delete/extract understandable and hide unavailable placeholders.

Split gains explicit consecutive ranges through existing SplitBy::Before, with full coverage,
no gaps/overlaps and a bounded output preview. Output folder selection remains the existing
async picker. Split must never silently replace existing outputs: preflight the batch, then
publish each fully flushed staging file with an atomic no-clobber hard link. Other exports and
ordinary Save/Save As keep their existing semantics. On a filesystem without hard links,
refuse safely; report this portability limitation. A later-part failure can leave completed
parts, but never replaces originals. Multi-file output is not an all-or-nothing transaction.

Validation pending: cloud formatting/assets, Rust/Clippy, UI/functional tests, negative control,
security/licences, actual egui screenshots and Windows package. No local Rust or EXE execution.

Native Combine runs the existing engine method on one bounded worker, guarded against panic.
The UI remains responsive and cancellation discards the result. Its non-interruptible engine
step drains before retry, without writing any file. The synchronous automation method remains.
Split errors report how many completed outputs remain; retry should use a separate empty folder.
