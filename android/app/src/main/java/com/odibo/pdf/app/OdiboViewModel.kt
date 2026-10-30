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
import com.odibo.pdf.render.PageRenderer
import com.odibo.pdf.storage.SafDocumentStore
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.File

data class OpenPdf(val file: File, val source: Uri, val name: String, val info: PdfInfo, val dirty: Boolean)

class OdiboViewModel(application: Application) : AndroidViewModel(application) {
    private val storage = SafDocumentStore(application)
    private val core = NativeBridge(application)
    private val operations = Mutex()
    private var renderer: PageRenderer? = null
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
        } finally { if (!accepted) withContext(NonCancellable + Dispatchers.IO) { storage.forget(output) } }
    }

    fun save(uri: Uri) = runOperation {
        val current = document ?: return@runOperation
        withContext(Dispatchers.IO) {
            try { storage.export(current.file, uri, current.source) }
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
    fun setTheme(value: String) { theme = value; storage.preferences.edit().putString("theme", value).apply() }
    fun setLanguage(value: String) { language = value; storage.preferences.edit().putString("language", value).apply() }
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
        viewModelScope.launch {
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
