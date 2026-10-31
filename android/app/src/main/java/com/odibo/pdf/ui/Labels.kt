package com.odibo.pdf.ui

import com.odibo.pdf.data.Problem

class Labels(private val russian: Boolean) {
    fun text(en: String, ru: String) = if (russian) ru else en
    val open get() = text("Open PDF", "Открыть PDF")
    val home get() = text("Home", "Главная")
    val settings get() = text("Settings", "Настройки")
    val close get() = text("Close", "Закрыть")
    val save get() = text("Save new copy", "Сохранить новую копию")
    val rotate get() = text("Rotate page 90°", "Повернуть страницу на 90°")
    fun page(index: Int, count: Int) = text("Page $index of $count", "Страница $index из $count")
    fun problem(problem: Problem): String = when (problem) {
        Problem.ACCESS -> text("Cannot access this document. Choose it again and allow access.", "Нет доступа к документу. Выберите его снова и разрешите доступ.")
        Problem.TOO_LARGE -> text("This document exceeds the Android 0.1 memory or size limit (16 MiB input).", "Документ превышает ограничение Android 0.1 по памяти или размеру (16 МиБ на входе).")
        Problem.INVALID_PDF -> text("This PDF could not be processed. It may be damaged, encrypted, signed or unsupported. The original was not changed.", "Не удалось обработать PDF. Возможно, он повреждён, зашифрован, подписан или не поддерживается. Оригинал не изменён.")
        Problem.SECURITY -> text("Encrypted PDFs are not supported in Android 0.1. Choose an unencrypted test copy.", "Зашифрованные PDF не поддерживаются в Android 0.1. Выберите незашифрованную тестовую копию.")
        Problem.SIGNED -> text("Signed PDFs can be viewed, but rotation is disabled to protect their signatures.", "Подписанные PDF можно просматривать, но поворот запрещён для защиты подписей.")
        Problem.REPAIRED -> text("This PDF needs structural repair. Android 0.1 will not change it. Try a valid test copy.", "Этот PDF требует восстановления структуры. Android 0.1 не будет его изменять. Выберите корректную тестовую копию.")
        Problem.NATIVE -> text("The bundled PDF worker could not start. Use an ARM64 device and reinstall the complete APK.", "Не удалось запустить PDF-модуль. Нужен смартфон ARM64 и полный APK.")
        Problem.TIMEOUT -> text("The PDF operation took too long and was stopped. The previous working copy is safe.", "Операция выполнялась слишком долго и остановлена. Предыдущая рабочая копия сохранена.")
        Problem.SAME_SOURCE -> text("Choose a new file. Saving over the source document is not allowed.", "Выберите новый файл. Перезапись исходного документа запрещена.")
        Problem.SAVE, Problem.VERIFY -> text("The new copy could not be saved or verified. A partial new file may remain; the original is unchanged. Choose another destination.", "Не удалось сохранить или проверить новую копию. Может остаться неполный новый файл; оригинал не изменён. Выберите другое место.")
    }
    val limitations get() = text(
        "Android 0.1 is test software, provided AS IS to the extent permitted by applicable law. This does not remove non-excludable legal rights. Back up important documents. ARM64 only; input up to 16 MiB / 2000 pages. Open, view, rotate and save a new copy are supported. Encrypted PDFs and editing signed PDFs are unsupported. Combine, Split, Reorder, annotations, forms and OCR are not included. Rendering uses Android PdfRenderer; rotations use the existing Rust PDF core. No account, analytics or document uploads. A document provider selected by you may itself use cloud storage.",
        "Android 0.1 — тестовое ПО, предоставляемое «КАК ЕСТЬ» в пределах применимого закона. Неотчуждаемые законные права сохраняются. Создавайте резервные копии важных документов. Только ARM64; входной файл до 16 МиБ / 2000 страниц. Доступны открытие, просмотр, поворот и сохранение новой копии. Зашифрованные PDF и изменение подписанных PDF не поддерживаются. Объединение, разделение, перестановка, аннотации, формы и OCR пока отсутствуют. Отображение: Android PdfRenderer; поворот: существующее Rust-ядро. Нет аккаунтов, аналитики или отправки документов приложением. Выбранный вами файловый провайдер может использовать облачное хранилище.")
}
