package ycoo.net.php

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.text.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.*
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.*
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.*

@Composable fun SearchPage(site:Site,nav:Nav) {
    var query by rememberSaveable{mutableStateOf("")};var searched by remember{mutableStateOf(false)};var busy by remember{mutableStateOf(false)};var error by remember{mutableStateOf("")};var rows by remember{mutableStateOf(emptyList<Topic>())};var next by remember{mutableStateOf<String?>(null)}
    val scope=rememberCoroutineScope();val focus=LocalFocusManager.current;val requester=remember{FocusRequester()};var request by remember{mutableStateOf<Job?>(null)}
    fun search(append:Boolean=false){if(query.isBlank())return;focus.clearFocus();request?.cancel();request=scope.launch{busy=true;error="";searched=true;try{val b=site.batch("search:${query.trim()}",1,if(append)next else null);rows=if(append)(rows+b.topics).distinctBy{it.id}else b.topics;next=b.next}catch(e:Exception){if(e is CancellationException)throw e;error=e.message.orEmpty()}finally{busy=false}}}
    val title by rememberUpdatedState<@Composable ()->Unit>({OriginalTextField(query,{query=it},placeholder={Text("搜索源社区")},singleLine=true,modifier=Modifier.fillMaxWidth().focusRequester(requester),keyboardOptions=KeyboardOptions(imeAction=ImeAction.Search),keyboardActions=KeyboardActions(onSearch={search()}),colors=TextFieldDefaults.colors(focusedContainerColor=Color.Transparent,unfocusedContainerColor=Color.Transparent,focusedIndicatorColor=Color.Transparent,unfocusedIndicatorColor=Color.Transparent))})
    DisposableEffect(nav){nav.titleContent={title()};onDispose{nav.titleContent=null}}
    LaunchedEffect(Unit){requester.requestFocus()}
    PageActions(nav){IconButton(onClick=tap{search()}){Icon(Icons.Rounded.Search,"搜索")}}
    Box(Modifier.fillMaxSize().padding(top=LocalPageTop.current),contentAlignment=Alignment.Center){when{
        !searched->Text("输入关键词搜索帖子")
        busy->CircularProgressIndicator()
        error.isNotEmpty()->Failure(error,{search()})
        rows.isEmpty()->Column(horizontalAlignment=Alignment.CenterHorizontally){Text("暂无结果");TextButton(onClick={nav.route("/search.php?mod=forum")}){Text("打开原站搜索")}}
        else->LazyColumn(contentPadding=PaddingValues(12.dp)){items(rows,key={it.id}){TopicRow(site,it,nav)};if(next!=null)item{TextButton(onClick={search(true)},modifier=Modifier.fillMaxWidth()){Text("加载更多结果")}};item{TextButton(onClick={nav.route("/search.php?mod=forum")},modifier=Modifier.fillMaxWidth()){Text("更多搜索选项")}}}
    }}
}
@Composable fun HistoryPage(site:Site,nav:Nav){
    var rows by remember{mutableStateOf(site.history())};var confirm by remember{mutableStateOf(false)}
    PageActions(nav){IconButton(onClick=tap{confirm=true}){Icon(Icons.Outlined.DeleteOutline,"清空历史")}}
    if(rows.isEmpty())Box(Modifier.fillMaxSize().padding(top=LocalPageTop.current),contentAlignment=Alignment.Center){Text("还没有阅读记录")}else LazyColumn(contentPadding=PaddingValues(start=12.dp,top=LocalPageTop.current+12.dp,end=12.dp,bottom=12.dp)){items(rows,key={it.id}){TopicRow(site,it,nav)}}
    if(confirm)OriginalDialog(onDismissRequest={confirm=false},title={Text("清空阅读历史？")},text={Text("只清除此设备上的阅读记录。")},dismissButton={TextButton(onClick={confirm=false}){Text("取消")}},confirmButton={Button(onClick={confirm=false;site.prefs.edit().remove("history.${site.uid}").apply();rows=emptyList()}){Text("清空")}})
}
@Composable fun LicensesPage(nav:Nav,selected:Int?=null){
    val context=LocalContext.current
    val entries=remember{org.json.JSONArray(context.assets.open("licenses.json").bufferedReader().use{it.readText().removePrefix("\uFEFF")}).objects()}
    if(selected!=null){val item=entries.getOrNull(selected) ?: return
        androidx.compose.foundation.text.selection.SelectionContainer{Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(start=16.dp,top=LocalPageTop.current+16.dp,end=16.dp,bottom=24.dp)){Text(item.getString("name"),style=MaterialTheme.typography.titleLarge);Spacer(Modifier.height(16.dp));Text(item.getString("text"),style=MaterialTheme.typography.bodySmall)}}
    }else LazyColumn(contentPadding=PaddingValues(top=LocalPageTop.current,bottom=24.dp)){
        item{Column(Modifier.fillMaxWidth().padding(24.dp),horizontalAlignment=Alignment.CenterHorizontally){coil.compose.AsyncImage("file:///android_asset/site-icon.png",null,Modifier.size(72.dp));Spacer(Modifier.height(14.dp));Text("源社区",style=MaterialTheme.typography.headlineSmall);Text(BuildConfig.VERSION_NAME)}}
        items(entries.size){i->val item=entries[i];SiteListItem(modifier=Modifier.clickable(onClick=tap{nav.titles["license:$i"]=item.getString("name").substringBeforeLast(':');nav.open("license:$i")}),headlineContent={Text(item.getString("name").substringBeforeLast(':'))},supportingContent={Text(item.getString("license"))})}
    }
}