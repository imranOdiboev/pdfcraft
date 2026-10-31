package com.odibo.pdf

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import java.io.File
import java.io.FileNotFoundException
import java.util.UUID

/** Test APK only: real SAF-contract URI/stream operations with controlled failures.
 * Uses ContentProvider to avoid granting signature MANAGE_DOCUMENTS to the target.
 * It is not evidence that Android's system picker or arbitrary providers passed.
 */
class PdfToolsSafProvider : ContentProvider() {
    companion object { const val AUTHORITY = "com.odibo.pdf.test.saf" }
    private val lock = Any()
    override fun onCreate() = true
    private fun folder(token: String): File {
        if (!token.matches(Regex("(success|alias|deny|mismatch|cancel)-[0-9a-f-]{36}"))) throw FileNotFoundException()
        return File(context?.cacheDir ?: throw FileNotFoundException(), "saf-$token").apply {
            mkdirs()
            val source = File(this, "source")
            if (!source.exists()) source.writeText("Synthetic original: must never be overwritten")
        }
    }
    private fun id(uri: Uri): Pair<String, String> {
        val document = DocumentsContract.getDocumentId(uri)
        val parts = document.split(':')
        if (parts.size != 2 || !parts[1].matches(Regex("source|out-[0-9a-f-]{36}"))) throw FileNotFoundException()
        folder(parts[0])
        return parts[0] to parts[1]
    }
    private fun event(dir: File, name: String) { File(dir, ".$name").appendText("1\n") }
    private fun count(dir: File, name: String): Int = File(dir, ".$name").takeIf { it.exists() }?.readLines()?.size ?: 0

    @Suppress("DEPRECATION")
    override fun call(method: String, arg: String?, extras: Bundle?): Bundle = synchronized(lock) {
        if (method == "qa:stats") {
            val dir = folder(arg ?: throw IllegalArgumentException())
            return@synchronized Bundle().apply {
                putInt("creates", count(dir, "creates")); putInt("writes", count(dir, "writes")); putInt("readbacks", count(dir, "readbacks"))
                putInt("outputs", dir.listFiles()?.count { it.name.startsWith("out-") } ?: 0)
            }
        }
        if (method != "android:createDocument") throw UnsupportedOperationException()
        val parent = extras?.getParcelable<Uri>("uri") ?: throw IllegalArgumentException()
        val token = DocumentsContract.getTreeDocumentId(parent)
        val dir = folder(token)
        event(dir, "creates")
        val name = if (token.startsWith("alias-")) "source" else "out-${UUID.randomUUID()}"
        if (name != "source") File(dir, name).createNewFile()
        Bundle().apply { putParcelable("uri", DocumentsContract.buildDocumentUriUsingTree(parent, "$token:$name")) }
    }

    override fun query(uri: Uri, projection: Array<out String>?, selection: String?, selectionArgs: Array<out String>?, sortOrder: String?): Cursor = synchronized(lock) {
        val columns = projection ?: arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
        val token = DocumentsContract.getTreeDocumentId(uri)
        val dir = folder(token)
        val names = if (uri.lastPathSegment == "children") dir.listFiles().orEmpty().filter { it.name == "source" || it.name.startsWith("out-") }.map { it.name }
            else listOf(id(uri).second)
        MatrixCursor(columns).apply { names.forEach { name ->
            addRow(columns.map { column -> when (column) {
                DocumentsContract.Document.COLUMN_DOCUMENT_ID -> "$token:$name"
                DocumentsContract.Document.COLUMN_DISPLAY_NAME -> "$name.pdf"
                DocumentsContract.Document.COLUMN_MIME_TYPE -> "application/pdf"
                DocumentsContract.Document.COLUMN_SIZE -> File(dir, name).length()
                else -> null
            } })
        } }
    }
    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor = synchronized(lock) {
        val (token, name) = id(uri)
        val dir = folder(token)
        if (mode == "r") {
            if (name != "source") event(dir, "readbacks")
            val file = if (name != "source" && token.startsWith("mismatch-")) File(dir, ".bad-readback").apply { writeText("provider corrupted read-back") } else File(dir, name)
            return@synchronized ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        }
        event(dir, "writes")
        if (name == "source" || token.startsWith("deny-")) throw FileNotFoundException("Controlled test provider write refusal")
        ParcelFileDescriptor.open(File(dir, name), ParcelFileDescriptor.MODE_WRITE_ONLY or ParcelFileDescriptor.MODE_TRUNCATE)
    }
    override fun getType(uri: Uri) = "application/pdf"
    override fun insert(uri: Uri, values: ContentValues?): Uri? = throw UnsupportedOperationException()
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?) = throw UnsupportedOperationException()
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?) = throw UnsupportedOperationException()
}
