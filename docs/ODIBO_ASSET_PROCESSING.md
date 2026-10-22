# ODIBO PDF — подготовка фирменной графики

Дата: 2026-10-22. Представитель проекта: IMR4N.

Два утверждённых исходных PNG сохранены без изменения байтов в
`assets/odibo/source-icon.png` и `assets/odibo/source-logo.png`. По сообщению
владельца, они созданы через ChatGPT от OpenAI специально для ODIBO PDF.
Происхождение, SHA-256 и отдельные условия бренда описаны в
`assets/odibo/PROVENANCE.md`, `ATTRIBUTION.toml` и
`assets/odibo/LICENSE-ODIBO-BRAND.txt`. Исключительное авторское право на полностью
сгенерированные элементы и регистрация товарного знака не заявляются.

## Принятые запросы к imagegen

Для иконки использован утверждённый квадратный исходник и следующий запрос:

> Prepare a production Windows app icon from the approved image. Keep the EXACT approved O symbol, white/cyan gradient, vivid blue bottom and red folded corner inside the same dark navy rounded tile. Crop away the exterior white margins and exterior shadow entirely. The rounded tile should fill 98 percent of a square 1024x1024 canvas. Fill the tiny space outside the rounded tile with an opaque uniform deep navy #061024, NOT white; do not apply transparency or alpha matting, to avoid edge artifacts. Output crisp clean antialiased contour, no speckles, no floating dots, no halos, no rough thresholds. Preserve the approved design, no text or other objects. This is an opaque navy-matte adaptation of the supplied icon, with dark corners, not a new logo.

Для тёмного горизонтального логотипа использован утверждённый горизонтальный
исходник и следующий запрос:

> Edit supplied approved horizontal ODIBO PDF logo for a dark navy UI. Use a perfectly flat opaque background solid RGB #102038, no transparency processing, no cutout. Change navy ODIBO letters to solid near-white #F2F6FF. Preserve exact approved O shape with all its pale opaque white/cyan highlights, vivid blue base and red fold; preserve the lettering geometry and PDF red. Do not add anything. Clean antialiased edge, no speckles or masks. Crop away large outer margins: final composition wide wordmark approximately 5:1 aspect, close to edge with small equal margins. This is a dark-theme matte version, not a new design. No texture, no gradients in the background, no white border, no shadows.

Оба вызова использовали `transparent_background=false`. Запрошенное соотношение
5:1 не было достигнуто: принятый горизонтальный результат имеет пропорцию 3:1.
Светлая версия получена изменением размера исходника, без генеративной перерисовки.

## Технические производные

Попытки генеративного удаления фона дали дефекты контура и не включены в продукт.
Финальные иконка и тёмный логотип имеют непрозрачный тёмный фон. Углы квадратной
иконки также тёмные; прозрачность не заявляется. Оценка вида в Explorer и на панели
задач остаётся частью приёмки владельцем.

Изменение размеров и упаковка ICO выполнены штатными средствами .NET/GDI без
установки программ и без скриптового выделения фона. Использованы качественная
бикубическая интерполяция и оборачивание краёв, чтобы избежать прозрачных полос
при выборке пикселей. Светлые части знака не удалялись цветовым ключом.

Результаты в `assets/odibo/`:

- `icon-16.png`, `icon-32.png`, `icon-48.png`, `icon-64.png`, `icon-128.png`,
  `icon-256.png`, `icon-512.png`, `icon-1024.png`;
- `odibo-pdf.ico`: шесть PNG-кадров 16, 32, 48, 64, 128 и 256 px;
- `logo-light.png` и `logo-dark.png`: 1536 × 512 px.

Исходный логотип 2172 × 724 превышал базовый лимит текстур egui 2048 px и вызывал
панику на Home. Рабочие версии уменьшены; отдельная регрессия проверяет размеры.
CI дополнительно временно подставляет большой исходник, требует падения именно
этой регрессии, восстанавливает рабочий файл и требует успешного повтора.

Каждый включённый графический файл имеет собственную запись SHA-256 и лицензии.
Промежуточные генерации и локальные пути imagegen в сборку не включаются.
Редактируемый векторный мастер не создавался.
