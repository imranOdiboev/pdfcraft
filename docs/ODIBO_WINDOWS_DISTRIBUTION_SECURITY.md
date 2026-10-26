# ODIBO PDF — Windows distribution security

Status: M4.0 engineering policy, 26 October 2026. Current candidates are an
**unsigned, limited Windows x64 beta**, distributed through GitHub Actions artifacts.
They are not a stable release, an Authenticode-verified publisher distribution, or
a signed update service. The candidate PR and its completed CI runs are the evidence
for implemented checks; this document does not claim that future signing exists.

For practical steps, see [installation](ODIBO_WINDOWS_INSTALLATION.md),
[manual updates](ODIBO_WINDOWS_UPDATES.md), and the
[owner acceptance checklist](ODIBO_M4_0_MANUAL_CHECKLIST.md).

## Build and package trust boundaries

The M4.0 path is the ODIBO test-build workflow, not the upstream release workflow.
Build and test only on disposable, standard GitHub-hosted runners. No installer is
executed on the owner's computer by the agent. No paid signing service, release
publication, telemetry, background updater, MCP registration, service or autostart
is introduced.

Required controls for a downloadable candidate:

- Check out the intended source once; build GUI and CLI with locked Cargo inputs,
  the pinned Rust toolchain, pinned craft-fonts and SHA-256-verified OCR models.
- Keep the workflow token read-only (`contents: read`) and checkout credentials
  unpersisted. Pin actions by full commit SHA. Do not give PR code signing keys,
  publishing permissions or an identity token for signing.
- Publish the final Setup/Portable candidate only after the security/notices,
  Linux quality and Windows acceptance gates succeed. Diagnostic screenshots and
  failed-test logs are separate evidence, not accepted download candidates.
- Use the same checked executable/model/licence payload for both distributions.
  Only Portable carries `portable.txt`. The installed copy uses the existing
  per-user settings/recovery locations; neither installer nor uninstaller removes
  documents, settings, recovery files or digital identities.
- Check the exact allowed package contents, x64 PE identity, versions, all model
  hashes and licences, original MIT/Apache-2.0 texts, PdfCraft/third-party notices,
  and ODIBO's separate brand terms. Reject private keys, certificate containers,
  `.env`/credential files, control-channel token files, Git metadata, accidental
  debug symbols, private PDFs and unapproved resources. This is a scoped package
  check, not a claim that arbitrary secrets can always be detected automatically.
- Verify the installed files after installation on the temporary runner, rather
  than inferring payload correctness from installer source alone. Exercise normal
  install, reinstall, upgrade, uninstall and Portable independently.

GitHub recommends least privilege and immutable action references in its
[secure-use guidance](https://docs.github.com/en/actions/reference/security/secure-use).
Do not replace a failing check with a warning to produce a successful build.

The legacy `packaging/windows/sign.ps1` helper is **not called** by this unsigned
candidate path. In particular, its optional Azure branch downloads an unpinned
signing client and is not approved as a future production signing implementation.
The legacy reusable Release workflow is not the M4.0 distribution path either.

## Installer compiler provenance

The selected compiler is **Inno Setup 7.1.0 x64**, from the author's immutable
[release `is-7_1_0`](https://github.com/jrsoftware/issrc/releases/tag/is-7_1_0).
The exact download URL, expected length and SHA-256 are recorded together in the
[tool provenance record](../packaging/windows/INNO_SETUP_PROVENANCE.md), rather
than maintaining a second editable checksum here.

Check that fixed digest **before executing** the downloaded compiler installer on
the disposable runner. Check its valid Authenticode signature and expected
`Pyrsys B.V.` publisher as documented by the author; compiler verification failure
stops the build. Do not fetch a floating `latest` tool or an arbitrary installation
script. Compiler signature verification does not sign the resulting ODIBO installer.
See the author's [download-verification instructions](https://jrsoftware.org/isdl-verify.php)
and the [tool provenance and decision record](../packaging/windows/INNO_SETUP_PROVENANCE.md).

The versioned [Inno Setup licence](https://raw.githubusercontent.com/jrsoftware/issrc/is-7_1_0/license.txt)
allows commercial use subject to its notices and redistribution conditions. Its
authors request commercial purchases, but their [commercial-licence FAQ](https://jrsoftware.org/isorder.php)
states purchase is not strictly required. No purchase, licence key or owner signing
credential is required for this engineering beta; no paid service is activated.
Retain applicable compiler/runtime licence notices when distributing generated
Setup. Do not relabel those components as ODIBO-authored or MIT/Apache-licensed.

Per-user setup uses the compiler's non-administrative mode; the
[PrivilegesRequired documentation](https://jrsoftware.org/ishelp/topic_setup_privilegesrequired.htm)
describes `lowest`. This does not grant a guarantee about every Windows policy or
directory: a blocked installation fails without changing security settings.

## Version and source identity

The product version comes from `[workspace.package]` in `Cargo.toml`: **0.10.1**
for this stage. Keep GUI/CLI `--version`, PE version resources, Setup metadata,
package names and manifest consistent with it. A filename or environment override
must not silently claim a version different from the compiled executable.

Record both identities when Actions tests a PR merge:

- **Source SHA:** the immutable PR head that the contributor submitted.
- **Checkout SHA:** the actual commit compiled and tested; for a `pull_request`
  run this can be GitHub's temporary merge commit rather than the source SHA.
- **Checkout tree:** the tree object of the compiled checkout. Record/verify
  parent commits when explaining a temporary merge. Do not claim that a later
  `main` is byte-identical without checking its tree.

Build information must also identify repository, workflow/run and attempt, target
`x86_64-pc-windows-msvc`, product version, build time, tool versions and unsigned
status. The manifest is an auditable record; unsigned text is not proof against a
malicious party that can replace the package and manifest together.

Successive engineering candidates can all report 0.10.1. Use the monotonically
increasing GitHub **`run_number` of the same workflow** as an additional installed
candidate sequence; a re-run's `run_attempt` is separate. Record it and reject an
older sequence during ordinary manual upgrades, while permitting reinstall of the
same candidate. Do not use a filename, lexical SHA order or the globally named
`run_id` as a semantic version. A different workflow has a different counter.

This local sequence check prevents accidental same-version downgrades. It is not
cryptographic anti-rollback: unsigned Setup and user-writable installation state
can be replaced or edited. It does not authorize an older application to interpret
newer settings/recovery data. Future authenticated updates need their own signed
version/channel and rollback policy.

The installed `.odibo-install-root` marker and persistent application identifier
help distinguish an existing installation from an unrelated directory. They are
identity hints, not signatures, privilege boundaries or permission to remove
unknown files. An unfamiliar PDF or other user file in the installation directory
must survive uninstall. A subsequent reinstall must handle retained files safely.

## Checksums and their limits

Publish an external `SHA256SUMS.txt` covering the **final Setup EXE and inner
Portable ZIP**, beside `BUILD_MANIFEST.json` in the artifact. Also check the staged
payload inventory against its per-file hashes. Hash after the last byte-changing
operation; future signing must occur before final package hashing. The outer
GitHub artifact ZIP digest and the inner Portable ZIP digest describe different
files and must not be interchanged.

Verification must fail on missing/extra files, mismatching hash, model or notice,
wrong target/version/source metadata, or malformed inventory. Include controlled
negative checks proving the verifier rejects a changed byte and missing required
material. Use GitHub's artifact digest verification without weakening its mismatch
policy. The pinned `download-artifact@9000827ccba6bdab643e8b6fd33ac0654aef8333`
[defaults to an error on mismatch](https://raw.githubusercontent.com/actions/download-artifact/9000827ccba6bdab643e8b6fd33ac0654aef8333/action.yml).

**A hash is not an independent publisher signature.** HTTPS and a matching hash
help detect damaged or changed downloads relative to an expected digest, but a
compromised server/account can replace a file and the hash stored beside it.
Current candidate verification must not be described as publisher authentication.
If origin, identity or verification is uncertain, stop and report it; do not run
an unverified installer because its filename looks correct.

## Windows warnings

Unsigned candidates may show an unknown-publisher/unrecognized-app warning or be
blocked by SmartScreen, Smart App Control or an organization's policy. Signing
also does not guarantee immediate reputation or freedom from warnings. Microsoft
explains these distinctions in [SmartScreen reputation for developers](https://learn.microsoft.com/windows/apps/package-and-deploy/smartscreen-reputation).

Do not disable Defender/SmartScreen, add exclusions, remove trust markings to
avoid a block, or bypass organization policy. These instructions explain the
limitation; they are not a bypass procedure. Stop on a security block and send a
redacted warning plus package hash/run reference through the voluntary bug-report
route. Do not send personal PDFs, credentials or private certificates.

## Future Authenticode signing — not configured in M4.0

The owner must separately approve the signing provider, cost and validated public
identity. `IMR4N` in application metadata is not a CA-validated publisher identity.
Do not ask for private keys, PFX passwords or certificates in chat, repository,
issue, artifact or PR. Prefer a protected hardware/managed key and a dedicated,
owner-approved signing environment; do not export a private key into build code.

A future signing path must have an explicit **RequireSigned** mode:

1. Build/test a fixed approved source and verify the unsigned payload. A separate
   trusted signing job receives only that validated payload and minimal narrowly
   scoped authorization. Untrusted PR code never receives signing authority.
2. Sign **both GUI and CLI** first using SHA-256 and an RFC 3161 timestamp with
   SHA-256. Verify signatures, certificate trust/Code Signing use, expected
   publisher and timestamp before packaging them.
3. Package those signed binaries and sign the generated uninstaller as applicable
   to the chosen compiler. Sign the final **Setup**; verify Setup and uninstaller
   as well as embedded/installed GUI and CLI. Do not rely only on the outer file.
4. Run `signtool verify /pa /all /v` with policy checks for expected signer and
   valid timestamp; treat warnings/failures according to the strict signing gate.
   Record the certificate identity and verification results without private data.
5. Produce final manifests/checksums after signing. Do not alter signed files.

Missing credentials, failed timestamp/signature/identity verification, or a signing
service error must fail **RequireSigned**; never fall back silently to unsigned.
An explicit unsigned test mode remains separate and visibly labelled. This is
procedural preparation, not an active signer or permission to purchase one.
Microsoft documents [SignTool verification and SHA-256 options](https://learn.microsoft.com/en-us/windows/desktop/seccrypto/signtool)
and [RFC 3161 timestamping](https://learn.microsoft.com/en-us/windows/win32/seccrypto/time-stamping-authenticode-signatures).

## Updates: manual now, independent authentication before automation

Keep the existing desktop update source disabled. No automatic check, background
download or execution is added. Users explicitly obtain a selected candidate,
check its identity/integrity, save documents, close ODIBO PDF and run Setup
themselves. Installed upgrades preserve per-user settings; Portable is extracted
into a new writable folder and its data is handled only as described in the
[manual update instructions](ODIBO_WINDOWS_UPDATES.md).

Before enabling any future updater, require all of the following:

- Explicit user agreement to checking/downloading/installing, with no surprise
  executable launch. Cancellation must not discard unsaved documents.
- HTTPS **and independent authenticity**: an expected Authenticode signer and/or
  signed metadata with a public trust root delivered independently of that same
  download response. A hash fetched with the binary is insufficient.
- Bind signed metadata to exact product/channel, Windows target, version,
  package length/hash and expiry/rollback policy. Support controlled key rotation
  and revocation, and cap downloads/metadata. Reject unsafe redirects/paths.
- On signature, chain, trust identity, timestamp, hash, size, version, network or
  expiry failure: stop without executing, preserve installed software and data,
  and show an actionable error. No insecure retry or downgrade fallback.
- Verify the exact file that will be launched and protect the handoff against
  replacement. Never reuse an arbitrary installer from a writable temporary path.

GitHub artifact attestations can be an additional future provenance mechanism,
not an Authenticode replacement or a safety verdict. If adopted, verify the
cryptographic signature and constrain repository, signer workflow and source
digest; merely storing an attestation JSON is not verification. GitHub CLI's
[attestation verification policy](https://cli.github.com/manual/gh_attestation_verify)
documents these identity constraints. OIDC/attestation write permissions would
belong only to a separately reviewed trusted job, not today's PR artifact path.

No authenticated update infrastructure exists for this beta. Documented manual
updates and honest unsigned limitations are the safe M4.0 result; a secure
automatic updater requires a later separately approved implementation.

## Revision history

- 2026-10-26: M4.0 policy for unsigned artifact candidates, compiler provenance,
  package/source checks, manual update boundaries and future signing requirements.
