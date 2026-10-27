# ODIBO installer cancellation investigation

Status: **Full run40503319692 passed native shortcuts, installed CLI/PDF and GUI edit/save/shutdown, then same-build reinstall returned7. Full acceptance remains blocked.**
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

The [first expanded fixture 40467143851](https://github.com/imranOdiboev/pdfcraft/actions/runs/40467143851/job/122065183121)
observed the original missing-field regression, then confirmed corrected metadata on
three installations, invalid-metadata refusal and higher-build refusal. It failed on
the final removal after immediate same-folder reinstall. The native first-phase
uninstaller returns before its temporary second phase deletes the original EXE;
reinstallation could race that pending deletion. Both fixture and full acceptance now
wait, bounded to 15 seconds, for actual native self-removal before reinstalling. They
never remove this EXE themselves or count process termination as success. Confirm the
wait and the complete lifecycle in the next run; the failed fixture is not a pass.

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

## Subsequent external OCR download failure and unchanged-input recovery

[Full run 40467568616, Windows job 122085084643](https://github.com/imranOdiboev/pdfcraft/actions/runs/40467568616/job/122085084643)
passed complete Linux gates/security, Windows desktop/CLI compilation, release CLI
acceptance, real GUI startup and Windows core/CLI tests. Packaging then failed before
Setup acceptance: the original OCR model S3 URL returned HTTP 403 `AccessDenied`.
This run did not recheck the installer and produced no final package. Its unrelated
network failure is not a passed installer result.

The author-hosted Hugging Face RTen files have different hashes, so they were not
substituted. Both existing model blobs and their licence texts were recovered from
the project's prior successful run 40317028274, artifact 12651029055. The archive
digest and all four canonical hashes matched. No historical executable was extracted
or run. The exact two weights (about 12.2 MB) and unchanged CC-BY-SA-4.0 licence are
now declared as offline build-input assets under `vendor/ocrs-models`; original
fetched model/hash/author/licence entries remain unchanged. Their notice records
the original sources and recovery chain. This durable copy avoids reliance on the
old artifact expiring November 2; no new repository, release or paid service is used.

A new early gate verifies cache/model/licence hashes and mutation regressions before
Windows compilation, then runs the existing `cargo xtask models` unchanged to
revalidate and generate original attribution. Windows consumes this same-run model
artifact and runs the existing model verifier again during staging. Final package
checks and all actual Setup/PDF/settings/uninstall/Portable gates remain mandatory.
Generated attribution is prepared by the existing isolated GitHub workflow, never
hand-edited. New complete-run results remain pending.

Two additional actual read-only agents, `ocr_source_recovery` and
`installer_final_gate_audit`, independently reviewed provenance/cache expiry and
the remaining real installed-app scenario. They found no further CLI/UI schema
mismatch. A recommendation for more specific running-editor refusal reason checks
is recorded as a future coverage improvement; existing failure/data assertions are
retained and are not claimed to prove every refusal reason.

## Reference behavior

## Latest shortcut failure (2026-10-27)

[Run 40486018971, Windows job 122146390714](https://github.com/imranOdiboev/pdfcraft/actions/runs/40486018971/job/122146390714)
passed Windows compilation, CLI acceptance, GUI startup, core tests, offline model
verification and both package constructions. All nine actual Setup cancellations
and silent Portable-folder refusal passed. Installation passed payload hashes,
versions and registered build metadata, then failed `Start menu shortcut points
to another application.` Final distribution upload was correctly skipped.

The failing assertion used WScript.Shell.TargetPath and did not record its actual
value. An independent read-only audit found the installer explicitly targets the
correct executable. Short Windows run40503068385 reproduced the exact defect:
WScript returned `?????????? — lifecycle fixture`, whereas the native Shell target
retained `Приложение — lifecycle fixture` and matched the existing installed EXE.
That diagnostic archive (SHA-256
`977fab24f1ca2b9ab090e8861d1909c32933651e221aaf9b412d18ebb69256da`)
was downloaded and independently checked. This is lossy ANSI conversion, not an
incorrect installer target or a DOS short-path alias. The new negative control
also exposed WScript's ANSI setter rejecting a Unicode target; use an ASCII-only
existing same-name/same-byte file for that intentional wrong-target fixture.
The first short run therefore failed its mutation setup, not native target reading.

Read the target using native Shell `System.Link.TargetParsingPath`; require the
exact existing full installed target and empty arguments. Record native/legacy
paths with runner roots redacted, with no link activation or application execution.
The short exact-source lifecycle fixture now checks fresh EN, RU reinstall and
reinstall after removal, shortcut removal on uninstall, and deliberate wrong-target
and argument mutations. These controls must reject incorrect links. Fresh CI is
required before this correction is considered verified.

Microsoft documents the native target property in
[System.Link.TargetParsingPath](https://learn.microsoft.com/en-us/windows/win32/properties/props-system-link-targetparsingpath).

## Post-GUI reinstall failure (2026-10-27)

[Full run40503319692, Windows job122209671710](https://github.com/imranOdiboev/pdfcraft/actions/runs/40503319692/job/122209671710)
passed all nine real cancellations, silent folder refusal, exact payload/registered
identity/native shortcut, installed CLI PDF acceptance, running-editor refusal and
real GUI open/raster/rotate/Undo/Redo/save/normal exit. The following same-build
reinstall returned native exit7. Its overall result is FAILURE; final distribution
upload was skipped. Earlier shortcut correction is proven by the full run.

The test retained each exited GUI Process object until its outer finally block.
The Windows process object can remain alive while its handle is retained. Whether
that retains the exclusive EXE lock in this case must be proved, not assumed.
A short regression on a private copy of the runner's own cmd.exe performs five
normal exits: require exclusive access to fail before releasing the retained
handle and succeed after the shared shutdown helper verifies exit0 and disposes
it. It never runs application fixture EXEs or installs anything on the owner PC.
The hypothesis test must fail if the locking behaviour is not reproduced.

Full acceptance now releases/removes a GUI Process object immediately after
normal shutdown. Existing 15-second shutdown and exact exit0 checks remain.
Installer guards are unchanged; fixed version/folder/executable-refusal markers
and an EXE basename are logged. Only these allowlisted markers, not raw setup
logs, paths or process command lines, are included in published QA diagnostics.
The probe and a fresh complete Windows acceptance remain required.

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
