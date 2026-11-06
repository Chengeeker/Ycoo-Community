package ycoo.net.php

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import org.json.JSONObject

@Composable fun FeedTabs(site:Site,nav:Nav,tabs:List<Pair<String,String>>,key:String) {
    val pref="tabs.${site.uid}.$key"
    var index by rememberSaveable {mutableIntStateOf(site.prefs.getInt(pref,if(key=="home")1 else 0).coerceIn(tabs.indices))}
    var following by rememberSaveable {mutableIntStateOf(site.prefs.getInt("$pref.following",0).coerceIn(0,2))}
    val selected=tabs[index].second
    val isFollowing=selected=="following"
    val view=if(isFollowing)listOf("following","following_forums","following_friends")[following] else selected
    val top=LocalPageTop.current
    val tabHeight=if(key=="home")48.dp else filterTabHeight()
    var checking by remember {mutableStateOf(false)}
    val scope=rememberCoroutineScope()
    fun select(i:Int) {scope.launch {
        if(tabs[i].second=="following" && !site.verified) {
            checking=true
            try {site.syncSession()} catch(e:Exception) {if(e is CancellationException) throw e;site.status=e.message.orEmpty();return@launch} finally {checking=false}
        }
        if(tabs[i].second=="following" && !site.loggedIn) {nav.open("login");return@launch}
        index=i;site.prefs.edit().putInt(pref,i).apply()
    }}
    HeaderTabs {
        OriginalTabs(tabs.map {it.first},index,scroll=key=="guide",height=tabHeight,divider=!isFollowing,onSelected=::select)
        if(isFollowing) OriginalTabs(listOf("我的关注","关注版块","好友动态"),following,secondary=true) {following=it;site.prefs.edit().putInt("$pref.following",it).apply()}
    }
    Box(Modifier.fillMaxSize()) {
        if(checking) Box(Modifier.fillMaxSize(),contentAlignment=Alignment.Center) {Column(horizontalAlignment=Alignment.CenterHorizontally) {CircularProgressIndicator();Spacer(Modifier.height(16.dp));Text("正在确认登录状态")}}
        else CompositionLocalProvider(LocalPageTop provides top+tabHeight+if(isFollowing)48.dp else 0.dp) {key(view) {FeedPage(site,nav,view)}}
    }
}

@Composable fun TopicRow(site:Site,topic:Topic,nav:Nav,followed:Boolean=false) {
    val s=MaterialTheme.colorScheme; val dark=LocalDark.current
    val origins=remember(topic.id){mutableMapOf<Int,androidx.compose.ui.geometry.Rect>()}
    val gallerySource=remember(topic.id,topic.images){Any()}
    val decoded=remember(topic.id,topic.images){mutableMapOf<Int,androidx.compose.ui.graphics.ImageBitmap>()}
    val previews=remember(topic.id,topic.images){topic.images.toMutableStateList()};val scope=rememberCoroutineScope()
    fun openImage(index:Int){
        if(nav.gallery?.closing==false)return
        val session=nav.showGallery(previews.toList(),index,previews.toList(),origins.toMap(),source=gallerySource,decoded=decoded.toMap())
        scope.launch {try{val originals=site.originals(topic.id);if(nav.gallery===session&&!session.closing)session.images=topic.images.mapIndexed {i,url->originals[thumbnailAid(url)] ?: previews[i]}}catch(e:Exception){if(e is CancellationException)throw e}}
    }
    val followColor=Color(if(dark)0xffffb45e else 0xff875000)
    val level=runCatching {Color(android.graphics.Color.parseColor(topic.levelColor))}.getOrDefault(Color(0xffff9900))
    val profileClick = if (topic.uid.isNotBlank() && topic.uid != "0") {
        Modifier.clickable(onClick = tap { nav.open("profile:${topic.uid}") })
    } else Modifier
    OriginalCard(Modifier.fillMaxWidth().padding(bottom=10.dp),radius=16.dp,elevation=0.dp) {
        Column(Modifier.clickable(onClick=tap {if(nav.gallery?.closing!=false){site.remember(topic);nav.open("thread:${topic.id}")}}).padding(start=12.dp,top=12.dp,end=12.dp,bottom=8.dp)) {
            Row(verticalAlignment=Alignment.CenterVertically) {
                Box(Modifier.size(48.dp).then(profileClick),contentAlignment=Alignment.Center) {SiteAvatar(topic.uid,topic.author,40.dp,topic.avatar)}
                Spacer(Modifier.width(6.dp))
                Column(Modifier.weight(1f).heightIn(min=48.dp),verticalArrangement=Arrangement.Center) {
                    Row(verticalAlignment=Alignment.CenterVertically) {
                        Text(topic.author.ifBlank {"作者信息暂不可用"},Modifier.weight(1f,false).then(profileClick),maxLines=2,overflow=TextOverflow.Ellipsis,style=MaterialTheme.typography.labelLarge.copy(lineHeight=16.8.sp))
                        if(topic.level.isNotEmpty()) {Spacer(Modifier.width(4.dp));Text(topic.level,Modifier.background(level,RoundedCornerShape(4.dp)).padding(horizontal=4.dp,vertical=1.dp),style=MaterialTheme.typography.labelSmall.copy(lineHeight=13.2.sp),color=if(level.luminance()>.179f)Color.Black else Color.White)}
                        if(topic.gender.isNotEmpty()) {Spacer(Modifier.width(4.dp));Icon(if(topic.gender=="male") Icons.Rounded.Male else Icons.Rounded.Female,if(topic.gender=="male")"男" else "女",Modifier.size(17.dp),tint=Color(if(topic.gender=="male"){if(dark)0xff80caff else 0xff0061a4}else{if(dark)0xffffb1c8 else 0xffac2f65}))}
                        if(topic.verificationIcon.isNotBlank()) {Spacer(Modifier.width(4.dp));SiteImage(topic.verificationIcon,topic.verificationLabel.ifBlank {"认证"},Modifier.size(18.dp))}
                    }
                    if(topic.time.isNotEmpty()) Text(topic.time,Modifier.padding(top=2.dp),style=MaterialTheme.typography.bodySmall.copy(lineHeight=14.4.sp),color=s.onSurfaceVariant)
                }
                if(topic.uid.isNotEmpty() && topic.uid!=site.uid) OutlinedButton(onClick=tap {if(!site.loggedIn)nav.open("login") else nav.open("profile:${topic.uid}")},modifier=Modifier.defaultMinSize(minWidth=48.dp,minHeight=32.dp),contentPadding=PaddingValues(horizontal=12.dp),shape=CircleShape,border=BorderStroke(1.dp,followColor),colors=ButtonDefaults.outlinedButtonColors(contentColor=followColor)) {Text(if(followed)"已关注" else "关注")}
            }
            Spacer(Modifier.height(6.dp))
            Row(verticalAlignment=Alignment.Top) {
                if(topic.pinned) {Text("置顶",Modifier.padding(top=2.dp,end=6.dp).background(s.errorContainer,RoundedCornerShape(4.dp)).padding(horizontal=4.dp,vertical=1.dp),style=MaterialTheme.typography.labelSmall,color=s.onErrorContainer)}
                Text(topic.title,Modifier.weight(1f),style=MaterialTheme.typography.titleMedium.copy(lineHeight=20.8.sp))
            }
            if(topic.preview.isNotEmpty()) Text(topic.preview,Modifier.padding(top=4.dp),maxLines=3,overflow=TextOverflow.Ellipsis,style=MaterialTheme.typography.bodyMedium,color=s.onSurfaceVariant)
            if(topic.images.isNotEmpty()) {
                Spacer(Modifier.height(12.dp));Row(Modifier.fillMaxWidth().height(if(topic.images.size==1)220.dp else 190.dp),horizontalArrangement=Arrangement.spacedBy(4.dp)) {
                    TopicThumbnail(site,topic,0,Modifier.weight(if(topic.images.size>=3)2f else 1f).fillMaxHeight().onGloballyPositioned{origins[0]=androidx.compose.ui.geometry.Rect(it.positionInRoot(),androidx.compose.ui.geometry.Size(it.size.width.toFloat(),it.size.height.toFloat()))},onSource={previews[0]=it},imageModifier=Modifier.gallerySource(nav,gallerySource,0),onDecoded={decoded[0]=it}) {openImage(0)}
                    if(topic.images.size>1) Column(Modifier.weight(1f).fillMaxHeight(),verticalArrangement=Arrangement.spacedBy(4.dp)) {
                        TopicThumbnail(site,topic,1,Modifier.weight(1f).fillMaxWidth().onGloballyPositioned{origins[1]=androidx.compose.ui.geometry.Rect(it.positionInRoot(),androidx.compose.ui.geometry.Size(it.size.width.toFloat(),it.size.height.toFloat()))},onSource={previews[1]=it},imageModifier=Modifier.gallerySource(nav,gallerySource,1),onDecoded={decoded[1]=it}) {openImage(1)}
                        if(topic.images.size>2) TopicThumbnail(site,topic,2,Modifier.weight(1f).fillMaxWidth().onGloballyPositioned{origins[2]=androidx.compose.ui.geometry.Rect(it.positionInRoot(),androidx.compose.ui.geometry.Size(it.size.width.toFloat(),it.size.height.toFloat()))},onSource={previews[2]=it},imageModifier=Modifier.gallerySource(nav,gallerySource,2),onDecoded={decoded[2]=it}) {openImage(2)}
                    }
                }
            }
            @OptIn(ExperimentalLayoutApi::class)
            FlowRow(horizontalArrangement=Arrangement.spacedBy(12.dp),verticalArrangement=Arrangement.Center) {
                if(topic.forum.isNotEmpty()) Text("# ${topic.forum}",Modifier.align(Alignment.CenterVertically).background(s.secondaryContainer,CircleShape).padding(8.dp,4.dp),style=MaterialTheme.typography.labelMedium,color=s.onSecondaryContainer)
                if(topic.likes.isNotEmpty()) TextButton(onClick=tap {nav.open("web:$ORIGIN/thread-${topic.id}-1-1.html?mobile=2")},contentPadding=PaddingValues(horizontal=4.dp),colors=ButtonDefaults.textButtonColors(contentColor=s.onSurfaceVariant)) {Icon(Icons.Outlined.ThumbUp,"点赞",Modifier.size(16.dp));Spacer(Modifier.width(4.dp));Text(topic.likes)}
                listOf(Triple(Icons.Outlined.ChatBubbleOutline,topic.replies,"回复"),Triple(Icons.Outlined.Visibility,topic.views,"阅读")).forEach { (icon,count,label)->if(count.isNotBlank()) Row(Modifier.heightIn(min=48.dp),verticalAlignment=Alignment.CenterVertically) {Icon(icon,label,Modifier.size(16.dp),tint=s.onSurfaceVariant);Spacer(Modifier.width(4.dp));Text(count,style=MaterialTheme.typography.bodySmall,color=s.onSurfaceVariant)}}
            }
        }
    }

}
@Composable fun TopicThumbnail(site:Site,topic:Topic,index:Int,modifier:Modifier,onSource:(String)->Unit={},imageModifier:Modifier=Modifier,onDecoded:(androidx.compose.ui.graphics.ImageBitmap)->Unit={},onOpen:()->Unit) {
    var source by remember(topic.images[index]) {mutableStateOf(topic.images[index])}; var failed by remember {mutableStateOf(false)}
    var repairing by remember {mutableStateOf(false)};var tried by remember {mutableStateOf(false)}; var revision by remember {mutableIntStateOf(0)}
    val scope=rememberCoroutineScope()
    Box(modifier.clip(RoundedCornerShape(10.dp)).background(MaterialTheme.colorScheme.surfaceContainerHighest).clickable(onClick=tap {if(failed){revision++;failed=false;tried=false}else onOpen()}),contentAlignment=Alignment.Center) {
        key(source,revision) {SiteImage(source,"帖子图片",Modifier.fillMaxSize().then(imageModifier),onSuccess={(it as? android.graphics.drawable.BitmapDrawable)?.bitmap?.let{bitmap->onDecoded(bitmap.asImageBitmap())}},onError={e->
            val status=(e as? coil.network.HttpException)?.response?.code
            val aid=thumbnailAid(source)
            if(!tried && aid!=null && status in listOf(403,404,410)) {tried=true;repairing=true;scope.launch {try{val original=site.originals(topic.id)[aid];if(original!=null&&original!=source){source=original;onSource(original)}else failed=true}catch(e:Exception){if(e is CancellationException)throw e;failed=true}finally{repairing=false}}} else failed=true
        })}
        if(repairing)CircularProgressIndicator()
        else if(failed) Icon(Icons.Rounded.Refresh,"图片加载失败，点击重试")
        if(index==2&&topic.images.size>3)Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha=.45f)),contentAlignment=Alignment.Center){Text("+${topic.images.size-3}",color=Color.White,fontSize=24.sp)}
    }
}

@OptIn(kotlinx.coroutines.FlowPreview::class,ExperimentalMaterial3Api::class)
@Composable fun FeedPage(site:Site,nav:Nav,initial:String) {
    val active=LocalPageActive.current
    val filterKey="forum.filter.${site.uid}.${initial.split(':').getOrNull(1)}"
    var selectedType by rememberSaveable(initial) {mutableStateOf(site.prefs.getString(filterKey,initial.split(':').getOrNull(2).orEmpty())!!)}
    val view=if(initial.startsWith("forum:"))"forum:${initial.split(':')[1]}:$selectedType" else initial
    val feed=remember(site.uid,site.epoch,view) {site.feed(view)}
    val scope=rememberCoroutineScope(); val top=LocalPageTop.current
    val position="position.${site.uid}.$view"
    val list=key(view){rememberLazyListState(site.prefs.getInt("$position.index",0),site.prefs.getInt("$position.offset",0))}
    val forum=initial.startsWith("forum:")
    val tabHeight=filterTabHeight()
    val localTop=top+if(forum)tabHeight else 0.dp
    if(forum) {
        val types=mapOf("" to "全部")+feed.types
        val scroll=types.size>3 || LocalDensity.current.fontScale>1.2f || types.values.any{it.length>4}
        HeaderTabs {
            OriginalTabs(types.values.toList(),types.keys.indexOf(selectedType).coerceAtLeast(0),scroll=scroll,height=tabHeight) {
                selectedType=types.keys.elementAt(it)
                site.prefs.edit().putString(filterKey,selectedType).apply()
            }
        }
    }
    LaunchedEffect(feed) {if(feed.topics.isEmpty())feed.load()}
    LaunchedEffect(nav.revisions[initial]){if(nav.revisions[initial]!=null)feed.load(true)}
    DisposableEffect(feed,active) {val refresh={scope.launch {feed.load(true)}; Unit}; val scroll={scope.launch {list.animateScrollToItem(0)};Unit}; if(active){nav.refresh=refresh;nav.scrollTop=scroll}
        onDispose {if(nav.refresh===refresh)nav.refresh=null;if(nav.scrollTop===scroll)nav.scrollTop=null;feed.savePosition(list.firstVisibleItemIndex,list.firstVisibleItemScrollOffset)}
    }
    LaunchedEffect(list,feed) {snapshotFlow {list.firstVisibleItemIndex to list.firstVisibleItemScrollOffset}.debounce(300).collect {feed.savePosition(it.first,it.second)}}
    LaunchedEffect(list,feed) {snapshotFlow {list.isScrollInProgress && list.layoutInfo.visibleItemsInfo.lastOrNull()?.index?.let {it>=list.layoutInfo.totalItemsCount-3}==true}.collect {if(it && feed.topics.isNotEmpty() && feed.error.isEmpty())feed.load()}}
    PullToRefreshBox(isRefreshing=feed.busy && feed.topics.isNotEmpty(),onRefresh={scope.launch {feed.load(true)}},modifier=Modifier.fillMaxSize()) {
        LazyColumn(state=list,modifier=Modifier.fillMaxSize(),contentPadding=PaddingValues(top=localTop+if(view.startsWith("following"))0.dp else 12.dp,bottom=LocalPageBottom.current)) {
            if(feed.sections.isNotEmpty()) item {PortalSections(feed.sections,nav)}
            if(!view.startsWith("my:"))item {Spacer(Modifier.height(12.dp))}
            items(feed.topics,key={it.id}) {Box(Modifier.padding(horizontal=12.dp)) {TopicRow(site,it,nav,view=="following")}}
            if(feed.topics.isEmpty())item {
                Box(Modifier.fillMaxWidth().then(if(feed.sections.isEmpty())Modifier.fillParentMaxHeight()else Modifier.padding(24.dp)),contentAlignment=Alignment.Center) {
                    when {feed.busy->CircularProgressIndicator();feed.error.isNotEmpty()->Failure(feed.error,{scope.launch{feed.load(true)}});else->Text(if(view.startsWith("my:"))"暂无内容"else"暂无帖子")}
                }
            } else item {
                Box(Modifier.fillMaxWidth().padding(16.dp),contentAlignment=Alignment.Center) {
                    when {feed.error.isNotEmpty()->TextButton(onClick={scope.launch{feed.load()}}){Text("${feed.error} · ${if(view.startsWith("my:"))"重试"else"点击重试"}")};feed.busy->CircularProgressIndicator();feed.more->TextButton(onClick={scope.launch{feed.load()}}){Text("加载更多")};!view.startsWith("my:")->Text("已显示全部内容")}
                }
            }
        }
    }
}

