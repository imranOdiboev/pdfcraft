package com.odibo.pdf

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.ParcelFileDescriptor
import android.view.View
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Real Compose UI test. Run only against the disposable instrumentation app data. */
@RunWith(AndroidJUnit4::class)
class HomeUiAcceptanceTest {
    @get:Rule val compose = createEmptyComposeRule()

    @Test
    fun homeSettingsLanguageAndThemeProduceRealContentScreenshots() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        // Select a deterministic Home state without reading or deleting PDF files.
        // URI/work-file tests have their own synthetic fixtures and assertions.
        context.getSharedPreferences("odibo-android", Context.MODE_PRIVATE).edit()
            .remove("working-name").remove("source-uri").remove("recent-uri")
            .putString("language", "en").putString("theme", "light").commit()

        ActivityScenario.launch(MainActivity::class.java).use { activity ->
            compose.onNodeWithText("Your PDFs, on your phone").assertIsDisplayed()
            compose.onNodeWithText("Open PDF").assertIsDisplayed().assertIsEnabled()
            compose.onNodeWithText("No recent documents yet. Use Open PDF to choose one safely.")
                .performScrollTo().assertIsDisplayed()
            // Return to the top for the capture by bringing the heading into view.
            compose.onNodeWithText("Your PDFs, on your phone").performScrollTo()
            val light = captureContent(activity, "home-en-light.png")

            compose.onNodeWithText("Settings").performScrollTo().performClick()
            compose.onNodeWithText("Language").assertIsDisplayed()
            compose.onNodeWithText("Dark").performScrollTo().performClick()
            compose.onNodeWithText("✓ Dark").assertIsDisplayed()
            compose.onNodeWithText("Русский").performScrollTo().performClick()
            compose.onNodeWithText("Язык").assertIsDisplayed()
            compose.onNodeWithText("✓ Русский").assertIsDisplayed()
            compose.onNodeWithText("Главная").performClick()

            compose.onNodeWithText("Ваши PDF — на вашем телефоне").assertIsDisplayed()
            compose.onNodeWithText("Открыть PDF").assertIsDisplayed().assertIsEnabled()
            val dark = captureContent(activity, "home-ru-dark.png")
            assertFalse("Light and dark screenshots must differ", light.contentEquals(dark))
            assertTrue(context.getSharedPreferences("odibo-android", Context.MODE_PRIVATE).getString("theme", "") == "dark")
            assertTrue(context.getSharedPreferences("odibo-android", Context.MODE_PRIVATE).getString("language", "") == "ru")
        }
    }

    private fun captureContent(activity: ActivityScenario<MainActivity>, name: String): ByteArray {
        compose.waitForIdle()
        var encoded = ByteArray(0)
        activity.onActivity { current ->
            // Draw only the application-owned view, never status/navigation bars,
            // the system file picker, personal recent files or device UI fonts.
            val content = current.findViewById<View>(android.R.id.content)
            assertTrue("App content must be laid out", content.width > 0 && content.height > 0)
            val bitmap = Bitmap.createBitmap(content.width, content.height, Bitmap.Config.ARGB_8888)
            try {
                content.draw(Canvas(bitmap))
                val colors = HashSet<Int>()
                for (y in 0 until bitmap.height step 8) {
                    for (x in 0 until bitmap.width step 8) colors.add(bitmap.getPixel(x, y))
                }
                assertTrue("Capture must contain rendered app content, not a blank canvas", colors.size > 16)
                val destination = File(current.filesDir, "screenshots").apply { mkdirs() }
                val file = File(destination, name)
                file.outputStream().use { assertTrue(bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)) }
                encoded = file.readBytes()
                assertTrue("PNG must contain actual rendered content", encoded.size > 5000)
            } finally { bitmap.recycle() }
        }
        // connectedDebugAndroidTest may uninstall the app before CI can pull its
        // private files. Export only these synthetic Home captures while installed.
        assertTrue(name in setOf("home-en-light.png", "home-ru-dark.png"))
        val command = "run-as com.odibo.pdf cat files/screenshots/$name > /data/local/tmp/odibo-$name.part && mv /data/local/tmp/odibo-$name.part /data/local/tmp/odibo-$name && cat /data/local/tmp/odibo-$name"
        val descriptor = InstrumentationRegistry.getInstrumentation().uiAutomation.executeShellCommand(command)
        val exported = ParcelFileDescriptor.AutoCloseInputStream(descriptor).use { it.readBytes() }
        assertTrue("Exported screenshot must match the actual PNG", encoded.contentEquals(exported))
        // Wait for the host collector before Gradle is allowed to uninstall us.
        val deadline = android.os.SystemClock.elapsedRealtime() + 30_000
        var collected = false
        while (!collected && android.os.SystemClock.elapsedRealtime() < deadline) {
            val status = InstrumentationRegistry.getInstrumentation().uiAutomation.executeShellCommand(
                "test -f /data/local/tmp/odibo-captured-$name && echo ready"
            )
            collected = ParcelFileDescriptor.AutoCloseInputStream(status).use {
                it.bufferedReader().readText().trim() == "ready"
            }
            if (!collected) Thread.sleep(100)
        }
        assertTrue("CI must retrieve the real screenshot before teardown", collected)
        return encoded
    }
}
