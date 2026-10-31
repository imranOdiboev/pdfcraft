package com.odibo.pdf.data

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.io.InputStream
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.coroutines.coroutineContext

data class PdfInfo(val pageCount: Int, val rotations: List<Int>)
enum class Problem { ACCESS, TOO_LARGE, INVALID_PDF, SECURITY, SIGNED, REPAIRED, NATIVE, TIMEOUT, SAVE, SAME_SOURCE, VERIFY }
class DocumentFailure(val problem: Problem) : Exception()

/** Launches only our bundled native worker. No shell, JNI or document network access. */
class NativeBridge(context: Context) {
    private val worker = File(context.applicationInfo.nativeLibraryDir, "libodibo_core_exec.so")
    private val mutex = Mutex()

    suspend fun inspect(input: File): PdfInfo = information(invoke(listOf("inspect", input.absolutePath)))
    suspend fun rotate(input: File, output: File, page: Int): PdfInfo =
        information(invoke(listOf("rotate", input.absolutePath, output.absolutePath, page.toString())))
    suspend fun combine(inputs: List<File>, output: File): PdfInfo =
        information(invoke(listOf("combine", output.absolutePath) + inputs.map { it.absolutePath }))
    suspend fun reorder(input: File, output: File, order: List<Int>): PdfInfo =
        information(invoke(listOf("reorder", input.absolutePath, output.absolutePath, order.joinToString(","))))
    suspend fun split(input: File, directory: File, cuts: List<Int>): List<Pair<File, PdfInfo>> {
        val result = invoke(listOf("split", input.absolutePath, directory.absolutePath, cuts.joinToString(",")))
        val outputs = result.optJSONArray("outputs") ?: throw DocumentFailure(Problem.NATIVE)
        if (outputs.length() !in 2..32) throw DocumentFailure(Problem.NATIVE)
        var bytes = 0L
        return List(outputs.length()) { index ->
            val value = outputs.optJSONObject(index) ?: throw DocumentFailure(Problem.NATIVE)
            val name = "part-%03d.pdf".format(java.util.Locale.ROOT, index + 1)
            if (value.optString("file") != name) throw DocumentFailure(Problem.NATIVE)
            val file = File(directory, name)
            bytes += file.length()
            if (!file.isFile || file.length() !in 1..ToolArguments.MAX_OUTPUT || bytes > ToolArguments.MAX_OUTPUT) throw DocumentFailure(Problem.VERIFY)
            file to information(value)
        }
    }

    private suspend fun invoke(arguments: List<String>): JSONObject = mutex.withLock {
        withContext(Dispatchers.IO) {
            if (!worker.isFile || !worker.canExecute()) throw DocumentFailure(Problem.NATIVE)
            val process = ProcessBuilder(listOf(worker.absolutePath) + arguments).start()
            val readers = try { Executors.newFixedThreadPool(2) } catch (failure: Throwable) {
                process.destroyForcibly()
                throw failure
            }
            try {
                val stdout = readers.submit<String> { boundedText(process.inputStream) }
                val stderr = readers.submit<String> { boundedText(process.errorStream) }
                val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(30)
                while (!process.waitFor(100, TimeUnit.MILLISECONDS)) {
                    coroutineContext.ensureActive()
                    if (System.nanoTime() >= deadline) throw DocumentFailure(Problem.TIMEOUT)
                }
                coroutineContext.ensureActive()
                val text = stdout.get(3, TimeUnit.SECONDS)
                stderr.get(3, TimeUnit.SECONDS) // Drain, but never expose native output or paths.
                val json = try { JSONObject(text) } catch (_: Exception) { throw DocumentFailure(Problem.NATIVE) }
                if (process.exitValue() != 0 || json.has("error")) {
                    val problem = when (json.optString("error")) {
                        "limit_exceeded" -> Problem.TOO_LARGE
                        "unsupported_security" -> Problem.SECURITY
                        "unsupported_signed" -> Problem.SIGNED
                        "unsupported_repaired" -> Problem.REPAIRED
                        "read_failed" -> Problem.ACCESS
                        "destination_exists", "write_failed" -> Problem.SAVE
                        "verification_failed" -> Problem.VERIFY
                        "worker_failed", "invalid_arguments" -> Problem.NATIVE
                        else -> Problem.INVALID_PDF
                    }
                    throw DocumentFailure(problem)
                }
                json
            } finally {
                try {
                    if (process.isAlive) {
                        process.destroy()
                        if (!process.waitFor(1, TimeUnit.SECONDS)) process.destroyForcibly()
                    }
                } finally {
                    runCatching { process.inputStream.close() }
                    runCatching { process.errorStream.close() }
                    runCatching { process.outputStream.close() }
                    readers.shutdownNow()
                }
            }
        }
    }

    private fun information(json: JSONObject): PdfInfo {
        val count = json.optInt("pageCount", -1)
        if (count !in 1..2000) throw DocumentFailure(Problem.INVALID_PDF)
        val values = json.optJSONArray("rotations") ?: throw DocumentFailure(Problem.NATIVE)
        if (values.length() != count) throw DocumentFailure(Problem.NATIVE)
        val rotations = List(count) { values.optInt(it, -1) }
        if (rotations.any { it !in listOf(0, 90, 180, 270) }) throw DocumentFailure(Problem.NATIVE)
        return PdfInfo(count, rotations)
    }

    private fun boundedText(stream: InputStream): String = stream.use {
        val buffer = ByteArray(65537)
        var size = 0
        while (size < buffer.size) {
            val read = it.read(buffer, size, buffer.size - size)
            if (read < 0) return@use buffer.copyOf(size).toString(Charsets.UTF_8)
            size += read
        }
        throw DocumentFailure(Problem.NATIVE)
    }
}
