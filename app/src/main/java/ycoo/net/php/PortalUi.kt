package ycoo.net.php

import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.pager.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.*
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import kotlinx.coroutines.*
import org.json.JSONObject

private val portalSectionGap = 12.dp
private val portalHeadingGap = 8.dp
private val portalRankRowMinHeight = 44.dp

@Composable fun PortalSections(sections:Map<String,List<Entry>>,nav:Nav) {
    val banners=sections["推荐"].orEmpty();val services=sections["快捷服务"].orEmpty();val forums=sections["热门版块"].orEmpty();val ranks=sections["七日排行"].orEmpty();val pins=sections["置顶"].orEmpty()
    Column(Modifier.padding(start=16.dp,top=portalSectionGap,end=16.dp)) {
        if(banners.isNotEmpty()) PortalCarousel(banners,nav)
        if(services.isNotEmpty()) {
            if(banners.isNotEmpty()) Spacer(Modifier.height(portalSectionGap))
            OriginalCard(Modifier.fillMaxWidth()) {SiteListItem(modifier=Modifier.clickable(onClick=tap {nav.route(sections["公告"]?.firstOrNull()?.url ?: "$ORIGIN/forum-42-1.html")}),headlineContent={Text("公告")},supportingContent=sections["公告"]?.firstOrNull()?.let{{Text(it.title)}},leadingContent={Icon(Icons.Outlined.Campaign,null)},trailingContent={Icon(Icons.Rounded.ChevronRight,null)})}
            val labelHeight = with(LocalDensity.current) { MaterialTheme.typography.labelMedium.lineHeight.toDp() }
            val shortcutHeight = maxOf(76.dp, 46.dp + labelHeight * 2)
            Spacer(Modifier.height(portalSectionGap))
            FixedGrid(services,5,shortcutHeight) {e->
                val icon=when(e.title){"每日签到"->Icons.Outlined.EventAvailable;"开心农场"->Icons.Outlined.Agriculture;"心情墙"->Icons.Outlined.Mood;"云盘"->Icons.Outlined.Cloud;else->Icons.Outlined.CollectionsBookmark}
                Column(Modifier.fillMaxSize().clip(RoundedCornerShape(16.dp)).clickable(onClick=tap {nav.route(e.url)}),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.Center) {
                    Surface(shape=CircleShape,color=MaterialTheme.colorScheme.primaryContainer,modifier=Modifier.size(40.dp)) {Box(contentAlignment=Alignment.Center) {Icon(icon,null,tint=MaterialTheme.colorScheme.onPrimaryContainer)}}
                    Spacer(Modifier.height(6.dp));Text(e.title,style=MaterialTheme.typography.labelMedium)
                }
            }
        }
        if(forums.isNotEmpty()) {
            PortalHeading(if(services.isEmpty())"热门圈子" else "热门板块") {if(services.isEmpty())nav.open("web:$ORIGIN/group.php?mobile=2") else nav.selectRoot?.invoke(1)}
            FixedGrid(forums,4,92.dp) {e->Column(Modifier.fillMaxSize().clip(RoundedCornerShape(16.dp)).clickable(onClick=tap {nav.route(e.url)}),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.Center) {
                SiteImage(e.image,null,Modifier.size(46.dp).clip(RoundedCornerShape(12.dp)),fallback=true);Spacer(Modifier.height(8.dp));Text(e.title,maxLines=1,overflow=TextOverflow.Ellipsis,style=MaterialTheme.typography.labelLarge)
            }}
        }
        if(ranks.isNotEmpty()) {PortalHeading("七日排行榜"); OriginalCard(Modifier.fillMaxWidth()) {Column {
            ranks.forEachIndexed {i,e->Row(Modifier.fillMaxWidth().heightIn(min=portalRankRowMinHeight).clickable(onClick=tap {nav.route(e.url)}).padding(horizontal=12.dp,vertical=6.dp),verticalAlignment=Alignment.CenterVertically) {
                Text("${i+1}",Modifier.width(22.dp),style=MaterialTheme.typography.titleMedium);Spacer(Modifier.width(8.dp));Text(e.title,Modifier.weight(1f),maxLines=1,overflow=TextOverflow.Ellipsis,fontSize=15.sp,fontWeight=FontWeight.SemiBold);Spacer(Modifier.width(8.dp));Text(e.detail,style=MaterialTheme.typography.bodySmall)
            }}
        }}}
        if(pins.isNotEmpty()) {PortalHeading("置顶区");BoxWithConstraints {
            val columns=kotlin.math.ceil(maxWidth.value/280).toInt().coerceAtLeast(1)
            FixedGrid(pins,columns,64.dp*(with(androidx.compose.ui.platform.LocalDensity.current){14.sp.toDp().value}/14).coerceAtLeast(1f),horizontal=12.dp,vertical=8.dp) {e->OriginalCard(Modifier.fillMaxSize(),radius=16.dp) {Row(Modifier.fillMaxSize().clickable(onClick=tap {nav.route(e.url)}).padding(8.dp),verticalAlignment=Alignment.CenterVertically) {
                SiteImage(e.image,null,Modifier.size(48.dp).clip(RoundedCornerShape(8.dp)),fallback=true);Spacer(Modifier.width(8.dp));Column(Modifier.weight(1f)) {Text(e.title,maxLines=1,overflow=TextOverflow.Ellipsis,style=MaterialTheme.typography.bodyMedium);Text(e.detail,maxLines=1,overflow=TextOverflow.Ellipsis,style=MaterialTheme.typography.bodySmall)}
            }}}
        }}
        PortalHeading("社区动态")
    }
}
@Composable fun PortalHeading(title:String,more:(()->Unit)?=null) {
    Row(Modifier.fillMaxWidth().padding(top=portalSectionGap,bottom=portalHeadingGap),verticalAlignment=Alignment.CenterVertically) {Text(title,Modifier.weight(1f),style=MaterialTheme.typography.titleMedium);if(more!=null)TextButton(onClick=tap(more)) {Text("全部")}}
}
@Composable fun <T> FixedGrid(values:List<T>,columns:Int,height:androidx.compose.ui.unit.Dp,horizontal:androidx.compose.ui.unit.Dp=0.dp,vertical:androidx.compose.ui.unit.Dp=0.dp,content:@Composable (T)->Unit) {
    Column(verticalArrangement=Arrangement.spacedBy(vertical)) {values.chunked(columns).forEach {row-> Row(Modifier.fillMaxWidth().height(height),horizontalArrangement=Arrangement.spacedBy(horizontal)) {
        row.forEach {value->Box(Modifier.weight(1f).fillMaxHeight()) {content(value)}};repeat(columns-row.size) {Spacer(Modifier.weight(1f))}
    }}}
}
@Composable fun PortalCarousel(entries:List<Entry>,nav:Nav) {
    val pager=rememberPagerState(pageCount={entries.size});val lifecycle=LocalLifecycleOwner.current.lifecycle
    val active=LocalPageActive.current
    var touched by remember {mutableLongStateOf(0L)}
    LaunchedEffect(entries,active) {if(active)while(true){delay(5000);if(lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED) && !pager.isScrollInProgress && System.currentTimeMillis()-touched>8000 && entries.size>1)pager.animateScrollToPage((pager.currentPage+1)%entries.size,animationSpec=tween(350,easing=CubicBezierEasing(.215f,.61f,.355f,1f)))}}
    Box(Modifier.fillMaxWidth().aspectRatio(2f).clip(RoundedCornerShape(20.dp)).pointerInput(Unit) {awaitPointerEventScope {while(true){awaitPointerEvent();touched=System.currentTimeMillis()}}}) {
        HorizontalPager(pager,Modifier.fillMaxSize()) {i->val e=entries[i]
            Box(Modifier.fillMaxSize().clickable(onClick=tap {nav.route(e.url)})) {
                SiteImage(e.image,null,Modifier.fillMaxSize(),fallback=true);Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color.Transparent,Color.Black.copy(alpha=.87f)))))
                Column(Modifier.align(Alignment.BottomStart).padding(start=14.dp,end=14.dp,bottom=16.dp)) {
                    Row(verticalAlignment=Alignment.CenterVertically) {SiteAvatar("",e.author,24.dp,e.avatar);Spacer(Modifier.width(6.dp));Text(e.author,color=Color.White,fontSize=12.sp)}
                    Spacer(Modifier.height(6.dp));Text(e.title,color=Color.White,fontSize=17.sp,fontWeight=FontWeight.SemiBold,maxLines=2,overflow=TextOverflow.Ellipsis);Text(e.detail,color=Color.White.copy(alpha=.7f),fontSize=11.sp)
                }
            }
        }
        Text("${pager.currentPage+1} / ${entries.size}",Modifier.align(Alignment.TopEnd).padding(end=12.dp,top=10.dp).background(Color.Black.copy(alpha=.54f),CircleShape).padding(8.dp,4.dp),fontSize=11.sp,color=Color.White)
    }
}

@Composable fun ForumsPage(site:Site,nav:Nav) {
    val cache="cache.${site.uid}.forums"
    var data by remember {mutableStateOf(runCatching {JSONObject(site.prefs.getString(cache,"{}")!!)}.getOrDefault(JSONObject()))}
    var error by remember {mutableStateOf("")};var busy by remember {mutableStateOf(false)}
    var selected by rememberSaveable {mutableIntStateOf(site.prefs.getInt("community.${site.uid}",0))}
    val scope=rememberCoroutineScope();val top=LocalPageTop.current;val tabHeight=filterTabHeight()
    suspend fun load() {if(busy)return;busy=true;error="";val ticket=site.epoch
        try {
            val v=site.api("forumindex")
            val statistics=try {doc(site.request("/forum.php?forumlist=1&mobile=2")).select(".comiis_forum_tj li").associate {it.label("span") to it.label("em")}.filter {it.key.isNotBlank() && it.value.isNotBlank()}} catch(e:Exception) {if(e is CancellationException)throw e;emptyMap()}
            site.assertEpoch(ticket);v.put("statistics",JSONObject(statistics));data=v;site.prefs.edit().putString(cache,v.toString()).apply()
        }catch(e:Exception){if(e is CancellationException)throw e;error=e.message.orEmpty()}finally{busy=false}
    }
    LaunchedEffect(Unit) {if(data.optJSONArray("forumlist")==null)load()}
    val active=LocalPageActive.current
    DisposableEffect(active,selected) {val refresh={scope.launch {load()};Unit};if(active&&selected==0)nav.refresh=refresh;onDispose {if(nav.refresh===refresh)nav.refresh=null}}
    val roots=data.optJSONArray("forumlist")?.objects().orEmpty()
    val all=(roots+roots.flatMap {it.optJSONArray("sublist")?.objects().orEmpty()}).distinctBy {it.optString("fid")}
    val categories=data.optJSONArray("catlist")?.objects().orEmpty()
    val groups=linkedMapOf<String,List<JSONObject>>()
    categories.forEach {cat->val ids=cat.optJSONArray("forums");groups[cat.text("name")]=all.filter {f->ids!=null && (0 until ids.length()).any {ids.optString(it)==f.optString("fid")}}}
    val known=groups.values.flatten().map {it.optString("fid")}.toSet()
    val other=all.filter {it.optString("fid") !in known}
    if(other.isNotEmpty())groups[""]=groups[""].orEmpty()+other
    HeaderTabs {
        OriginalTabs(listOf("版区","新帖","精选","热门"),selected,height=tabHeight) {selected=it;site.prefs.edit().putInt("community.${site.uid}",it).apply()}
    }
    Box(Modifier.fillMaxSize()) {
        if(selected>0)CompositionLocalProvider(LocalPageTop provides top+tabHeight) {FeedPage(site,nav,listOf("newthread","digest","hot")[selected-1])}
        else LazyColumn(contentPadding=PaddingValues(top=top+tabHeight+12.dp,bottom=LocalPageBottom.current)) {
            item {OriginalCard(Modifier.padding(horizontal=26.dp,vertical=5.dp).fillMaxWidth()) {
                val stats=data.optJSONObject("statistics")
                val values=if(stats!=null && stats.length()>0)stats.keys().asSequence().map {it to stats.optString(it)}.toList() else listOf("今日新帖" to roots.sumOf {it.optInt("todayposts")}.toString(),"主题" to roots.sumOf {it.optInt("threads")}.toString(),"帖子" to roots.sumOf {it.optInt("posts")}.toString())
                Column(Modifier.padding(vertical=8.dp)) {Row(Modifier.fillMaxWidth()) {values.forEach {(label,value)->Column(Modifier.weight(1f),horizontalAlignment=Alignment.CenterHorizontally) {Text(label,style=MaterialTheme.typography.labelMedium,color=MaterialTheme.colorScheme.onSurfaceVariant);Spacer(Modifier.height(4.dp));Text(value,style=MaterialTheme.typography.titleMedium)}}}}
            }}
            groups.filterValues { it.isNotEmpty() }.forEach { (name, forums) -> item(key="forum-group:$name") {
                val hasHeading = name.isNotBlank() && name != "全部版块"
                var expanded by rememberSaveable(name) { mutableStateOf(true) }
                if(hasHeading) Preference(name,onClick={expanded=!expanded},trailing={Icon(if(expanded)Icons.Rounded.ExpandLess else Icons.Rounded.ExpandMore,null)})
                if(expanded || !hasHeading) BoxWithConstraints(Modifier.padding(horizontal=16.dp).padding(bottom=8.dp)) {
                    val columns = if(maxWidth>=808.dp) 4 else 2
                    Column(verticalArrangement=Arrangement.spacedBy(8.dp)) {
                        forums.chunked(columns).forEach { row ->
                            Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min), horizontalArrangement=Arrangement.spacedBy(8.dp)) {
                                row.forEach { forum -> ForumBoardCard(forum,nav,Modifier.weight(1f).fillMaxHeight()) }
                                repeat(columns-row.size) { Spacer(Modifier.weight(1f)) }
                            }
                        }
                    }
                }
            }}
            if(error.isNotEmpty())item {Failure(error,{scope.launch {load()}})}
            if(busy)item {Box(Modifier.fillMaxWidth().padding(24.dp),contentAlignment=Alignment.Center) {CircularProgressIndicator()}}
        }
    }
}

@Composable private fun ForumBoardCard(forum:JSONObject, nav:Nav, modifier:Modifier) {
    val name = forum.text("name")
    val today = forum.optLong("todayposts")
    val posts = forum.optLong("posts", -1L).takeIf { it >= 0 }
    val count = if(today > 0) "今日: $today" else "帖数: ${posts ?: "—"}"
    val colors = MaterialTheme.colorScheme
    val countColor = if(today <= 0) colors.onSurfaceVariant else if(LocalDark.current) Color(0xffffa333) else Color(0xff9a4b00)
    val icon = link(forum.text("icon"))?.toString().orEmpty()
    var iconFailed by remember(icon) { mutableStateOf(icon.isEmpty()) }
    OriginalCard(modifier, radius=16.dp, elevation=0.dp) {
        Row(Modifier.fillMaxWidth().heightIn(min=70.dp).clickable(onClick=tap {
            val route="forum:${forum.optString("fid")}"
            nav.titles[route]=name
            nav.open(route)
        }).padding(horizontal=10.dp,vertical=8.dp),verticalAlignment=Alignment.CenterVertically) {
            Box(Modifier.size(44.dp).clip(RoundedCornerShape(10.dp)).background(colors.secondaryContainer),contentAlignment=Alignment.Center) {
                if(!iconFailed)SiteImage(icon,null,Modifier.fillMaxSize(),onError={iconFailed=true})
                else Icon(Icons.Outlined.Forum,null,tint=colors.onSecondaryContainer)
            }
            Spacer(Modifier.width(8.dp))
            Column(Modifier.weight(1f)) {
                Text(name,maxLines=1,overflow=TextOverflow.Ellipsis,style=MaterialTheme.typography.bodyLarge,color=colors.onSurface)
                Text(count,style=MaterialTheme.typography.bodySmall,color=countColor)
            }
        }
    }
}

