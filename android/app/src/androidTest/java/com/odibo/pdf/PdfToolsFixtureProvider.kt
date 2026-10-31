package com.odibo.pdf

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileNotFoundException
import java.util.Locale

/** Test-APK-only, read-only source; production APK must never contain this provider. */
class PdfToolsFixtureProvider : ContentProvider() {
    override fun onCreate() = true
    private fun source(uri: Uri): File {
        val id = uri.lastPathSegment
        if (id !in listOf("first", "second")) throw FileNotFoundException()
        val directory = context?.cacheDir ?: throw FileNotFoundException()
        return File(directory, "odibo-fixture-$id.pdf").also { file ->
            if (!file.exists()) file.writeBytes(pdf(if (id == "first") listOf("1 0 0", "0 1 0") else listOf("0 0 1", "1 1 0")))
        }
    }
    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") throw FileNotFoundException("Read-only synthetic source")
        return ParcelFileDescriptor.open(source(uri), ParcelFileDescriptor.MODE_READ_ONLY)
    }
    override fun query(uri: Uri, projection: Array<out String>?, selection: String?, selectionArgs: Array<out String>?, sortOrder: String?): Cursor {
        val file = source(uri)
        val columns = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        return MatrixCursor(columns).apply { addRow(columns.map { column -> when (column) {
            OpenableColumns.DISPLAY_NAME -> "${uri.lastPathSegment}.pdf"
            OpenableColumns.SIZE -> file.length()
            else -> null
        } }) }
    }
    override fun getType(uri: Uri) = "application/pdf"
    override fun insert(uri: Uri, values: ContentValues?): Uri? = throw UnsupportedOperationException()
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?) = throw UnsupportedOperationException()
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?) = throw UnsupportedOperationException()

    private fun pdf(colors: List<String>): ByteArray {
        val content = colors.map { "$it rg\n20 20 150 250 re f\n" }
        val objects = listOf("<< /Type /Catalog /Pages 2 0 R >>", "<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 300] /Contents 5 0 R >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 300] /Contents 6 0 R >>") +
            content.map { "<< /Length ${it.toByteArray(Charsets.US_ASCII).size} >>\nstream\n${it}endstream" }
        val bytes = ByteArrayOutputStream()
        fun write(s: String) { bytes.write(s.toByteArray(Charsets.US_ASCII)) }
        val offsets = mutableListOf(0)
        write("%PDF-1.4\n")
        objects.forEachIndexed { index, obj -> offsets.add(bytes.size()); write("${index + 1} 0 obj\n$obj\nendobj\n") }
        val start = bytes.size()
        write("xref\n0 ${offsets.size}\n0000000000 65535 f \n")
        offsets.drop(1).forEach { write(String.format(Locale.ROOT, "%010d 00000 n \n", it)) }
        write("trailer\n<< /Size ${offsets.size} /Root 1 0 R >>\nstartxref\n$start\n%%EOF\n")
        return bytes.toByteArray()
    }
}
