package com.odibo.pdf.storage

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import com.odibo.pdf.data.DocumentFailure
import com.odibo.pdf.data.Problem
import java.io.File
import java.io.InputStream
import java.io.OutputStream
import java.security.MessageDigest
import java.util.UUID

class SafDocumentStore(private val context: Context) {
    private val resolver = context.contentResolver
    val preferences = context.getSharedPreferences("odibo-android", Context.MODE_PRIVATE)
    private val directory = File(context.filesDir, "working-pdf").apply { mkdirs() }

    fun newWorkingFile(): File = File(directory, UUID.randomUUID().toString() + ".pdf")
    fun forget(file: File) { if (file.parentFile?.canonicalFile == directory.canonicalFile) file.delete() }

    fun importPdf(uri: Uri): File {
        val file = newWorkingFile()
        try {
            resolver.openInputStream(uri)?.use { input -> file.outputStream().use { output -> copyBounded(input, output, 16L * 1024 * 1024) } }
                ?: throw DocumentFailure(Problem.ACCESS)
            return file
        } catch (error: Exception) { forget(file); throw error }
    }

    fun displayName(uri: Uri): String = try {
        resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) cursor.getString(0)?.take(160) else null
        } ?: "document.pdf"
    } catch (_: Exception) { "document.pdf" }

    fun remember(uri: Uri) {
        try { resolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION) } catch (_: SecurityException) { }
        if (hasPersistentRead(uri)) preferences.edit().putString("recent-uri", uri.toString()).apply()
    }
    private fun hasPersistentRead(uri: Uri): Boolean = resolver.persistedUriPermissions.any { it.uri == uri && it.isReadPermission }
    fun recent(): Uri? = preferences.getString("recent-uri", null)?.let { Uri.parse(it) }?.takeIf { hasPersistentRead(it) }

    fun restoreWorkingFile(): File? {
        val name = preferences.getString("working-name", null) ?: return null
        if (!name.matches(Regex("[0-9a-f-]{36}\\.pdf"))) return null
        return File(directory, name).takeIf { it.isFile && it.length() in 1..(32L * 1024 * 1024) }
    }
    fun rememberWorkingFile(file: File, source: Uri, name: String, dirty: Boolean) {
        preferences.edit().putString("working-name", file.name).putString("source-uri", source.toString())
            .putString("working-title", name).putBoolean("working-dirty", dirty).apply()
    }

    fun export(file: File, destination: Uri, source: Uri) {
        if (sameDocument(source, destination)) throw DocumentFailure(Problem.SAME_SOURCE)
        val expected = digest(file.inputStream())
        resolver.openOutputStream(destination, "w")?.use { output ->
            file.inputStream().use { copyBounded(it, output, 32L * 1024 * 1024) }
            output.flush()
        } ?: throw DocumentFailure(Problem.SAVE)
        val actual = resolver.openInputStream(destination)?.use { digest(it) } ?: throw DocumentFailure(Problem.VERIFY)
        if (!actual.contentEquals(expected)) throw DocumentFailure(Problem.VERIFY)
    }

    private fun sameDocument(first: Uri, second: Uri): Boolean {
        if (first == second || first.normalizeScheme() == second.normalizeScheme()) return true
        if (first.authority != second.authority) return false
        return try {
            DocumentsContract.isDocumentUri(context, first) && DocumentsContract.isDocumentUri(context, second) &&
                DocumentsContract.getDocumentId(first) == DocumentsContract.getDocumentId(second)
        } catch (_: Exception) { false }
    }
    private fun digest(input: InputStream): ByteArray = input.use {
        val digest = MessageDigest.getInstance("SHA-256")
        val bytes = ByteArray(64 * 1024)
        var total = 0L
        while (true) {
            val size = it.read(bytes)
            if (size < 0) break
            total += size
            if (total > 32L * 1024 * 1024) throw DocumentFailure(Problem.TOO_LARGE)
            digest.update(bytes, 0, size)
        }
        digest.digest()
    }
    private fun copyBounded(input: InputStream, output: OutputStream, limit: Long) {
        val buffer = ByteArray(64 * 1024)
        var total = 0L
        while (true) {
            val size = input.read(buffer)
            if (size < 0) break
            total += size
            if (total > limit) throw DocumentFailure(Problem.TOO_LARGE)
            output.write(buffer, 0, size)
        }
    }
}
