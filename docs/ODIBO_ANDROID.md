# ODIBO PDF Android 0.1

Status: Android 0.1 merged in PR #13. ARM64 packaging and API 35 x86_64
emulator checks passed in [run 41134714016](https://github.com/imranOdiboev/pdfcraft/actions/runs/41134714016).
Physical ARM64 phone acceptance remains **not performed**. Android 0.2 tools are
under development; see [the current stage report](ODIBO_ANDROID_0_2.md).

Android 0.1 targets Android 8.0/API 26 or newer on **ARM64-v8a**. It is an offline
test application: no mandatory account, analytics or document upload. Selecting a
cloud-backed provider in Android's system picker may cause that provider to fetch
or upload the chosen file; that is separate from ODIBO's local processing.

## Intended first working scenario

Open a PDF through the system document picker, view its real pages, navigate and
zoom, rotate a selected page, save a new copy through the system destination
picker, then open the saved copy again. The Android UI and `PdfRenderer` are
separate from the existing Rust PDF object/edit core. A packaged Rust executable
worker performs inspect and rotation through bounded local process calls. It is
installed in the application's native-code directory; it is not downloaded at
runtime, copied to writable storage for execution or loaded through JNI.

The native library-directory filename `libodibo_core_exec.so` is a packaging
convention for the executable PIE, not a claim that it is a JNI shared library.
Rust keeps `unsafe_code = forbid`; worker panics and failures are isolated from
the Android process. User PDF paths/content must not be logged.

## Install a test APK

1. Open the Android workflow linked from the PR. Confirm its checks completed
   successfully and that the artifact identifies the intended source commit.
2. Download the **ARM64 debug APK artifact**, extract `app-debug.apk`, and compare
   its SHA-256 with the checksum supplied by that run. Do not install the x86_64
   emulator-only package on an ARM64 phone.
3. Transfer the APK to the phone. Android may require permission for the chosen
   file manager/browser to install unknown apps. Follow your device or workplace
   policy; do not disable security protections. Stop if the origin/hash is unclear.
4. Install and open ODIBO PDF. Use synthetic PDFs or backed-up copies initially.
   Grant access only to the document selected by the system picker.
5. Perform the open → rotate → save new copy → reopen checklist in
   [the test plan](ODIBO_ANDROID_TEST_PLAN.md). Record device model, Android
   version, ABI, language, font scale, build commit and results.

This is a **debug-signed testing APK**, not production signing or a Google Play
release. CI debug signing identities can change between runs; Android may reject
an update signed with a different key. Preserve exported files and any required
data before deciding whether to remove an older test installation. Uninstalling
removes app-private working copies and preferences. Exported provider documents
are separate from those private files.

## Safety and initial limits

- Input is limited to **16 MiB** and **2,000 pages**; native output is limited to
  32 MiB. Metadata/object budgets reject some otherwise valid PDFs. These limits
  are rejection thresholds, not a guarantee that every eligible PDF fits memory.
- Encrypted documents are unsupported. Signed PDFs must not be modified; viewing
  may work if otherwise compatible. Malformed/reconstructed PDFs can be refused.
- Original files are read-only inputs. Changes use an app-private working copy;
  export creates a new document. Provider write failure can leave a partial **new**
  output; Android document-provider output is not generally an atomic transaction.
  Keep the original and do not rely on a failed export.
- Provider access may expire or be revoked. Select the document again if access
  fails. A document being listed as recent does not by itself prove access.
- Large/scanned/complex PDFs may exceed rendering or memory budgets. Rendering
  precision depends on the Android platform renderer and can differ from Windows.
- Cancellation is supported only where the app actually provides it; worker
  cancellation is not an Undo operation. Never assume a partial export succeeded.
- OCR, Combine, Split and Reorder are backlog unless the current PR documents
  passing end-to-end implementations. **No Russian/Cyrillic OCR is claimed.**
- No automated update service. Clean real-phone coverage, unusual providers,
  low-memory/process termination and manufacturer-specific behavior need manual
  verification; an x86 emulator run is not an ARM64 physical-phone test.

## Licences, privacy and test-software notice

ODIBO PDF is developed from PdfCraft. Original author notices and MIT OR Apache-2.0
terms remain applicable to open components. Fonts and other dependencies retain
their own licences. Approved ODIBO artwork remains under the separate
`LicenseRef-ODIBO-Brand` terms; no trademark registration or exclusive copyright in
fully generated AI artwork is asserted. See the app's Licences and Information,
root `LICENSE-MIT`, `LICENSE-APACHE`, `NOTICE`, `ATTRIBUTION.md`, and
`assets/odibo/LICENSE-ODIBO-BRAND.txt`.

Android 0.1 is test software provided **AS IS**, without warranties, only to the
extent permitted by applicable law. Nothing excludes statutory rights or liability
that cannot lawfully be excluded or limited. Keep backups of important documents.

ODIBO PDF Android 0.1 — тестовое ПО, предоставляемое **«КАК ЕСТЬ» (AS IS)** в
пределах, допускаемых применимым законодательством. Эти условия не отменяют
неотчуждаемые законные права пользователя. Сохраняйте резервные копии важных PDF.
Не публикуйте личные документы, пароли, сертификаты и неочищенные журналы в Issues.

## Revision history

- 2026-10-31: first Android foundation installation, safety and verification guide.
