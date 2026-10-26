# ODIBO PDF — Windows installation / Установка Windows

Status: M4.0 test-distribution instructions, 26 October 2026. Check the candidate PR
for actual CI evidence and owner acceptance. Neither package is a stable release
or an Authenticode-signed application. Windows 10/11 x64 manual acceptance is
separate from tests on temporary Windows Server CI runners.

## Download and verify / Скачать и проверить

1. Follow the candidate PR's successful [Windows build](https://github.com/imranOdiboev/pdfcraft/actions/workflows/odibo-foundation.yml).
   Confirm the repository, branch, source SHA and run. Sign in to GitHub and download
   `odibo-windows-beta-…` under **Artifacts**. Retention is seven days, not a permanent download.
2. Extract this outer artifact ZIP. It contains a Setup EXE, a Portable ZIP,
   `SHA256SUMS.txt` and `BUILD_MANIFEST.json`. Do not confuse the artifact ZIP with
   the inner Portable ZIP. The manifest records version, source/build identity and
   the workflow run. PR head and temporary test-merge commits can differ; compare
   the recorded identities with the run and PR rather than assuming they are identical.
3. Compare the chosen package's SHA-256 against the exact entry in `SHA256SUMS.txt`
   and the candidate PR's evidence. In PowerShell, from the download folder:

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath '.\ODIBO-PDF-0.10.1-<commit7>-Setup-x64.exe'
Get-FileHash -Algorithm SHA256 -LiteralPath '.\ODIBO-PDF-0.10.1-<commit7>-Portable-x64.zip'
```

Replace `<commit7>` with the actual filename. Matching a hash detects changed bytes;
a hash downloaded with the file does **not** independently authenticate its publisher.
There is no signed update infrastructure. If identity, hash or origin is uncertain,
do not run the file. Request clarification in the candidate PR.

Скачайте артефакт по ссылке из PR, распакуйте внешний ZIP и сверьте точное имя,
SHA-256, исходный коммит и запуск CI. Замените `<commit7>` настоящим фрагментом имени.
Хеш не заменяет подпись издателя. При несовпадении или сомнении не запускайте пакет.

## Setup / Установка

Save and close all ODIBO documents first. Run the verified `…-Setup-x64.exe` as the
current user. The intended setup installs into `%LOCALAPPDATA%\Programs\ODIBO PDF`
without administrator privileges, registers its uninstaller and adds its application
shortcut. Open **ODIBO PDF** from Start after setup finishes. Setup does not
automatically open the application, enable MCP, create a service or autostart entry,
collect telemetry, or take over the default PDF association.

The application, CLI, OCR models, licence notices and build information are installed
together. Basic PDF work does not require an account or internet connection. Installed
settings and recovery retain the existing ODIBO per-user locations; the installation
directory is not the settings directory. No settings-format migration or upstream
PdfCraft-data import is introduced.

Сохраните и закройте документы. Запустите проверенный Setup обычным пользователем,
завершите мастер и откройте ODIBO PDF через «Пуск». Установщик рассчитан на текущего
пользователя; папка по умолчанию указана выше. Если неожиданно требуются права
администратора, отмените установку и сообщите об этом. Не выбирайте для установки
папку с документами или данными portable-версии.

## Portable / Без установки

Extract the **whole inner Portable ZIP** into a new writable folder. Keep both EXEs,
`models/`, `licences/`, notices, attribution and `portable.txt` together. Run
`odibo-pdf.exe`. `portable.txt` selects `ODIBOPDFData` beside the executables for
application settings, logs, recovery and new digital IDs. If that folder cannot be
written, the existing application fallback can use per-user data and reports why;
use a writable folder and check the warning before testing isolation. Windows can
still maintain OS caches or metadata.

Распакуйте весь внутренний Portable ZIP в новую папку с правом записи. Запустите
`odibo-pdf.exe`, не удаляя `portable.txt` и остальные файлы. Данные приложения
хранятся в `ODIBOPDFData`; при предупреждении о невозможности записи сначала
исправьте папку. Не копируйте настройки поверх работающего приложения.

## Windows warnings / Предупреждения Windows

Unsigned test packages may show an unknown-publisher or unrecognized-application
warning, or be blocked by Windows or an organization's policy. **Do not disable
Defender, SmartScreen or organization security controls.** These instructions do not
ask you to bypass a block. Stop and report the exact warning after removing personal
details. A clean CI run and matching checksum do not grant a verified publisher or
guarantee that every document or Windows configuration is safe.

Тестовая сборка не подписана: предупреждение или блокировка возможны. Не отключайте
защиту и не обходите запрет организации. Остановитесь и передайте обезличенный текст
предупреждения через [добровольный отчёт](ODIBO_BUG_REPORT.md).

## Uninstall / Удаление

Save and close the application. In Windows **Settings → Apps → Installed apps**
(Windows 10: **Apps & features**), select **ODIBO PDF → Uninstall**. This removes
installed program files and its registered shortcuts; the intended uninstaller keeps
user documents and ODIBO settings/recovery data. Do not manually delete application
data to complete an uninstall. For Portable, close the application and retain the
folder if it contains documents or `ODIBOPDFData` you need; deleting that folder would
also delete those files. There is no automatic portable-data deletion.

Закройте приложение. Откройте «Параметры → Приложения → Установленные приложения»
(Windows 10: «Приложения и возможности»), выберите ODIBO PDF и «Удалить».
Пользовательские документы, настройки и восстановление должны сохраниться; проверьте
это по [чек-листу](ODIBO_M4_0_MANUAL_CHECKLIST.md). Для portable не удаляйте папку,
пока не сохранили нужные документы и `ODIBOPDFData`.

See [manual updates](ODIBO_WINDOWS_UPDATES.md), [known limitations](../README.md#status-and-limitations)
and [installer-tool provenance](../packaging/windows/INNO_SETUP_PROVENANCE.md).
