package ycoo.net.php

import android.content.Intent
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.*
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.*
import org.json.JSONArray
import org.json.JSONObject

fun jsonRows(value:Any?):List<JSONObject> = when(value) {is JSONArray->value.objects();is JSONObject->if(value.has("list"))jsonRows(value.opt("list")) else value.keys().asSequence().mapNotNull {value.optJSONObject(it)}.toList();else->emptyList()}
@Composable fun QrCode(url:String,label:String,modifier:Modifier=Modifier) {
    val matrix=remember(url) {com.google.zxing.qrcode.QRCodeWriter().encode(url,com.google.zxing.BarcodeFormat.QR_CODE,0,0,mapOf(com.google.zxing.EncodeHintType.ERROR_CORRECTION to com.google.zxing.qrcode.decoder.ErrorCorrectionLevel.L,com.google.zxing.EncodeHintType.MARGIN to 0))}
    Canvas(modifier.sizeIn(maxWidth=220.dp,maxHeight=220.dp).fillMaxWidth().aspectRatio(1f).background(Color.White).semantics {contentDescription=label}) {
        val inset=10.dp.toPx();val unit=(size.width-2*inset)/matrix.width
        for(y in 0 until matrix.height)for(x in 0 until matrix.width)if(matrix[x,y])drawRect(Color.Black,Offset(inset+x*unit,inset+y*unit),Size(unit+.1f,unit+.1f))
    }
}
@OptIn(ExperimentalLayoutApi::class)
@Composable fun PromotionPage(site:Site) {
    val url="$ORIGIN/?fromuid=${site.uid}";val clipboard=LocalClipboardManager.current;val context=LocalContext.current
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(start=24.dp,top=LocalPageTop.current+24.dp,end=24.dp,bottom=24.dp)) {
        SectionCard(color=MaterialTheme.colorScheme.settingsCardColor()) {Column(Modifier.fillMaxWidth().padding(24.dp),horizontalAlignment=Alignment.CenterHorizontally) {
            SiteAvatar(site.uid,site.username,72.dp);Spacer(Modifier.height(12.dp));Text(site.username,style=MaterialTheme.typography.titleLarge);Text("UID ${site.uid}");Spacer(Modifier.height(24.dp));QrCode(url,"推广链接二维码");Spacer(Modifier.height(16.dp));Text("邀请好友扫码访问源社区")
        }}
        Spacer(Modifier.height(16.dp));SelectionContainer {Text(url)};Spacer(Modifier.height(8.dp))
        FlowRow(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
            FilledTonalButton(onClick=tap {clipboard.setText(AnnotatedString(url));site.status="推广链接已复制"}) {Icon(Icons.Rounded.ContentCopy,null);Spacer(Modifier.width(8.dp));Text("复制链接")}
            OutlinedButton(onClick=tap {context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT,url),"分享"))}) {Icon(Icons.Outlined.Share,null);Spacer(Modifier.width(8.dp));Text("分享")}
        }
    }
}
@Composable fun ProfileSettingsPage(site:Site,nav:Nav) {
    var bindings by remember {mutableStateOf(emptyMap<String,String>())};var loading by remember {mutableStateOf(true)};var failed by remember {mutableStateOf(false)};val scope=rememberCoroutineScope()
    suspend fun load() {loading=true;failed=false;try {
        val source=site.request("/home.php?mod=spacecp&ac=profile&mobile=2")
        bindings=doc(source).select("a[href]").mapNotNull {a->val label=a.text();val url=link(a.attr("href")) ?: return@mapNotNull null
            when {label.contains("微信")&&label.contains("绑定")->"微信绑定" to url.toString();label.contains("QQ",true)&&label.contains("绑定")->"QQ绑定" to url.toString();else->null}}.toMap()
    } catch(e:Exception) {if(e is CancellationException)throw e;failed=true} finally {loading=false}}
    LaunchedEffect(Unit) {load()}
    Column(Modifier.verticalScroll(rememberScrollState()).padding(start=16.dp,top=LocalPageTop.current+16.dp,end=16.dp,bottom=24.dp)) {SectionCard(color=MaterialTheme.colorScheme.settingsCardColor()) {
        listOf(Triple("资料修改",Icons.Outlined.Badge,""),Triple("密码安全",Icons.Outlined.Security,"&op=password"),Triple("认证信息",Icons.Outlined.VerifiedUser,"&op=verify")).forEach {(label,icon,op)->Preference(label,icon,onClick={nav.open("web:$ORIGIN/home.php?mod=spacecp&ac=profile$op")})}
        listOf("微信绑定","QQ绑定").forEach {label->Preference(label,Icons.Rounded.Link,if(bindings.containsKey(label))null else if(loading)"正在读取站点入口" else if(failed)"读取失败，点击重试" else "站点未返回可识别的入口",onClick=if(bindings.containsKey(label)){{nav.open("web:${bindings[label]}")}}else if(failed){{scope.launch {load()}}}else null)}
    }}
}
@Composable fun CreditsPage(site:Site,nav:Nav) {
    var tab by remember {mutableIntStateOf(0)};var data by remember {mutableStateOf<JSONObject?>(null)};var error by remember {mutableStateOf("")};val scope=rememberCoroutineScope();val ticket=site.epoch;val owner=site.uid
    suspend fun load() {error="";try {val v=site.api("profile",mapOf("uid" to owner));site.assertEpoch(ticket);require(v.optJSONObject("space")?.optString("uid")==owner){"账户已变化，请重新打开积分页面"};data=v} catch(e:Exception) {if(e is CancellationException)throw e;error=e.message.orEmpty()}}
    LaunchedEffect(Unit){load()}
    val top=LocalPageTop.current
    val tabHeight=filterTabHeight()
    HeaderTabs {OriginalTabs(listOf("我的","转账","充值","记录"),tab,scroll=LocalDensity.current.fontScale>1.2f,height=tabHeight){tab=it}}
    Column(Modifier.fillMaxSize().padding(top=top+tabHeight)) {
        if(tab==0) {val v=data
            when {error.isNotEmpty()->Box(Modifier.fillMaxSize(),contentAlignment=Alignment.Center){Failure(error,{scope.launch {load()}})};v==null->Box(Modifier.fillMaxSize(),contentAlignment=Alignment.Center){CircularProgressIndicator()};else->{val space=v.getJSONObject("space");val currencies=v.optJSONObject("extcredits") ?: JSONObject()
                LazyColumn(contentPadding=PaddingValues(16.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) {
                    item {SectionCard(color=MaterialTheme.colorScheme.settingsCardColor()) {SiteListItem(headlineContent={Text("积分")},supportingContent={Text(space.optString("credits","—"),style=MaterialTheme.typography.headlineMedium)})}}
                    item {SectionCard(color=MaterialTheme.colorScheme.settingsCardColor()) {currencies.keys().asSequence().filter {it.toIntOrNull()!=null&&currencies.optJSONObject(it)!=null}.sortedByDescending {it.toInt()}.forEach {id->SiteListItem(headlineContent={Text(currencies.getJSONObject(id).text("title"))},trailingContent={Text(space.optString("extcredits$id","—"))})}}}
                }
            }}
        } else key(tab) {val url="$ORIGIN/home.php?mod=spacecp&ac=credit&op=${listOf("","transfer","buy","log")[tab]}&mobile=2"
            CompositionLocalProvider(LocalPageTop provides 0.dp) {if(tab==3)NativePage(site,nav,url,embedded=true)else BrowserPage(site,url,nav,embedded=true)}
        }
    }
}
@Composable fun MessagesPage(site:Site,nav:Nav,module:String) {
    var rows by remember {mutableStateOf(emptyList<JSONObject>())};var page by remember {mutableIntStateOf(0)};var more by remember {mutableStateOf(true)};var busy by remember {mutableStateOf(false)};var error by remember {mutableStateOf("")};val scope=rememberCoroutineScope()
    val path="$ORIGIN/home.php?mod=space&do=${if(module=="mypm")"pm" else "notice"}"
    suspend fun load() {if(busy)return;busy=true;error="";try {
        val v=site.api(module,mapOf("page" to "${page+1}"));val batch=jsonRows(v.opt("list") ?: v.opt("data"));rows=rows+batch;page++;more=batch.isNotEmpty()&&(if(v.optInt("count")==0)batch.size>=v.optInt("perpage") else rows.size<v.optInt("count"))
    }catch(e:Exception){if(e is CancellationException)throw e;error=e.message.orEmpty()}finally{busy=false}}
    LaunchedEffect(Unit){load()}
    PageActions(nav){IconButton(onClick=tap {nav.open("web:$path")}){Icon(Icons.Rounded.OpenInBrowser,"原站管理")}}
    if(rows.isEmpty()&&(busy||error.isNotEmpty())) {Box(Modifier.fillMaxSize().padding(top=LocalPageTop.current),contentAlignment=Alignment.Center){if(busy)CircularProgressIndicator()else Failure(error,{scope.launch{load()}})};return}
    LazyColumn(contentPadding=PaddingValues(start=12.dp,top=LocalPageTop.current+12.dp,end=12.dp,bottom=12.dp)) {
        if(rows.isEmpty()&&!busy&&error.isEmpty())item {Box(Modifier.fillMaxWidth().padding(32.dp),contentAlignment=Alignment.Center){Text("暂无内容")}}
        items(rows){row->val uid=listOf(row.optString("touid"),row.optString("msgfromid")).firstOrNull {it.matches(Regex("[1-9]\\d*"))&&it!=site.uid}
            val name=(if(uid==row.optString("touid"))row.text("tousername")else "").ifBlank {row.text("msgfrom")}.ifBlank {row.text("author")}
            val message=listOf("message","note","lastsummary","subject").firstNotNullOfOrNull {key->row.opt(key)?.let {plain(it.toString())}}.orEmpty()
            SiteListItem(modifier=Modifier.clickable(onClick=tap {nav.open("web:${if(module=="mypm"&&uid!=null)"$ORIGIN/home.php?mod=space&do=pm&subop=view&touid=$uid&viewall=1" else path}")}),headlineContent={Text(name.ifBlank {"站点消息"})},supportingContent={Text(listOf(message,row.text("vdateline")).filter {it.isNotEmpty()}.joinToString("\n"),maxLines=4,overflow=TextOverflow.Ellipsis)},leadingContent=if(uid!=null){{SiteAvatar(uid,name)}}else null)
        }
        if(error.isNotEmpty())item {TextButton(onClick={scope.launch{load()}},modifier=Modifier.fillMaxWidth()){Text("$error · 重试")}} else if(more)item {TextButton(onClick={scope.launch{load()}},enabled=!busy,modifier=Modifier.fillMaxWidth()){Text(if(busy)"加载中…" else "加载更多")}}
    }
}
@Composable fun DarkroomPage(site:Site,nav:Nav) {
    var rows by remember {mutableStateOf(emptyList<JSONObject>())};var cursor by remember {mutableStateOf<String?>(null)};var more by remember {mutableStateOf(true)};var busy by remember {mutableStateOf(false)};var error by remember {mutableStateOf("")};val scope=rememberCoroutineScope()
    suspend fun load(refresh:Boolean=false) {if(busy)return;busy=true;error="";try {
        val previous=if(refresh)null else cursor
        val v=withContext(Dispatchers.Default){Parse.darkroom(site.request(site.url("/forum.php",mapOf("mod" to "misc","action" to "showdarkroom","ajaxdata" to "json")+(previous?.let {mapOf("cid" to it)} ?: emptyMap()))))}
        val batch=jsonRows(v.opt("data"));val next=Regex("^1\\|(\\d+)$").find(v.optString("message"))?.groupValues?.get(1);rows=((if(refresh)emptyList()else rows)+batch).distinctBy {it.optString("cid")};more=batch.isNotEmpty()&&next!=null&&next!=previous;cursor=next
    }catch(e:Exception){if(e is CancellationException)throw e;error=e.message.orEmpty()}finally{busy=false}}
    LaunchedEffect(Unit){load()}
    PageActions(nav){IconButton(onClick=tap {scope.launch{load(true)}},enabled=!busy){Icon(Icons.Rounded.Refresh,"刷新")}}
    if(rows.isEmpty()&&(busy||error.isNotEmpty())) {Box(Modifier.fillMaxSize().padding(top=LocalPageTop.current),contentAlignment=Alignment.Center){if(busy)CircularProgressIndicator()else Failure(error,{scope.launch{load(true)}})};return}
    LazyColumn(contentPadding=PaddingValues(start=12.dp,top=LocalPageTop.current+12.dp,end=12.dp,bottom=12.dp),verticalArrangement=Arrangement.spacedBy(8.dp)) {
        if(rows.isEmpty()&&!busy&&error.isEmpty())item {Text("暂无记录",Modifier.fillMaxWidth(),textAlign=androidx.compose.ui.text.style.TextAlign.Center)}
        items(rows){r->SectionCard(color=MaterialTheme.colorScheme.settingsCardColor()) {SiteListItem(modifier=Modifier.clickable(enabled=r.optString("uid").matches(Regex("[1-9]\\d*")),onClick=tap{nav.open("profile:${r.optString("uid")}")}),headlineContent={Text(r.text("username"))},leadingContent={SiteAvatar(r.optString("uid"),r.text("username"))},supportingContent={Text((listOf(r.text("action"),r.text("reason"),r.text("dateline"),"到期：${r.text("groupexpiry")}")).filter {it.isNotEmpty()}.joinToString(" · "))})}}
        if(error.isNotEmpty())item {TextButton(onClick={scope.launch{load()}},modifier=Modifier.fillMaxWidth()){Text("$error · 重试")}}else if(more)item {TextButton(onClick={scope.launch{load()}},enabled=!busy,modifier=Modifier.fillMaxWidth()){Text(if(busy)"加载中…"else"加载更多")}}
    }
}
