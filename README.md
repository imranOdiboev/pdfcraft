<p align="center">
  <img src="assets/odibo/logo-light.png" alt="ODIBO PDF" width="440">
</p>

# ODIBO PDF

**A local PDF workbench for Windows: read, combine, split, organize and annotate documents.**

Built with Rust and egui. Maintained by **IMR4N**, independently branded and developed from [PdfCraft](https://github.com/storytold/pdfcraft).

[Русский](README.ru.md) · [Try the Windows test build](#windows-x64-test-build) · [Known limitations](#status-and-limitations) · [Build from source](#build-from-source)

![ODIBO PDF Home with real quick actions, in Russian and the light theme](docs/screenshots/odibo/home-ru-light.png)

*Actual Rust/egui interface, captured on a disposable Linux GitHub Actions runner with synthetic documents. These are not native Windows screenshots. [Capture provenance and licences](docs/screenshots/odibo/PROVENANCE.md).*

## What you can do

| Task | Available workflow |
|---|---|
| Read PDFs | Open files or recent documents, navigate pages and thumbnails, search and zoom. |
| Combine documents | Add or drop several PDFs, preview and reorder them, remove unwanted inputs, create a new document and choose **Save As**. |
| Split a document | Choose the existing split modes or validated consecutive page ranges, preview the outputs and select a destination folder. |
| Organize pages | Select several pages, move, rotate, delete or insert pages using the existing tools and Undo/Redo. |
| Annotate and fill | Add comments and supported annotations, fill forms, and use Fill & Sign. A drawn signature is not a certificate-based digital signature. |
| Edit and export | Use the existing text/image tools and supported export formats, subject to the limitations below. |
| Automate | Use the CLI, JSON scripts or the explicitly started MCP server. No agent server is enabled automatically. |

English and Russian interfaces, light/dark themes and UI scaling are supported. Everyday PDF workflows run locally without a mandatory account or cloud upload. Optional providers and external links are separate, user-initiated actions.

## A look inside

| Editor · dark theme | Combine · light theme |
|---|---|
| ![Russian PDF editor with document and panels, dark theme](docs/screenshots/odibo/editor-ru-dark.png) | ![Russian Combine workspace with staged synthetic PDF files, light theme](docs/screenshots/odibo/combine-ru-light.png) |

| Split · dark theme | Organize · light theme |
|---|---|
| ![Russian Split dialog with validated page ranges, dark theme](docs/screenshots/odibo/split-ru-dark.png) | ![Russian Organize workspace with page thumbnails, light theme](docs/screenshots/odibo/organize-ru-light.png) |

Screenshots show the real application with permitted embedded fonts and synthetic content, not HTML mockups or personal PDFs. Image files live in this repository; provenance and SHA-256 hashes are tracked in [ATTRIBUTION.toml](ATTRIBUTION.toml).

## Windows x64 test build

**This is an unsigned test application, not an official stable release.** There is currently no permanent binary download URL, installer or configured automatic update service.

1. Open [Actions → ODIBO Windows test build](https://github.com/imranOdiboev/pdfcraft/actions/workflows/odibo-foundation.yml).
2. Select a **successful** run for the branch or PR you intend to test. For a candidate build, use the run linked in that PR; a successful build alone does not mean the owner has accepted it.
3. Sign in to GitHub and download the `odibo-rebranding-windows-x64-…` artifact under **Artifacts**. The legacy artifact name is retained. Artifacts expire after **seven days**; if none is available, there is no current download to offer.
4. Extract the **entire ZIP** into a writable folder, then start `odibo-pdf.exe`. Keep `models/`, `licences/`, both executables, notices and licence files together.

Windows may show an unsigned-application warning. Verify the repository, run, commit and checksums before deciding whether to run the build; these instructions do not require disabling Windows protection. The archive includes build information and checksum files for verification.

`portable.txt` stores application data in `ODIBOPDFData` beside the executables. Remove that marker before starting if you prefer the separate ODIBO per-user directories. Start with copies of non-sensitive test documents. Use **Save As** to keep the original file when experimenting.

## Status and limitations

ODIBO PDF is under active development. Windows x64 is the current product target; the codebase also contains other native platforms and a WebAssembly frontend. This does not promise finished Web or Android products, production readiness or parity with another PDF editor.

- Editing existing text and complex PDF rendering can have fidelity limitations. Office export may lose layout; in-app Office-to-PDF import is not provided. See the [documented gaps](docs/gaps.md) and [format coverage](docs/file-format-parity.md).
- Bundled OCR recognizes **English/basic Latin text**. Russian OCR is **not supported** by the current recognition model; a Russian interface does not imply Russian OCR.
- Batch OCR runs in the background on desktop and currently has no cancellation control.
- Explicit split ranges must cover the whole document consecutively without gaps or overlap. Use the existing Extract operation for selected subsets.
- Safe split output requires a destination with hard-link support, such as NTFS. The M3.7 test candidate extends this requirement to separate-file extraction and batch OCR output; that candidate must be reviewed and merged separately. Unsupported destinations fail safely. If a later output fails, previously completed new files can remain; batch output is not an all-or-nothing transaction.
- Split processing is synchronous and may pause the interface on large documents. Cancelling Combine discards its result, but does not interrupt an engine step already running.
- Undo retains up to 100 recent changes. Test important files on copies and check saved results by reopening them.

The [roadmap](ROADMAP.md), [architecture](docs/architecture.md) and [upstream parity assessment](docs/target-app-parity.md) describe the larger codebase. Historical upstream measurements are not new ODIBO benchmarks or user-study results.

## Build from source

With the project Rust toolchain and platform prerequisites available:

```sh
cargo build --locked --release -p pdfcraft -p pdfcraft-cli
cargo test --locked --workspace
cargo clippy --locked --workspace --all-targets -- -D warnings
cargo xtask assets
```

Internal Cargo package names remain `pdfcraft`; the executables are `odibo-pdf` and `odibo-pdf-cli` (`.exe` on Windows). CI runs full workspace checks on disposable runners. Source builds need `cargo xtask models` for OCR; the test Windows archive already bundles the models and their notices. Optional pinned craft-fonts provide additional script coverage; see [AGENTS.md](AGENTS.md) and the [build workflow](.github/workflows/odibo-foundation.yml).

```sh
cargo run --locked --release -p pdfcraft-cli -- --help
cargo run --locked --release -p pdfcraft-cli -- tools
cargo run --locked --release -p pdfcraft-cli -- run --script steps.json --root ./test-files
```

MCP starts only with `odibo-pdf-cli mcp`. The authenticated loopback UI control channel is also opt-in. See [automation documentation](crates/automation/README.md).

An unbranded build remains possible, even with `assets/odibo/` absent:

```sh
cargo build --locked -p pdfcraft --features unbranded
```

This excludes ODIBO graphic resources. A separately distributed modified product must also adopt its own identity under the brand terms.

## Licences, attribution and thanks

Thank you to **PdfCraft and its contributors** for the original software. ODIBO PDF is an independent modified version, not an endorsement by the upstream authors.

Open-source code retains [MIT](LICENSE-MIT) **OR** [Apache-2.0](LICENSE-APACHE). Original author notices and [NOTICE](NOTICE) remain. Dependencies, fonts and OCR models keep their own licences; see [ATTRIBUTION.md](ATTRIBUTION.md) and [licence notices](docs/ODIBO_LICENSE_NOTICES.md).

**ODIBO logos, icons and technical derivatives have separate terms:** [LicenseRef-ODIBO-Brand](assets/odibo/LICENSE-ODIBO-BRAND.txt), not MIT/Apache-2.0. Project representative IMR4N reports that the two original brand images were generated through OpenAI ChatGPT for this project; [brand provenance](assets/odibo/PROVENANCE.md) records this. No exclusive copyright in fully AI-generated elements or registered trademark status is claimed. These terms do not restrict the open components, unprotectable material or lawful factual references. Screenshots may be shared to describe or review ODIBO PDF; displayed brand elements retain their separate terms.
