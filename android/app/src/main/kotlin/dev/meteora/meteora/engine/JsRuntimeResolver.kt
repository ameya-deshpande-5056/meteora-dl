package dev.meteora.meteora.engine

import android.content.Context
import android.util.Log
import java.io.File
import java.io.RandomAccessFile
import java.util.concurrent.TimeUnit

/**
 * Locates a JavaScript runtime executable for yt-dlp's EJS challenge solving.
 *
 * `youtubedl-android` ships the QuickJS CLI inside the APK's native library
 * payload (as `libqjs.so`). Android extracts native libraries into
 * `nativeLibraryDir`, which is the only location a targetSdk 29+ app is still
 * allowed to execute a binary from, so that path is what we pass to yt-dlp via
 * `--js-runtimes quickjs:<path>`.
 *
 * A candidate is only accepted after it actually evaluates an expression and
 * reports its banner — QuickJS has no `--version` flag, so `-e 1+1` is the
 * capability check and `-h` supplies the version line.
 */
object JsRuntimeResolver {
    private const val TAG = "JsRuntimeResolver"

    enum class Kind(val cliName: String) {
        QUICKJS("quickjs"),
        DENO("deno"),
    }

    data class Runtime(
        val kind: Kind,
        val path: String,
        val version: String?,
    )

    private data class ProbeResult(
        val exitCode: Int,
        val output: String,
    )

    fun resolve(context: Context): Runtime? {
        val nativeLibDir = context.applicationInfo.nativeLibraryDir ?: return null
        val candidates = listOf(
            "libqjs-cli.so" to Kind.QUICKJS,
            "libqjs.so" to Kind.QUICKJS,
            "libquickjs.so" to Kind.QUICKJS,
            "libdeno.so" to Kind.DENO,
            "deno" to Kind.DENO,
        )

        for ((fileName, kind) in candidates) {
            val file = File(nativeLibDir, fileName)
            if (!file.exists() || !file.isFile) continue
            if (!isElf(file)) {
                Log.w(TAG, "$fileName is present but is not an executable ELF")
                continue
            }
            val version = verify(file, kind)
            if (version == null) {
                Log.w(TAG, "$fileName could not be executed for verification")
                continue
            }
            Log.i(TAG, "JavaScript runtime ready: ${kind.cliName} ${file.absolutePath} ($version)")
            return Runtime(kind, file.absolutePath, version)
        }

        Log.w(TAG, "No usable JavaScript runtime found; EJS challenges will be skipped")
        return null
    }

    private fun isElf(file: File): Boolean = try {
        RandomAccessFile(file, "r").use { raf ->
            val magic = ByteArray(4)
            raf.readFully(magic)
            magic[0] == 0x7F.toByte() &&
                magic[1] == 'E'.code.toByte() &&
                magic[2] == 'L'.code.toByte() &&
                magic[3] == 'F'.code.toByte()
        }
    } catch (e: Throwable) {
        Log.w(TAG, "Unable to inspect ${file.name}", e)
        false
    }

    private fun verify(file: File, kind: Kind): String? = when (kind) {
        Kind.QUICKJS -> verifyQuickJs(file)
        Kind.DENO -> {
            val probe = run(file, listOf("--version"))
            if (probe != null && probe.exitCode == 0) probe.output.trim().take(80) else null
        }
    }

    private fun verifyQuickJs(file: File): String? {
        // Real capability check: evaluate a trivial expression.
        val eval = run(file, listOf("-e", "1+1"))
        if (eval == null || eval.exitCode != 0) return null

        val help = run(file, listOf("-h"))
        val versionLine = help?.output
            ?.lineSequence()
            ?.map { it.trim() }
            ?.firstOrNull { it.contains("QuickJS version", ignoreCase = true) }
        return versionLine ?: "QuickJS"
    }

    private fun run(file: File, args: List<String>): ProbeResult? = try {
        val process = ProcessBuilder(listOf(file.absolutePath) + args)
            .redirectErrorStream(true)
            .start()
        val output = process.inputStream.bufferedReader().use { it.readText() }.trim()
        val finished = process.waitFor(8, TimeUnit.SECONDS)
        if (!finished) {
            process.destroyForcibly()
            null
        } else {
            ProbeResult(process.exitValue(), output)
        }
    } catch (e: Throwable) {
        Log.w(TAG, "Unable to execute ${file.name}", e)
        null
    }
}
