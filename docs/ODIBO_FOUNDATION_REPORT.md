# ODIBO PDF: отчёт первого технического этапа

Дата: 21.10.2026. Ветка: `feature/odibo-foundation`.
Исходная база: `d695bc56545944fe9c7181901c61d0bf1c11c887`.
Pull Request: https://github.com/imranOdiboev/pdfcraft/pull/1 → **main этого форка**.

Статус: **технический этап выполнен, Windows x64 сборка и основные тесты прошли**.
Код готов к следующему этапу — ребрендингу ODIBO PDF. Коммерческий релиз этим отчётом не утверждается.

Проверенный исходный коммит: `34b6d72a9ba6c25291213c3f38414880ec20d97d`.
Успешный [foundation run 39579542556](https://github.com/imranOdiboev/pdfcraft/actions/runs/39579542556).
GitHub проверял PR merge commit `2bd9007b709096399c91aacfa4e6271f6b319d6c`; именно он указан
в именах артефактов и BUILD_INFO.txt. Заключительный коммит обновляет только Markdown-документацию;
исходники, lockfile и workflow после указанного успешного прогона не менялись.

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

| Проверка | Фактический результат |
|---|---|
| Подготовка минимального lockfile | [Bootstrap run 39571488437](https://github.com/imranOdiboev/pdfcraft/actions/runs/39571488437) — success |
| cargo-deny с исходной политикой | Прошёл в финальном foundation run; два целевых advisory устранены обновлением |
| Генерация Windows dependency notices | Прошла с cargo-about 0.9.2, проверенным SHA-256, и `--fail --locked` |
| Format и Clippy `-D warnings` | Прошли, включая feature `pdfcraft-ui-egui/unbranded` |
| Linux workspace с unbranded | **3 856 passed, 0 failed, 15 ignored** |
| Отдельный Linux PDF acceptance | **3 passed, 0 failed**; обязательные qpdf и pdftotext |
| Windows release build | `pdfcraft.exe` и `pdfcraft-cli.exe` 0.10.1, MSVC x64, статический CRT; успешно |
| Windows acceptance в release-профиле | **3 passed, 0 failed, 0 ignored** |
| Windows core/CLI tests | **1 167 passed, 0 failed, 6 ignored**; cos, organize, render, engine, automation, CLI |
| Layering, asset licences/hashes, parity, WASM, CLI без MCP | Все прошли; assets: 272 repository, 6 bundled, 22 fetched; parity — проверка существующих записей, не новая оценка зрелости |
| Home/About links и отсутствие marks | UI-тесты прошли; Home 1440×900 отрендерен и визуально просмотрен без системных шрифтов |
| Лицензии fonts/CMap сверх cargo-about | Шаг прошёл; скачанный notice ZIP содержит все 10 ожидаемых файлов, хеш совпал |
| Windows ZIP | Скачан и проверен без запуска exe: **58 файлов, 57 SHA-256 проверены**, оба PE имеют machine `0x8664` |

Дополнительный [исходный CI run 39579542603](https://github.com/imranOdiboev/pdfcraft/actions/runs/39579542603)
тоже успешен: обычная конфигурация Linux — **3 856 passed / 15 ignored**;
Windows — **3 828 passed / 16 ignored**, в обоих случаях 0 failed. Унаследованный
[FreeBSD build/test](https://github.com/imranOdiboev/pdfcraft/actions/runs/39579543292) прошёл.
Суммы разных прогонов не складываются: многие тесты выполняются повторно.

15 Linux ignored: 6 случаев с частными документами/шрифтами, 3 corpus-теста,
4 измерительные/диагностические пробы, 1 сетевой тест updater и 1 тест частной D-Bus сессии.
6 Windows core ignored: 3 corpus-теста, 2 случая с частными документами/шрифтами и 1 timing probe.
Новые foundation acceptance-тесты не игнорируются. Плановый fuzz job на PR не запускается;
ARM64 packaging намеренно пропущен для этого форка до адаптации брендинга и installer IDs.
Ранний format failure исправлен; отменённые промежуточные runs заменены указанным успешным run.

## Что доказывает PDF acceptance

Синтетические документы содержат 2 и 3 страницы с разными метками LEFT-1/LEFT-2 и RIGHT-1/2/3.
Тест запускает отдельные процессы настоящего CLI, проверяет открытие, объединение, Save As,
повторное открытие, инкрементальное сохранение, raster preview и split на части по две страницы.
Сверяются порядок текста, число страниц, сохранность байтов источников и предыдущей ревизии.
Путь содержит кириллицу и пробелы. Linux CI обязательно использует независимые qpdf и pdftotext.
На Windows в release acceptance явно пропущены 9 вызовов отсутствующего qpdf; это не 9
игнорируемых Rust-тестов. Три acceptance-теста прошли. pdftotext не сообщал об отсутствии.
Это не универсальная сертификация любого PDF и не ручной аудит Windows GUI.

## Как получить тестовую Windows-сборку

Открыть [Windows artifact 12340774906](https://github.com/imranOdiboev/pdfcraft/actions/runs/39579542556/artifacts/12340774906)
либо успешный run выше → Artifacts →
`odibo-foundation-windows-x64-2bd9007b709096399c91aacfa4e6271f6b319d6c`.
Войти в GitHub. ZIP — **85 976 773 байта, около 82 MiB**; хранится до **28.10.2026, 16:07
Asia/Yekaterinburg**. Распаковать весь ZIP в отдельную доступную для записи
папку и запустить `pdfcraft.exe`, сохранив остальные файлы рядом. CLI — `pdfcraft-cli.exe`.
Версия/commit указаны в BUILD_INFO.txt, контрольные суммы — SHA256SUMS.txt.

SHA-256 самого ZIP:
`c9a3f4280cf23938724cf522a02359c8eefa33c613166c5719c3ec3287b23c04`.
В архиве есть обе OCR-модели, их CC BY-SA attribution/licences, тексты лицензий
assets/vendor/craft-fonts и dependency-bundled fonts/CMap, корневые лицензии и NOTICE.
Снимок интерфейса доступен в [UI QA artifact](https://github.com/imranOdiboev/pdfcraft/actions/runs/39579542556/artifacts/12337949168).

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
Неразрешённых ошибок сборки или проваленных тестов в указанных прогонах нет.
Остаются исходные security exceptions и перечисленные ignored/неисполненные проверки.
Комплект OCR-весов проверен, но распознавание с ними не было отдельным acceptance-критерием.
Полное ребрендинг-тестирование, native Windows GUI/GPU, реальные принтеры, real-world corpus,
квалифицированные подписи, русский OCR, собственный updater/IDs, signing и юридическое одобрение
коммерческого выпуска остаются последующими задачами.

Список файлов следующего этапа: [ODIBO_REBRANDING_CHECKLIST.md](ODIBO_REBRANDING_CHECKLIST.md).
Обязательные уведомления: [ODIBO_LICENSE_NOTICES.md](ODIBO_LICENSE_NOTICES.md).
