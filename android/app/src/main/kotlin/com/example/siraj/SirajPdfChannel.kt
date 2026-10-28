package com.example.siraj

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.system.Os
import android.system.OsConstants
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.ceil

/** Android framework PDF engine, API21+ (app min26). No third-party engine or
 * ABI binaries. All parser/page operations execute serially off the UI thread.
 * A single admitted render plus one close barrier bounds native work/memory. */
class SirajPdfChannel(context: Context, messenger: BinaryMessenger) {
    private val support = context.filesDir.canonicalFile
    private val channel = MethodChannel(messenger, "siraj/pdf")
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val busy = AtomicBoolean(false)
    private val closing = AtomicBoolean(false)
    private val disposed = AtomicBoolean(false)
    private var renderer: PdfRenderer? = null // worker-confined
    private var documentId: String? = null

    private class Failure(val code: String) : Exception()
    private class BoundedOutput : ByteArrayOutputStream() {
        override fun write(value: Int) {
            if (count >= 20 * 1024 * 1024) throw Failure("resource_limit")
            super.write(value)
        }
        override fun write(bytes: ByteArray, offset: Int, length: Int) {
            if (length > 20 * 1024 * 1024 - count) throw Failure("resource_limit")
            super.write(bytes, offset, length)
        }
        fun wipe() { buf.fill(0); reset() }
    }

    init {
        channel.setMethodCallHandler { call, result ->
            if (disposed.get()) { result.error("closed", "Reader closed", null); return@setMethodCallHandler }
            if (call.method == "appSupport") { result.success(support.path); return@setMethodCallHandler }
            if (call.method !in setOf("open", "render", "close")) {
                result.notImplemented(); return@setMethodCallHandler
            }
            val isClose = call.method == "close"
            if (if (isClose) !closing.compareAndSet(false, true)
                else closing.get() || !busy.compareAndSet(false, true)) {
                result.error("busy", "Reader busy", null); return@setMethodCallHandler
            }
            // Snapshot bounded typed arguments before leaving the channel thread.
            val path = call.argument<String>("path")
            val id = call.argument<String>("id")
            val page = call.argument<Int>("page")
            val width = call.argument<Int>("width")
            worker.execute {
                var reply: Any? = null
                var error: String? = null
                try {
                    if (disposed.get()) throw Failure("closed")
                    reply = when (call.method) {
                        "open" -> open(path)
                        "render" -> render(id, page, width)
                        else -> { close(id); null }
                    }
                } catch (e: Failure) { error = e.code }
                catch (_: OutOfMemoryError) { error = "resource_limit" }
                catch (_: SecurityException) { error = "invalid_file" }
                catch (_: IOException) { error = "io_failure" }
                catch (_: Exception) { error = "invalid_file" }
                finally { if (isClose) closing.set(false) else busy.set(false) }
                val value = reply
                val failure = error
                main.post {
                    if (disposed.get()) {
                        if (value is Map<*, *>) (value["png"] as? ByteArray)?.fill(0)
                    } else if (failure != null) result.error(failure, "PDF operation failed", null)
                    else result.success(value)
                }
            }
        }
    }

    private fun safeFile(path: String?): File {
        if (path == null || path.length > 4096 || path.indexOf('\u0000') >= 0) throw Failure("unsafe_path")
        val file = File(path)
        val base = File(support, "pdf-books-v1")
        val leaf = file.parentFile ?: throw Failure("unsafe_path")
        if (!file.isAbsolute || file.path != file.canonicalPath ||
            base.path != base.canonicalPath || leaf.path != leaf.canonicalPath ||
            leaf.parentFile != base || !Regex("[a-f0-9]{64}").matches(leaf.name) ||
            file.name !in setOf("book.pdf", "candidate.pdf")) throw Failure("unsafe_path")
        if (!file.isFile) throw Failure("missing_file")
        return file
    }
    private fun open(path: String?): Map<String, Any> {
        if (renderer != null) throw Failure("busy")
        val file = safeFile(path)
        val fd = Os.open(file.path, OsConstants.O_RDONLY or OsConstants.O_NOFOLLOW, 0)
        val descriptor = try { ParcelFileDescriptor.dup(fd) } finally { Os.close(fd) }
        var created: PdfRenderer? = null
        try {
            created = PdfRenderer(descriptor)
            val pages = created.pageCount
            if (pages < 1 || pages > 100000) throw Failure("invalid_file")
            val id = UUID.randomUUID().toString()
            renderer = created
            documentId = id
            return mapOf("id" to id, "pages" to pages)
        } catch (e: Throwable) {
            if (created != null) created.close() else descriptor.close()
            throw e
        }
    }
    private fun render(id: String?, number: Int?, width: Int?): Map<String, Any> {
        val document = renderer ?: throw Failure("closed")
        if (id != documentId) throw Failure("closed")
        if (number == null || number < 0 || number >= document.pageCount ||
            width == null || width < 1 || width > 2048) throw Failure("invalid_page")
        val page = document.openPage(number)
        try {
            if (page.width <= 0 || page.height <= 0) throw Failure("invalid_file")
            val heightDouble = ceil(width.toDouble() * page.height / page.width)
            if (!heightDouble.isFinite() || heightDouble < 1 || heightDouble > 4096 ||
                width.toDouble() * heightDouble > 4 * 1024 * 1024) throw Failure("resource_limit")
            val height = heightDouble.toInt()
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val output = BoundedOutput()
            try {
                bitmap.eraseColor(Color.WHITE)
                page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)) throw Failure("io_failure")
                return mapOf("id" to id!!, "page" to number, "width" to width,
                    "height" to height, "png" to output.toByteArray())
            } finally { output.wipe(); bitmap.recycle() }
        } finally { page.close() }
    }
    private fun close(id: String?) {
        // Repeating a successfully closed handle is safe; a foreign ID cannot
        // close a newly opened document.
        if (renderer == null) return
        if (id != documentId) throw Failure("closed")
        renderer!!.close()
        renderer = null
        documentId = null
    }
    fun dispose() {
        if (!disposed.compareAndSet(false, true)) return
        channel.setMethodCallHandler(null)
        worker.execute {
            try { renderer?.close() } finally { renderer = null; documentId = null }
        }
        worker.shutdown() // drains accepted render/close before descriptor cleanup
    }
}
