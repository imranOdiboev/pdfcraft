package com.odibo.pdf

import android.content.Context
import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.view.View
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.lifecycle.ViewModelProvider
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.odibo.pdf.app.OdiboViewModel
import com.odibo.pdf.data.DocumentFailure
import com.odibo.pdf.data.Problem
import com.odibo.pdf.storage.SafDocumentStore
import java.io.File
import java.security.MessageDigest
import kotlinx.coroutines.CancellationException
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Uses real resolver imports, actual app ViewModel and the packaged Rust worker. */
@RunWith(AndroidJUnit4::class)
class ToolsUiAcceptanceTest {
    @get:Rule val compose = createEmptyComposeRule()
    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext
    private fun sourceHash(uri: Uri) = context.contentResolver.openInputStream(uri)!!.use {
        MessageDigest.getInstance("SHA-256").digest(it.readBytes()).toList()
    }
    private fun waitFor(model: OdiboViewModel, condition: () -> Boolean) {
        compose.waitUntil(timeoutMillis = 30_000) { !model.busy && (model.error != null || condition()) }
        compose.runOnIdle { assertNull("Real PDF operation reported an error", model.error); assertTrue(condition()) }
    }

    @Test fun actualCombineSplitReorderUiAndRecreationKeepSourcesUnchanged() {
        context.getSharedPreferences("odibo-android", Context.MODE_PRIVATE).edit()
            .remove("working-name").remove("source-uri").remove("recent-uri")
            .putString("language", "en").putString("theme", "light").commit()
        val inputs = listOf("first", "second").map { Uri.parse("content://com.odibo.pdf.test.fixtures/$it") }
        val before = inputs.map(::sourceHash)
        ActivityScenario.launch(MainActivity::class.java).use { activity ->
            lateinit var model: OdiboViewModel
            activity.onActivity { model = ViewModelProvider(it)[OdiboViewModel::class.java]; model.addCombine(inputs) }
            waitFor(model) { model.combineInputs.size == 2 }
            compose.onNodeWithText("Combine PDF").performScrollTo().performClick()
            compose.onNodeWithContentDescription("Move file 1 down").performScrollTo().performClick()
            compose.runOnIdle { assertEquals("second.pdf", model.combineInputs.first().name) }
            compose.onNodeWithText("Combine 2 files").performScrollTo().assertIsEnabled()
            capture(activity, "tools-combine-en-light.png")
            compose.onNodeWithText("Combine 2 files").performClick()
            waitFor(model) { model.document?.info?.pageCount == 4 }
            compose.onNodeWithText("Split PDF").performScrollTo().performClick()
            compose.onNodeWithText("Page ranges").performScrollTo().performTextReplacement("1-2, 3-4")
            compose.onNodeWithText("Preview: 2 output PDFs").assertIsDisplayed()
            capture(activity, "tools-split-en-light.png")
            compose.onNodeWithText("Prepare split PDFs").performScrollTo().performClick()
            waitFor(model) { model.toolResults.size == 2 }
            compose.runOnIdle { assertEquals(listOf(2, 2), model.toolResults.map { it.info.pageCount }) }
            compose.onNodeWithText("Home").performClick()
            activity.onActivity { model.updateLanguage("ru"); model.updateTheme("dark") }
            compose.onNodeWithText("Порядок страниц").performScrollTo().performClick()
            compose.onNodeWithContentDescription("Переместить страницу 1 вниз").performScrollTo().performClick()
            activity.recreate()
            compose.onNodeWithContentDescription("Переместить страницу 2 вверх").performScrollTo().assertIsNotEnabled()
            compose.onNodeWithText("Применить порядок").performScrollTo().assertIsEnabled()
            capture(activity, "tools-reorder-ru-dark.png")
            activity.onActivity { it.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE }
            compose.waitUntil(timeoutMillis = 15_000) { context.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE }
            compose.onNodeWithContentDescription("Переместить страницу 2 вверх").performScrollTo().assertIsNotEnabled()
            compose.onNodeWithText("Применить порядок").performScrollTo().assertIsEnabled()
            val prior = model.document!!.file
            compose.onNodeWithText("Применить порядок").performClick()
            waitFor(model) { model.document?.file != prior }
            compose.runOnIdle { assertEquals(4, model.document?.info?.pageCount) }
            activity.onActivity { it.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT }
            compose.waitUntil(timeoutMillis = 15_000) { context.resources.configuration.orientation == Configuration.ORIENTATION_PORTRAIT }
        }
        assertEquals(before, inputs.map(::sourceHash))
    }

    @Test fun sourceAliasCancellationAndReadOnlyDestinationNeverChangeSources() {
        val sources = listOf("first", "second").map { Uri.parse("content://com.odibo.pdf.test.fixtures/$it") }
        val before = sources.map(::sourceHash)
        val storage = SafDocumentStore(context)
        val local = storage.importPdf(sources.first())
        try {
            try {
                storage.export(local, sources.first(), sources.first())
                fail("Saving over the source must fail before opening a writable stream")
            } catch (failure: DocumentFailure) { assertEquals(Problem.SAME_SOURCE, failure.problem) }
            try {
                storage.export(local, sources[1], listOf(sources.first())) { throw CancellationException("synthetic cancellation") }
                fail("A cancelled export cannot report success")
            } catch (_: CancellationException) { }
            try {
                // A real ContentProvider denies write access, not a fake bridge.
                storage.export(local, sources[1], listOf(sources.first()))
                fail("A read-only destination cannot report success")
            } catch (_: java.io.FileNotFoundException) { }
            assertEquals(before, sources.map(::sourceHash))
        } finally { storage.forget(local) }
    }

    private fun capture(activity: ActivityScenario<MainActivity>, name: String) {
        compose.waitForIdle()
        activity.onActivity { current ->
            val view = current.findViewById<View>(android.R.id.content)
            assertTrue(view.width > 0 && view.height > 0)
            val image = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
            try {
                view.draw(Canvas(image))
                val colors = HashSet<Int>()
                for (y in 0 until image.height step 8) for (x in 0 until image.width step 8) colors.add(image.getPixel(x, y))
                assertTrue("Real app screenshot must not be blank", colors.size > 16)
                val folder = File(current.filesDir, "screenshots").apply { mkdirs() }
                val file = File(folder, name)
                file.outputStream().use { assertTrue(image.compress(Bitmap.CompressFormat.PNG, 100, it)) }
                assertTrue(file.length() > 5000)
                File(folder, "$name.ready").writeText("ready")
            } finally { image.recycle() }
        }
        val marker = File(context.filesDir, "screenshots/$name.collected")
        val deadline = android.os.SystemClock.elapsedRealtime() + 30_000
        while (!marker.isFile && android.os.SystemClock.elapsedRealtime() < deadline) Thread.sleep(100)
        assertTrue("CI must collect the genuine tool screenshot", marker.isFile)
    }
}
