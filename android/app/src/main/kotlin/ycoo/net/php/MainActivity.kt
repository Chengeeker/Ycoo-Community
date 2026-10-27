package ycoo.net.php

import android.webkit.CookieManager
import android.app.Activity
import android.content.Intent
import android.app.DownloadManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.Manifest
import android.content.pm.PackageManager
import android.webkit.URLUtil
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingFiles: MethodChannel.Result? = null
    private val fileRequestCode = 5141
    private val downloadPermissionCode = 5142
    private var pendingDownload: Pair<String, MethodChannel.Result>? = null
    private var pendingSave: Pair<ByteArray, Pair<String, MethodChannel.Result>>? = null
    private val savePermissionCode = 5143
    private val selectedFileUris = mutableSetOf<String>()
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ycoo.net.php/session").setMethodCallHandler { call, result ->
            val manager = CookieManager.getInstance()
            val origin = "https://ycoo.net"
            when (call.method) {
                "getCookies" -> {
                    val url = call.argument<String>("url") ?: origin
                    if (!isSiteCookieUrl(url)) result.error("INVALID", "Cookie 来源无效", null)
                    else result.success(manager.getCookie(url) ?: "")
                }
                "setCookies" -> {
                    val url = call.argument<String>("url") ?: origin
                    if (!isSiteCookieUrl(url)) { result.error("INVALID", "Cookie 来源无效", null); return@setMethodCallHandler }
                    val values = call.argument<List<String>>("cookies") ?: emptyList()
                    if (values.isEmpty()) result.success(null) else {
                        var remaining = values.size
                        values.forEach { cookie ->
                            manager.setCookie(url, cookie) {
                                remaining--
                                if (remaining == 0) { manager.flush(); result.success(null) }
                            }
                        }
                    }
                }
                "clearCookies" -> manager.removeAllCookies { manager.flush(); result.success(null) }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ycoo.net.php/actions").setMethodCallHandler { call, result ->
            when (call.method) {
                "saveMediaToGallery" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val mime = call.argument<String>("mimeType").orEmpty()
                    if (bytes == null || bytes.isEmpty() || bytes.size > 64 * 1024 * 1024 || mime !in listOf("image/jpeg", "image/png", "image/gif", "image/webp", "image/bmp", "image/avif")) {
                        result.error("INVALID", "图片数据无效", null)
                    } else if (pendingSave != null) result.error("BUSY", "保存授权正在进行", null)
                    else if (Build.VERSION.SDK_INT < 29 && checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                        pendingSave = Pair(bytes, Pair(mime, result))
                        requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), savePermissionCode)
                    } else saveToGallery(bytes, mime, result)
                }
                "download" -> {
                    val url = call.argument<String>("url").orEmpty()
                    if (pendingDownload != null) result.error("BUSY", "下载授权正在进行", null)
                    else if (Build.VERSION.SDK_INT < 29 &&
                        checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                        pendingDownload = Pair(url, result)
                        requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), downloadPermissionCode)
                    } else enqueueDownload(url, result)
                }
                "shareText" -> {
                    val text = call.argument<String>("text").orEmpty()
                    if (text.isBlank()) result.error("EMPTY", "分享内容为空", null)
                    else try {
                        startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                        }, "分享"))
                        result.success(null)
                    } catch (_: Exception) {
                        result.error("UNAVAILABLE", "无法打开系统分享", null)
                    }
                }
                "chooseFiles" -> {
                    if (pendingFiles != null) result.error("BUSY", "文件选择器正在使用", null)
                    else {
                        val types = (call.argument<List<String>>("types") ?: emptyList())
                            .filter { it.matches(Regex("[a-zA-Z0-9.+*-]+/[a-zA-Z0-9.+*-]+")) }
                            .take(32)
                        val picker = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = if (types.size == 1) types.first() else "*/*"
                            if (types.isNotEmpty()) putExtra(Intent.EXTRA_MIME_TYPES, types.toTypedArray())
                            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, call.argument<Boolean>("multiple") == true)
                        }
                        pendingFiles = result
                        try { startActivityForResult(picker, fileRequestCode) }
                        catch (_: Exception) {
                            pendingFiles = null
                            result.error("UNAVAILABLE", "无法打开系统文件选择器", null)
                        }
                    }
                }
                "readSelectedFile" -> {
                    val value = call.argument<String>("uri").orEmpty()
                    if (value !in selectedFileUris) result.error("INVALID", "请重新选择文件", null)
                    else Thread {
                        try {
                            val uri = Uri.parse(value)
                            val name = contentResolver.query(uri, arrayOf(android.provider.OpenableColumns.DISPLAY_NAME), null, null, null)?.use { if (it.moveToFirst()) it.getString(0) else null } ?: "upload.bin"
                            val bytes = java.io.ByteArrayOutputStream()
                            (contentResolver.openInputStream(uri) ?: throw java.io.IOException()).use { input ->
                                val buffer = ByteArray(65536)
                                while (true) {
                                    val count = input.read(buffer)
                                    if (count < 0) break
                                    if (bytes.size() + count > 64 * 1024 * 1024) throw java.io.IOException("文件超过 64MB")
                                    bytes.write(buffer, 0, count)
                                }
                            }
                            val mime = contentResolver.getType(uri) ?: "application/octet-stream"
                            runOnUiThread { result.success(mapOf("name" to name, "bytes" to bytes.toByteArray(), "mimeType" to mime)) }
                        } catch (_: Exception) { runOnUiThread { result.error("READ_FAILED", "无法读取文件，单文件最大 64MB", null) } }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isSiteCookieUrl(url: String): Boolean {
        val uri = Uri.parse(url)
        return uri.scheme == "https" && uri.host == "ycoo.net" && uri.userInfo == null && (uri.port == -1 || uri.port == 443)
    }

    private fun saveToGallery(bytes: ByteArray, mime: String, result: MethodChannel.Result) {
        Thread {
            var createdUri: Uri? = null
            var createdFile: java.io.File? = null
            try {
                val ext = if (mime == "image/jpeg") "jpg" else mime.substringAfter('/')
                val name = "yuan_${System.currentTimeMillis()}.$ext"
                val saved: String
                if (Build.VERSION.SDK_INT >= 29) {
                    val values = android.content.ContentValues().apply {
                        put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME, name)
                        put(android.provider.MediaStore.MediaColumns.MIME_TYPE, mime)
                        put(android.provider.MediaStore.MediaColumns.RELATIVE_PATH, "Pictures/源社区")
                        put(android.provider.MediaStore.MediaColumns.IS_PENDING, 1)
                    }
                    val uri = contentResolver.insert(android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values) ?: throw java.io.IOException("无法创建相册记录")
                    createdUri = uri
                    (contentResolver.openOutputStream(uri) ?: throw java.io.IOException("无法写入相册")).use { it.write(bytes) }
                    values.clear()
                    values.put(android.provider.MediaStore.MediaColumns.IS_PENDING, 0)
                    contentResolver.update(uri, values, null, null)
                    saved = uri.toString()
                } else {
                    val directory = java.io.File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "源社区")
                    if (!directory.isDirectory && !directory.mkdirs()) throw java.io.IOException("无法创建相册目录")
                    val file = java.io.File.createTempFile("yuan_", ".$ext", directory)
                    createdFile = file
                    file.outputStream().use { it.write(bytes) }
                    android.media.MediaScannerConnection.scanFile(this, arrayOf(file.absolutePath), arrayOf(mime), null)
                    saved = file.absolutePath
                }
                runOnUiThread { result.success(saved) }
            } catch (_: Exception) {
                createdUri?.let { try { contentResolver.delete(it, null, null) } catch (_: Exception) {} }
                createdFile?.delete()
                runOnUiThread { result.error("SAVE_FAILED", "保存图片失败", null) }
            }
        }.start()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != fileRequestCode) return
        val callback = pendingFiles ?: return
        pendingFiles = null
        val uris = mutableListOf<String>()
        if (resultCode == Activity.RESULT_OK) {
            data?.clipData?.let { clip ->
                for (i in 0 until minOf(clip.itemCount, 20)) {
                    val uri = clip.getItemAt(i).uri
                    if (uri.scheme == "content") uris.add(uri.toString())
                }
            }
            data?.data?.let { if (it.scheme == "content") uris.add(it.toString()) }
        }
        selectedFileUris.addAll(uris)
        callback.success(uris.distinct())
    }

    private fun enqueueDownload(url: String, result: MethodChannel.Result) {
        try {
            val uri = Uri.parse(url)
            if (uri.scheme !in listOf("https", "http") || uri.host.isNullOrBlank() || uri.userInfo != null) {
                result.error("INVALID", "下载链接无效", null)
                return
            }
            val name = URLUtil.guessFileName(url, null, null).replace(Regex("[/\\\\]"), "_").take(180)
            val request = DownloadManager.Request(uri)
                .setTitle(name)
                .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                .setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, name)
            val manager = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
            result.success(manager.enqueue(request))
        } catch (_: Exception) {
            result.error("UNAVAILABLE", "无法启动下载，请尝试浏览器下载", null)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == savePermissionCode) {
            val pending = pendingSave ?: return
            pendingSave = null
            if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) saveToGallery(pending.first, pending.second.first, pending.second.second)
            else pending.second.second.error("DENIED", "未授予相册写入权限", null)
            return
        }
        if (requestCode != downloadPermissionCode) return
        val pending = pendingDownload ?: return
        pendingDownload = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) enqueueDownload(pending.first, pending.second)
        else pending.second.error("DENIED", "未授予下载目录权限", null)
    }
}
