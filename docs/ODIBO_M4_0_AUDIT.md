# ODIBO PDF M4.0 — installer and distribution audit

Status: implementation candidate; Windows cloud installation acceptance pending.
Reviewed: 2026-10-26. Base: `de27ec00ab8d989ae3d2b485e1d7f9bb1209b855`.
PRs [#8](https://github.com/imranOdiboev/pdfcraft/pull/8) and
[#9](https://github.com/imranOdiboev/pdfcraft/pull/9) were merged by the owner.
The owner explicitly confirmed manual Windows M3.7 acceptance and authorized M4.0
in this conversation on 26 October. Branch: `feature/odibo-windows-installer`.

## Four actual independent subagents

All four audited before implementation. Runtime capacity permits three concurrent
subagents plus the lead; the fourth started when a slot became available. Initial
audits were read-only. Implementation used three isolated Git worktrees. The lead
alone integrated shared files and the product branch; no simulated agent roles.

| Agent | Findings and disposition |
|---|---|
| `m40_installer_engineer` | P1: legacy WiX MSI is admin-only, lacks full notices and removes the old version before its transaction. Compared WiX/Inno/NSIS; implement per-user Inno 7.1.0 with pinned authenticated compiler, shared complete payload, guarded destination, native uninstall and no forced app closure. |
| `m40_security_updates` | P1: packaging-only changes miss the build filter; artifacts can precede Linux gates; legacy version override can disagree with EXE; Azure signer download is unpinned. Extend filter/dependencies, bind Cargo/PE/CLI/manifest identity, and do not invoke legacy release/signing. Final review also caught insufficient rejection of extra executables beneath model/notice paths; add self-consistent mutation tests. |
| `m40_windows_qa` | P1: old MSI test only inspects tables; Cargo acceptance executes build-tree EXE, not installed CLI; forced GUI shutdown cannot prove saved settings. Add explicit installed-path/hash checks, real lifecycle/PDF tests, normal quit/restart, portable isolation and user-data sentinels. |
| `m40_documentation` | P1: README says no installer; Issues feedback is disabled; screenshots can expose prohibited proprietary system typography. Add EN/RU Setup/Portable choice, install/update/remove guidance, PR feedback and manual checklist. Retain actual existing egui gallery; capture Setup only when permitted fonts are proven. |

## Plan, ownership, complexity and risks

1. Keep Rust/egui, PDF engine, command IDs, CLI/MCP, settings/recovery and licences.
2. Build a canonical installed payload from the current complete foundation staging;
   portable differs only by its marker and checksum inventory.
3. Verify Cargo/PE/CLI version, x64/subsystems, PR source head versus tested checkout
   and tree, run/build identity, pinned OCR models, notices and file hashes.
4. Compile per-user offline Setup and run actual lifecycle/installed PDF acceptance
   only on disposable standard GitHub-hosted Windows runners.
5. Publish unsigned artifact-only candidates after mandatory checks. Owner decides
   manual acceptance, merge and release; no M4.1 work or official Release.

Lead owns foundation workflow, shared verifier/manifest, documentation-link checking
and integration. Isolated installer/QA/documentation worktrees own their assigned
files. Installer lifecycle and native QA are medium/high complexity; workflow and
inventory coordination medium; docs low/medium. No concurrent writes to one worktree.

Inno Setup commercial purchase is requested but explicitly not mandatory under its
[official FAQ](https://jrsoftware.org/isorder.php). No paid service is used.
Exact pins, original licence, RemObjects acknowledgement and LZMA runtime exception
are in [tool provenance](../packaging/windows/INNO_SETUP_PROVENANCE.md).
No compiler binaries, copied GPL source, new font or third-party image is committed.
Embedded installer-runtime terms remain separate from open application source.

## Rejected shortcuts and limits

- Do not merely flip the old MSI scope: its HKLM registrations and lifecycle differ.
  Legacy files stay present but are not the new candidate path.
- No forced process closure, recursive app/data deletion, format migration, default
  PDF takeover, autostart, MCP startup, telemetry or new updater. Preserve unknown
  files and all per-user/portable data. Persistent `.odibo-install-root` is only a
  folder identity hint, not authentication.
- SHA-256 is integrity relative to an expected value, not proof of publisher. Current
  candidates are unsigned. No Windows protection bypass. Future signing/update trust
  is documented in [distribution security](ODIBO_WINDOWS_DISTRIBUTION_SECURITY.md).
- Same-version GitHub workflow run-number ordering protects accidental downgrades,
  not malicious publishers, workflow resets or every future release channel.
- No previous ODIBO Setup was distributed. Same-build reinstall and registry fixtures
  are not historical cross-version upgrades. Actual older-release upgrade and
  interrupted-copy rollback remain separately identified until genuinely exercised.
- Hosted Windows Server is not clean Windows 10/11, standard-user-token, physical
  DPI/SmartScreen or screen-reader proof. Use the [manual checklist](ODIBO_M4_0_MANUAL_CHECKLIST.md).
- Preserve inherited PDF/OCR limits and five existing advisory-policy exceptions;
  no new ignore or disabled gate. A green policy check does not mean zero advisories.

## Verification record

Initial local static checks: inventory mutation tests, PowerShell parsing, original
gallery hashes and documentation links. An initial sandbox temporary-folder access
failure was resolved by using a fresh workspace scratch folder. No owner-machine
application installation/execution or Rust build occurred.

Cloud checks and package results will be recorded with exact source/run/artifact
identities in the PR and final report. No installer success is claimed by this audit.

Revision history: 2026-10-26 — owner gate, four real audits, isolated plan and candidate.
