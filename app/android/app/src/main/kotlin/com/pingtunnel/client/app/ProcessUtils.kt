package com.pingtunnel.client.app

import android.system.Os
import android.util.Log
import java.io.BufferedReader
import java.io.File
import java.io.FileDescriptor
import java.io.InputStreamReader
import kotlin.concurrent.thread

object ProcessUtils {
    // Flags whose following argument is a shared secret (numeric -key or an
    // -encrypt-key passphrase) and must never reach logcat in cleartext -
    // adb logcat is readable by any app/user with USB debugging enabled, no
    // root required, so this is a real recovery path for the tunnel's key.
    private val SECRET_FLAGS = setOf("-key", "-encrypt-key")

    private fun redactedCommand(command: List<String>): String {
        val out = StringBuilder()
        var i = 0
        while (i < command.size) {
            if (out.isNotEmpty()) out.append(' ')
            out.append(command[i])
            if (command[i] in SECRET_FLAGS && i + 1 < command.size) {
                out.append(" ***")
                i += 2
                continue
            }
            i++
        }
        return out.toString()
    }

    private fun buildProcessBuilder(
        command: List<String>,
        workDir: File?,
        env: Map<String, String>?
    ): ProcessBuilder {
        val builder = ProcessBuilder(command).redirectErrorStream(true)
        if (workDir != null) {
            builder.directory(workDir)
        }
        if (env != null) {
            builder.environment().putAll(env)
        }
        return builder
    }

    fun startProcess(
        tag: String,
        command: List<String>,
        workDir: File? = null,
        env: Map<String, String>? = null
    ): Process {
        Log.i(tag, "Starting: ${redactedCommand(command)}")
        val builder = buildProcessBuilder(command, workDir, env)
        val process = builder.start()
        streamLogs(tag, process)
        return process
    }

    fun startProcessWithStdinFd(
        tag: String,
        command: List<String>,
        workDir: File? = null,
        stdinFd: FileDescriptor? = null,
        env: Map<String, String>? = null
    ): Process {
        Log.i(tag, "Starting: ${redactedCommand(command)}")
        val builder = buildProcessBuilder(command, workDir, env)

        var stdinDup: FileDescriptor? = null
        if (stdinFd != null) {
            stdinDup = Os.dup(FileDescriptor.`in`)
            Os.dup2(stdinFd, 0)
            builder.redirectInput(ProcessBuilder.Redirect.INHERIT)
        }

        val process = try {
            builder.start()
        } finally {
            if (stdinDup != null) {
                Os.dup2(stdinDup, 0)
                Os.close(stdinDup)
            }
        }

        streamLogs(tag, process)
        return process
    }

    fun stopProcess(process: Process?) {
        if (process == null) return
        process.destroy()
        thread(start = true, name = "proc-wait") {
            try {
                process.waitFor()
            } catch (_: Exception) {
            }
        }
        thread(start = true, name = "proc-kill") {
            try {
                Thread.sleep(1500)
                process.destroyForcibly()
            } catch (_: Exception) {
            }
        }
    }

    private fun streamLogs(tag: String, process: Process) {
        thread(start = true, name = "$tag-logger") {
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            try {
                while (true) {
                    val line = reader.readLine() ?: break
                    if (line.isNotEmpty()) {
                        Log.i(tag, line)
                    }
                }
            } catch (e: Exception) {
                Log.d(tag, "Log stream closed: $e")
            }
        }
    }
}
