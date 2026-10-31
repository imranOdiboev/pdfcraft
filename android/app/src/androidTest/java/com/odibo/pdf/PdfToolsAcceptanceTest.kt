package com.odibo.pdf

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.ByteArrayOutputStream
import java.io.File
import java.security.MessageDigest
import java.util.Locale
import java.util.UUID
import java.util.concurrent.TimeUnit
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

/** Real packaged worker plus independently rendered page-order verification. */
@RunWith(AndroidJUnit4::class)
class PdfToolsAcceptanceTest {
    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext

    private fun execute(vararg args: String): Pair<Int, JSONObject> {
        val worker = File(context.applicationInfo.nativeLibraryDir, "libodibo_core_exec.so")
        assertTrue(worker.canExecute())
        val process = ProcessBuilder(listOf(worker.absolutePath) + args).redirectErrorStream(true).start()
        try {
            assertTrue("Native PDF operation exceeded deadline", process.waitFor(30, TimeUnit.SECONDS))
            val bytes = process.inputStream.readBytes()
            assertTrue(bytes.size < 65536)
            return process.exitValue() to JSONObject(bytes.toString(Charsets.UTF_8))
        } finally {
            if (process.isAlive) process.destroyForcibly()
            process.inputStream.close(); process.errorStream.close(); process.outputStream.close()
        }
    }

    private fun success(vararg args: String): JSONObject {
        val result = execute(*args)
        assertEquals("Real worker rejected ${args.first()}", 0, result.first)
        return result.second
    }

    private fun hash(bytes: ByteArray): String = MessageDigest.getInstance("SHA-256")
        .digest(bytes).joinToString("") { "%02x".format(it) }

    // Contributor-original vector-only PDFs, no fonts or external test assets.
    private fun fixture(first: String, second: String): ByteArray {
        val streams = listOf(first, second).map { "$it rg\n10 10 170 270 re f\n" }
        val objects = listOf(
            "<< /Type /Catalog /Pages 2 0 R >>",
            "<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 300] /Contents 5 0 R >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 300] /Contents 6 0 R >>",
        ) + streams.map { "<< /Length ${it.toByteArray(Charsets.US_ASCII).size} >>\nstream\n${it}endstream" }
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

    private fun renderedPages(file: File): List<String> {
        val fd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        val renderer = try { PdfRenderer(fd) } catch (error: Exception) { fd.close(); throw error }
        return renderer.use { pdf ->
            List(pdf.pageCount) { index ->
                pdf.openPage(index).use { page ->
                    val bitmap = Bitmap.createBitmap(200, 300, Bitmap.Config.ARGB_8888)
                    try {
                        bitmap.eraseColor(Color.WHITE)
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        val output = ByteArrayOutputStream()
                        assertTrue(bitmap.compress(Bitmap.CompressFormat.PNG, 100, output))
                        hash(output.toByteArray())
                    } finally { bitmap.recycle() }
                }
            }
        }
    }

    @Test fun combineSplitReorderPreserveRenderedOrderAndSourceSha256() {
        val dir = File(context.cacheDir, "tools-${UUID.randomUUID()}").apply { assertTrue(mkdir()) }
        try {
            val left = File(dir, "first.pdf").apply { writeBytes(fixture("1 0 0", "0 1 0")) }
            val right = File(dir, "second.pdf").apply { writeBytes(fixture("0 0 1", "1 1 0")) }
            val originals = listOf(left, right).associateWith { hash(it.readBytes()) }
            val expected = renderedPages(right) + renderedPages(left)
            assertEquals(4, expected.toSet().size)
            val combined = File(dir, "combined.pdf")
            success("combine", combined.path, right.path, left.path)
            assertEquals(4, success("inspect", combined.path).getInt("pageCount"))
            assertEquals(expected, renderedPages(combined))
            val splitDir = File(dir, "parts")
            val parts = success("split", combined.path, splitDir.path, "1,3").getJSONArray("outputs")
            assertEquals(3, parts.length())
            val actual = mutableListOf<String>()
            listOf(1, 2, 1).forEachIndexed { index, count ->
                val name = parts.getJSONObject(index).getString("file")
                assertEquals("part-${String.format(Locale.ROOT, "%03d", index + 1)}.pdf", name)
                val part = File(splitDir, name)
                assertEquals(count, success("inspect", part.path).getInt("pageCount"))
                actual.addAll(renderedPages(part))
            }
            assertEquals(expected, actual)
            val reordered = File(dir, "reordered.pdf")
            success("reorder", combined.path, reordered.path, "3,1,0,2")
            assertEquals(listOf(3, 1, 0, 2).map { expected[it] }, renderedPages(reordered))
            originals.forEach { (source, before) -> assertEquals(before, hash(source.readBytes())) }
        } finally { dir.deleteRecursively() }
    }

    @Test fun invalidArgumentsAndDestinationsNeverModifyOriginals() {
        val dir = File(context.cacheDir, "tools-errors-${UUID.randomUUID()}").apply { assertTrue(mkdir()) }
        try {
            val source = File(dir, "original.pdf").apply { writeBytes(fixture("1 0 0", "0 1 0")) }
            val before = hash(source.readBytes())
            val output = File(dir, "absent.pdf")
            for (order in listOf("", "0", "0,0", "0,2", "1,-1", "x,1")) {
                assertTrue(execute("reorder", source.path, output.path, order).first != 0)
                assertFalse(output.exists())
            }
            for (cuts in listOf("", "0", "2", "1,1", "-1", "x")) {
                val parts = File(dir, "absent-parts")
                assertTrue(execute("split", source.path, parts.path, cuts).first != 0)
                assertFalse(parts.exists())
            }
            assertTrue(execute("combine", output.path, source.path).first != 0)
            assertFalse(output.exists())
            val existing = File(dir, "existing.pdf").apply { writeText("preserve me") }
            val sentinel = hash(existing.readBytes())
            assertTrue(execute("combine", existing.path, source.path, source.path).first != 0)
            assertEquals(sentinel, hash(existing.readBytes()))
            val corrupt = File(dir, "corrupt.pdf").apply { writeText("not a PDF") }
            assertTrue(execute("combine", output.path, source.path, corrupt.path).first != 0)
            assertFalse(output.exists())
            assertTrue(execute("reorder", source.path, source.path, "1,0").first != 0)
            assertEquals(before, hash(source.readBytes()))
        } finally { dir.deleteRecursively() }
    }
}
