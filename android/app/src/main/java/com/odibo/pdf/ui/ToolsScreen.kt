package com.odibo.pdf.ui

import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.odibo.pdf.app.OdiboViewModel
import com.odibo.pdf.data.ToolArguments
import kotlinx.coroutines.CancellationException
import java.io.File

@Composable
fun CombineScreen(model: OdiboViewModel, labels: Labels, add: () -> Unit, combine: () -> Unit) {
    val inputs = model.combineInputs
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(labels.combine, style = MaterialTheme.typography.headlineSmall)
            Text(labels.text("Select at least two PDFs. Their pages will follow the order below; originals stay unchanged.", "Выберите не менее двух PDF. Страницы будут объединены в указанном порядке; оригиналы не изменятся."))
            Text(labels.text("Up to 32 files; all inputs together must fit the 16 MiB / 2,000-page limits.", "До 32 файлов; суммарно — не более 16 МиБ / 2000 страниц."), style = MaterialTheme.typography.bodyMedium)
            Button(onClick = add, enabled = !model.busy, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) { Text(labels.text("Add PDF files", "Добавить PDF")) }
            Button(onClick = combine, enabled = !model.busy && inputs.size >= 2, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) { Text(labels.text("Combine ${inputs.size} files", "Объединить ${inputs.size} файла")) }
        }
        }
        if (inputs.isEmpty()) item { Text(labels.text("No PDFs selected. Add files with the system picker.", "PDF пока не выбраны. Добавьте файлы через системный выбор."), Modifier.padding(vertical = 16.dp)) }
            itemsIndexed(inputs, key = { _, input -> input.file.absolutePath }) { index, input ->
                ElevatedCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                            ToolThumbnail(model, input.file, 0, labels)
                            Column(Modifier.weight(1f)) {
                                Text("${index + 1}. ${input.name}", style = MaterialTheme.typography.titleMedium)
                                Text(labels.text("${input.info.pageCount} pages", "Страниц: ${input.info.pageCount}"))
                            }
                        }
                        OrderButtons(labels, labels.text("file ${index + 1}", "файл ${index + 1}"), index, inputs.size, !model.busy, { delta -> model.moveCombine(index, delta) })
                        TextButton(onClick = { model.removeCombine(index) }, enabled = !model.busy) { Text(labels.text("Remove from list", "Убрать из списка")) }
                    }
                }
            }
    }
}

@Composable
fun SplitScreen(model: OdiboViewModel, labels: Labels, open: () -> Unit, export: () -> Unit, openResult: (Int) -> Unit) {
    val document = model.document
    if (document == null) { ToolNeedsDocument(labels, open); return }
    var ranges by rememberSaveable(document.file.absolutePath) { mutableStateOf("") }
    val parsed = remember(ranges, document.info.pageCount) {
        try { ToolArguments.parseRanges(ranges, document.info.pageCount) } catch (_: IllegalArgumentException) { null }
    }
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(labels.split, style = MaterialTheme.typography.headlineSmall)
                Text(document.name, style = MaterialTheme.typography.titleMedium)
                Text(labels.text("${document.info.pageCount} pages", "Страниц: ${document.info.pageCount}"))
                Text(labels.text("Enter consecutive, non-overlapping ranges covering every page. For 5 pages: 1-2, 3-5. Each range creates one PDF.", "Введите последовательные диапазоны без пропусков и повторов, охватывающие все страницы. Для 5 страниц: 1-2, 3-5. Каждый диапазон создаёт один PDF."))
                OutlinedTextField(value = ranges, onValueChange = { ranges = it.take(20_000) }, enabled = !model.busy,
                    modifier = Modifier.fillMaxWidth(), label = { Text(labels.text("Page ranges", "Диапазоны страниц")) },
                    placeholder = { Text("1-2, 3-5") }, isError = ranges.isNotBlank() && parsed == null,
                    supportingText = { Text(if (parsed == null && ranges.isNotBlank()) labels.text("Use increasing ranges from page 1 to the last page, without gaps or overlaps.", "Диапазоны должны идти по порядку от первой до последней страницы, без пропусков и повторов.") else labels.text("Page numbers start at 1; create 2–32 PDFs.", "Нумерация с 1; от 2 до 32 PDF.")) })
                if (parsed != null) Text(labels.text("Preview: ${parsed.size} output PDFs", "Результат: ${parsed.size} PDF"), style = MaterialTheme.typography.titleMedium)
            }
        }
        if (parsed != null) itemsIndexed(parsed) { index, range ->
            Text(labels.text("PDF ${index + 1}: pages ${range.first}–${range.last}", "PDF ${index + 1}: страницы ${range.first}–${range.last}"))
        }
        item {
            Button(onClick = { model.split(ranges) }, enabled = !model.busy && parsed != null && parsed.size >= 2, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) { Text(labels.text("Prepare split PDFs", "Подготовить PDF")) }
        }
        if (model.toolResults.isNotEmpty()) {
            item {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(labels.text("Prepared and verified. Choose a folder to save new files.", "Файлы подготовлены и проверены. Выберите папку для сохранения новых файлов."), style = MaterialTheme.typography.titleMedium)
                    Text(labels.text("A provider failure may leave partial new files. Originals remain unchanged.", "При ошибке провайдера могут остаться неполные новые файлы. Оригиналы не изменяются."))
                    Button(onClick = export, enabled = !model.busy, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) { Text(labels.text("Choose folder and save", "Выбрать папку и сохранить")) }
                }
            }
            itemsIndexed(model.toolResults, key = { _, result -> result.file.absolutePath }) { index, result ->
                OutlinedCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(result.name, style = MaterialTheme.typography.titleMedium)
                        Text(labels.text("${result.info.pageCount} pages", "Страниц: ${result.info.pageCount}"))
                        TextButton(onClick = { openResult(index) }, enabled = !model.busy) { Text(labels.text("Open result ${index + 1}", "Открыть результат ${index + 1}")) }
                    }
                }
            }
        }
        if (model.savedToolCopies.isNotEmpty()) item { Text(labels.text("Saved and verified: ${model.savedToolCopies.size} PDFs.", "Сохранено и проверено PDF: ${model.savedToolCopies.size}."), style = MaterialTheme.typography.titleMedium) }
    }
}

@Composable
fun ReorderScreen(model: OdiboViewModel, labels: Labels, open: () -> Unit) {
    val document = model.document
    if (document == null) { ToolNeedsDocument(labels, open); return }
    var order by rememberSaveable(document.file.absolutePath) { mutableStateOf(ArrayList((0 until document.info.pageCount).toList())) }
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(labels.reorder, style = MaterialTheme.typography.headlineSmall)
            Text(document.name, style = MaterialTheme.typography.titleMedium)
            Text(labels.text("Move pages up or down. Every original page appears once. Apply, review, then save a new copy.", "Перемещайте страницы вверх и вниз. Каждая исходная страница используется один раз. Примените порядок, проверьте и сохраните новую копию."))
            Button(onClick = { model.reorder(order.toList()) }, enabled = !model.busy && order != (0 until document.info.pageCount).toList(), modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) { Text(labels.text("Apply page order", "Применить порядок")) }
            TextButton(onClick = { order = ArrayList((0 until document.info.pageCount).toList()) }, enabled = !model.busy) { Text(labels.text("Reset order", "Сбросить порядок")) }
        }
        }
            itemsIndexed(order, key = { _, page -> page }) { index, originalPage ->
                ElevatedCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            ToolThumbnail(model, document.file, originalPage, labels)
                            Column(Modifier.weight(1f)) {
                                Text(labels.text("Position ${index + 1}", "Позиция ${index + 1}"), style = MaterialTheme.typography.titleMedium)
                                Text(labels.text("Original page ${originalPage + 1}", "Исходная страница ${originalPage + 1}"))
                            }
                        }
                        OrderButtons(labels, labels.text("page ${originalPage + 1}", "страницу ${originalPage + 1}"), index, order.size, !model.busy) { delta ->
                            val target = index + delta
                            if (target in order.indices) {
                                val next = ArrayList(order)
                                val moved = next.removeAt(index)
                                next.add(target, moved)
                                order = next
                            }
                        }
                    }
                }
            }
    }
}

@Composable
private fun ToolNeedsDocument(labels: Labels, open: () -> Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text(labels.text("Open a PDF to use this tool", "Откройте PDF для работы с инструментом"), style = MaterialTheme.typography.headlineSmall)
        Text(labels.text("Choose a document with the system picker. The original will remain unchanged.", "Выберите документ через системное окно. Оригинал останется без изменений."))
        Button(onClick = open, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) { Text(labels.open) }
    }
}

@Composable
private fun OrderButtons(labels: Labels, item: String, index: Int, count: Int, enabled: Boolean, move: (Int) -> Unit) {
    // Full labels and native buttons provide TalkBack/keyboard actions without drag-only controls.
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        OutlinedButton(onClick = { move(-1) }, enabled = enabled && index > 0, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
            .semantics { contentDescription = labels.text("Move $item up", "Переместить $item вверх") }) { Text(labels.text("Move up", "Вверх")) }
        OutlinedButton(onClick = { move(1) }, enabled = enabled && index + 1 < count, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)
            .semantics { contentDescription = labels.text("Move $item down", "Переместить $item вниз") }) { Text(labels.text("Move down", "Вниз")) }
    }
}

@Composable
private fun ToolThumbnail(model: OdiboViewModel, file: File, page: Int, labels: Labels) {
    var bitmap by remember(file, page) { mutableStateOf<Bitmap?>(null) }
    var failed by remember(file, page) { mutableStateOf(false) }
    LaunchedEffect(file, page) {
        try { bitmap = if (model.document?.file == file) model.render(file, page, 200) else model.renderToolPreview(file, 200); failed = bitmap == null }
        catch (cancelled: CancellationException) { throw cancelled }
        catch (_: Exception) { failed = true }
    }
    val image = bitmap
    Box(Modifier.width(64.dp).height(88.dp), contentAlignment = Alignment.Center) {
        if (image != null) Image(image.asImageBitmap(), contentDescription = labels.text("Preview of page ${page + 1}", "Миниатюра страницы ${page + 1}"), modifier = Modifier.fillMaxSize())
        else if (failed) Text(labels.text("No preview", "Нет миниатюры"), style = MaterialTheme.typography.labelSmall)
        else CircularProgressIndicator(Modifier.size(24.dp))
    }
}
