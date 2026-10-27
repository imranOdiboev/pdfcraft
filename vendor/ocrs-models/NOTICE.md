# Unmodified Ocrs model build inputs

Models by Robert Knight, trained on HierText and synthetic data, used unchanged
under CC-BY-SA-4.0. The full licence is in `LICENSE-CC-BY-SA-4.0.txt`.
These weights keep their own licence, independently of the source-code MIT/Apache terms.

Original author sources:

- https://github.com/robertknight/ocrs-models
- https://huggingface.co/robertknight/ocrs/blob/df0edd170279ab971b53e094c627255a87e1a503/README.md
- https://ocrs-models.s3-accelerate.amazonaws.com/text-detection.rten
- https://ocrs-models.s3-accelerate.amazonaws.com/text-recognition.rten

| File | Bytes | SHA-256 |
|---|---:|---|
| text-detection.rten | 2510284 | f15cfb56bd02c4bf478a20343986504a1f01e1665c2b3a0ad66340f054b1b5ca |
| text-recognition.rten | 9716568 | e484866d4cce403175bd8d00b128feb08ab42e208de30e42cd9889d8f1735a6e |
| LICENSE-CC-BY-SA-4.0.txt | 20138 | 28a9529c7d0bb4dc51f4bf5c116a3d16ef247a052f7591466768ddf563fd1cf5 |

On 2026-10-27 the original S3 URLs returned HTTP 403 `AccessDenied` during Windows
packaging. The currently available author-hosted Hugging Face RTen files have
different hashes and were rejected as replacements. These exact previously pinned
bytes were recovered from this project's own successful S3-fetching build:

- Source commit: `aa9bc135ba6bfcb6b9bc40f09f81f339e9b65c30`.
- Tested merge checkout: `e7276a010f262a45b8ce22b039e805b37f0f297b`.
- Run: https://github.com/imranOdiboev/pdfcraft/actions/runs/40317028274
- Artifact: https://github.com/imranOdiboev/pdfcraft/actions/runs/40317028274/artifacts/12651029055
- Archive SHA-256: `8219c3db7c8318e2318f3f21ccf6e2b6898ffffc7a53f630ef0bca70869dd0a1`.

The archive digest and each original model/licence digest matched the existing
`ATTRIBUTION.toml` pins before selective extraction. No old executable was extracted
or executed. This committed build-input copy removes dependence on that artifact's
expiry; updating weights requires a separate provenance, licence and hash review.

Windows CI verifies these files before compiling, then uses the existing
`cargo xtask models` and final package verifier to revalidate the same pins and
include the original attribution and licence texts. No OCR weights, alphabet,
engine behavior or original fetched-model pins were changed.
