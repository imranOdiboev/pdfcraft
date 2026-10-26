# ODIBO PDF — test-build notes template

Template only. Completing this document does not publish a GitHub Release or authorize
distribution as stable. Replace each pending field with verified evidence or explicitly
leave it **not tested / unavailable**. Never invent a passing result.

## Identity and downloads

- Status: unsigned Windows x64 engineering/beta candidate; owner acceptance pending.
- Cargo version: pending.
- Source commit: pending (full SHA, link).
- Actual checkout/build commit: pending; explain any temporary PR test merge.
- Workflow run URL / number / attempt: pending.
- Owner manual acceptance, date and scope: pending; CI is not owner acceptance.
- Artifact URL / name / expiry: pending; GitHub sign-in required for Actions artifacts.

| File | Size in bytes | SHA-256 | Signature status |
|---|---|---|---|
| Setup EXE, exact name pending | Pending | Pending | Unsigned unless independently verified otherwise |
| Portable ZIP, exact name pending | Pending | Pending | Included EXEs unsigned unless verified otherwise |

Attach `BUILD_MANIFEST.json` and `SHA256SUMS.txt`. A checksum is an integrity check,
not independent proof of the publisher. No automatic updater or signed release feed
is configured. Do not advise disabling Defender or SmartScreen.

## Changes and data handling

- User-visible changes: pending, with concrete before/after behavior.
- Installer mode, default path and shortcuts: pending verified details.
- Upgrade/reinstall behavior tested: pending, with both build identities.
- Settings/document preservation and portable isolation: pending evidence.
- Settings migration: none unless a real reviewed migration is explicitly described.
- [Install/uninstall](ODIBO_WINDOWS_INSTALLATION.md) and [manual updates](ODIBO_WINDOWS_UPDATES.md).

## Verification

| Check | Result | Evidence / omissions |
|---|---|---|
| Linux and Windows Rust tests | Pending | Counts passed/failed/ignored and exact run |
| Clippy, security and licences | Pending | Existing advisory exceptions stated separately |
| Setup content/hashes/metadata | Pending | Actual package and installed-file verification |
| Install/reinstall/upgrade/cancel/uninstall | Pending | Exact runner OS; synthetic predecessor identified |
| GUI and installed CLI PDF acceptance | Pending | Synthetic fixtures, source-preservation checks |
| Portable acceptance and isolation | Pending | Actual runs |
| Windows 10 / 11 manual acceptance | Not tested | [Owner checklist](ODIBO_M4_0_MANUAL_CHECKLIST.md) |
| Screenshots | Pending | Actual source/run; permissions and attribution, no invented captures |

## Known issues and reporting

List candidate-specific failures and untested scenarios, then retain applicable
[product limitations](../README.md#status-and-limitations): English/basic Latin OCR,
no Russian OCR, synchronous Split, no batch-OCR cancellation, hard-link destination
requirement, nontransactional multi-file output, fidelity and Undo limits.

Report voluntarily using [the privacy-conscious template](ODIBO_BUG_REPORT.md).
Do not request personal PDFs or unredacted logs. Preserve PdfCraft credits, code and
third-party licences and the separate ODIBO brand terms. Do not merge or publish
a release merely because this template has been filled out.

Русский: укажите точные версию, коммиты, запуск, имена и SHA-256 пакетов, неподписанный
статус, реальные результаты и пропуски. Не называйте CI ручной приёмкой владельцем.
Не публикуйте официальный релиз и не объявляйте стабильность без отдельного решения.
