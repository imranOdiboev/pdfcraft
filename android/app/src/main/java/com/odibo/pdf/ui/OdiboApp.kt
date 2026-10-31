@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package com.odibo.pdf.ui

import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.odibo.pdf.R
import com.odibo.pdf.app.OdiboViewModel
import java.util.Locale

@Composable
fun OdiboApp(model: OdiboViewModel, incoming: Uri?, consumeIncoming: () -> Unit, onOpen: () -> Unit, onSave: () -> Unit) {
    val labels = Labels(model.language == "ru" || (model.language == "system" && Locale.getDefault().language == "ru"))
    var screen by remember { mutableStateOf("home") }
    var pending by remember { mutableStateOf<(() -> Unit)?>(null) }
    fun requestOpen(action: () -> Unit) { if (model.document?.dirty == true) pending = action else action() }
    LaunchedEffect(model.document?.file) { if (model.document != null) screen = "viewer" }
    LaunchedEffect(incoming, model.busy) {
        if (incoming != null && !model.busy) {
            requestOpen { model.open(incoming) }
            consumeIncoming()
        }
    }
    BackHandler(screen != "home") { screen = "home" }
    OdiboTheme(model.theme) {
        Scaffold(topBar = {
            TopAppBar(title = { Text(if (screen == "viewer") model.document?.name ?: "ODIBO PDF" else "ODIBO PDF", maxLines = 1, overflow = TextOverflow.Ellipsis) },
                navigationIcon = { if (screen != "home") TextButton(onClick = { screen = "home" }) { Text(labels.home) } })
        }) { padding ->
            Column(Modifier.fillMaxSize().padding(padding)) {
                if (model.busy) LinearProgressIndicator(Modifier.fillMaxWidth())
                when (screen) {
                    "viewer" -> model.document?.let { ViewerScreen(model, it, labels, onSave) } ?: HomeScreen(model, labels, { requestOpen(onOpen) }, { screen = "settings" }, { uri -> requestOpen { model.open(uri) } }, { screen = "viewer" })
                    "settings" -> SettingsScreen(model, labels)
                    else -> HomeScreen(model, labels, { requestOpen(onOpen) }, { screen = "settings" }, { uri -> requestOpen { model.open(uri) } }, { screen = "viewer" })
                }
            }
        }
        model.error?.let { problem -> AlertDialog(onDismissRequest = model::clearError,
            title = { Text(labels.text("Could not complete the operation", "Не удалось выполнить операцию")) },
            text = { Text(labels.problem(problem)) }, confirmButton = { TextButton(onClick = model::clearError) { Text(labels.close) } }) }
        pending?.let { action -> AlertDialog(onDismissRequest = { pending = null },
            title = { Text(labels.text("Open another document?", "Открыть другой документ?")) },
            text = { Text(labels.text("The current working copy has unsaved changes. Save a new copy before switching, or discard these changes.", "В рабочей копии есть несохранённые изменения. Сначала сохраните новую копию либо откажитесь от изменений.")) },
            confirmButton = { TextButton(onClick = { pending = null; action() }) { Text(labels.text("Discard and open", "Отказаться и открыть")) } },
            dismissButton = { TextButton(onClick = { pending = null; screen = "viewer" }) { Text(labels.text("Keep working", "Продолжить работу")) } }) }
    }
}

@Composable
private fun HomeScreen(model: OdiboViewModel, labels: Labels, open: () -> Unit, settings: () -> Unit, recent: (Uri) -> Unit, resume: () -> Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp), horizontalAlignment = Alignment.Start) {
        Image(painterResource(R.drawable.odibo_icon), contentDescription = "ODIBO PDF", modifier = Modifier.size(88.dp))
        Text(labels.text("Your PDFs, on your phone", "Ваши PDF — на вашем телефоне"), style = MaterialTheme.typography.headlineMedium)
        Text(labels.text("Open, view, rotate and save a new copy. Processing stays on this device.", "Открывайте, просматривайте, поворачивайте и сохраняйте новую копию. Обработка выполняется на устройстве."))
        Button(onClick = open, enabled = !model.busy, modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp)) { Text(labels.open) }
        model.document?.let { document -> OutlinedButton(onClick = resume, enabled = !model.busy, modifier = Modifier.fillMaxWidth()) { Text(labels.text("Continue: ", "Продолжить: ") + document.name, maxLines = 2) } }
        model.recent?.let { uri -> OutlinedButton(onClick = { recent(uri) }, enabled = !model.busy, modifier = Modifier.fillMaxWidth()) { Text(labels.text("Reopen last permitted document", "Открыть последний доступный документ")) } }
        if (model.document == null && model.recent == null) Text(labels.text("No recent documents yet. Use Open PDF to choose one safely.", "Недавних документов пока нет. Нажмите «Открыть PDF», чтобы выбрать файл."), style = MaterialTheme.typography.bodyMedium)
        TextButton(onClick = settings, enabled = !model.busy) { Text(labels.settings) }
        Text(labels.text("Android 0.1 · Test build · Back up important documents", "Android 0.1 · Тестовая сборка · Сохраняйте резервные копии"), style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun SettingsScreen(model: OdiboViewModel, labels: Labels) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(labels.settings, style = MaterialTheme.typography.headlineSmall)
        Text(labels.text("Language", "Язык"), style = MaterialTheme.typography.titleMedium)
        Choice("system", labels.text("System language", "Системный язык"), model.language, model::updateLanguage)
        Choice("ru", "Русский", model.language, model::updateLanguage)
        Choice("en", "English", model.language, model::updateLanguage)
        Text(labels.text("Theme", "Тема"), style = MaterialTheme.typography.titleMedium)
        Choice("system", labels.text("System theme", "Системная тема"), model.theme, model::updateTheme)
        Choice("light", labels.text("Light", "Светлая"), model.theme, model::updateTheme)
        Choice("dark", labels.text("Dark", "Тёмная"), model.theme, model::updateTheme)
        Text("ODIBO PDF Android 0.1 · IMR4N", style = MaterialTheme.typography.titleMedium)
        Text(labels.limitations)
        Text(labels.text("Based on PdfCraft. Open code: MIT OR Apache-2.0. ODIBO brand terms are separate.", "На основе PdfCraft. Открытый код: MIT OR Apache-2.0. Фирменные материалы ODIBO имеют отдельные условия."))
        OutlinedButton(onClick = model::loadLicences, enabled = !model.busy) { Text(labels.text("Read licences and notices", "Лицензии и уведомления")) }
        if (model.licences.isNotEmpty()) Text(model.licences, style = MaterialTheme.typography.bodySmall)
    }
}

@Composable
private fun Choice(value: String, text: String, selected: String, change: (String) -> Unit) {
    OutlinedButton(onClick = { change(value) }, modifier = Modifier.fillMaxWidth()) { Text((if (selected == value) "✓ " else "") + text) }
}
