package ycoo.net.php

import android.content.Intent
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.platform.*
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.distinctUntilChanged
import org.json.JSONObject

@OptIn(ExperimentalMaterial3Api::class)
@Composable fun ThreadPage(site:Site,nav:Nav,tid:String) {
    var posts by remember {mutableStateOf(emptyList<JSONObject>())};var thread by remember {mutableStateOf(JSONObject())};var fid by remember {mutableStateOf("")}
    var purchaseRequired by remember {mutableStateOf(false)};var busy by remember {mutableStateOf(false)};var error by remember {mutableStateOf("")};var retryRefresh by remember {mutableStateOf(false)};var page by remember {mutableIntStateOf(0)};var more by remember {mutableStateOf(true)}
    val scope=rememberCoroutineScope();val ticket=site.epoch;val state=rememberLazyListState();val clipboard=LocalClipboardManager.current;val context=LocalContext.current
    suspend fun load(refresh:Boolean=false) {
        if(busy)return;busy=true;error=""
        try {coroutineScope {
            val p=if(refresh)1 else page+1
            val supplemental=async {try {site.request("/forum.php?mod=viewthread&tid=$tid&page=$p&mobile=2")}catch(e:Exception){if(e is CancellationException)throw e;null}}
            val query=mapOf("tid" to tid,"page" to "$p")
            val v=site.api("viewthread",if(refresh)query+("_session" to System.nanoTime().toString())else query)
            val nextThread=v.optJSONObject("thread")
            require(nextThread?.optString("tid")==tid){"站点返回的帖子与当前主题不匹配"}
            val batch=v.optJSONArray("postlist")?.objects().orEmpty()
            val requiresPurchase=v.optString("forum_threadpay")=="1"
            val html=withTimeoutOrNull(800){supplemental.await()};if(html==null)supplemental.cancel()else withContext(Dispatchers.Default){enrichThreadPosts(batch,html,!requiresPurchase)}
            site.assertEpoch(ticket);thread=nextThread;fid=v.optString("fid",thread.optString("fid"))
            if(p==1)purchaseRequired=requiresPurchase
            posts=((if(refresh)emptyList()else posts)+batch).distinctBy {it.optString("pid")};page=p;more=p*v.optInt("ppp",20)<thread.optInt("replies")+1
            site.remember(Topic(tid,thread.text("subject"),thread.text("author"),thread.optString("authorid"),fid=fid))
        }}catch(e:Exception){if(e is CancellationException)throw e;retryRefresh=refresh;error=e.message.orEmpty()}finally{busy=false}
    }
    fun compose(post:JSONObject?=null) {
        if(!site.loggedIn){nav.loginThen("editor:$fid:$tid:${post?.optString("pid").orEmpty()}");return};val pid=post?.optString("pid").orEmpty()
        if(post!=null)nav.titles["quote:$pid"]="引用 ${post.text("author")} · ${post.optString("number",post.optString("position"))} 楼"
        nav.open("editor:$fid:$tid:$pid")
    }
    LaunchedEffect(tid,nav.revisions["thread:$tid"]){load(posts.isNotEmpty())}
    val density=LocalDensity.current;val threshold=with(density){350.dp.toPx()}
    LaunchedEffect(state,posts.size,more,busy,error,site.settingsRevision){if(posts.isNotEmpty()&&more&&!busy&&error.isEmpty()&&site.prefs.getBoolean("autoReplies",true))snapshotFlow {
        val last=state.layoutInfo.visibleItemsInfo.lastOrNull();state.isScrollInProgress&&last!=null&&last.index>=state.layoutInfo.totalItemsCount-2&&last.offset+last.size-state.layoutInfo.viewportEndOffset<threshold
    }.distinctUntilChanged().collect {if(it)load()}}
    PageActions(nav) {
        IconButton(onClick=tap {if(!site.loggedIn)nav.open("login")else site.run {site.syncSession();site.api("favthread",mapOf("id" to tid,"favoritesubmit" to "true"),mapOf("formhash" to site.formhash,"description" to ""));site.status="已收藏到源社区"}}){Icon(Icons.Outlined.BookmarkBorder,"收藏")}
        var menu by remember {mutableStateOf(false)}
        Box {IconButton(onClick={menu=true}){Icon(Icons.Rounded.MoreVert,"更多操作")};DropdownMenu(menu,{menu=false}){
            listOf("复制链接","在原站查看","分享帖子","网页查找","电脑版").forEachIndexed {i,label->DropdownMenuItem(text={Text(label)},onClick={menu=false;val url="$ORIGIN/thread-$tid-1-1.html";when(i){0->{clipboard.setText(AnnotatedString(url));site.status="链接已复制"};2->context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT,url),"分享帖子"));else->nav.open("web:$url?mobile=${if(i==4)"no"else"2"}${if(i==3)"#compose-find"else""}")}})}
        }}
    }
    Column(Modifier.fillMaxSize()) {
        PullToRefreshBox(busy&&posts.isNotEmpty(),{scope.launch{load(true)}},Modifier.weight(1f)) {
            if(posts.isEmpty()&&busy)Box(Modifier.fillMaxSize(),contentAlignment=Alignment.Center){CircularProgressIndicator()}
            else LazyColumn(state=state,contentPadding=PaddingValues(start=12.dp,top=LocalPageTop.current+12.dp,end=12.dp,bottom=24.dp),verticalArrangement=Arrangement.Top) {
                item {Column(Modifier.padding(start=4.dp,end=4.dp,bottom=16.dp)) {
                    Text(thread.text("subject"),style=MaterialTheme.typography.headlineSmall.copy(fontWeight=FontWeight.SemiBold));Spacer(Modifier.height(12.dp));Text("${thread.text("views")} 阅读 · ${thread.text("replies")} 回复",style=MaterialTheme.typography.bodySmall,color=MaterialTheme.colorScheme.onSurfaceVariant)
                }}
                itemsIndexed(posts,key={_,p->p.optString("pid")}){i,p->OriginalCard(Modifier.fillMaxWidth().padding(bottom=12.dp),16.dp,elevation=0.dp){Column(Modifier.padding(12.dp)) {
                    Row(Modifier.fillMaxWidth().heightIn(min=72.dp).clickable(onClick=tap{nav.open("profile:${p.optString("authorid")}")}),verticalAlignment=Alignment.CenterVertically){
                        Box(Modifier.width(40.dp)){SiteAvatar(p.optString("authorid"),p.text("author"))};Spacer(Modifier.width(16.dp))
                        Column(Modifier.weight(1f)){Text(p.text("author"),fontSize=15.sp,lineHeight=20.25.sp,fontWeight=FontWeight.SemiBold);Text("${p.text("dateline")} · ${p.optString("number",p.optString("position","${i+1}"))} 楼"+listOf("displayLevel","displayCategory").map{p.text(it)}.filter{it.isNotEmpty()}.joinToString("",transform={" · $it"}),fontSize=12.5.sp,lineHeight=17.5.sp,color=MaterialTheme.colorScheme.onSurfaceVariant)}
                        IconButton(onClick=tap{compose(p)}){Icon(Icons.Outlined.Reply,"引用回复")}
                    }
                    val locked=purchaseRequired&&p.optString("first")=="1"
                    val body=remember(p,locked){forumPostHtml(p,locked)}
                    if(body.isNotBlank()){Spacer(Modifier.height(8.dp));Body(body,nav)}
                    if(locked) {
                        Spacer(Modifier.height(8.dp))
                        val price=thread.text("price").takeIf {(it.toIntOrNull() ?: 0)>0}
                        val count=p.optString("displayPayCount")
                        SectionCard {
                            Column(Modifier.padding(12.dp)) {
                                Text(listOfNotNull(count.takeIf(String::isNotBlank),price?.let{"支付 $it 星币后可浏览"} ?: "购买后可浏览").joinToString(" · "),style=MaterialTheme.typography.bodyMedium)
                                TextButton(
                                    enabled=!busy,
                                    modifier=Modifier.align(Alignment.End),
                                    onClick=tap {
                                        if(site.loggedIn)nav.open("native:$ORIGIN/forum.php?mod=misc&action=pay&tid=$tid&mobile=2")
                                        else nav.loginThen("thread:$tid")
                                    }
                                ) {Icon(Icons.Outlined.Lock,null);Spacer(Modifier.width(8.dp));Text(if(site.loggedIn)"购买主题"else"登录后购买")}
                            }
                        }
                    }
                    if(p.optString("displayCopyright").isNotEmpty()) {
                        Spacer(Modifier.height(8.dp))
                        Body(p.optString("displayCopyright"),nav)
                    }
                    if(hasForumFileAttachment(p,locked))TextButton(onClick=tap{nav.open("web:$ORIGIN/forum.php?mod=redirect&goto=findpost&ptid=$tid&pid=${p.optString("pid")}&mobile=2")}){Icon(Icons.Rounded.Attachment,null);Text("查看原站附件")}
                }}}
                if(error.isNotEmpty())item{Failure(error,{scope.launch{load(retryRefresh)}})}
                item {Box(Modifier.fillMaxWidth().padding(12.dp),contentAlignment=Alignment.Center){if(busy)CircularProgressIndicator()else if(more)TextButton(onClick={scope.launch{load()}}){Text("加载更多回复")}else Text("已显示全部可见内容",style=MaterialTheme.typography.bodySmall)}}
            }
        }
        Surface {Button(onClick=tap{compose()},modifier=Modifier.fillMaxWidth().navigationBarsPadding().padding(start=16.dp,top=8.dp,end=16.dp,bottom=8.dp)){Icon(Icons.Rounded.Reply,null);Spacer(Modifier.width(8.dp));Text("回复帖子")}}
    }
}
