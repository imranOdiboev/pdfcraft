# ODIBO PDF: отчёт первого технического этапа

Дата: 21.10.2026. Ветка: `feature/odibo-foundation`.
Исходная база: `d695bc56545944fe9c7181901c61d0bf1c11c887`.
Pull Request: https://github.com/imranOdiboev/pdfcraft/pull/1 → **main этого форка**.

Статус: **проверки выполняются**. Этот промежуточный статус будет заменён фактическими
результатами после завершения Actions. Наличие workflow само по себе не считается успешной сборкой.

## Изменения

- Собственный `.github/workflows/odibo-foundation.yml`: стандартные Ubuntu/Windows x64 runner,
  Rust 1.95.0, закреплённые Actions и шрифтовый input; без craft-common-actions, release/secrets
  и прямой записи в main. На компьютере владельца ничего не устанавливалось и Cargo не запускался.
- Lockfile подготовлен командами Cargo в изолированном job: rustls-webpki 0.103.15 → 0.103.16,
  webpki-root-certs 1.0.9 → 1.0.10. Cargo также переувязал существующие Windows dependency edges;
  новых версий остальных registry-пакетов не добавлялось. Для CLI-теста добавлен существующий
  workspace testkit как dev-dependency.
- `deny.toml` сохранён: новые ignore или ослабления security policy не добавлены.
- Добавлены три CLI acceptance-теста: полный PDF round trip; отказы на повреждённом PDF/неверном
  диапазоне; сохранность источника и destination sentinel при ошибке записи.
- По отдельному разрешению владельца test-сборка использует `pdfcraft-ui-egui/unbranded`:
  исключает SVG marks на этапе компиляции и утверждения принадлежности ArtCraft. Все PDF-функции,
  название PdfCraft, upstream links, copyright и лицензии сохранены.
- Windows-архив комплектуется обоими exe, моделями OCR и их лицензиями, root notices,
  third-party Cargo HTML, asset/vendor/font licences, portable mode, build information и SHA-256.
- Дополнительно сохраняются исходные тексты лицензий встроенных egui fonts и CMap из
  Cargo.lock-resolved пакетов: автоматический cargo-about не включил отдельный Bitstream Vera
  notice. Наличие этих файлов и текста Bitstream проверяется до публикации артефакта.
- Подготовлены `ODIBO_REBRANDING_CHECKLIST.md` и `ODIBO_LICENSE_NOTICES.md`.
- Владелец явно выбрал display name IMR4N; добавлена только его запись people.toml.
  Генерируемая статистика contributors.json не изменялась.
- Унаследованная ARM64-упаковка ограничена исходным репозиторием storytold/pdfcraft:
  её installer IDs и встроенные marks ещё не адаптированы для форка. Это не удаляет
  платформенную поддержку из приложения и не отключает проверки безопасности/тесты x64.
  Повторное создание одинаковых foundation jobs на push и pull_request устранено.

## Проверки

| Проверка | Фактическое состояние на этом промежуточном коммите |
|---|---|
| Подготовка минимального lockfile | [Bootstrap run 39571488437](https://github.com/imranOdiboev/pdfcraft/actions/runs/39571488437) — success |
| cargo-deny с исходной политикой | Прошёл, в том числе в PR run 39574204427; два целевых advisory устранены |
| Генерация Windows dependency notices | Прошла с cargo-about 0.9.2, проверенным SHA-256, и `--fail --locked` |
| Format | Первый проход нашёл форматирование нового теста; diff rustfmt применён; повторный format прошёл |
| Windows release build / тесты | Выполняются; успешный результат пока не заявляется |
| Linux Clippy | Прошёл в PR run 39574204427 с `-D warnings` и feature unbranded |
| Linux workspace | Прошёл в foundation run 39575929434 (unbranded) и в исходном CI run 39575929430 (обычная конфигурация) |
| Отдельный interop / собственный WASM gate | Выполняются; успешный результат пока не заявляется |
| Лицензии шрифтов и CMap сверх cargo-about | Добавлена обязательная проверка и копирование оригинальных текстов; проверка нового шага выполняется в следующем запуске |
| Готовность к ребрендингу | Решение после завершения проверок |

## Что доказывает PDF acceptance

Синтетические документы содержат 2 и 3 страницы с разными метками LEFT-1/LEFT-2 и RIGHT-1/2/3.
Тест запускает отдельные процессы настоящего CLI, проверяет открытие, объединение, Save As,
повторное открытие, инкрементальное сохранение, raster preview и split на части по две страницы.
Сверяются порядок текста, число страниц, сохранность байтов источников и предыдущей ревизии.
Путь содержит кириллицу и пробелы. Linux CI обязательно использует независимые qpdf и pdftotext.
На Windows их отсутствие явно печатается как skipped external check; внутренние acceptance-тесты
при этом выполняются. Это не универсальная сертификация любого PDF и не ручной аудит всего GUI.

## Как получить тестовую Windows-сборку

После успешного Windows job открыть проверенный запуск **ODIBO foundation** в Actions,
в разделе Artifacts скачать `odibo-foundation-windows-x64-<полный SHA>`.
Войти в GitHub; артефакт хранится семь дней. Распаковать весь ZIP в отдельную доступную для записи
папку и запустить `pdfcraft.exe`, сохранив остальные файлы рядом. CLI — `pdfcraft-cli.exe`.
Версия/commit указаны в BUILD_INFO.txt, контрольные суммы — SHA256SUMS.txt.

Это unsigned portable test build. Установщик и официальный релиз не публикуются. До ребрендинга
остаются исходные namespace/IDs и upstream update links, поэтому закрыть другие экземпляры PdfCraft
перед тестом и не использовать Check for updates как канал обновления этого форка. Эти ограничения
не следует переносить в коммерческую поставку; см. checklist следующего этапа.

## Существующие исключения security policy

В исходном deny.toml остаются пять явно обоснованных исключений: `RUSTSEC-2023-0071`
для `rsa` (по upstream-политике — только public-key verification, private-key операции
на native выполняет aws-lc-rs) и четыре сообщения об отсутствии сопровождения
`proc-macro-error`, `zvariant`, `zbus_names`, `zvariant_derive`. Они не добавлены этим PR.
Прохождение cargo-deny означает соответствие этой политике, а не отсутствие любых рисков.
Два целевых TLS-advisory `RUSTSEC-2026-0382` и `RUSTSEC-2026-0383` исправляются обновлением,
а не исключением из проверки.

## Границы этапа

main не изменён напрямую; PR не объединён. В этом этапе нет нового коммерческого UI, смены
названия, платформенной разработки Web/Android, оплаты, signing или массового релиза.
Полное ребрендинг-тестирование, real-world corpus, GPU/принтеры, квалифицированные подписи,
русский OCR и юридическое одобрение будущего коммерческого выпуска остаются последующими задачами.
