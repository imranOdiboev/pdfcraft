# ODIBO PDF brand provenance

Project representative: **IMR4N**. Approved 2026-10-22.

The owner reports that both original images were generated through **ChatGPT by OpenAI**
specifically for this project. The originals are preserved byte-for-byte as
`source-icon.png` and `source-logo.png`; their SHA-256 hashes and every shipped derivative
are recorded in `ATTRIBUTION.toml`. No Adobe product artwork or proprietary font file
has been introduced. The raster wordmark is supplied artwork, not a bundled typeface.

Technical transparent-background adaptations use the imagegen tool with the approved
sources as edit targets. Prompts require preservation of the O silhouette, white/cyan
gradient, vivid blue base and red folded corner; no new visual concept is authorized.
Low-quality interim results are not shipped. Resizing and ICO packing are deterministic
format preparation. No automatic SVG tracing is used; no editable vector master is claimed.

These materials use `LicenseRef-ODIBO-Brand`; see `LICENSE-ODIBO-BRAND.txt`.
The code and original PdfCraft notices retain their respective licences. No exclusive
copyright in fully AI-generated elements or registered trademark status is asserted.
The precise generating model, original generation date, applicable service terms and
extent of human creative contribution have not been independently verified.

For builds without these materials:

```sh
cargo build --locked -p pdfcraft --features unbranded
```

This feature excludes all includes of ODIBO graphical assets and substitutes an existing
openly licensed icon. It is tested with this directory absent. Before distributing an
independently modified product, replace the product name and identity as described in
the brand terms. The feature alone does not grant rights to market a fork as ODIBO PDF.
