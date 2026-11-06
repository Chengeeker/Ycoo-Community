package ycoo.net.php

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.platform.*
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.IntOffset
import kotlinx.coroutines.*
import org.json.JSONObject

@OptIn(ExperimentalMaterial3Api::class,ExperimentalFoundationApi::class,ExperimentalLayoutApi::class)
@Composable fun ProfilePage(site:Site,nav:Nav,uid:String) {
    var user by remember {mutableStateOf<UserProfile?>(null)};var loading by remember {mutableStateOf(false)};var error by remember {mutableStateOf("")}
    var tab by remember {mutableIntStateOf(0)};var threadType by remember {mutableStateOf("thread")};var acting by remember {mutableStateOf(false)};var pending by remember {mutableStateOf<Pair<String,String>?>(null)}
    val contents=remember {mutableStateMapOf<String,List<Any>>()};val pages=remember {mutableMapOf<String,Int>()};val more=remember {mutableStateMapOf<String,Boolean>()};val contentBusy=remember {mutableStateMapOf<String,Boolean>()};val contentErrors=remember {mutableStateMapOf<String,String>()};val login=remember {mutableStateMapOf<String,Boolean>()}
    var qr by remember {mutableStateOf(false)};var medal by remember {mutableStateOf<JSONObject?>(null)};val scope=rememberCoroutineScope();val clipboard=LocalClipboardManager.current
    val kind=listOf("profile","thread","blog","album")[tab];val key=if(tab==1)"thread-$threadType"else kind
    fun path(section:String,type:String?=null)=site.url("/home.php",mapOf("mod" to "space","uid" to uid,"do" to section,"view" to "me","from" to "space","mobile" to "2")+(type?.let {mapOf("type" to it)} ?: emptyMap()))
    suspend fun load() {if(loading)return;loading=true;error="";try {user=site.userProfile(uid)}catch(e:Exception){if(e is CancellationException)throw e;error=e.message.orEmpty()}finally{loading=false}}
    suspend fun loadContent(refresh:Boolean=false) {
        val k=key;val section=kind;val type=threadType;val profile=user ?: return
        if(section=="profile"||contentBusy[k]==true)return
        contentBusy[k]=true;contentErrors.remove(k)
        try {val page=if(refresh)1 else (pages[k] ?: 0)+1;val source=site.request(site.url(path(section,if(section=="thread")type else null),mapOf("page" to "$page","_session" to System.nanoTime().toString())))
            val parsed=withContext(Dispatchers.Default) {val d=doc(source);val needsLogin=d.selectFirst("#loginform")!=null;val entries=if(needsLogin)emptyList()else profileEntries(source,section,profile,type=="reply")
                val message=d.label("#messagetext");require(needsLogin||entries.isNotEmpty()||message.isEmpty()){message}
                Triple(needsLogin,entries,d.selectFirst(".pg a.nxt,a[rel=next],.comiis_page a.nxt")!=null||(section=="thread"&&entries.size>=20))}
            login[k]=parsed.first;contents[k]=((if(refresh)emptyList()else contents[k].orEmpty())+parsed.second).distinctBy {if(it is Topic)it.id else (it as Entry).url};pages[k]=page;more[k]=parsed.third
        }catch(e:Exception){if(e is CancellationException)throw e;contentErrors[k]=e.message.orEmpty()}finally{contentBusy[k]=false}
    }
    fun interaction(action:String,title:String) {
        if(acting)return
        if(!site.loggedIn){nav.loginThen("profile:$uid");return};acting=true
        scope.launch {try {var uri=profileAction(site.request(path("profile")),uid,action)
            if(uri==null)uri=profileAction(site.request(site.url(path("profile"),mapOf("mobile" to "no","_session" to System.nanoTime().toString()))),uid,action)
            require(uri!=null){"站点未提供当前账号可用的${title}入口，请刷新资料后重试"}
            if(action=="pm")nav.open("web:$uri")else pending=title to uri
        }catch(e:Exception){if(e is CancellationException)throw e;site.status=e.message.orEmpty()}finally{acting=false}}
    }
    LaunchedEffect(uid,site.epoch,nav.revisions["profile:$uid"]){contents.clear();pages.clear();more.clear();login.clear();contentBusy.clear();contentErrors.clear();load();if(kind!="profile")loadContent(true)}
    LaunchedEffect(key,user!=null){if(user!=null&&kind!="profile"&&!contents.containsKey(key))loadContent()}
    PageActions(nav) {
        IconButton(onClick=tap {scope.launch{load();if(kind!="profile")loadContent(true)}},enabled=!loading){Icon(Icons.Rounded.Refresh,"刷新",Modifier.size(20.dp))}
        var menu by remember {mutableStateOf(false)}
        Box {IconButton(onClick={menu=true}){Icon(Icons.Rounded.MoreVert,"更多操作",Modifier.size(20.dp))};DropdownMenu(menu,{menu=false}){
            DropdownMenuItem(text={Text("复制主页链接")},onClick={menu=false;clipboard.setText(AnnotatedString("$ORIGIN/space-uid-$uid.html"));site.status="主页链接已复制"})
            DropdownMenuItem(text={Text("原站主页")},onClick={menu=false;nav.open("web:${path("profile")}")})
        }}
    }
    Column(Modifier.fillMaxSize().padding(top=LocalPageTop.current)) {
        val u=user
        if(u==null)Box(Modifier.weight(1f).fillMaxWidth(),contentAlignment=Alignment.Center){if(loading)CircularProgressIndicator()else Failure(error.ifBlank {"无法读取用户资料"},{scope.launch{load()}})}
        else {
            val list=rememberLazyListState()
            val profileBackdrop=rememberBackdrop()
            val tabHeight=maxOf(52.dp,with(LocalDensity.current){12.sp.toDp()}*1.2f+24.dp)
            PullToRefreshBox(isRefreshing=loading,onRefresh={scope.launch{load();if(kind!="profile")loadContent(true)}},modifier=Modifier.weight(1f)) {
                LazyColumn(state=list,modifier=Modifier.recordBackdrop(profileBackdrop),contentPadding=PaddingValues(bottom=24.dp)) {
                    item {Box(Modifier.fillMaxWidth().heightIn(min=224.dp)) {
                        Box(Modifier.matchParentSize().background(MaterialTheme.colorScheme.primaryContainer)){if(u.cover.isNotEmpty())SiteImage(u.cover,null,Modifier.fillMaxSize())}
                        Box(Modifier.matchParentSize().background(Brush.verticalGradient(listOf(Color.Black.copy(alpha=.26f),Color.Black.copy(alpha=.85f)))))
                        Column(Modifier.padding(16.dp)) {
                            SiteAvatar(uid,u.name,64.dp,u.avatar);Spacer(Modifier.height(12.dp));Text(u.name,fontSize=24.sp,fontWeight=FontWeight.SemiBold,color=Color.White);Spacer(Modifier.height(4.dp))
                            Row {listOf(Triple("人气","views",""),Triple("关注","following","following"),Triple("粉丝","follower","follower")).forEach {(label,count,action)->
                                Box(Modifier.weight(1f).heightIn(min=48.dp).then(if(action.isNotEmpty())Modifier.clickable(onClick=tap {nav.open("web:$ORIGIN/home.php?mod=follow&do=$action&uid=$uid")})else Modifier).padding(vertical=4.dp),contentAlignment=Alignment.CenterStart){
                                    Text(if(with(LocalDensity.current){13.sp.toDp()}>18.dp)"${u.count(count)}\n$label"else"${u.count(count)} $label",color=Color.White,fontSize=13.sp,lineHeight=15.6.sp,fontWeight=FontWeight.Normal)
                                }
                            }}
                            FlowRow(horizontalArrangement=Arrangement.spacedBy(8.dp),verticalArrangement=Arrangement.spacedBy(4.dp)) {
                                if(u.level.isNotEmpty()) {val levelColor=runCatching{Color(android.graphics.Color.parseColor(u.levelColor))}.getOrDefault(MaterialTheme.colorScheme.primaryContainer);Surface(modifier=Modifier.align(Alignment.CenterVertically),shape=RoundedCornerShape(8.dp),color=levelColor){Text(u.level,Modifier.padding(12.dp,6.dp),fontSize=12.sp,lineHeight=14.4.sp,color=if(levelColor.luminance()>.179f)Color.Black else Color.White)}}
                                if(u.group.isNotEmpty())Surface(
                                    modifier=Modifier.align(Alignment.CenterVertically),
                                    shape=RoundedCornerShape(8.dp),
                                    color=Color.Transparent,
                                    contentColor=Color.White,
                                    border=BorderStroke(1.dp,Color.White.copy(alpha=.65f))
                                ){Text(u.group,Modifier.padding(12.dp,6.dp),fontSize=12.sp,lineHeight=14.4.sp)}
                                if(uid!=site.uid)FilledTonalButton(onClick=tap{interaction("follow",if(u.followed)"取消关注"else"关注")},enabled=!acting,contentPadding=PaddingValues(12.dp,4.dp),modifier=Modifier.align(Alignment.CenterVertically).heightIn(min=32.dp)){Text(if(u.followed)"已关注"else"关注",fontSize=12.sp)}
                            }
                        }
                    }}
                    stickyHeader {Spacer(Modifier.fillMaxWidth().height(tabHeight))}
                    if(error.isNotEmpty())item {TextButton(onClick={scope.launch{load()}},modifier=Modifier.fillMaxWidth()){Text("$error · 重试")}}
                    if(tab==0)item {Column(Modifier.padding(start=16.dp,top=8.dp,end=16.dp)) {
                        ProfileDetail("认证信息",u.verification.ifBlank {"暂无认证"})
                        SiteListItem(headlineContent={Text("勋章荣誉")},trailingContent={TextButton(onClick=tap{nav.route("/home.php?mod=medal")}){Text("勋章中心")}})
                        if(u.medals.isEmpty())Text("暂无勋章",Modifier.padding(horizontal=16.dp))else FlowRow(horizontalArrangement=Arrangement.spacedBy(4.dp),verticalArrangement=Arrangement.spacedBy(4.dp)){u.medals.forEach {m->Box(Modifier.size(48.dp,56.dp).clickable(onClick=tap{medal=m}).padding(6.dp)){SiteImage(m.text("image"),m.text("name"),Modifier.fillMaxSize(),scale=androidx.compose.ui.layout.ContentScale.Fit)}}}
                        ProfileDetail("个人签名",u.signature.ifBlank {"这家伙很懒，什么也没留下…"})
                        ProfileDetail("二维码","分享 TA 的个人主页",onClick={qr=true},trailing={Icon(Icons.Rounded.QrCode2,null)})
                        OriginalDivider()
                        val metrics=listOf(Triple("帖子","threads",Icons.Outlined.Article),Triple("回复","replies",Icons.Outlined.Forum),Triple("好友","friends",Icons.Outlined.People),Triple("粉丝","follower",Icons.Outlined.Person),Triple("日志","blogs",Icons.Outlined.Book),Triple("相册","albums",Icons.Outlined.PhotoLibrary),Triple("心情","doings",Icons.Outlined.Mood),Triple("人气","views",Icons.Outlined.Visibility))
                        metrics.chunked(4).forEachIndexed {row,items->Row {items.forEachIndexed {col,(label,count,icon)->val i=row*4+col
                            Column(Modifier.weight(1f).clickable(onClick=tap{when(i){0->{threadType="thread";tab=1};1->{threadType="reply";tab=1};2->nav.open("web:${path("friend")}");3->nav.open("web:$ORIGIN/home.php?mod=follow&do=follower&uid=$uid");4->tab=2;5->tab=3;6->nav.open("web:${path("doing")}");7->nav.route("${path("friend")}&view=visitor")}}).padding(horizontal=2.dp,vertical=10.dp),horizontalAlignment=Alignment.CenterHorizontally){Icon(icon,null,Modifier.size(22.dp),tint=listOf(MaterialTheme.colorScheme.primary,MaterialTheme.colorScheme.secondary,MaterialTheme.colorScheme.tertiary)[i%3]);Spacer(Modifier.height(6.dp));Text(label,fontSize=12.sp,lineHeight=14.4.sp);Text(u.count(count),fontSize=12.sp,lineHeight=14.4.sp)}
                        }}}
                        OriginalDivider()
                        val credits=listOf("积分" to u.count("credits"))+u.credits.keys().asSequence().mapNotNull {id->u.credits.optJSONObject(id)?.let {it.text("title") to u.count("extcredits$id")}}.toList()
                        credits.chunked(2).forEach {row->Row {row.forEach {(label,value)->SiteListItem(modifier=Modifier.weight(1f),headlineContent={Text(label)},supportingContent={Text(value,style=MaterialTheme.typography.titleLarge,color=MaterialTheme.colorScheme.primary)})};if(row.size==1)Spacer(Modifier.weight(1f))}}
                        OriginalDivider();ProfileDetail("用户ID",uid);ProfileDetail("在线时间",u.space.text("oltime").let {if(it.isBlank())""else"$it 小时"});ProfileDetail("注册时间",u.space.text("regdate"));ProfileDetail("最后访问",u.space.text("lastvisit"))
                    }} else {
                        if(tab==1)item {Row(Modifier.padding(horizontal=16.dp)){listOf("thread" to "主题","reply" to "回复").forEach {(type,label)->TextButton(onClick={threadType=type},enabled=contentBusy[key]!=true){Text(label,fontWeight=if(threadType==type)FontWeight.Bold else FontWeight.Normal)}}}}
                        if(login[key]==true)item {Button(onClick={nav.open("login")},modifier=Modifier.padding(16.dp)){Icon(Icons.Rounded.Login,null);Text("登录后查看")}}
                        val entries=contents[key].orEmpty()
                        if(entries.isEmpty()&&contentBusy[key]!=true&&login[key]!=true&&contentErrors[key]==null)item {Box(Modifier.fillMaxWidth().padding(32.dp),contentAlignment=Alignment.Center){Text("暂无可见内容")}}
                        items(entries){entry->Box(Modifier.padding(horizontal=16.dp)){when(entry){is Topic->TopicRow(site,entry,nav);is Entry->SiteListItem(modifier=Modifier.clickable(onClick=tap{nav.route(entry.url)}),headlineContent={Text(entry.title)},leadingContent={if(entry.image.isEmpty())Icon(if(tab==3)Icons.Outlined.PhotoLibrary else Icons.Outlined.Book,null)else SiteImage(entry.image,null,Modifier.size(56.dp))},trailingContent={Icon(Icons.Rounded.ChevronRight,null)})}}}
                        if(contentErrors[key]!=null)item {TextButton(onClick={scope.launch{loadContent(entries.isEmpty())}},modifier=Modifier.fillMaxWidth()){Text("${contentErrors[key]} · 重试")}}
                        if(contentBusy[key]==true)item {Box(Modifier.fillMaxWidth().padding(20.dp),contentAlignment=Alignment.Center){CircularProgressIndicator()}}else if(more[key]==true)item {TextButton(onClick={scope.launch{loadContent()}}){Text("加载更多")}}
                    }
                }
                CompositionLocalProvider(LocalBackdrop provides profileBackdrop) {
                    FrostedHeader(Modifier.offset {IntOffset(0,list.layoutInfo.visibleItemsInfo.firstOrNull{it.index==1}?.offset?.coerceAtLeast(0) ?: if(list.firstVisibleItemIndex==0)list.layoutInfo.viewportEndOffset else 0)},color=MaterialTheme.colorScheme.surface,materialAlpha=0f) {
                        SecondaryTabRow(tab,containerColor=Color.Transparent) {
                            listOf("资料" to Icons.Outlined.Badge,"帖子" to Icons.Outlined.Article,"日志" to Icons.Outlined.Book,"相册" to Icons.Outlined.PhotoLibrary).forEachIndexed {i,(label,icon)->
                                Tab(selected=tab==i,onClick=tap{tab=i},modifier=Modifier.height(tabHeight),selectedContentColor=MaterialTheme.colorScheme.onSurface,unselectedContentColor=MaterialTheme.colorScheme.onSurfaceVariant) {
                                    Icon(icon,null,Modifier.size(18.dp));Spacer(Modifier.height(2.dp));Text(label,fontSize=12.sp,lineHeight=14.4.sp,fontWeight=FontWeight.Normal)
                                }
                            }
                        }
                    }
                }
            }
            if(uid!=site.uid)Surface(color=MaterialTheme.colorScheme.surfaceContainer){Row(Modifier.fillMaxWidth().navigationBarsPadding().padding(vertical=6.dp)){listOf(Triple("friend","加好友",Icons.Outlined.PersonAdd),Triple("poke","打招呼",Icons.Outlined.WavingHand),Triple("pm","聊聊天",Icons.Outlined.Chat),Triple("block","拉黑",Icons.Outlined.Block)).forEach {(action,label,icon)->TextButton(onClick=tap{interaction(action,label)},enabled=!acting,modifier=Modifier.weight(1f).heightIn(min=48.dp),contentPadding=PaddingValues(2.dp,6.dp)){Column(horizontalAlignment=Alignment.CenterHorizontally){Icon(icon,null,Modifier.size(18.dp));Spacer(Modifier.height(4.dp));Text(label,fontSize=12.sp)}}}}}
        }
    }
    pending?.let {(label,url)->OriginalDialog(onDismissRequest={pending=null},title={Text(label)},text={Text("确认对 ${user?.name ?: uid} 执行“$label”？")},dismissButton={TextButton(onClick={pending=null}){Text("取消")}},confirmButton={Button(onClick={pending=null;nav.route(url);nav.titles[nav.current]=label}){Text("继续")}})}
    if(qr)OriginalBottomSheet(onDismissRequest={qr=false}) {Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(24.dp),horizontalAlignment=Alignment.CenterHorizontally){Text(user?.name.orEmpty(),style=MaterialTheme.typography.titleLarge);Text("UID $uid");Spacer(Modifier.height(16.dp));Box(Modifier.background(Color.White).padding(12.dp)){QrCode("$ORIGIN/space-uid-$uid.html","个人主页二维码",Modifier.width(220.dp))};Spacer(Modifier.height(12.dp));Text("扫码查看个人主页");TextButton(onClick={clipboard.setText(AnnotatedString("$ORIGIN/space-uid-$uid.html"));site.status="主页链接已复制"}){Icon(Icons.Rounded.ContentCopy,null);Spacer(Modifier.width(8.dp));Text("复制主页链接")}}}
    medal?.let {m->OriginalDialog(onDismissRequest={medal=null},title={Text(m.text("name"))},text={Column(horizontalAlignment=Alignment.CenterHorizontally){SiteImage(m.text("image"),null,Modifier.size(72.dp),scale=androidx.compose.ui.layout.ContentScale.Fit);Spacer(Modifier.height(12.dp));Text(m.text("description").ifBlank {"站点授予的荣誉勋章"})}},confirmButton={TextButton(onClick={medal=null}){Text("关闭")}})}
}
@Composable fun ProfileDetail(label:String,value:String,onClick:(()->Unit)?=null,trailing:(@Composable ()->Unit)?=null) {
    val large=with(LocalDensity.current){14.sp.toDp()}>20.dp
    SiteListItem(modifier=if(onClick==null)Modifier else Modifier.clickable(onClick=tap(onClick)),headlineContent={if(large)Text(label)else Row {Text(label,Modifier.weight(2f));Spacer(Modifier.width(12.dp));Text(value.ifBlank {"暂无"},Modifier.weight(5f),textAlign=androidx.compose.ui.text.style.TextAlign.End,color=MaterialTheme.colorScheme.onSurfaceVariant)}},supportingContent=if(large){{Text(value.ifBlank {"暂无"})}}else null,trailingContent=trailing)
}

