package com.odibo.pdf

import android.net.Uri
import android.os.Bundle
import android.provider.DocumentsContract
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.odibo.pdf.data.DocumentFailure
import com.odibo.pdf.data.NativeBridge
import com.odibo.pdf.data.Problem
import com.odibo.pdf.storage.SafDocumentStore
import java.security.MessageDigest
import java.util.UUID
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

/** Real resolver/SAF create-write-readback, native output and reopen tests. */
@RunWith(AndroidJUnit4::class)
class SafToolsAcceptanceTest {
    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext
    private val resolver get() = context.contentResolver
    private fun tree(mode: String): Uri = DocumentsContract.buildTreeDocumentUri(PdfToolsSafProvider.AUTHORITY, "$mode-${UUID.randomUUID()}")
    private fun source(tree: Uri) = DocumentsContract.buildDocumentUriUsingTree(tree, "${DocumentsContract.getTreeDocumentId(tree)}:source")
    private fun digest(uri: Uri): List<Byte> = resolver.openInputStream(uri)!!.use { MessageDigest.getInstance("SHA-256").digest(it.readBytes()).toList() }
    private fun stats(tree: Uri): Bundle = resolver.call(PdfToolsSafProvider.AUTHORITY, "qa:stats", DocumentsContract.getTreeDocumentId(tree), null)!!

    @Test fun realSplitSafExportsMatchBytesReopenAndKeepSource() = runBlocking {
        val storage = SafDocumentStore(context)
        val core = NativeBridge(context)
        val inputUri = Uri.parse("content://com.odibo.pdf.test.fixtures/first")
        val inputHash = digest(inputUri)
        val input = storage.importPdf(inputUri)
        val folder = storage.newSplitDirectory()
        val destination = tree("success")
        val sentinel = source(destination)
        val before = digest(sentinel)
        try {
            val parts = core.split(input, folder, listOf(1))
            assertEquals(2, parts.size)
            val outputs = storage.exportParts(parts.map { it.first }, destination, listOf(inputUri, sentinel)) {}
            assertEquals(2, outputs.size)
            assertEquals(2, stats(destination).getInt("writes"))
            for ((index, uri) in outputs.withIndex()) {
                val expected = MessageDigest.getInstance("SHA-256").digest(parts[index].first.readBytes()).toList()
                assertEquals(expected, digest(uri))
                val imported = storage.importPdf(uri)
                try { assertEquals(1, core.inspect(imported).pageCount) } finally { storage.forget(imported) }
            }
            assertEquals(before, digest(sentinel))
            assertEquals(inputHash, digest(inputUri))
        } finally { storage.forgetSplit(folder); storage.forget(input) }
    }

    @Test fun aliasWriteRefusalReadbackMismatchAndPartialCancellationNeverClaimSuccess() {
        val storage = SafDocumentStore(context)
        val inputUri = Uri.parse("content://com.odibo.pdf.test.fixtures/first")
        val inputHash = digest(inputUri)
        val input = storage.importPdf(inputUri)
        try {
            for (mode in listOf("alias", "deny", "mismatch", "cancel")) {
                val destination = tree(mode)
                val sentinel = source(destination)
                val before = digest(sentinel)
                var refused = false
                try {
                    storage.exportParts(listOf(input, input), destination, listOf(inputUri, sentinel)) {
                        if (mode == "cancel" && stats(destination).getInt("readbacks") >= 1) throw CancellationException("Cancel after first completed new export")
                    }
                } catch (failure: DocumentFailure) {
                    refused = true
                    assertEquals(if (mode == "alias") Problem.SAME_SOURCE else Problem.VERIFY, failure.problem)
                } catch (_: java.io.FileNotFoundException) {
                    assertEquals("deny", mode); refused = true
                } catch (_: CancellationException) {
                    assertEquals("cancel", mode); refused = true
                }
                assertTrue("Failure/cancellation cannot be reported as successful", refused)
                assertEquals(before, digest(sentinel))
                val observed = stats(destination)
                if (mode == "alias") assertEquals("Old source ID must be refused before writable open", 0, observed.getInt("writes"))
                if (mode == "cancel") {
                    assertEquals("Only the first new PDF exists after cancellation", 1, observed.getInt("outputs"))
                    assertEquals(1, observed.getInt("writes"))
                }
            }
            assertEquals(inputHash, digest(inputUri))
        } finally { storage.forget(input) }
    }
}
