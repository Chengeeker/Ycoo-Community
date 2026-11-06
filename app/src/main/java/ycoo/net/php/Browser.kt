package ycoo.net.php

import android.annotation.SuppressLint
import android.content.Intent
import android.net.Uri
import android.webkit.*
import android.net.http.SslError
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.background
import androidx.compose.ui.Alignment
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.*
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.Lifecycle

val LocalNav=staticCompositionLocalOf<Nav>{error("Navigation unavailable")}
@SuppressLint("SetJavaScriptEnabled")
@OptIn(ExperimentalMaterial3Api::class)
@Composable fun BrowserPage(site:Site,source:String,nav:Nav=LocalNav.current,embedded:Boolean=false) {
    val context=LocalContext.current;val clipboard=LocalClipboardManager.current
    val initial=remember(source){link(source)?.newBuilder()?.fragment(null)?.build()}
    var browser by remember{mutableStateOf<WebView?>(null)};var error by remember{mutableStateOf("")};var progress by remember{mutableIntStateOf(0)}
    var current by remember{mutableStateOf(initial?.toString().orEmpty())};var title by remember{mutableStateOf(nav.titles[nav.current] ?: "原站页面")};var canBack by remember{mutableStateOf(false)}
    var findOpen by remember{mutableStateOf(false)};var pendingFind by remember{mutableStateOf(source.endsWith("#compose-find"))};var find by remember{mutableStateOf("")}
    var upload by remember{mutableStateOf<ValueCallback<Array<Uri>>?>(null)}
    var js by remember{mutableStateOf<Triple<String,String?,JsResult>?>(null)};var jsText by remember{mutableStateOf("")}
    val chooser=rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()){result->upload?.onReceiveValue(WebChromeClient.FileChooserParams.parseResult(result.resultCode,result.data));upload=null}
    val owner=LocalLifecycleOwner.current
    fun external(url:String){link(url)?.let{runCatching{context.startActivity(Intent(Intent.ACTION_VIEW,Uri.parse(it.toString())))}.onFailure{error="没有可打开此链接的浏览器"}}}
    DisposableEffect(Unit){if(initial?.isSite()==true)site.beginWebSessionChange();onDispose{upload?.onReceiveValue(null);upload=null;js?.third?.cancel();browser?.stopLoading();browser?.destroy();site.run{site.syncSession();nav.current.takeIf(String::isNotEmpty)?.let{nav.invalidate(it)}}}}
    DisposableEffect(owner,browser){val observer=LifecycleEventObserver{_,event->if(event==Lifecycle.Event.ON_STOP)browser?.onPause()else if(event==Lifecycle.Event.ON_START)browser?.onResume()};owner.lifecycle.addObserver(observer);onDispose{owner.lifecycle.removeObserver(observer)}}
    val active=LocalPageActive.current
    DisposableEffect(active,browser){if(active)browser?.onResume()else browser?.onPause();onDispose{}}
    BackHandler(canBack&&active){browser?.goBack()}
    fun search(backwards:Boolean=false){if(find.isBlank())return;browser?.evaluateJavascript("window.find(${org.json.JSONObject.quote(find)},false,$backwards,true)"){if(it=="false")site.status="没有找到匹配内容"}}
    Scaffold(topBar={if(!embedded)TopAppBar(expandedHeight=56.dp,title={Column{Text(title,maxLines=1,overflow=TextOverflow.Ellipsis,fontSize=16.sp,fontWeight=FontWeight.Bold);Text(link(current)?.host ?: current,maxLines=1,style=MaterialTheme.typography.labelSmall)}},navigationIcon={IconButton(onClick=tap{nav.back()}){Icon(Icons.Default.Close,"关闭页面")}},actions={
        IconButton(onClick=tap{browser?.reload()}){Icon(Icons.Default.Refresh,"刷新")}
        var menu by remember{mutableStateOf(false)}
        androidx.compose.foundation.layout.Box{IconButton(onClick={menu=true}){Icon(Icons.Default.MoreVert,"更多操作")};DropdownMenu(menu,{menu=false}){
            listOf("复制链接","在浏览器打开","分享网页","网页查找","回到顶部","电脑版","下载当前链接").forEachIndexed{i,label->DropdownMenuItem(text={Text(label)},onClick={menu=false;when(i){
                0->clipboard.setText(AnnotatedString(current));1->external(current);2->runCatching{context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT,current),"分享"))}.onFailure{site.status="无法打开系统分享"};3->findOpen=true;4->browser?.evaluateJavascript("window.scrollTo({top:0,behavior:'smooth'})",null);5->{browser?.settings?.userAgentString=DESKTOP_UA;link(current)?.newBuilder()?.setQueryParameter("mobile","no")?.build()?.let{browser?.loadUrl(it.toString())}};6->nav.download=current
            }})}
        }}
    },colors=TopAppBarDefaults.topAppBarColors(containerColor=MaterialTheme.colorScheme.background))}){padding->
        Column(Modifier.fillMaxSize().padding(if(embedded)PaddingValues(0.dp)else padding)){
            if(progress<100)LinearProgressIndicator(progress={progress/100f},modifier=Modifier.fillMaxWidth())
            Box(Modifier.weight(1f).fillMaxWidth()){
            AndroidView(modifier=Modifier.fillMaxSize(),factory={ctx->WebView(ctx).apply{
                browser=this;settings.javaScriptEnabled=true;settings.domStorageEnabled=true;settings.allowFileAccess=false;settings.allowContentAccess=true;settings.mixedContentMode=WebSettings.MIXED_CONTENT_NEVER_ALLOW
                settings.userAgentString=if(initial?.queryParameter("mobile")=="no")DESKTOP_UA else MOBILE_UA
                CookieManager.getInstance().setAcceptThirdPartyCookies(this,false)
                webViewClient=object:WebViewClient(){
                    override fun shouldOverrideUrlLoading(view:WebView,request:WebResourceRequest):Boolean{
                        val u=link(request.url.toString()) ?: return true
                        if(request.isForMainFrame){if(isImageUrl(u.toString())||(threadId(u)!=null&&u.toString()!=initial.toString())){nav.route(u.toString());return true};if(isDownloadUrl(u.toString())&&u.toString()!=initial.toString()){nav.download=u.toString();return true}}
                        return false
                    }
                    override fun onPageStarted(view:WebView,url:String?,icon:android.graphics.Bitmap?){error="";current=url.orEmpty();canBack=view.canGoBack()}
                    override fun onPageFinished(view:WebView,url:String?){canBack=view.canGoBack();CookieManager.getInstance().flush();if(pendingFind){pendingFind=false;findOpen=true}}
                    override fun onReceivedError(view:WebView,request:WebResourceRequest,e:WebResourceError){if(request.isForMainFrame){error=e.description.toString();progress=100}}
                    override fun onReceivedSslError(view:WebView,handler:SslErrorHandler,e:SslError){handler.cancel();error="站点证书校验失败";progress=100}
                }
                webChromeClient=object:WebChromeClient(){
                    override fun onProgressChanged(view:WebView,value:Int){progress=value}
                    override fun onReceivedTitle(view:WebView,value:String?){if(!value.isNullOrBlank())title=value}
                    override fun onJsAlert(view:WebView,url:String,message:String,result:JsResult):Boolean{js=Triple(message,"alert",result);return true}
                    override fun onJsConfirm(view:WebView,url:String,message:String,result:JsResult):Boolean{js=Triple(message,"confirm",result);return true}
                    override fun onJsPrompt(view:WebView,url:String,message:String,defaultValue:String?,result:JsPromptResult):Boolean{jsText=defaultValue.orEmpty();js=Triple(message,"prompt",result);return true}
                    override fun onShowFileChooser(view:WebView,callback:ValueCallback<Array<Uri>>,params:FileChooserParams):Boolean{upload?.onReceiveValue(null);upload=callback;try{chooser.launch(params.createIntent())}catch(_:Exception){upload=null;callback.onReceiveValue(null);site.status="无法打开文件选择器"};return true}
                }
                setDownloadListener{url,_,_,_,_->nav.download=url}
                initial?.let{loadUrl(it.toString())}
            }})
            if(error.isNotEmpty())Box(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background),contentAlignment=Alignment.Center){Failure(error,{error="";browser?.reload()})}
            }
        }
    }
    if(findOpen)OriginalDialog(onDismissRequest={findOpen=false},title={Text("网页查找")},text={OriginalTextField(find,{find=it},label={Text("查找文字")},singleLine=true,keyboardActions=androidx.compose.foundation.text.KeyboardActions(onDone={search()}),colors=originalFieldColors())},confirmButton={TextButton(onClick={findOpen=false}){Text("完成")}},dismissButton={androidx.compose.foundation.layout.Row{TextButton(onClick={search(true)}){Text("上一处")};TextButton(onClick={search()}){Text("下一处")}}})
    js?.let{(message,kind,result)->OriginalDialog(onDismissRequest={result.cancel();js=null},title=if(kind=="prompt"){{Text(message)}}else null,text={if(kind=="prompt")OriginalTextField(jsText,{jsText=it},colors=originalFieldColors())else Text(message)},dismissButton=if(kind!="alert"){{TextButton(onClick={result.cancel();js=null}){Text("取消")}}}else null,confirmButton={val confirm={if(result is JsPromptResult)result.confirm(jsText)else result.confirm();js=null};if(kind=="alert")TextButton(onClick=confirm){Text("确定")}else Button(onClick=confirm){Text("确定")}})}
}


