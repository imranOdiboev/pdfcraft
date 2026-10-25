# ODIBO PDF stage 3.6 — independent audit and implementation

Base: main `5ddb911b514fe50637fb4c0dce0c171319badbe3`, merged PR #6. Branch: `feature/odibo-uiux-polish`.

## Real subagents and boundaries

Three actual subagents were spawned concurrently through Codex collaboration tools:
`/root/ux_auditor`, `/root/accessibility_auditor`, `/root/qa_reviewer`.
They read the supplied `.codex/agents/*.toml` roles and repository instructions.
They did not edit files, run applications or Rust locally, commit, dispatch CI, or spawn other agents.
The main agent alone implements and integrates. Four project TOML files were validated and copied
from the owner-supplied archive with an explicit no-overwrite check. Their content is unchanged.
The current session used actual spawn tools with role instructions; this does not assert a hot
reload of newly copied client configuration. Project configuration follows the official schema:
https://learn.chatgpt.com/docs/agent-configuration/subagents

## Findings and disposition

These initial findings were verified by code inspection; runtime regression evidence is recorded in CI.

| Priority | Auditor | Reproduction and location | Smallest accepted change |
|---|---|---|---|
| P1 | accessibility | `palette.rs::show`: arrow to result 12 at 820x520; results exceed viewport | Bounded results scroll and reveal selected command, including query reset |
| P1 | accessibility | `dialogs.rs::password_modal`: Tab away from password; focus reclaimed each frame | Initial focus only; preserve action keyboard activation and IME |
| P2 | UX, QA | `widgets.rs::toast`, `files.rs::write_files_policy`: split failure details expire after 3.5s | Transient persistent operation error, selectable details, reachable Dismiss; ordinary success still expires |
| P2 | UX | `dialogs.rs` Split: invalid/gapped ranges show invented one-part preview | Hide output counts/ranges until validation succeeds |
| P2 | UX | Split configuration yields one file and disables action without explanation | Localized reason to choose at least two outputs; unchanged engine semantics |
| P2 | accessibility | `widgets.rs` primary pills: white small text on dark-theme accent/hover | Shared readable opaque primary fills and contrast regression |
| P2 | accessibility | Split numeric controls have unrelated nearby labels | Associate fields with localized labels |
| P2 | QA | `pickers.rs`: synthetic picker future panic queues no result/error | Explicit failed reply, no continuation, persistent actionable notice |
| P2 | QA | Split on a volume without hard-link support: raw OS error only | Folder guidance and localized recovery advice; no unsafe write fallback |
| P3 defensive | QA | `combine_ui.rs`: inject invalid completed result; staging cleared before fallible open | Open first, clear staging only on success; original error/cancel behavior retained |

Independent QA review of the draft also found query-change scroll retention and overly tall error
cards; both received bounded-layout fixes and targeted tests before CI.

## Recommendations deliberately not implemented

- Global translation by matching engine/OS English error strings: brittle and loses useful diagnostics.
  Localized operation context retains raw technical details instead.
- Immediate interruption of engine Combine work, asynchronous Split, or a multi-file output transaction:
  architectural work outside this polish scope. Existing bounded worker, cancellation/drain and no-clobber
  behavior remain; no pretend progress or unsafe fallback was added.
- Rewriting Home/Organize or adding decorative animation: no verified defect warrants it.
- Formal accessibility certification: automated tests and captures cannot establish it.

## Preservation and verification

No PDF engine, CLI/MCP command identifiers, saved preference schema, recovery or write policy change.
No new library, image, font, paid API or cloud dependency. MIT/Apache notices and ODIBO brand terms remain.
New copy is clean-room, all 22 catalogues retain translations and attribution hashes.
Tests and actual egui screenshots run on disposable GitHub runners; nothing is installed locally.
Final CI, test counts, screenshots and Windows x64 ZIP evidence will be attached to the separate PR.
No automatic merge, release, or stage 3.7 work.
