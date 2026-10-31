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
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Exercises the packaged Rust PIE and Android renderer, never a fake bridge. */
@RunWith(AndroidJUnit4::class)
class NativeWorkerAcceptanceTest {
    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext

    private fun worker(vararg arguments: String): Pair<Int, JSONObject> {
        val executable = File(context.applicationInfo.nativeLibraryDir, "libodibo_core_exec.so")
        assertTrue("Packaged Rust worker is missing", executable.isFile)
        assertTrue("Packaged Rust worker is not executable", executable.canExecute())
        val process = ProcessBuilder(listOf(executable.absolutePath) + arguments)
            .redirectErrorStream(true).start()
        try {
            if (!process.waitFor(30, TimeUnit.SECONDS)) {
                process.destroyForcibly()
                throw AssertionError("Real Rust worker exceeded its test deadline")
            }
            val bytes = process.inputStream.use { it.readBytes() }
            assertTrue("Unexpected worker output size", bytes.size <= 16 * 1024)
            return process.exitValue() to JSONObject(bytes.toString(Charsets.UTF_8).trim())
        } finally {
            process.inputStream.close()
            process.errorStream.close()
            process.outputStream.close()
            if (process.isAlive) process.destroyForcibly()
        }
    }

    private fun digest(file: File): String = MessageDigest.getInstance("SHA-256")
        .digest(file.readBytes()).joinToString("") { "%02x".format(it) }

    /** All PDF content is generated here: vector rectangles, no external fonts/assets. */
    private fun syntheticPdf(): ByteArray {
        val content1 = "1 0 0 rg\n20 20 80 100 re f\n"
        val content2 = "0 0 1 rg\n40 40 100 150 re f\n"
        val objects = listOf(
            "<< /Type /Catalog /Pages 2 0 R >>",
            "<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 300] /Contents 5 0 R >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 300] /Contents 6 0 R >>",
            "<< /Length ${content1.toByteArray(Charsets.US_ASCII).size} >>\nstream\n${content1}endstream",
            "<< /Length ${content2.toByteArray(Charsets.US_ASCII).size} >>\nstream\n${content2}endstream",
        )
        val bytes = ByteArrayOutputStream()
        fun write(value: String) { bytes.write(value.toByteArray(Charsets.US_ASCII)) }
        write("%PDF-1.4\n")
        val offsets = mutableListOf(0)
        objects.forEachIndexed { index, value ->
            offsets.add(bytes.size())
            write("${index + 1} 0 obj\n$value\nendobj\n")
        }
        val xref = bytes.size()
        write("xref\n0 ${offsets.size}\n0000000000 65535 f \n")
        offsets.drop(1).forEach { write(String.format(Locale.ROOT, "%010d 00000 n \n", it)) }
        write("trailer\n<< /Size ${offsets.size} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n")
        return bytes.toByteArray()
    }

    private fun assertRealRendering(file: File, expectedWidth: Int, expectedHeight: Int) {
        // PdfRenderer owns the descriptor after successful construction.
        val descriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        val renderer = try { PdfRenderer(descriptor) } catch (failure: Exception) {
            descriptor.close()
            throw failure
        }
        renderer.use {
            assertEquals(2, it.pageCount)
            it.openPage(0).use { page ->
                assertEquals(expectedWidth, page.width)
                assertEquals(expectedHeight, page.height)
                val bitmap = Bitmap.createBitmap(page.width, page.height, Bitmap.Config.ARGB_8888)
                try {
                    bitmap.eraseColor(Color.WHITE)
                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    val pixels = IntArray(bitmap.width * bitmap.height)
                    bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
                    assertTrue("Real rendered PDF is blank", pixels.any { pixel ->
                        Color.alpha(pixel) > 0 && (pixel and 0x00ffffff) != 0x00ffffff
                    })
                } finally { bitmap.recycle() }
            }
        }
    }

    @Test
    fun actualNativeInspectRotateSaveReopenAndRenderPreservesSource() {
        val directory = File(context.cacheDir, "native-test-${UUID.randomUUID()}")
        assertTrue(directory.mkdir())
        try {
            val input = File(directory, "original.pdf").apply { writeBytes(syntheticPdf()) }
            val output = File(directory, "rotated-copy.pdf")
            val before = digest(input)
            val (inspectCode, info) = worker("inspect", input.absolutePath)
            assertEquals(0, inspectCode)
            assertEquals(2, info.getInt("pageCount"))
            assertEquals(0, info.getJSONArray("rotations").getInt(0))
            assertRealRendering(input, 200, 300)
            val (rotateCode, edited) = worker("rotate", input.absolutePath, output.absolutePath, "0")
            assertEquals(0, rotateCode)
            assertTrue(edited.getBoolean("saved"))
            assertTrue(output.isFile)
            val (reopenCode, reopened) = worker("inspect", output.absolutePath)
            assertEquals(0, reopenCode)
            assertEquals(2, reopened.getInt("pageCount"))
            assertEquals(90, reopened.getJSONArray("rotations").getInt(0))
            assertEquals(0, reopened.getJSONArray("rotations").getInt(1))
            assertRealRendering(output, 300, 200)
            assertEquals(before, digest(input))
            assertEquals(0, worker("inspect", input.absolutePath).second.getJSONArray("rotations").getInt(0))
        } finally { directory.deleteRecursively() }
    }

    @Test
    fun actualNativeFailuresNeverReplaceExistingFiles() {
        val directory = File(context.cacheDir, "native-errors-${UUID.randomUUID()}")
        assertTrue(directory.mkdir())
        try {
            val input = File(directory, "original.pdf").apply { writeBytes(syntheticPdf()) }
            val existing = File(directory, "existing.pdf").apply { writeText("preserve existing bytes") }
            val before = digest(input)
            val existingBefore = digest(existing)
            val refused = worker("rotate", input.absolutePath, existing.absolutePath, "0")
            assertTrue(refused.first != 0)
            assertEquals("destination_exists", refused.second.getString("error"))
            assertEquals(existingBefore, digest(existing))
            val invalid = File(directory, "invalid.pdf").apply { writeText("not a PDF") }
            assertTrue(worker("inspect", invalid.absolutePath).first != 0)
            val absentOutput = File(directory, "must-not-be-created.pdf")
            val missingPage = worker("rotate", input.absolutePath, absentOutput.absolutePath, "2")
            assertTrue(missingPage.first != 0)
            assertEquals("invalid_page", missingPage.second.getString("error"))
            assertFalse(absentOutput.exists())
            assertEquals(before, digest(input))
        } finally { directory.deleteRecursively() }
    }
}
