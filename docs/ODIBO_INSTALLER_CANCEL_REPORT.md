# ODIBO installer cancellation investigation

Status: **root cause reproduced; nine real fixture cancellations passed; full application acceptance pending**.
Reviewed: 2026-10-27. This report does not authorize a release or merge.

## Observed failure and exact cause

Main [run 40371883731, job 121770835349](https://github.com/imranOdiboev/pdfcraft/actions/runs/40371883731/job/121770835349)
compiled the GUI/CLI, passed their tests and GUI startup checks, and built/verified
Setup and Portable. It then failed before installation with
`Could not activate the real setup Cancel button.` Final distribution upload was skipped.

The old test requested UIA descendants with `ControlType.Button`. On the actual
Inno Setup 7.1.0 Windows runner, `TNewButton` exposes **ControlType.Pane** and an empty
supported-pattern list. Consequently the filter discarded the real Cancel control.
The 45-second deadline, localization and process ownership were not the cause.

[Diagnostic run 40388739921](https://github.com/imranOdiboev/pdfcraft/actions/runs/40388739921)
observed an interactive session 2, the original Setup EXE and its `.tmp` child in
that session, and the child's visible/enabled `TSelectLanguageForm`. Its Cancel had
matching native/UIA HWND, native class `TNewButton`, UIA type `Pane`, Enabled=true,
Offscreen=false and no InvokePattern. Both the language dialog and its controls
were available. This is metadata from the real compiled installer, not a mock UI.

## Correction and evidence

- Discover all UIA descendants, then verify Cancel/Yes name, expected owned dialog,
  native `TNewButton`/`Button` class, same live process, child HWND, visibility and
  enabled state before activating the actual button using asynchronous `BM_CLICK`.
- Follow the observed bootstrap process tree to a fixed point. Bind retained PIDs
  to process creation times and require matching session to reject PID reuse.
- Require normal exit and no destination/registration/remaining child. Explicit
  EN/RU wizard cases require both Cancel and confirmation Yes, with exit code 2.
  The separate language-selection Cancel case returns initialization-abort code 1
  and must still have a recorded real Cancel activation. Arbitrary nonzero exits
  or forced process termination are not passing evidence.
- Run three repetitions each for language selection, English wizard and Russian
  wizard: **nine mandatory cancellations** on the full real application Setup.
- Missing UIA support now fails; it no longer downgrades cancellation to manual-required.
- Save bounded owned-process/window/UIA metadata, elapsed times, activation method,
  confirmation and exit evidence on failure as well as success. Exclude command
  lines, environment dumps, account names, unrelated windows, screenshots and PDFs.
  Paths in owned control labels are redacted. Forced cleanup is recorded separately.

[Repeated-test run 40389487670](https://github.com/imranOdiboev/pdfcraft/actions/runs/40389487670)
compiled the exact installer source with an explicitly inert payload. Restoring the
old Button-only filter failed after 45 seconds and confirmed that a visible enabled
Cancel was excluded specifically by that filter. With the corrected discovery,
all **9/9** real cancellations passed, including six wizard confirmations. No
termination was counted as cancellation. The fixture is diagnostic/regression
evidence, not full installed GUI/PDF acceptance or a distributable package.

## Full acceptance and distribution gate

The existing full workflow still requires real GUI/CLI compilation, core/PDF tests,
package inventory/licence checks and Setup -> install -> installed PDF/GUI ->
settings/reinstall/running-editor refusal -> uninstall -> Portable isolation checks.
They are not replaced by the fixture. Follow the latest full workflow in
[PR #11 checks](https://github.com/imranOdiboev/pdfcraft/pull/11/checks); superseded
commit runs can be cancelled by the existing workflow concurrency policy.
No successful final package or checksum is claimed in this preparation snapshot.
Completed acceptance and received-package verification belong in the PR report.

Clean Windows 10/11, ordinary non-admin accounts/UAC, physical DPI and mid-copy
rollback remain separate manual checks. This test proves pre-install cancellation.
UIA Pane exposure is recorded, not described as screen-reader certification.
No code signing, updater, PDF-engine changes, owner-machine installation, release
or automatic merge is included.

## Reference behavior

- [Microsoft BM_CLICK](https://learn.microsoft.com/en-us/windows/win32/controls/bm-click)
  describes activation of the real button handler.
- [Inno exit codes](https://jrsoftware.org/ishelp/topic_setupexitcodes.htm)
  distinguishes initialization abort, wizard cancellation and installation failure.
- [Inno language dialog](https://jrsoftware.org/ishelp/topic_setup_showlanguagedialog.htm)
  explains the initial dialog; explicit `/LANG` cases additionally test the wizard.

Revision history: 2026-10-27 — original failing main log inspected, owned-window
probe run, old filter reproduced as a negative control, nine corrected fixture
cancellations passed. Full application acceptance remains pending.
