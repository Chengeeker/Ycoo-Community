package ycoo.net.php

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.EventAvailable
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.*

data class SignData(val stats:List<String>,val label:String,val hash:String) {
    val signed get()=label.contains("已签")
    companion object {fun parse(source:String):SignData {val d=doc(source);return SignData(d.select(".comiis_qdinfo li").map{it.text().trim()},d.label("#signresult"),Regex("operation=qiandao[^\"\\s]*formhash=([a-zA-Z0-9]{8})").find(source)?.groupValues?.get(1) ?: Parse.webSession(source)?.optString("formhash").orEmpty())}}
}
@OptIn(ExperimentalMaterial3Api::class)
@Composable fun SignPage(site:Site,nav:Nav) {
    var data by remember {mutableStateOf<SignData?>(null)};var ranking by remember {mutableStateOf<NativeContent?>(null)};var ranks by remember {mutableStateOf(emptyList<Entry>())}
    var tab by remember {mutableIntStateOf(0)};var page by remember {mutableIntStateOf(1)};var busy by remember {mutableStateOf(false)};var error by remember {mutableStateOf("")};val scope=rememberCoroutineScope()
    suspend fun load() {if(busy)return;busy=true;error="";try {coroutineScope {
        val a=async {site.request("/k_misign-sign.html?mobile=2&_session=${System.nanoTime()}")};val url="/plugin.php?id=k_misign:sign&operation=${if(tab==3)"calendar"else"list"}&op=${listOf("today","month","zong","calendar")[tab]}&page=$page&mobile=2"
        val b=async {site.request(url)};val sa=a.await();val sb=b.await()
        withContext(Dispatchers.Default) {Triple(SignData.parse(sa),parseNative(sb,link(url).toString()),doc(sb).select("tbody[id^=autolist_]").mapNotNull {r->val name=r.label("h4 a");if(name.isEmpty())null else Entry(name,"$ORIGIN/space-uid-${r.id().removePrefix("autolist_")}.html",r.selectFirst("img")?.image().orEmpty(),r.label(".k_misign_lc").replaceFirst(name,""))})}.let {data=it.first;ranking=it.second;ranks=it.third}
    }}catch(e:Exception){if(e is CancellationException)throw e;error=e.message.orEmpty()}finally{busy=false}}
    LaunchedEffect(tab,page){load()}
    val tabHeight=filterTabHeight()
    HeaderTabs { OriginalTabs(listOf("今日榜","月榜","总榜","签到日历"),tab,true,height=tabHeight){if(!busy){tab=it;page=1}} }
    Column(Modifier.fillMaxSize()) {
        PullToRefreshBox(busy,{scope.launch{load()}}) {LazyColumn(contentPadding=PaddingValues(start=16.dp,top=LocalPageTop.current+tabHeight+16.dp,end=16.dp,bottom=16.dp)) {
            if(busy)item {LinearProgressIndicator(Modifier.fillMaxWidth())}
            if(error.isNotEmpty())item {Failure(error,{scope.launch{load()}})}
            item {SectionCard {Column(Modifier.fillMaxWidth().padding(16.dp),horizontalAlignment=Alignment.CenterHorizontally) {
                data?.stats?.forEach {Text(it,Modifier.padding(vertical=4.dp))};Spacer(Modifier.height(12.dp))
                Button(enabled=!busy&&data?.signed!=true,onClick=tap {
                    if(!site.loggedIn)nav.open("login")else {val hash=data?.hash.orEmpty();scope.launch{busy=true;try {require(hash.matches(Regex("[a-zA-Z0-9]{8}"))){"未能确认签到凭据，请刷新后重试"};site.status=plain(unwrap(site.request("/plugin.php?id=k_misign:sign&operation=qiandao&format=text&formhash=$hash&_session=${System.nanoTime()}&mobile=2")))}catch(e:Exception){if(e is CancellationException)throw e;site.status=e.message.orEmpty()}finally{busy=false};load()}}
                }) {Icon(Icons.Outlined.EventAvailable,null);Spacer(Modifier.width(8.dp));Text(if(data?.signed==true)"今日已签到"else if(site.loggedIn)"立即签到"else"登录后签到")}
            }}}
            items(ranks){r->SiteListItem(modifier=Modifier.clickable(onClick=tap{nav.route(r.url)}),headlineContent={Text(r.title)},supportingContent={Text(r.detail)},leadingContent={SiteAvatar(link(r.url)?.let(::profileId).orEmpty(),r.title,url=r.image)})}
            if(ranks.isEmpty())item {ranking?.let {Body(it.html,nav)}}
            item {Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.End){TextButton(onClick={page--},enabled=!busy&&page>1){Text("上一页")};Text("$page",Modifier.align(Alignment.CenterVertically));TextButton(onClick={page++},enabled=!busy){Text("下一页")}}}
        }}
    }
}
