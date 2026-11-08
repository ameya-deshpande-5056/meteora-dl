package dev.meteora.meteora.process

import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class SafeProcessExecutor {

    data class ExecutionResult(
        val exitCode: Int,
        val output: String,
        val isCancelled: Boolean = false
    )

    suspend fun execute(
        command: List<String>,
        workingDir: File? = null,
        environment: Map<String, String> = emptyMap(),
        onLineOutput: ((String) -> Unit)? = null
    ): ExecutionResult = withContext(Dispatchers.IO) {
        val processBuilder = ProcessBuilder(command)
        if (workingDir != null && workingDir.exists()) {
            processBuilder.directory(workingDir)
        }

        val env = processBuilder.environment()
        environment.forEach { (key, value) ->
            env[key] = value
        }

        processBuilder.redirectErrorStream(true)
        val process = processBuilder.start()

        val outputBuffer = StringBuilder()
        var cancelled = false

        try {
            BufferedReader(InputStreamReader(process.inputStream)).use { reader ->
                var line: String? = reader.readLine()
                while (line != null) {
                    outputBuffer.appendLine(line)
                    onLineOutput?.invoke(line)
                    line = reader.readLine()
                }
            }

            val exitCode = process.waitFor()
            ExecutionResult(exitCode = exitCode, output = outputBuffer.toString(), isCancelled = false)
        } catch (e: InterruptedException) {
            cancelled = true
            process.destroyForcibly()
            ExecutionResult(exitCode = -1, output = outputBuffer.toString(), isCancelled = true)
        }
    }
}
