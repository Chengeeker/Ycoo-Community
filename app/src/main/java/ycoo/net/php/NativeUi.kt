package ycoo.net.php

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.platform.*
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.*
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okio.BufferedSink
import org.jsoup.nodes.Element

@Composable fun NativePage(site:Site,nav:Nav,initial:String,embedded:Boolean=false) {
    val initialUrl=link(initial)!!
    if(initialUrl.encodedPath=="/plugin.php"&&initialUrl.queryParameter("id")=="bphp_clouds:index"){CloudPage(site,nav);return}
    if(initialUrl.encodedPath.startsWith("/k_misign")||initialUrl.queryParameter("id")=="k_misign:sign"){SignPage(site,nav);return}
    if(initialUrl.queryParameter("action")=="showdarkroom"){DarkroomPage(site,nav);return}
    var current by remember {mutableStateOf(initial)};var content by remember {mutableStateOf<NativeContent?>(null)};var error by remember {mutableStateOf("")};var busy by remember {mutableStateOf(false)}
    var switching by remember {mutableStateOf(false)};var price by remember {mutableStateOf<String?>(null)};var revision by remember {mutableIntStateOf(0)};var detail by remember {mutableStateOf<Entry?>(null)};val scope=rememberCoroutineScope();val clipboard=LocalClipboardManager.current
    val purchaseTid=if(initialUrl.encodedPath=="/forum.php"&&initialUrl.queryParameter("action")=="pay")initialUrl.queryParameter("tid")else null
    var submittingPurchase by remember {mutableStateOf(false)}
    val onPurchaseBusy:(Boolean)->Unit={submittingPurchase=it}
    suspend fun load(target:String=current) {if(busy||submittingPurchase)return;switching=target!=current;busy=true;error="";try {
        val u=link(target)!!
        val next=if(u.encodedPath=="/home.php"&&u.queryParameter("mod")=="medal"&&u.queryParameter("action")=="log"&&site.loggedIn) {
            val owner=site.uid;val p=site.api("profile",mapOf("uid" to owner,"_session" to System.nanoTime().toString())).optJSONObject("space");require(p?.optString("uid")==owner){"勋章资料与当前账号不匹配，请刷新重试"}
            NativeContent(listOf(Entry("勋章中心","$ORIGIN/home.php?mod=medal&mobile=2"),Entry("我的勋章",target)),emptyList(),jsonRows(p?.opt("medals")).map {Entry(it.text("name"),"",link(it.text("image"))?.takeIf {u->u.isSite()}?.toString().orEmpty(),it.text("description"))},"",emptyList(),message="暂无勋章",selected=1)
        }else {val source=site.request(site.url(target,mapOf("mobile" to "2","_session" to System.nanoTime().toString())));withContext(Dispatchers.Default){parseNative(source,target)}}
        if(purchaseTid!=null&&site.loggedIn){
            val v=site.api("viewthread",mapOf("tid" to purchaseTid,"_session" to System.nanoTime().toString()))
            val t=v.optJSONObject("thread")
            require(t?.optString("tid")==purchaseTid&&v.optString("member_uid")==site.uid){"购买主题或登录状态不匹配"}
            if(v.threadPurchaseUnlocked()&&nav.current=="native:$initial"){
                nav.invalidate("thread:$purchaseTid");nav.back();return
            }
            require(v.optString("forum_threadpay")=="1"){"站点未返回可确认的购买状态"}
            price=t.optString("price").takeIf {(it.toIntOrNull() ?: 0)>0} ?: error("站点未返回可确认的主题价格")
        }
        content=next;current=target;revision++
    }catch(e:Exception){if(e is CancellationException)throw e;error=e.message.orEmpty()}finally{busy=false;switching=false}}
    LaunchedEffect(initial){load()}
    DisposableEffect(initial){onDispose{if(purchaseTid==null)nav.current.takeIf(String::isNotEmpty)?.takeIf{it.startsWith("profile:")||it.startsWith("thread:")}?.let{nav.invalidate(it)}}}
    if(!embedded)PageActions(nav){
        if(content!=null)IconButton(onClick=tap{clipboard.setText(AnnotatedString(content!!.info));site.status="已复制页面结构信息，不包含 Cookie、密码或表单值"}){Icon(Icons.Outlined.BugReport,"复制页面适配信息")}
        IconButton(onClick=tap{scope.launch{load()}},enabled=!busy&&!submittingPurchase){Icon(Icons.Rounded.Refresh,"刷新")}
    }
    val c=content
    val equalTaskTabs=initialUrl.queryParameter("mod")=="task"&&c?.tabs?.size==4
    val taskScale=with(LocalDensity.current){15.sp.toDp().value}
    val taskLines=if(taskScale/15>1.5f)3 else 2
    val tabHeight=if(!embedded&&c!=null&&c.tabs.isNotEmpty()) {if(equalTaskTabs)maxOf(48.dp,(taskScale*1.2f*taskLines+16).dp)else filterTabHeight()}else 0.dp
    val top=LocalPageTop.current+tabHeight
    if(!embedded && c!=null && c.tabs.isNotEmpty()) {
        val scroll=!(initialUrl.queryParameter("mod")=="task"&&c.tabs.size==4)&&(c.tabs.size>3||c.tabs.any{it.title.length>4}||LocalDensity.current.fontScale>1.2f)
        HeaderTabs { OriginalTabs(c.tabs.map{it.title},c.selected.coerceIn(c.tabs.indices),scroll=scroll,height=tabHeight,maxLines=if(equalTaskTabs)taskLines else 1) {i->if(c.tabs[i].url.isEmpty())nav.loginThen("native:$current")else if(!busy)scope.launch{load(c.tabs[i].url)}} }
    }
    Column(Modifier.fillMaxSize()) {
        if((c==null||switching)&&busy)Box(Modifier.fillMaxSize().padding(top=top),contentAlignment=Alignment.Center){CircularProgressIndicator()}
        else if(c==null&&error.isNotEmpty())Box(Modifier.fillMaxSize().padding(top=top),contentAlignment=Alignment.Center){Failure(error,{scope.launch{load()}})}
        else LazyColumn(contentPadding=PaddingValues(start=16.dp,top=top+16.dp,end=16.dp,bottom=16.dp)) {
            if(busy)item{LinearProgressIndicator(Modifier.fillMaxWidth())}
            if(error.isNotEmpty())item{Text(error,Modifier.padding(bottom=12.dp),color=MaterialTheme.colorScheme.error)}
            if(c?.scripts==true)item{Text("此插件仍可能包含未适配的脚本操作，可复制页面适配信息反馈。",Modifier.padding(vertical=12.dp))}
            if(c?.login==true)item{Button(onClick=tap{nav.open("login")},modifier=Modifier.fillMaxWidth()){Icon(Icons.Rounded.Login,null);Spacer(Modifier.width(8.dp));Text("登录后继续")}}
            if(c!=null){
                if(c.parts.isNotEmpty())items(c.parts.size){i->val part=c.parts[i];when(part.kind){
                    "html"->Body(part.html,nav,followImageLinks=true)
                    "form"->key(revision,i){NativeForm(site,nav,c.forms[part.index],current,purchaseTid,price,onPurchaseBusy){response->content=parseNative(response,current);revision++}}
                    "contact"->{val e=c.contacts[part.index];SiteListItem(modifier=Modifier.clickable(onClick=tap{nav.route(e.url)}),headlineContent={Text(e.title)},supportingContent=if(e.detail.isEmpty())null else {{Text(e.detail)}},leadingContent={SiteAvatar(link(e.url)?.let(::profileId).orEmpty(),e.title,size=40.dp,url=e.image)})}
                    "medal"->{val e=c.medals[part.index];MedalRow(e,busy,{detail=e},{nav.route(e.url)})}
                }}else{
                items(c.contacts){e->SiteListItem(modifier=Modifier.clickable(onClick=tap{nav.route(e.url)}),headlineContent={Text(e.title)},supportingContent=if(e.detail.isEmpty())null else {{Text(e.detail)}},leadingContent={SiteAvatar(link(e.url)?.let(::profileId).orEmpty(),e.title,size=40.dp,url=e.image)})}
                items(c.medals){e->MedalRow(e,busy,{detail=e},{nav.route(e.url)})}
                if(c.html.isNotBlank())item{Body(c.html,nav,followImageLinks=true)}
                items(c.forms.size){i->key(revision,i){NativeForm(site,nav,c.forms[i],current,purchaseTid,price,onPurchaseBusy){response->content=parseNative(response,current);revision++}}}
                }
                if(!c.login&&c.html.isBlank()&&c.contacts.isEmpty()&&c.medals.isEmpty()&&c.forms.isEmpty())item{Text(c.message.ifBlank{"站点暂未返回可显示的内容"})}
            }
        }
    }
    detail?.let {e->OriginalDialog(onDismissRequest={detail=null},title={Text(e.title)},text={Column(horizontalAlignment=Alignment.CenterHorizontally){MedalImage(e,96.dp);Spacer(Modifier.height(16.dp));Text(e.detail)}},confirmButton={TextButton(onClick={detail=null}){Text("关闭")}})}
}
@Composable private fun MedalImage(entry:Entry,size:androidx.compose.ui.unit.Dp) {
    var failed by remember(entry.image){mutableStateOf(entry.image.isEmpty())}
    if(failed)Icon(Icons.Outlined.WorkspacePremium,entry.title,Modifier.size(size))
    else SiteImage(entry.image,entry.title,Modifier.size(size),scale=androidx.compose.ui.layout.ContentScale.Fit,onError={failed=true})
}
@Composable private fun MedalRow(entry:Entry,busy:Boolean,onDetail:()->Unit,onApply:()->Unit) {
    SiteListItem(modifier=Modifier.clickable(onClick=tap(onDetail)),leadingContent={MedalImage(entry,40.dp)},headlineContent={
        Row(verticalAlignment=Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {Text(entry.title);if(entry.detail.isNotEmpty()){Spacer(Modifier.height(4.dp));Text(entry.detail,style=MaterialTheme.typography.bodyMedium,color=MaterialTheme.colorScheme.onSurfaceVariant)}}
            if(entry.url.isNotEmpty()){Spacer(Modifier.width(12.dp));FilledTonalButton(onClick=tap(onApply),enabled=!busy,modifier=Modifier.width(104.dp),contentPadding=PaddingValues(horizontal=12.dp)){Text("立即申请",textAlign=androidx.compose.ui.text.style.TextAlign.Center)}}
        }
    })
}

data class UploadFile(val uri:android.net.Uri,val name:String,val mime:String)
fun initialFormValues(form:Element):Map<String,List<String>> {
    val result=linkedMapOf<String,List<String>>()
    val fields=form.select("input[name],textarea[name],select[name]").filterNot{it.hasAttr("disabled")}
    for(f in fields){val name=f.attr("name");val type=f.attr("type").lowercase()
        if(type in setOf("submit","button","file","reset")||(type in setOf("checkbox","radio")&&!f.hasAttr("checked")))continue
        val value=when(f.tagName()){"textarea"->f.text();"select"->(f.selectFirst("option[selected]") ?: f.selectFirst("option"))?.let{if(it.hasAttr("value"))it.attr("value")else it.text()}.orEmpty();else->if(f.hasAttr("value"))f.attr("value")else if(type=="checkbox")"on"else""}
        result[name]=if(type=="checkbox"&&(name.endsWith("[]")||fields.count{it.attr("name")==name}>1))result[name].orEmpty()+value else listOf(value)
    };return result
}
@Composable fun NativeForm(site:Site,nav:Nav,form:Element,base:String,purchaseTid:String?,price:String?,onPurchaseBusy:(Boolean)->Unit,onResponse:(String)->Unit) {
    val fields=remember(form){form.select("input[name],textarea[name],select[name]").filterNot{it.hasAttr("disabled")}}
    val values=remember(form){mutableStateMapOf<String,List<String>>().apply{putAll(initialFormValues(form))}};val files=remember{mutableStateMapOf<String,UploadFile>()}
    var selectedField by remember{mutableStateOf("")};var busy by remember{mutableStateOf(false)};var confirm by remember{mutableStateOf(false)};var submit by remember{mutableStateOf<Pair<String,String>?>(null)};var error by remember{mutableStateOf("")}
    var purchaseSent by remember(form){mutableStateOf(false)}
    val context=LocalContext.current;val scope=rememberCoroutineScope();val owner=site.uid;val ticket=site.epoch
    val picker=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()){uri->if(uri!=null){
        val name=context.contentResolver.query(uri,arrayOf(android.provider.OpenableColumns.DISPLAY_NAME),null,null,null)?.use{if(it.moveToFirst())it.getString(0)else null}.orEmpty().ifBlank{"upload.bin"}
        val mime=context.contentResolver.getType(uri)?.takeIf{it.matches(Regex("[a-zA-Z0-9.+-]+/[a-zA-Z0-9.+-]+"))} ?: "application/octet-stream"
        files[selectedField]=UploadFile(uri,name,mime)
    }}
    fun label(f:Element):String=f.attr("placeholder").ifBlank{f.attr("title")}.ifBlank{form.select("label[for]").firstOrNull{f.id().isNotEmpty()&&it.attr("for")==f.id()}?.text().orEmpty()}.ifBlank{f.parents().firstOrNull{it.tagName()=="label"}?.text().orEmpty()}.ifBlank{mapOf("username" to "用户名","password" to "密码","message" to "内容","subject" to "标题","name" to "名称","signature" to "签名","bio" to "简介")[f.attr("name")] ?: "填写内容"}
    SectionCard {Column(Modifier.padding(12.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) {
        val summary=remember(form){form.clone().apply{select("input,button,select,textarea,label").remove()}}
        if(summary.text().isNotBlank()||summary.selectFirst("img")!=null)Body(summary.html(),nav)
        fields.forEach {f->val name=f.attr("name");val type=f.attr("type").lowercase();if(type in setOf("hidden","submit","button","reset"))return@forEach
            when {
                f.tagName()=="select"->{var expanded by remember{mutableStateOf(false)};val options=f.select("option");Box {
                    OriginalTextField(options.firstOrNull{it.attr("value")==values[name]?.firstOrNull()}?.text().orEmpty(),{},readOnly=true,label={Text(label(f))},modifier=Modifier.fillMaxWidth(),colors=originalFieldColors());Box(Modifier.matchParentSize().clickable(enabled=!busy){expanded=true})
                    DropdownMenu(expanded,{expanded=false}){options.forEach{o->DropdownMenuItem(text={Text(o.text())},onClick={values[name]=listOf(if(o.hasAttr("value"))o.attr("value")else o.text());expanded=false})}}
                }}
                type=="radio"->SiteListItem(headlineContent={Text(label(f))},leadingContent={RadioButton(values[name]?.firstOrNull()==f.attr("value"),{values[name]=listOf(f.attr("value"))},enabled=!busy)})
                type=="checkbox"->{val value=f.attr("value").ifBlank{"on"};val checked=values[name]?.contains(value)==true;SiteListItem(headlineContent={Text(label(f))},trailingContent={Checkbox(checked,{chosen->val list=values[name].orEmpty().toMutableList();list.remove(value);if(chosen)list.add(value);if(list.isEmpty())values.remove(name)else values[name]=list},enabled=!busy)})}
                type=="file"->OutlinedButton(enabled=!busy,onClick={selectedField=name;val accepts=f.attr("accept").split(',').map{it.trim()}.filter{it.contains('/')};picker.launch(accepts.ifEmpty{listOf("*/*")}.toTypedArray())}){Icon(Icons.Rounded.UploadFile,null);Text(files[name]?.name ?: "选择文件")}
                else->OriginalTextField(values[name]?.firstOrNull().orEmpty(),{values[name]=listOf(it)},enabled=!busy,readOnly=f.hasAttr("readonly"),visualTransformation=if(type=="password")PasswordVisualTransformation()else VisualTransformation.None,label={Text(label(f))},minLines=if(f.tagName()=="textarea")4 else 1,maxLines=if(f.tagName()=="textarea")4 else 1,modifier=Modifier.fillMaxWidth(),colors=originalFieldColors())
            }
        }
        val buttons=form.select("button:not([type=button]):not([type=reset]),input[type=submit]")
        buttons.forEach{b->Button(enabled=!busy&&!purchaseSent&&!b.hasAttr("disabled"),modifier=Modifier.fillMaxWidth(),onClick={submit=b.attr("name") to if(b.hasAttr("value"))b.attr("value")else"true";confirm=true}){Text(if(purchaseTid!=null)"购买主题"else if(b.tagName()=="input")b.attr("value").ifBlank{"提交"}else b.text().ifBlank{"提交"})}}
        if(buttons.isEmpty()&&purchaseTid==null)Button(enabled=!busy,onClick={submit=null;confirm=true},modifier=Modifier.fillMaxWidth()){Text("查询")}
        if(error.isNotEmpty())Text(error,Modifier.padding(bottom=12.dp),color=MaterialTheme.colorScheme.error)
    }}
    if(confirm)OriginalDialog(onDismissRequest={confirm=false},title={Text(if(purchaseTid==null)"确认提交"else"确认购买主题")},text={Text(if(purchaseTid==null)"确认提交“${nativeTitle(base)}”中的这项操作？"else"购买该主题将由站点扣除 ${price ?: "页面所示数量的"} 星币。确认购买？")},dismissButton={TextButton(onClick={confirm=false}){Text("取消")}},confirmButton={Button(onClick={
        confirm=false;busy=true;error="";if(purchaseTid!=null)onPurchaseBusy(true);scope.launch{try {
            require(owner==site.uid);site.assertEpoch(ticket)
            val target=link(form.attr("action").ifBlank{base},base) ?: error("无效表单地址");require(target.isSite()){"表单要求离开站点，请通过原站确认"}
            val payload=values.toMutableMap();submit?.takeIf{it.first.isNotEmpty()}?.let{payload[it.first]=listOf(it.second)}
            if(purchaseTid!=null){require(!purchaseSent&&isThreadPurchaseForm(form,base,purchaseTid)&&(payload["tid"]==null||payload["tid"]==listOf(purchaseTid))){"购买表单与当前主题不匹配，请刷新后重试"}
                val before=site.api("viewthread",mapOf("tid" to purchaseTid,"_session" to System.nanoTime().toString()));require(before.optJSONObject("thread")?.optString("tid")==purchaseTid&&before.optString("member_uid")==owner&&site.loggedIn){"购买主题或登录状态不匹配"}
                if(nav.current!="native:$base")return@launch
                if(before.threadPurchaseUnlocked()){nav.invalidate("thread:$purchaseTid");nav.back();return@launch}
                require(before.optString("forum_threadpay")=="1"){"站点未返回可确认的购买状态"}
                require(price!=null&&before.optJSONObject("thread")?.optString("price")==price){"主题价格已变化，请刷新并重新核对价格"}
                site.assertEpoch(ticket)
                purchaseSent=true
            }
            val pairs=payload.flatMap{(k,v)->v.map{k to it}};val url=target.newBuilder().setQueryParameter("mobile","2").build()
            val response=if(!form.attr("method").equals("post",true))site.request(url.newBuilder().apply{pairs.forEach{(k,v)->addQueryParameter(k,v)}}.build().toString())else {
                val body=if(files.isEmpty())FormBody.Builder().apply{pairs.forEach{(k,v)->add(k,v)}}.build()else MultipartBody.Builder().setType(MultipartBody.FORM).apply{
                    pairs.forEach{(k,v)->addFormDataPart(k,v)};files.forEach{(name,file)->addFormDataPart(name,file.name,object:RequestBody(){override fun contentType()=file.mime.toMediaType();override fun writeTo(sink:BufferedSink){val buffer=ByteArray(8192);var count=0L;context.contentResolver.openInputStream(file.uri)?.use{input->while(true){val read=input.read(buffer);if(read<0)break;count+=read;require(count<=64L*1024*1024){"文件超过 64MB"};sink.write(buffer,0,read)}} ?: error("无法读取选择的文件")}})}
                }.build()
                site.request(url.toString(),body=body)
            }
            site.assertEpoch(ticket)
            if(purchaseTid!=null){
                val after=site.api("viewthread",mapOf("tid" to purchaseTid,"_session" to System.nanoTime().toString()))
                require(after.threadPurchaseUnlocked()&&after.optJSONObject("thread")?.optString("tid")==purchaseTid&&after.optString("member_uid")==owner){"尚未确认主题已解锁"}
                nav.invalidate("thread:$purchaseTid");if(nav.current=="native:$base")nav.back();return@launch
            }
            onResponse(response)
        }catch(e:Exception){if(e is CancellationException)throw e;error=if(purchaseSent)"${e.message}\n请刷新购买页核对解锁状态。"else"${e.message}\n输入已保留，请先核对原站，避免重复提交。"}finally{busy=false;if(purchaseTid!=null)onPurchaseBusy(false)}}
    }){Text("确认")}})
}

