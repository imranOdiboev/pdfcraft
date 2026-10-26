# ODIBO PDF — manual updates / Ручное обновление

Status: M4.0, 26 October 2026. No automatic updater, signed release feed or background
download service is enabled. Current test binaries and Setup are unsigned. Updating
is an explicit action by the user; a future signing design is not an active service.

## Installed application / Установленная версия

1. Save your documents and close ODIBO PDF. Keep separate copies of important test
   inputs and results. An installer cannot recover unsaved work for you.
2. Obtain the candidate selected by the owner from its successful CI run. Follow
   the [identity and checksum checks](ODIBO_WINDOWS_INSTALLATION.md#download-and-verify--скачать-и-проверить).
   Version `0.10.1` alone does not distinguish successive engineering builds:
   compare the source commit and recorded run number too.
3. Run the verified new Setup yourself, using the same Windows account and intended
   installation directory. Do not uninstall first or remove application-data folders
   to force an upgrade. Do not proceed if the installer asks to close an application
   containing unsaved work: cancel, save, close, then retry.
4. Open the application and confirm its version/build information, settings and
   recent documents. Open a **copy** of a test PDF, save a new result and reopen it.
   If verification or setup fails, stop; retain the old data and report the error.

Сохраните документы, закройте ODIBO PDF, проверьте новую сборку и самостоятельно
запустите Setup от той же учётной записи. Не удаляйте настройки перед обновлением.
Проверьте версию/коммит, настройки и сохранённый тестовый PDF после запуска.
При ошибке не пытайтесь исправлять её удалением пользовательских данных.

The intended M4.0 installer preserves the existing per-user data locations and
settings format. Reinstall/upgrade behavior must have actual CI evidence in the PR;
Windows 10/11 owner acceptance remains separate. Downgrades and moving to a different
installation directory are not a documented recovery procedure. Do not promise that
an arbitrary earlier binary can read future settings or recovery files.

## Portable / Portable-версия

Download and verify the new package, then extract it into a **new** writable folder.
Do not overlay it onto a running copy or delete the old folder. Keep `portable.txt`.
For a clean independent test, leave the new `ODIBOPDFData` separate. If deliberately
continuing the same settings, close both copies, back up the old data and copy the
whole `ODIBOPDFData` into the new folder before starting; keep the untouched backup.
This is an optional manual copy, not an automatic migration or a guarantee across
future incompatible versions. Do not merge individual recovery or digital-ID files.

Новую portable-сборку распакуйте отдельно. Старая папка может содержать документы,
восстановление и цифровые идентификаторы — не удаляйте её для обновления.
Изоляция от установленной версии требует сохранённого `portable.txt` и доступной
для записи `ODIBOPDFData`. Перенос данных, если нужен, выполняйте только после
закрытия обеих копий и резервного копирования всей папки.

## Trust boundary / Граница доверия

HTTPS and SHA-256 provide useful transport/integrity checks, but a checksum served
alongside a malicious file does not prove its publisher. Current test distribution
has no independent signed update trust root. Do not label these downloads trusted,
signed or publisher-verified. No file is downloaded and executed silently. Any future
updater needs independently authenticated metadata/packages, an explicitly trusted
signer, user consent and failure without execution when verification fails.

HTTPS и хеш не заменяют независимую проверку подлинности. Подписанного канала
обновления сейчас нет. Не отключайте Defender/SmartScreen и не запускайте пакет,
если его происхождение или проверка вызывают сомнение.
