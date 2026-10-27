# ODIBO installer cancellation investigation

Status: **Cancel passed nine times on the full application Setup; a subsequent silent-folder refusal hung and its correction is awaiting CI**.
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

### Subsequent full-run result and independent audit

[Full run 40390282213, Windows job 121834838121](https://github.com/imranOdiboev/pdfcraft/actions/runs/40390282213/job/121834838121)
passed GUI/CLI compilation, release acceptance, real GUI startup, Windows core tests,
package construction and **all nine real Cancel cases**. Its next scenario, refusing
a Portable destination, timed out after 180 seconds. Overall acceptance failed;
final package upload was correctly skipped. Prior generic CI also passed.

The remaining `NextButtonClick(wpSelectDir)` error used ordinary `MsgBox`. Inno calls
this event during silent installation too; `/SUPPRESSMSGBOXES` cannot suppress a
custom `MsgBox`, so the safe folder rejection blocked waiting for acknowledgment.
Two real read-only auditors, `installer_timeout_audit` and `silent_refusal_qa`,
independently reviewed this path. The correction logs a stable refusal marker,
uses `SuppressibleMsgBox`, and retains `Result := False` and all folder validation.
Interactive users still see the same warning. Silent refusal must return native
initialization exit **1**, separately from actual wizard Cancel's **2**.

A fast regression temporarily compiles the exact source with only this dialog
restored to `MsgBox`: it must observe the owned visible folder-error modal and OK
button, prove the process remains blocked for 30 seconds, then acknowledge that
specific button for diagnostic cleanup. This is not successful unattended refusal
or cancellation. The corrected source must refuse EN/RU destinations autonomously,
log the specific refusal, preserve marker/user-file hashes and full inventory, and
create no payload or registration. All nine real Cancel cases remain mandatory.
Future failed child-process timeouts also retain safe owned-window diagnostics.
The [fast regression run 40453694197](https://github.com/imranOdiboev/pdfcraft/actions/runs/40453694197)
passed: the original dialog blocked for 30 seconds, corrected EN/RU refusal exited
autonomously with code 1, and all nine real Cancel cases passed again. The
[full application run 40453694150](https://github.com/imranOdiboev/pdfcraft/actions/runs/40453694150/job/122033370407)
also passed all nine Cancel cases and Portable-folder refusal. It then failed after
installation because the registered `ODIBOAppVersion` value was missing. No final
packages were uploaded; complete Windows acceptance remains blocked.

### Installed build identity: preserve metadata after native registration

The three custom values were declared in `[Registry]` within Inno's native uninstall
key. In the pinned compiler's installation order, `CreateRegistryEntries` runs before
`RegisterUninstallInfo`. The latter deletes an existing uninstall key and recreates
it, removing our premature entries. This is an installer lifecycle error, not a
reason to remove the version/commit checks or read a less specific fallback value.

Keep the same key and field names. Write them during `ssPostInstall`, after native
uninstall registration exists; fail explicitly on an absent key or failed write.
The full application test still asserts every value, now with a clear missing-field
diagnostic. Neither version/downgrade refusal nor payload/settings protection is relaxed.

Expand the fast inert-payload fixture before another full run: temporarily restore
the original three `[Registry]` entries and remove only the post-install write call.
Require a normal install with native registration but all three custom fields absent,
then uninstall it. This expected regression is not a successful identity check.
The corrected exact source must preserve all fields through fresh install, same-build
EN/RU reinstall, removal and same-folder installation; missing metadata and a simulated
higher build must refuse without changing file inventory/hashes. Unknown synthetic
user data must survive. The fixture never runs either inert application executable
and does not replace actual PDF/GUI/settings/Portable acceptance. New results pending.

References: [pinned Inno installation source](https://github.com/jrsoftware/issrc/blob/7d634620f1d1caca6c76e8398da7133153db9e7b/Projects/Src/Setup.Install.pas),
[documented post-install event](https://jrsoftware.org/ishelp/topic_scriptevents.htm).

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

2026-10-27 — full application Setup passed nine real cancellations; subsequent
silent unsafe-folder rejection blocked on an unsuppressible custom dialog.
Independent audit and a separate old-dialog negative control added; full rerun pending.

2026-10-27 — silent refusal and nine actual Setup cancellations passed on the full
application package; installed build metadata was then erased by native uninstall-key
recreation. Move writes to post-install and add an old-timing negative control plus
metadata/reinstall/downgrade lifecycle fixture. Full rerun remains required.
