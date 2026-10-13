package com.emolearnar.app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "emolearnar/excel_export"
    private val createDocumentRequestCode = 7401

    private var pendingBytes: ByteArray? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveExcelReport" -> {
                    val fileName = call.argument<String>("fileName")
                    val bytes = call.argument<ByteArray>("bytes")

                    if (fileName.isNullOrBlank() || bytes == null) {
                        result.error(
                            "INVALID_ARGUMENTS",
                            "Missing Excel file name or bytes.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    openSaveExcelDocument(fileName, bytes, result)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun openSaveExcelDocument(
        fileName: String,
        bytes: ByteArray,
        result: MethodChannel.Result
    ) {
        if (pendingResult != null) {
            result.error(
                "EXPORT_IN_PROGRESS",
                "Another Excel export is already in progress.",
                null
            )
            return
        }

        pendingBytes = bytes
        pendingResult = result

        val safeFileName = if (fileName.endsWith(".xlsx")) fileName else "$fileName.xlsx"
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            putExtra(Intent.EXTRA_TITLE, safeFileName)
        }

        try {
            startActivityForResult(intent, createDocumentRequestCode)
        } catch (error: ActivityNotFoundException) {
            clearPendingExport()
            result.error(
                "NO_FILE_PICKER",
                "No Android file picker is available on this device.",
                error.message
            )
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != createDocumentRequestCode) return

        val result = pendingResult
        val bytes = pendingBytes
        clearPendingExport()

        if (result == null || bytes == null) return

        if (resultCode != Activity.RESULT_OK) {
            result.error("EXPORT_CANCELLED", "Excel export was cancelled.", null)
            return
        }

        val uri: Uri? = data?.data
        if (uri == null) {
            result.error("MISSING_URI", "Android did not return a save location.", null)
            return
        }

        try {
            contentResolver.openOutputStream(uri)?.use { outputStream ->
                outputStream.write(bytes)
                outputStream.flush()
            } ?: run {
                result.error("WRITE_FAILED", "Unable to open the selected save location.", null)
                return
            }

            result.success(uri.toString())
        } catch (error: Exception) {
            result.error("WRITE_FAILED", "Unable to save Excel report.", error.message)
        }
    }

    private fun clearPendingExport() {
        pendingBytes = null
        pendingResult = null
    }
}
