package ycoo.net.php

import android.app.DownloadManager
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.*
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.unit.dp

fun isImageUrl(raw:String)=link(raw)?.encodedPath?.contains(Regex("\\.(png|jpe?g|gif|webp|avif|bmp)$",RegexOption.IGNORE_CASE))==true
fun isVideoUrl(raw:String)=link(raw)?.encodedPath?.contains(Regex("\\.(mp4|m3u8|webm|mov|m4v|mkv)$",RegexOption.IGNORE_CASE))==true
fun isDownloadUrl(raw:String):Boolean {val u=link(raw) ?: return false;return u.queryParameter("mod")=="attachment"||u.encodedPath.contains(Regex("\\.(apk|zip|7z|rar|epub|mobi|azw3|pdf)$",RegexOption.IGNORE_CASE))}
@OptIn(ExperimentalMaterial3Api::class)
@Composable fun LinkDialogs(site:Site,nav:Nav) {
    val context=LocalContext.current;val clipboard=LocalClipboardManager.current;var queued by remember{mutableStateOf<String?>(null)}
    fun enqueue(raw:String){try{val u=link(raw) ?: error("下载链接无效");val name=android.webkit.URLUtil.guessFileName(u.toString(),null,null).replace(Regex("[/\\\\]"),"_").take(180)
        val request=DownloadManager.Request(Uri.parse(u.toString())).setTitle(name).setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED).setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS,name)
        (context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager).enqueue(request);site.status="已加入系统下载队列，请在通知栏查看进度"
    }catch(_:Exception){site.status="无法启动下载，请尝试浏览器下载"}}
    val permission=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()){allowed->queued?.let{if(allowed)enqueue(it)else site.status="未授予下载目录权限"};queued=null}
    nav.download?.let{url->OriginalDialog(onDismissRequest={nav.download=null},title={Text("下载文件")},text={Text("选择系统下载或浏览器下载。需要登录权限的附件可在浏览器中完成验证。")},dismissButton={Row{TextButton(onClick={nav.download=null;clipboard.setText(AnnotatedString(url))}){Text("复制链接")};TextButton(onClick={nav.download=null;nav.open("web:$url")}){Text("浏览器")}}},confirmButton={Button(onClick={nav.download=null;if(Build.VERSION.SDK_INT<29&&context.checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE)!=PackageManager.PERMISSION_GRANTED){queued=url;permission.launch(android.Manifest.permission.WRITE_EXTERNAL_STORAGE)}else enqueue(url)}){Text("系统下载")}})}
    nav.external?.let{url->OriginalBottomSheet(onDismissRequest={nav.external=null}){Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).navigationBarsPadding().padding(start=24.dp,end=24.dp,bottom=24.dp)){
        Text("即将离开源社区",style=MaterialTheme.typography.titleLarge);Spacer(Modifier.height(12.dp));Text("此链接指向外部网站，请确认访问地址。");Spacer(Modifier.height(12.dp));SelectionContainer{Text(url)};Spacer(Modifier.height(20.dp))
        Button(onClick={nav.external=null;if(isDownloadUrl(url))nav.download=url else nav.open("web:$url")},modifier=Modifier.fillMaxWidth()){Text("继续访问")};Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement=Arrangement.spacedBy(12.dp)){OutlinedButton(onClick={nav.external=null;clipboard.setText(AnnotatedString(url));site.status="链接已复制"},modifier=Modifier.weight(1f)){Text("复制链接")};OutlinedButton(onClick={nav.external=null;nav.open("web:$url")},modifier=Modifier.weight(1f)){Text("浏览器打开")}}
    }}}
}
