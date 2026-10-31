package com.odibo.pdf.app

import android.app.Application
import android.graphics.Bitmap
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.odibo.pdf.data.DocumentFailure
import com.odibo.pdf.data.NativeBridge
import com.odibo.pdf.data.PdfInfo
import com.odibo.pdf.data.Problem
import com.odibo.pdf.data.ToolArguments
import com.odibo.pdf.render.PageRenderer
import com.odibo.pdf.storage.SafDocumentStore
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.launch
import kotlinx.coroutines.Job
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.File
import kotlin.coroutines.coroutineContext

data class OpenPdf(val file: File, val source: Uri, val name: String, val info: PdfInfo, val dirty: Boolean)
data class ToolInput(val file: File, val source: Uri, val name: String, val info: PdfInfo)
data class ToolResult(val file: File, val name: String, val info: PdfInfo)

class OdiboViewModel(application: Application) : AndroidViewModel(application) {
    private val storage = SafDocumentStore(application)
    private val core = NativeBridge(application)
    private val operations = Mutex()
    private var renderer: PageRenderer? = null
    private var operation: Job? = null
    private var resultDirectory: File? = null
    private var splitSources: List<Uri> = emptyList()
    private var protectedSources: List<Uri> = storage.preferences.getStringSet("protected-sources", emptySet())?.map { Uri.parse(it) }.orEmpty()
    var combineInputs by mutableStateOf<List<ToolInput>>(emptyList()); private set
    var toolResults by mutableStateOf<List<ToolResult>>(emptyList()); private set
    var splitSourceName by mutableStateOf(""); private set
    var savedToolCopies by mutableStateOf<List<Uri>>(emptyList()); private set
    var document by mutableStateOf<OpenPdf?>(null); private set
    var busy by mutableStateOf(false); private set
    var error by mutableStateOf<Problem?>(null); private set
    var savedCopy by mutableStateOf<Uri?>(null); private set
    var recent by mutableStateOf(storage.recent()); private set
    var theme by mutableStateOf(storage.preferences.getString("theme", "system") ?: "system"); private set
    var language by mutableStateOf(storage.preferences.getString("language", "system") ?: "system"); private set
    var licences by mutableStateOf(""); private set

    init {
        val restored = storage.restoreWorkingFile()
        val uri = storage.preferences.getString("source-uri", null)
        if (restored != null && uri != null) {
            runOperation {
                val info = core.inspect(restored)
                val next = createRenderer(restored)
                if (next.pageCount != info.pageCount) { next.close(); throw DocumentFailure(Problem.INVALID_PDF) }
                renderer = next
                document = OpenPdf(restored, Uri.parse(uri), storage.preferences.getString("working-title", "document.pdf") ?: "document.pdf", info, storage.preferences.getBoolean("working-dirty", false))
            }
        }
    }

    fun open(uri: Uri) {
        if (uri.scheme != "content") { error = Problem.ACCESS; return }
        runOperation {
            val file = importFile(uri)
            var accepted = false
            try {
                val info = core.inspect(file)
                val next = createRenderer(file)
                if (next.pageCount != info.pageCount) { next.close(); throw DocumentFailure(Problem.INVALID_PDF) }
                val name = withContext(Dispatchers.IO) { storage.displayName(uri) }
                val previous = document
                val oldRenderer = renderer
                renderer = next
                document = OpenPdf(file, uri, name, info, false)
                protectedSources = listOf(uri)
                storage.preferences.edit().putStringSet("protected-sources", setOf(uri.toString())).apply()
                savedCopy = null
                accepted = true
                withContext(Dispatchers.IO) {
                    storage.rememberWorkingFile(file, uri, name, false)
                    storage.remember(uri)
                    oldRenderer?.close()
                    previous?.let { storage.forget(it.file) }
                }
                recent = storage.recent()
            } finally { if (!accepted) withContext(NonCancellable + Dispatchers.IO) { storage.forget(file) } }
        }
    }

    fun rotate(page: Int) = runOperation {
        val previous = document ?: return@runOperation
        if (page !in 0 until previous.info.pageCount) throw DocumentFailure(Problem.INVALID_PDF)
        val output = storage.newWorkingFile()
        var accepted = false
        try {
            val info = core.rotate(previous.file, output, page)
            val next = createRenderer(output)
            if (next.pageCount != info.pageCount) { next.close(); throw DocumentFailure(Problem.INVALID_PDF) }
            val oldRenderer = renderer
            renderer = next
            document = previous.copy(file = output, info = info, dirty = true)
            savedCopy = null
            accepted = true
            withContext(Dispatchers.IO) {
                storage.rememberWorkingFile(output, previous.source, previous.name, true)
                oldRenderer?.close()
                storage.forget(previous.file)
            }
        } finally { if (!accepted && document?.file != output) withContext(NonCancellable + Dispatchers.IO) { storage.forget(output) } }
    }

    fun save(uri: Uri) = runOperation {
        val current = document ?: return@runOperation
        withContext(Dispatchers.IO) {
            val job = coroutineContext
            try { storage.export(current.file, uri, protectedSources + current.source) { job.ensureActive() } }
            catch (cancelled: CancellationException) { throw cancelled }
            catch (failure: DocumentFailure) { throw failure }
            catch (_: Exception) { throw DocumentFailure(Problem.SAVE) }
        }
        document = current.copy(dirty = false)
        withContext(Dispatchers.IO) { storage.rememberWorkingFile(current.file, current.source, current.name, false) }
        savedCopy = uri
    }

    suspend fun render(file: File, page: Int, width: Int): Bitmap? = withContext(Dispatchers.IO) {
        if (document?.file != file) return@withContext null
        val current = renderer ?: return@withContext null
        try { current.page(page, width) } catch (_: Exception) { null } catch (_: OutOfMemoryError) { null }
    }
    fun clearError() { error = null }
    fun cancelOperation() { operation?.cancel() }

    fun addCombine(uris: List<Uri>) = runOperation {
        if (uris.isEmpty()) return@runOperation
        if (combineInputs.size + uris.size > 32) throw DocumentFailure(Problem.TOO_LARGE)
        val added = mutableListOf<ToolInput>()
        var accepted = false
        try {
            var total = combineInputs.sumOf { it.file.length() }
            for (uri in uris) {
                if (uri.scheme != "content") throw DocumentFailure(Problem.ACCESS)
                val file = importFile(uri)
                // Register immediately so inspection/read failures clean our copy.
                added += ToolInput(file, uri, "document.pdf", PdfInfo(1, listOf(0)))
                total += file.length()
                if (total > ToolArguments.MAX_INPUT) throw DocumentFailure(Problem.TOO_LARGE)
                val info = core.inspect(file)
                if (combineInputs.sumOf { it.info.pageCount } + added.dropLast(1).sumOf { it.info.pageCount } + info.pageCount > 2000) throw DocumentFailure(Problem.TOO_LARGE)
                val title = withContext(Dispatchers.IO) { storage.displayName(uri) }
                added[added.lastIndex] = ToolInput(file, uri, title, info)
            }
            combineInputs = combineInputs + added
            accepted = true
        } finally {
            if (!accepted) withContext(NonCancellable + Dispatchers.IO) { added.forEach { storage.forget(it.file) } }
        }
    }

    fun moveCombine(index: Int, delta: Int) {
        if (busy || delta !in listOf(-1, 1)) return
        val target = index + delta
        if (index !in combineInputs.indices || target !in combineInputs.indices) return
        combineInputs = combineInputs.toMutableList().apply { add(target, removeAt(index)) }
    }
    fun removeCombine(index: Int) {
        if (busy || index !in combineInputs.indices) return
        val removed = combineInputs[index]
        combineInputs = combineInputs.filterIndexed { i, _ -> i != index }
        viewModelScope.launch(Dispatchers.IO) { storage.forget(removed.file) }
    }

    fun combine() = runOperation {
        val inputs = combineInputs
        try { ToolArguments.validateAggregate(inputs.map { it.file.length() }) }
        catch (_: IllegalArgumentException) { throw DocumentFailure(Problem.TOO_LARGE) }
        val output = storage.newWorkingFile()
        var accepted = false
        try {
            val info = core.combine(inputs.map { it.file }, output)
            if (info.pageCount != inputs.sumOf { it.info.pageCount }) throw DocumentFailure(Problem.VERIFY)
            installResult(output, inputs.first().source, "combined.pdf", info, inputs.map { it.source })
            accepted = true
        } finally { if (!accepted && document?.file != output) withContext(NonCancellable + Dispatchers.IO) { storage.forget(output) } }
    }

    fun reorder(order: List<Int>) = runOperation {
        val current = document ?: return@runOperation
        try { ToolArguments.validateOrder(order, current.info.pageCount) }
        catch (_: IllegalArgumentException) { throw DocumentFailure(Problem.INVALID_PDF) }
        val output = storage.newWorkingFile()
        var accepted = false
        try {
            val info = core.reorder(current.file, output, order)
            if (info.pageCount != current.info.pageCount) throw DocumentFailure(Problem.VERIFY)
            installResult(output, current.source, current.name, info, protectedSources + current.source)
            accepted = true
        } finally { if (!accepted && document?.file != output) withContext(NonCancellable + Dispatchers.IO) { storage.forget(output) } }
    }

    fun split(ranges: String) = runOperation {
        val current = document ?: return@runOperation
        val partition = try { ToolArguments.parseRanges(ranges, current.info.pageCount) }
        catch (_: IllegalArgumentException) { throw DocumentFailure(Problem.INVALID_PDF) }
        val folder = storage.newSplitDirectory()
        var accepted = false
        try {
            val parts = core.split(current.file, folder, partition.drop(1).map { it.first - 1 })
            if (parts.size != partition.size) throw DocumentFailure(Problem.VERIFY)
            for ((index, part) in parts.withIndex()) {
                if (part.second.pageCount != partition[index].count() || core.inspect(part.first) != part.second) throw DocumentFailure(Problem.VERIFY)
            }
            val old = resultDirectory
            toolResults = parts.map { ToolResult(it.first, it.first.name, it.second) }
            splitSourceName = current.name
            resultDirectory = folder
            splitSources = (protectedSources + current.source).distinct()
            savedToolCopies = emptyList()
            accepted = true
            withContext(NonCancellable + Dispatchers.IO) { old?.let { storage.forgetSplit(it) } }
        } finally { if (!accepted) withContext(NonCancellable + Dispatchers.IO) { storage.forgetSplit(folder) } }
    }

    fun exportTools(tree: Uri) = runOperation {
        val parts = toolResults
        if (parts.isEmpty()) return@runOperation
        // Counts describe this export attempt, never a previous successful folder.
        savedToolCopies = emptyList()
        val job = coroutineContext
        savedToolCopies = withContext(Dispatchers.IO) {
            try { storage.exportParts(parts.map { it.file }, tree, splitSources) { job.ensureActive() } }
            catch (cancelled: CancellationException) { throw cancelled }
            catch (failure: DocumentFailure) { throw failure }
            catch (_: Exception) { throw DocumentFailure(Problem.SAVE) }
        }
    }

    fun openToolResult(index: Int) = runOperation {
        val result = toolResults.getOrNull(index) ?: return@runOperation
        val current = document ?: return@runOperation
        // Copy to an independent working file; split cleanup never owns the viewer.
        val output = storage.newWorkingFile()
        var accepted = false
        try {
            withContext(Dispatchers.IO) { result.file.copyTo(output, overwrite = false) }
            installResult(output, splitSources.firstOrNull() ?: current.source, result.name, core.inspect(output), splitSources)
            accepted = true
        } finally { if (!accepted && document?.file != output) withContext(NonCancellable + Dispatchers.IO) { storage.forget(output) } }
    }

    private suspend fun installResult(file: File, source: Uri, name: String, info: PdfInfo, sources: List<Uri>) {
        val next = createRenderer(file)
        if (next.pageCount != info.pageCount) { next.close(); throw DocumentFailure(Problem.VERIFY) }
        withContext(NonCancellable) {
            val previous = document
            val oldRenderer = renderer
            renderer = next
            document = OpenPdf(file, source, name, info, true)
            protectedSources = sources.distinct()
            savedCopy = null
            withContext(Dispatchers.IO) {
                storage.rememberWorkingFile(file, source, name, true)
                storage.preferences.edit().putStringSet("protected-sources", protectedSources.map { it.toString() }.toSet()).apply()
                oldRenderer?.close()
                previous?.let { storage.forget(it.file) }
            }
        }
    }

    suspend fun renderToolPreview(file: File, width: Int): Bitmap? = withContext(Dispatchers.IO) {
        if (combineInputs.none { it.file == file } && toolResults.none { it.file == file }) return@withContext null
        try { PageRenderer(file).use { it.page(0, width) } }
        catch (_: Exception) { null } catch (_: OutOfMemoryError) { null }
    }
    private suspend fun importFile(uri: Uri): File {
        var imported: File? = null
        try { return withContext(Dispatchers.IO) { storage.importPdf(uri).also { imported = it } } }
        catch (failure: Throwable) {
            withContext(NonCancellable + Dispatchers.IO) { imported?.let { storage.forget(it) } }
            throw failure
        }
    }
    private suspend fun createRenderer(file: File): PageRenderer {
        var opened: PageRenderer? = null
        try { return withContext(Dispatchers.IO) { PageRenderer(file).also { opened = it } } }
        catch (failure: Throwable) {
            withContext(NonCancellable + Dispatchers.IO) { opened?.close() }
            throw failure
        }
    }
    fun updateTheme(value: String) { theme = value; storage.preferences.edit().putString("theme", value).apply() }
    fun updateLanguage(value: String) { language = value; storage.preferences.edit().putString("language", value).apply() }
    fun loadLicences() = runOperation {
        licences = withContext(Dispatchers.IO) {
            listOf("NOTICE", "LICENSE-MIT", "LICENSE-APACHE", "LICENSE-ODIBO-BRAND.txt", "THIRD_PARTY_NOTICES.txt").joinToString("\n\n") { name ->
                "$name\n" + getApplication<Application>().assets.open("legal/$name").bufferedReader().use { it.readText() }
            }
        }
    }
    private fun runOperation(action: suspend () -> Unit) {
        if (busy) return
        busy = true
        error = null
        operation = viewModelScope.launch {
            try { operations.withLock { action() } }
            catch (cancelled: CancellationException) { throw cancelled }
            catch (failure: DocumentFailure) { error = failure.problem }
            catch (_: SecurityException) { error = Problem.ACCESS }
            catch (_: OutOfMemoryError) { error = Problem.TOO_LARGE }
            catch (_: Exception) { error = Problem.ACCESS }
            finally { busy = false }
        }
    }
    override fun onCleared() {
        // PdfRenderer owns its descriptor. A short-lived cleanup thread waits for any render.
        val current = renderer
        Thread { try { current?.close() } catch (_: Exception) { } }.start()
        super.onCleared()
    }
}
