package ycoo.net.php

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.LocalContext
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.*
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okio.BufferedSink
import org.json.JSONObject

fun cloudResponse(source:String):JSONObject {
    val result=runCatching {JSONObject(source)}.getOrElse {error("云盘返回内容无法识别")}
    require(result.optString("sta")=="1"){result.optString("msg","云盘操作未确认")}
    return result
}

@Composable fun CloudPage(site:Site,nav:Nav) {
    val owner=remember {site.uid};val ticket=remember {site.epoch}
    val scope=rememberCoroutineScope();val context=LocalContext.current
    var hash by remember {mutableStateOf("")};var cid by remember {mutableStateOf("0")};var parent by remember {mutableStateOf("0")}
    var search by remember {mutableStateOf("")};var page by remember {mutableIntStateOf(1)};var maxPage by remember {mutableIntStateOf(1)}
    var busy by remember {mutableStateOf(false)};var failure by remember {mutableStateOf("")}
    var config by remember {mutableStateOf(JSONObject())};var user by remember {mutableStateOf(JSONObject())}
    var folders by remember {mutableStateOf(emptyList<JSONObject>())};var files by remember {mutableStateOf(emptyList<JSONObject>())}
    var input by remember {mutableStateOf<Pair<String,JSONObject?>?>(null)};var inputText by remember {mutableStateOf("")}
    var deletion by remember {mutableStateOf<Pair<JSONObject,Boolean>?>(null)}
    val inputFocus=remember {FocusRequester()}
    suspend fun call(values:Map<String,String>,file:UploadFile?=null):JSONObject {
        require(site.loggedIn&&site.uid==owner){"请先登录"};site.assertEpoch(ticket)
        val fields=values+mapOf("formhash" to hash)
        val body=file?.let {upload->MultipartBody.Builder().setType(MultipartBody.FORM).apply {
            fields.forEach{(name,value)->addFormDataPart(name,value)}
            addFormDataPart("file",upload.name,object:RequestBody(){
                override fun contentType()=upload.mime.toMediaType()
                override fun writeTo(sink:BufferedSink){context.contentResolver.openInputStream(upload.uri)?.use {stream->
                    val buffer=ByteArray(8192);var total=0L
                    while(true){val count=stream.read(buffer);if(count<0)break;total+=count;require(total<=64L*1024*1024){"文件超过 64MB"};sink.write(buffer,0,count)}
                } ?: error("无法读取选择的文件")}
            })
        }.build()}
        val result=cloudResponse(site.request("/plugin.php?id=bphp_clouds:api&mobile=2",if(body==null)fields else null,body))
        site.assertEpoch(ticket);return result
    }
    suspend fun load(reset:Boolean=false) {
        if(busy)return
        if(reset)page=1
        busy=true;failure=""
        try {
            require(site.loggedIn){"请先登录"}
            if(hash.isEmpty()) {
                val source=site.request("/plugin.php?id=bphp_clouds:index&mobile=2&_session=${System.nanoTime()}")
                hash=Regex("['\"]formhash['\"]\\s*:\\s*['\"]([a-zA-Z0-9]{8})['\"]").find(source)?.groupValues?.get(1) ?: site.formhash
                require(hash.matches(Regex("[a-zA-Z0-9]{8}"))){"无法确认云盘凭据，请重新登录"}
                coroutineScope {val a=async{call(mapOf("ac" to "config"))};val b=async{call(mapOf("ac" to "getUserInfo"))};config=a.await().optJSONObject("data") ?: JSONObject();user=b.await().optJSONObject("data") ?: JSONObject()}
            }
            val result=call(mapOf("ac" to "fileDisplay","cid" to cid,"type" to "all","page" to "$page","searchKey" to search))
            folders=jsonRows(result.opt("cList"));files=jsonRows(result.opt("fList"));parent=result.optString("pid","0");maxPage=result.optInt("maxPage").coerceAtLeast(1)
        }catch(e:Exception){if(e is CancellationException)throw e;failure=e.message.orEmpty()}finally{busy=false}
    }
    fun perform(values:Map<String,String>,file:UploadFile?=null) {
        if(busy)return
        busy=true;scope.launch {try{val result=call(values,file);site.status=result.optString("msg","操作已完成")}
            catch(e:Exception){if(e is CancellationException)throw e;site.status=e.message.orEmpty()}
            finally{busy=false};load()}
    }
    val picker=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()){uri->if(uri!=null&&!busy&&owner==site.uid&&ticket==site.epoch){
        runCatching {
            val name=context.contentResolver.query(uri,arrayOf(android.provider.OpenableColumns.DISPLAY_NAME),null,null,null)?.use{if(it.moveToFirst())it.getString(0)else null}.orEmpty().ifBlank{"upload.bin"}
            val mime=context.contentResolver.getType(uri)?.takeIf{it.matches(Regex("[a-zA-Z0-9.+-]+/[a-zA-Z0-9.+-]+"))} ?: "application/octet-stream"
            perform(mapOf("ac" to "upload","cid" to cid,"flag" to "2","rePath" to ""),UploadFile(uri,name,mime))
        }.onFailure{site.status=it.message.orEmpty()}
    }}
    LaunchedEffect(Unit){load()}
    PageActions(nav){IconButton(onClick=tap{scope.launch{load()}},enabled=!busy){Icon(Icons.Default.Refresh,"刷新")}}
    @Composable fun Menu(entry:JSONObject,folder:Boolean) {
        var expanded by remember {mutableStateOf(false)}
        Box {IconButton(onClick={expanded=true},enabled=!busy){Icon(Icons.Default.MoreVert,"更多操作")}
            DropdownMenu(expanded,{expanded=false}) {
                if(!folder)DropdownMenuItem(text={Text("下载")},onClick={expanded=false;link(entry.optString("link"))?.let{nav.download=it.toString()}})
                DropdownMenuItem(text={Text("重命名")},onClick={expanded=false;input="重命名" to entry;inputText=entry.optString(if(folder)"c_name"else"name")})
                DropdownMenuItem(text={Text("删除")},onClick={expanded=false;deletion=entry to folder})
            }
        }
    }
    Box(Modifier.fillMaxSize()) {
        LazyColumn(contentPadding=PaddingValues(start=16.dp,top=LocalPageTop.current+16.dp,end=16.dp,bottom=100.dp)) {
            if(busy)item{LinearProgressIndicator(Modifier.fillMaxWidth())}
            if(!site.loggedIn)item{Button(onClick=tap{nav.loginThen("cloud")},modifier=Modifier.fillMaxWidth()){Icon(Icons.Default.Login,null);Spacer(Modifier.width(8.dp));Text("登录云盘")}}
            if(failure.isNotEmpty())item{Text(failure,Modifier.padding(vertical=12.dp))}
            if(site.loggedIn) {
                item{OriginalTextField(search,{search=it},label={Text("搜索文件")},leadingIcon={Icon(Icons.Rounded.Search,null)},keyboardOptions=KeyboardOptions(imeAction=ImeAction.Search),keyboardActions=KeyboardActions(onSearch={scope.launch{load(true)}}))}
                item{Row(verticalAlignment=Alignment.CenterVertically){TextButton(onClick={cid=parent;scope.launch{load(true)}},enabled=!busy&&cid!="0"){Icon(Icons.Default.ArrowUpward,null);Spacer(Modifier.width(8.dp));Text("上一级")};TextButton(onClick={cid="0";scope.launch{load(true)}},enabled=!busy){Text("根目录")};Spacer(Modifier.weight(1f));IconButton(onClick={input="新建文件夹" to null;inputText=""},enabled=!busy){Icon(Icons.Outlined.CreateNewFolder,"新建文件夹")}}}
                if(user.length()>0)item{Text("已用 ${user.optString("capacity","-")} / ${user.optString("spaceSize","-")} 字节")}
                items(folders){folder->SiteListItem(modifier=Modifier.clickable(enabled=!busy,onClick=tap{cid=folder.optString("cid");scope.launch{load(true)}}),headlineContent={Text(folder.optString("c_name"))},leadingContent={Icon(Icons.Outlined.Folder,null)},trailingContent={Menu(folder,true)})}
                items(files){file->SiteListItem(modifier=Modifier.clickable(onClick=tap{nav.route(file.optString("link"))}),headlineContent={Text(file.optString("name"))},supportingContent={Text(file.optString("sizeText",file.optString("size")))},leadingContent={Icon(Icons.Outlined.InsertDriveFile,null)},trailingContent={Menu(file,false)})}
                if(!busy&&failure.isEmpty()&&folders.isEmpty()&&files.isEmpty())item{Text("暂无文件",Modifier.padding(24.dp))}
                item{Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.End,verticalAlignment=Alignment.CenterVertically){TextButton(onClick={page--;scope.launch{load()}},enabled=!busy&&page>1){Text("上一页")};Text("$page / $maxPage");TextButton(onClick={page++;scope.launch{load()}},enabled=!busy&&page<maxPage){Text("下一页")}}}
            }
        }
        if(site.loggedIn)OriginalFab(onClick={if(!busy){if(config.optString("storageType")!="local")site.status="该云盘使用第三方存储，当前原生上传仅支持本地存储"else picker.launch(arrayOf("*/*"))}},modifier=Modifier.align(Alignment.BottomEnd).navigationBarsPadding().padding(16.dp)){Icon(Icons.Default.UploadFile,"上传文件")}
    }
    input?.let{(title,entry)->OriginalDialog(onDismissRequest={input=null},title={Text(title)},text={LaunchedEffect(Unit){inputFocus.requestFocus()};OriginalTextField(inputText,{inputText=it},modifier=Modifier.fillMaxWidth().focusRequester(inputFocus))},dismissButton={TextButton(onClick={input=null}){Text("取消")}},confirmButton={Button(onClick={val name=inputText.trim();input=null;if(name.isNotEmpty()){if(entry==null)perform(mapOf("ac" to "addClassName","addClassName" to name,"cid" to cid))else {val folder=entry.has("c_name");if(name!=entry.optString(if(folder)"c_name"else"name"))perform(mapOf("ac" to "reName","name" to name,"sid" to entry.optString(if(folder)"cid"else"id"),"pid" to entry.optString(if(folder)"pid"else"cid"),"type" to if(folder)"classify"else"file"))}}}){Text("确认")}})}
    deletion?.let{(entry,folder)->OriginalDialog(onDismissRequest={deletion=null},title={Text("删除云盘内容？")},text={Text(entry.optString(if(folder)"c_name"else"name"))},dismissButton={TextButton(onClick={deletion=null}){Text("取消")}},confirmButton={Button(onClick={deletion=null;perform(mapOf("ac" to "del",(if(folder)"cid[]"else"fid[]") to entry.optString(if(folder)"cid"else"id")))}){Text("删除")}})}
}
