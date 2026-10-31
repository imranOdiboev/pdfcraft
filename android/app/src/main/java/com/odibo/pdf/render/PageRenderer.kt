package com.odibo.pdf.render

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import java.io.File
import kotlin.math.sqrt

/** Call from a worker dispatcher. Only one native page is open at a time. */
class PageRenderer(file: File) : AutoCloseable {
    private val guard = Any()
    private val renderer: PdfRenderer
    private var closed = false
    init {
        val descriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        renderer = try { PdfRenderer(descriptor) } catch (error: Throwable) { runCatching { descriptor.close() }; throw error }
    }
    val pageCount: Int get() = synchronized(guard) { renderer.pageCount }
    fun page(index: Int, width: Int): Bitmap = synchronized(guard) {
        check(!closed)
        renderer.openPage(index).use { page ->
            val ratio = page.height.toDouble() / page.width.toDouble()
            require(ratio.isFinite() && ratio > 0)
            val scale = minOf(width.coerceIn(200, 1600).toDouble(), sqrt(2_000_000.0 / ratio))
            val w = scale.toInt().coerceAtLeast(1)
            val h = (scale * ratio).toInt().coerceIn(1, 2_000_000 / w)
            val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            try {
                bitmap.eraseColor(Color.WHITE)
                page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                bitmap
            } catch (error: Throwable) { bitmap.recycle(); throw error }
        }
    }
    override fun close() = synchronized(guard) { if (!closed) { renderer.close(); closed = true } }
}
