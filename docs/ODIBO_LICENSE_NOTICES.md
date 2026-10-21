# ODIBO foundation: сохраняемые лицензионные уведомления

Дата: 21.10.2026. Статус: технический перечень обязательных уведомлений для тестовой Windows-поставки.
Это не юридическое заключение о правах всех вкладов или доступности товарного знака.

| Компонент | Условия и обязательные материалы |
|---|---|
| PdfCraft и новые foundation-изменения | `MIT OR Apache-2.0`: сохранить `LICENSE-MIT`, `LICENSE-APACHE`, применимые copyright и `NOTICE`. Не заменять ArtCraft Team/PdfCraft contributors своим авторством. Изменённые файлы отмечены в истории и PR; лицензии исходного кода остаются применимы |
| Cargo dependencies | Точные разрешённые лицензии и полные тексты собираются cargo-about 0.9.2 из зафиксированного Windows dependency graph; результат `THIRD_PARTY_CARGO.html`. Build-time зависимости могут быть включены сверх runtime-набора. cargo-deny остаётся отдельной обязательной проверкой |
| Локальные vendor patches | Полные LICENSE/NOTICE/COPYING из `vendor/` сохраняются отдельно с путями. Это покрывает patched hayro-family, lopdf, winit, egui-wgpu и vello_common; нельзя считать их автоматически включёнными в отчёт для registry crates |
| Lucide и document icon | ISC, для document icon также MIT OR Apache-2.0. Сохранить `assets/icons/LICENSE-lucide.txt` и `assets/app-icon/LICENSE-document.txt`, включая copyright/disclaimer |
| Inter, JetBrains Mono, Dancing Script | Сохранить `assets/fonts/OFL-*.txt`. OFL относится к шрифтам; Reserved Font Names не присваиваются изменённым версиям |
| craft-fonts | Закреплённая ревизия `3d9ab3a132ed0eff457e424226a435a901da30d3`; сохранить OFL/copyright для семейств. Копирование только этих OFL не заменяет лицензии локальных Inter/JetBrains/Dancing |
| egui bundled fonts | Ubuntu Font Licence, OFL, MIT/Bitstream Vera и MIT для соответствующих файлов; учтены в dependency report и attribution. Проверять полные тексты, а не только SPDX в Cargo.toml |
| Foxit standard-14 substitutes | BSD-3-Clause, `vendor/hayro-interpret/assets/LICENSE_FOXIT`, PDFium/Foxit copyright и disclaimer. Не использовать имена для endorsement |
| Adobe CMap | BSD-3-Clause для технических таблиц hayro-cmap, с сохранением исходных notices. Не даёт прав на Adobe artwork, логотипы или системные шрифты |
| ICC data | Сохранить применимые сведения о происхождении и тексты, включая CGATS licence-файлы; не заменять их общей лицензией приложения |
| OCR-модели | CC BY-SA 4.0, Robert Knight: `models/ATTRIBUTION.txt`, файлы `*.LICENCE.txt`, происхождение/хеши. xtask models загружает и проверяет их; OCR не удалён из сборки. EULA будущего продукта должна сохранять права на отдельно лицензированные веса |
| ArtCraft trademarks | `docs/brand/LICENSE-brand.txt` исключает marks из open source. В тестовом exe они не встраиваются; авторское упоминание в NOTICE сохраняется. Прежний upstream-брендинг нельзя выдавать за собственный |

## Что делает foundation workflow

- Проверяет исходный `deny.toml` без добавления ignore для исправляемых advisories.
- Использует cargo-about, закреплённый по версии и SHA-256 его архива; новые инструменты запускаются
  только на disposable GitHub runner.
- Добавляет к exe корневые лицензии, NOTICE, оба файла attribution, HTML dependency notices,
  все существующие licence/notice-файлы из assets/vendor/craft-fonts и лицензии OCR-моделей.
- Вкладывает `BUILD_INFO.txt`, `TEST_BUILD.txt`, `SHA256SUMS.txt` и portable.txt. Имена
  executable и название продукта пока PdfCraft. Архив не содержит ArtCraft SVG/PNG.
- Не создаёт GitHub Release и не применяет чужую подпись. Изменения в main не отправляются.

Реестр `ATTRIBUTION.toml` и независимый `cargo xtask assets` сохраняются. При будущей замене
материалов сначала обновляется TOML, затем `cargo xtask assets --write` генерирует Markdown.
Новый Rust-тест создаёт свои PDF только во временном каталоге runner; бинарные fixtures в Git
не добавляются и пользовательские документы не загружаются.

## Перед самостоятельным коммерческим выпуском

Проверить состав уже распакованного продукта, полноту copyright и условий для реально встроенных
материалов, собственный EULA с third-party исключениями, договоры и бренд. Автоматический отчёт
облегчает проверку, но не доказывает отсутствие всех правовых рисков. Любые отдельные новые модели,
renderer, Office-конвертеры и Android SDK требуют нового анализа лицензий.

Первичные тексты: [MIT](https://opensource.org/license/mit),
[Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0),
[OFL](https://openfontlicense.org/open-font-license-official-text/),
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/),
[OCR model card](https://huggingface.co/robertknight/ocrs).
