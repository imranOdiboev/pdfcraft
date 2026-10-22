# ODIBO PDF: перечень изменений следующего этапа

Дата: 21.10.2026. Основание: foundation-ветка от PdfCraft `d695bc5`.
Статус: **план ребрендинга; переименование приложения ещё не выполнено**.

В foundation тестовый архив собирается с `pdfcraft-ui-egui/unbranded`. Этот флаг исключает
ArtCraft SVG из компиляции и убирает указания принадлежности upstream из Home/About/Help.
Название PdfCraft, PDF-функции, исходные лицензии и авторские сведения сохранены.
Это не полный ребрендинг и не готовый самостоятельный установщик.

| Область | Файлы, которые потребуется изменить | Проверка после изменения |
|---|---|---|
| Название, версия, имя исполняемого файла | `apps/pdfcraft/Cargo.toml`, `apps/pdfcraft-cli/Cargo.toml`, `apps/pdfcraft/src/main.rs`, `apps/pdfcraft-cli/src/main.rs`, `crates/engine/src/build_info.rs`, корневые Cargo.toml/Cargo.lock в нужной части | Новое имя в окне, CLI help/--version и артефактах; внутренние crates переименовывать необязательно |
| Windows PE metadata и иконки | `apps/pdfcraft/build.rs`, `apps/pdfcraft-cli/build.rs`, `assets/app-icon/`, `packaging/icons.sh` | ProductName/CompanyName/FileDescription, новые оригинальные иконки; attribution и хеши |
| Home, About и брендовые ссылки | `crates/ui-egui/src/home.rs`, `dialogs.rs`, `widgets.rs`, `chrome.rs`, `i18n/mod.rs`, каталоги `i18n/*.tsv`, `crates/engine/src/links.rs`, `commands.rs` | ODIBO PDF во всех языках и темах; нет чужого endorsement; ссылки и команды работают |
| Updater | `apps/pdfcraft/src/updates.rs`, связанные tests и release URLs | Собственный endpoint и allowlist; невозможно предложить upstream-сборку как обновление ODIBO PDF |
| Настройки, логи, recovery, portable | `apps/pdfcraft/src/settings.rs`, `logging.rs`, `crates/ui-egui/src/portable.rs`, связанные пути в UI, `packaging/windows/portable.txt` | Отдельные data directories, отсутствие коллизии/изменения установок PdfCraft |
| Single-instance и управляющий канал | `apps/pdfcraft/src/single_instance.rs`, связанные имена сокетов/namespace, `crates/ui-egui/src/control.rs` | ODIBO PDF и PdfCraft запускаются одновременно; чужие файлы/окна не перехватываются; opt-in/auth сохранены |
| Windows MSI/registry | `packaging/windows/pdfcraft.wxs`, `installer-ui.wxs`, `package.ps1`, `sign.ps1`, `test-msi.ps1`, `security-audit.ps1` | Свой Manufacturer вместо Learning Machines LLC, новый UpgradeCode, ProgID/ярлыки/каталоги/контекстное меню; install/upgrade/uninstall не затрагивают PdfCraft |
| Документные metadata | `crates/create/src/lib.rs`, записи Producer/Creator в `crates/cos`, `engine`, `export`, `sign`, шаблоны отчётов | Новые документы имеют честный Producer; исходное авторство пользовательских документов не затирается |
| Сборка и документация | `.github/workflows/odibo-foundation.yml`, `.github/odibo/TEST_BUILD.txt`, release workflow, README, docs/images, demo | Собственные имена artifacts, инструкции и контакты; независимая упаковка, полный notice bundle |
| Реестр материалов | `ATTRIBUTION.toml`, генерируемый `ATTRIBUTION.md`, `NOTICE` | Записи только реально используемых материалов; старое авторство не заменено своим; generated Markdown обновлён через xtask |

Позднейшие платформенные точки, **вне текущего этапа**:

- Web: `apps/pdfcraft-web/index.html`, `src/main.rs`, `Trunk.toml`, `packaging/web/` — title,
  домен, host API, storage namespace, privacy и notices клиентской поставки.
- macOS/Linux/FreeBSD: `packaging/macos/Info.plist.in`, `Credits.rtf`, Linux desktop/MIME/metainfo/nfpm
  и packaging-скрипты — bundle/package IDs, publisher, URLs, data paths и подпись.
- Android: отдельного Android-приложения и pipeline в этом этапе не создаётся. Нужен самостоятельный
  технический выбор UI/интеграции Rust, storage permissions, package ID и store-публикации.

Требуется от владельца на этапе ребрендинга: окончательная графика, publisher/юрлицо,
собственные домен/update endpoint, контакты поддержки и выбранные signing identities.
Права на название ODIBO PDF по товарным знакам должны быть проверены для выбранных рынков.

## Приёмка ребрендинга

1. Поиск PdfCraft/ArtCraft/storytold/storyteller/getartcraft и Learning Machines по кодовой базе:
   каждое совпадение объяснено как attribution, совместимость либо подлежит замене.
2. Сосуществование двух приложений, обновление и удаление проверены на чистой Windows VM.
3. GUI, переводы, CLI, metadata, package names и updater согласованы.
4. В установленном пакете есть все licence texts/copyright/NOTICE; не требуется обращаться к GitHub,
   чтобы прочитать условия встроенных компонентов.
5. Подтверждены open/combine/split/save/reopen и проверка неизменности источников.

Источники: `docs/brand/LICENSE-brand.txt`, `AGENTS.md`, `COMMERCIAL_PLAN.md`,
исходники и packaging анализируемой ветки. Этот список не даёт разрешения на публикацию релиза.
