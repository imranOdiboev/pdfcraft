package com.odibo.pdf.ui

import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.rememberTransformableState
import androidx.compose.foundation.gestures.transformable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.odibo.pdf.app.OdiboViewModel
import com.odibo.pdf.app.OpenPdf
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

@Composable
fun ViewerScreen(model: OdiboViewModel, document: OpenPdf, labels: Labels, save: () -> Unit) {
    val list = rememberLazyListState()
    val scope = rememberCoroutineScope()
    val page by remember(list, document.info.pageCount) { derivedStateOf { list.firstVisibleItemIndex.coerceIn(0, document.info.pageCount - 1) } }
    var jump by remember { mutableStateOf("") }
    Column(Modifier.fillMaxSize()) {
        Text(labels.page(page + 1, document.info.pageCount) + if (document.dirty) labels.text(" · Unsaved", " · Не сохранено") else "", Modifier.padding(horizontal = 16.dp, vertical = 8.dp), style = MaterialTheme.typography.titleSmall)
        Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = { model.rotate(page) }, enabled = !model.busy) { Text(labels.rotate) }
            Button(onClick = save, enabled = !model.busy) { Text(labels.save) }
        }
        Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(value = jump, onValueChange = { jump = it.filter(Char::isDigit).take(5) }, modifier = Modifier.weight(1f), singleLine = true,
                label = { Text(labels.text("Page number", "Номер страницы")) }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number))
            TextButton(onClick = { jump.toIntOrNull()?.let { target -> if (target in 1..document.info.pageCount) scope.launch { list.animateScrollToItem(target - 1) } } }, enabled = !model.busy && jump.toIntOrNull()?.let { it in 1..document.info.pageCount } == true) { Text(labels.text("Go", "Перейти")) }
        }
        model.savedCopy?.let { uri -> Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(labels.text("Copy saved and verified.", "Копия сохранена и проверена."), modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
            TextButton(onClick = { model.open(uri) }, enabled = !model.busy) { Text(labels.text("Reopen", "Открыть")) }
        } }
        LazyColumn(state = list, modifier = Modifier.fillMaxWidth().weight(1f).background(MaterialTheme.colorScheme.surfaceVariant), contentPadding = PaddingValues(12.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            items((0 until document.info.pageCount).toList(), key = { document.file.name + ":" + it }) { index ->
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                    Text(labels.page(index + 1, document.info.pageCount), style = MaterialTheme.typography.labelLarge)
                    PdfPage(model, document, index, labels)
                }
            }
        }
    }
}

@Composable
private fun PdfPage(model: OdiboViewModel, document: OpenPdf, page: Int, labels: Labels) {
    var bitmap by remember(document.file, page) { mutableStateOf<Bitmap?>(null) }
    var failed by remember(document.file, page) { mutableStateOf(false) }
    var size by remember { mutableStateOf(IntSize.Zero) }
    var scale by remember(document.file, page) { mutableFloatStateOf(1f) }
    var pan by remember(document.file, page) { mutableStateOf(Offset.Zero) }
    val transform = rememberTransformableState { zoom, offset, _ ->
        scale = (scale * zoom).coerceIn(1f, 4f)
        val maxX = size.width * (scale - 1f) / 2
        val maxY = size.height * (scale - 1f) / 2
        pan = Offset((pan.x + offset.x).coerceIn(-maxX, maxX), (pan.y + offset.y).coerceIn(-maxY, maxY))
    }
    LaunchedEffect(document.file, page) {
        try { bitmap = model.render(document.file, page, 1080); failed = bitmap == null }
        catch (cancelled: CancellationException) { throw cancelled }
        catch (_: Exception) { failed = true }
    }
    val image = bitmap
    if (image != null) {
        Box(Modifier.fillMaxWidth().aspectRatio(image.width.toFloat() / image.height).clipToBounds().onSizeChanged { size = it }
            .transformable(state = transform, canPan = { scale > 1f })) {
            Image(image.asImageBitmap(), contentDescription = labels.page(page + 1, document.info.pageCount), modifier = Modifier.fillMaxSize().graphicsLayer {
                scaleX = scale; scaleY = scale; translationX = pan.x; translationY = pan.y
            })
        }
        if (scale > 1f) TextButton(onClick = { scale = 1f; pan = Offset.Zero }) { Text(labels.text("Reset zoom", "Сбросить масштаб")) }
    } else Box(Modifier.fillMaxWidth().height(200.dp).background(Color.White), contentAlignment = Alignment.Center) {
        if (failed) Text(labels.text("This page could not be rendered.", "Не удалось отобразить страницу."), color = Color(0xFF252525), modifier = Modifier.padding(20.dp))
        else CircularProgressIndicator()
    }
}
