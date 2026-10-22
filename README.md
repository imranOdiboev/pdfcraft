# ODIBO PDF

ODIBO PDF is an independently branded, modified version of [PdfCraft](https://github.com/storytold/pdfcraft), maintained in this fork by **IMR4N**. The current engineering target is **Windows x64**. This is a test application, not a production release or an endorsement by the upstream authors.

The existing Rust PDF engine, viewer, editor, combine/split, page management, annotations, forms, save/export, OCR and opt-in CLI/MCP automation remain in the project. Rebranding does not establish Acrobat feature parity or production readiness. See the existing [gap assessment](docs/gaps.md) and [parity measurements](docs/target-app-parity.md).

## Windows test build

Open this repository's **Actions → ODIBO Windows test build**, select a successful run for the rebranding PR, then download the `odibo-rebranding-windows-x64-…` artifact while signed in to GitHub. Artifacts expire after seven days.

Extract the entire ZIP into a writable folder and start `odibo-pdf.exe`. Keep `models/`, `licences/`, NOTICE and licence files with both executables. `odibo-pdf-cli.exe --help` describes automation. `portable.txt` keeps data in `ODIBOPDFData` beside the executables. Remove that marker to use separate ODIBO per-user directories. There is no installer in this test archive, no signing certificate and no configured update service. Upstream update servers are never queried.

Validation results and limitations: [rebranding report](docs/ODIBO_REBRANDING_REPORT.md). Earlier foundation evidence: [foundation report](docs/ODIBO_FOUNDATION_REPORT.md).

## Source builds

Internal Rust package names are retained to keep upstream integration practical:

```sh
cargo build --locked --release -p pdfcraft -p pdfcraft-cli
cargo test --locked --workspace
cargo clippy --locked --workspace --all-targets -- -D warnings
cargo xtask assets
```

The executables are `odibo-pdf` and `odibo-pdf-cli` (with `.exe` on Windows). The optional pinned craft-fonts checkout supplies CJK and other interface fonts; see [AGENTS.md](AGENTS.md) and the Actions workflow. No system font may enter a published screenshot or PDF.

For a build without ODIBO graphic assets, even with `assets/odibo/` absent:

```sh
cargo build --locked -p pdfcraft --features unbranded
```

This excludes ODIBO graphic resources. A separate distributed fork must also adopt its own product identity as required by the brand terms. CLI tool and control method IDs remain compatible; MCP and the authenticated loopback UI channel remain opt-in.

## Licences and provenance

The open-source code retains [MIT](LICENSE-MIT) **OR** [Apache-2.0](LICENSE-APACHE), with original authors and required [NOTICE](NOTICE) preserved. Dependencies, fonts and OCR models have their own licences and attributions, included in test archives. See [ATTRIBUTION.md](ATTRIBUTION.md) and [licence notices](docs/ODIBO_LICENSE_NOTICES.md).

**ODIBO logos, icons and their technical derivatives are excluded from the code licence:** they use [LicenseRef-ODIBO-Brand](assets/odibo/LICENSE-ODIBO-BRAND.txt). The owner reports that the originals were generated through ChatGPT by OpenAI specifically for this project; [provenance](assets/odibo/PROVENANCE.md) records this separately. No exclusive copyright in fully AI-generated elements or trademark registration is claimed. These conditions do not restrict rights in the open components, unprotectable material or lawful factual references.

PdfCraft and its contributors retain credit for the original software. ArtCraft marks and endorsement claims are not displayed by this application's UI; the original brand terms remain in the repository as provenance. Web and Android product work is outside this Windows test stage.
