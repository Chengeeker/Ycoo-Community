package ycoo.net.php

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.webkit.CookieManager
import kotlinx.coroutines.*
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit

private data class MediaTicket(val epoch:Int)
fun mediaClient(site:Site)=OkHttpClient.Builder().connectTimeout(20,TimeUnit.SECONDS).readTimeout(40,TimeUnit.SECONDS).retryOnConnectionFailure(false)
    .addInterceptor{chain->val ticket=chain.request().header("X-Compose-Epoch")?.toIntOrNull() ?: site.epoch
        if(ticket!=site.epoch)throw IOException("账户已切换，请重新加载")
        chain.proceed(chain.request().newBuilder().removeHeader("X-Compose-Epoch").tag(MediaTicket::class.java,MediaTicket(ticket)).build())
    }.addNetworkInterceptor{chain->val ticket=chain.request().tag(MediaTicket::class.java)?.epoch ?: site.epoch
        if(ticket!=site.epoch)throw IOException("账户已切换，请重新加载")
        val request=chain.request().newBuilder().removeHeader("Cookie").removeHeader("Referer").header("User-Agent",DESKTOP_UA)
        if(chain.request().url.isSite()){request.header("Referer","$ORIGIN/");CookieManager.getInstance().getCookie(chain.request().url.toString())?.takeIf{it.isNotBlank()}?.let{request.header("Cookie",it)}}
        val response=chain.proceed(request.build())
        if(ticket!=site.epoch){response.close();throw IOException("账户已切换，请重新加载")};response
    }.build()
fun galleryImageFormat(bytes:ByteArray):Pair<String,String>? {
    if(bytes.size<12)return null
    fun ascii(start:Int,length:Int)=String(bytes,start,length,Charsets.US_ASCII)
    return when{bytes[0].toInt()and 255==255&&bytes[1].toInt()and 255==216->"jpg" to "image/jpeg";bytes[0].toInt()and 255==137&&ascii(1,3)=="PNG"->"png" to "image/png";ascii(0,3)=="GIF"->"gif" to "image/gif";ascii(0,4)=="RIFF"&&ascii(8,4)=="WEBP"->"webp" to "image/webp";ascii(0,2)=="BM"->"bmp" to "image/bmp";ascii(4,8)=="ftypavif"->"avif" to "image/avif";else->null}
}
suspend fun saveGalleryImage(context:Context,site:Site,url:String):String {
    val ticket=site.epoch;val client=mediaClient(site)
    return withContext(Dispatchers.IO){
        val bytes=client.newCall(Request.Builder().url(requireNotNull(link(url))).header("X-Compose-Epoch","$ticket").build()).execute().use{response->
            require(response.isSuccessful){"图片加载失败：${response.code}"};val body=response.body ?: error("图片为空");require(body.contentLength()<=64L*1024*1024){"图片超过 64MB，请使用原站下载"}
            val output=ByteArrayOutputStream();body.byteStream().use{input->val buffer=ByteArray(8192);while(true){ensureActive();val read=input.read(buffer);if(read<0)break;require(output.size()+read<=64*1024*1024){"图片超过 64MB，请使用原站下载"};output.write(buffer,0,read)}};output.toByteArray()
        }
        ensureActive();site.assertEpoch(ticket);val format=galleryImageFormat(bytes) ?: error("图片格式无法识别，请使用原站下载");val name="yuan_${System.currentTimeMillis()}.${format.first}"
        if(Build.VERSION.SDK_INT>=29){val values=ContentValues().apply{put(MediaStore.MediaColumns.DISPLAY_NAME,name);put(MediaStore.MediaColumns.MIME_TYPE,format.second);put(MediaStore.MediaColumns.RELATIVE_PATH,"Pictures/源社区");put(MediaStore.MediaColumns.IS_PENDING,1)}
            val uri=context.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI,values) ?: error("无法创建相册记录")
            try{(context.contentResolver.openOutputStream(uri) ?: error("无法写入相册")).use{it.write(bytes)};ensureActive();values.clear();values.put(MediaStore.MediaColumns.IS_PENDING,0);context.contentResolver.update(uri,values,null,null);uri.toString()}catch(e:Exception){context.contentResolver.delete(uri,null,null);throw e}
        }else{val directory=File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),"源社区");require(directory.isDirectory||directory.mkdirs()){"无法创建相册目录"};val file=File.createTempFile("yuan_",".${format.first}",directory)
            try{file.outputStream().use{it.write(bytes)};ensureActive();android.media.MediaScannerConnection.scanFile(context,arrayOf(file.absolutePath),arrayOf(format.second),null);file.absolutePath}catch(e:Exception){file.delete();throw e}
        }
    }
}
