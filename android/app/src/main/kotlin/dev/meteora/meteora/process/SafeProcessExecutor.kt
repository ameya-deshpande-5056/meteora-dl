package dev.meteora.meteora.process

import android.util.Log
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class SafeProcessExecutor {

    companion object {
        private const val TAG = "SafeProcessExecutor"
    }

    data class ExecutionResult(
        val exitCode: Int,
        val output: String,
        val isCancelled: Boolean = false,
        val errorMessage: String? = null
    )

    suspend fun execute(
        command: List<String>,
        workingDir: File? = null,
        environment: Map<String, String> = emptyMap(),
        onLineOutput: ((String) -> Unit)? = null
    ): ExecutionResult = withContext(Dispatchers.IO) {
        if (command.isEmpty()) {
            return@withContext ExecutionResult(
                exitCode = -1,
                output = "",
                errorMessage = "Command list cannot be empty"
            )
        }

        // Verify and grant execute permissions on the executable file if it's an explicit path
        val executablePath = command.first()
        val execFile = File(executablePath)
        if (execFile.isAbsolute && execFile.exists() && !execFile.canExecute()) {
            try {
                execFile.setExecutable(true, false)
            } catch (e: Exception) {
                Log.w(TAG, "Could not set executable permission on $executablePath: ${e.message}")
            }
        }

        val outputBuffer = StringBuilder()
        var process: Process? = null

        try {
            val processBuilder = ProcessBuilder(command)
            if (workingDir != null && workingDir.exists()) {
                processBuilder.directory(workingDir)
            }

            val env = processBuilder.environment()
            environment.forEach { (key, value) ->
                env[key] = value
            }

            processBuilder.redirectErrorStream(true)
            process = processBuilder.start()

            BufferedReader(InputStreamReader(process.inputStream)).use { reader ->
                var line: String? = reader.readLine()
                while (line != null) {
                    outputBuffer.appendLine(line)
                    onLineOutput?.invoke(line)
                    line = reader.readLine()
                }
            }

            val exitCode = process.waitFor()
            ExecutionResult(
                exitCode = exitCode,
                output = outputBuffer.toString(),
                isCancelled = false
            )
        } catch (e: InterruptedException) {
            process?.destroyForcibly()
            ExecutionResult(
                exitCode = -1,
                output = outputBuffer.toString(),
                isCancelled = true,
                errorMessage = "Process was interrupted / cancelled"
            )
        } catch (e: Throwable) {
            Log.e(TAG, "Process execution failed for command: $command", e)
            ExecutionResult(
                exitCode = 126,
                output = outputBuffer.toString(),
                isCancelled = false,
                errorMessage = "Execution failed: ${e.localizedMessage ?: e.javaClass.simpleName}"
            )
        } finally {
            process?.destroy()
        }
    }
}
