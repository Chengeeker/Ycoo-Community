package ycoo.net.php

import android.os.Bundle
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.tween
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.compose.PredictiveBackHandler
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.*
import androidx.compose.ui.unit.*
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import coil.request.ImageRequest
import android.webkit.CookieManager
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import org.json.JSONObject

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { val site: Site = viewModel(); OriginalTheme(site) { CommunityApp(site) } }
    }
}

@Stable class Nav {
    internal class Page(val route: String) {
        val offset = Animatable(1f)
    }

    internal val pages = mutableStateListOf<Page>()
    internal var exiting by mutableStateOf<Page?>(null)
        private set
    val titles = mutableStateMapOf<String,String>()
    var actions by mutableStateOf<(@Composable ()->Unit)?>(null)
    val pageActions=mutableStateMapOf<String,@Composable ()->Unit>()
    var afterLogin:String?=null
    val revisions=mutableStateMapOf<String,Int>()
    fun invalidate(route:String){revisions[route]=(revisions[route] ?: 0)+1}
    fun loginThen(route:String){afterLogin=route;open("login")}
    var titleContent by mutableStateOf<(@Composable ()->Unit)?>(null)
    var blockBack = false
    var download by mutableStateOf<String?>(null)
    var external by mutableStateOf<String?>(null)
    var gallery by mutableStateOf<GallerySession?>(null)
    fun showGallery(images:List<String>,initial:Int=0,previews:List<String> = images,origins:Map<Int,androidx.compose.ui.geometry.Rect> = emptyMap(),coverOrigin:Boolean=true,source:Any?=null,decoded:Map<Int,androidx.compose.ui.graphics.ImageBitmap> = emptyMap()):GallerySession {
        gallery?.takeUnless{it.closing}?.let{return it}
        require(images.isNotEmpty())
        val previous=gallery
        val next=GallerySession(images,initial,previews,origins,coverOrigin,source,decoded)
        if(previous?.closing==true&&source!=null&&source===previous.source&&initial==previous.current)next.resumed=previous.snapshot?.invoke()
        gallery=next;return next
    }
    var refresh: (() -> Unit)? = null
    var scrollTop: (() -> Unit)? = null
    var selectRoot: ((Int) -> Unit)? = null
    val current get() = pages.lastOrNull()?.route.orEmpty()
    fun open(route: String) {
        if (current == route) return
        exiting = null
        pages.add(Page(route))
    }
    fun back() {
        if (!blockBack && pages.isNotEmpty()) exiting = pages.removeAt(pages.lastIndex)
    }
    internal fun finishExit(page: Page) {
        if (exiting === page) exiting = null
    }
    internal fun clearPages() {
        exiting = null
        pages.clear()
    }
    fun route(raw: String) {
        if(raw.trim().matches(Regex("javascript:\\s*(?:history\\.(?:back\\(\\)|go\\(-1\\))|window\\.history\\.back\\(\\));?",RegexOption.IGNORE_CASE))){back();return}
        val u = link(raw) ?: return
        val tid = threadId(u); val uid = profileId(u)
        when {
            isImageUrl(u.toString()) -> {showGallery(listOf(u.toString()))}
            isVideoUrl(u.toString()) -> open("video:$u")
            !u.isSite() -> {external=u.toString()}
            isDownloadUrl(u.toString()) -> {download=u.toString()}
            tid != null -> open("thread:$tid")
            uid != null -> open("profile:$uid")
            u.encodedPath=="/plugin.php" && u.queryParameter("id")=="bphp_clouds:index" -> open("cloud")
            u.isSite() && (u.encodedPath.startsWith("/forum-") || u.queryParameter("mod") == "forumdisplay") -> {
                val fid = Regex("forum-(\\d+)").find(u.encodedPath)?.groupValues?.get(1) ?: u.queryParameter("fid")
                if(fid != null) open("forum:$fid") else open("web:$u")
            }
            u.isSite() && u.encodedPath == "/member.php" && u.queryParameter("action") == "login" -> open("login")
            u.isSite() && nativePage(u.toString()) -> open("native:$u")
            else -> open("web:$u")
        }
    }
}

@Composable fun CommunityApp(site:Site, nav:Nav = remember { Nav() }) {
    val snack=remember {SnackbarHostState()}
    val window=(LocalContext.current as? android.app.Activity)?.window
    val lightSystemBars=!LocalDark.current && nav.gallery==null
    SideEffect {
        if(window!=null) {
            val controller=androidx.core.view.WindowCompat.getInsetsController(window,window.decorView)
            controller.isAppearanceLightStatusBars=lightSystemBars
            controller.isAppearanceLightNavigationBars=lightSystemBars
        }
    }
    var tab by rememberSaveable(site.uid){mutableIntStateOf(site.prefs.getInt("tab.${site.uid}",0).coerceIn(0,3))}
    fun setTab(i:Int){tab=i;site.prefs.edit().putInt("tab.${site.uid}",i).apply()}
    nav.selectRoot=::setTab
    LaunchedEffect(site.uid){nav.clearPages();nav.gallery=null;nav.download=null;nav.external=null;nav.afterLogin?.takeIf{site.loggedIn}?.let{nav.afterLogin=null;nav.open(if(it=="profile:0")"profile:${site.uid}"else it)}}
    LaunchedEffect(site.status){if(site.status.isNotBlank()){snack.showSnackbar(site.status);site.status=""}}
    var seeking by remember { mutableStateOf<Nav.Page?>(null) }
    PredictiveBackHandler(nav.pages.isNotEmpty() && nav.gallery == null && !nav.blockBack) { events ->
        val page = nav.pages.lastOrNull() ?: return@PredictiveBackHandler
        val start = page.offset.value
        seeking = page
        try {
            events.collect { page.offset.snapTo(start + (1f - start) * it.progress) }
            if (nav.pages.lastOrNull() === page) nav.back()
        } finally {
            if (seeking === page) seeking = null
        }
    }
    val pages = nav.pages.toList()
    val exiting = nav.exiting
    val layers = pages + listOfNotNull(exiting)
    val context=LocalContext.current
    val reduced=android.provider.Settings.Global.getFloat(context.contentResolver,android.provider.Settings.Global.ANIMATOR_DURATION_SCALE,1f)==0f
    Box(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        CompositionLocalProvider(LocalNav provides nav,LocalPageKey provides "root",LocalPageActive provides pages.isEmpty()) {
            RetainedPage(layers.size <= 1){PageFrame(site,nav,"",tab,::setTab)}
        }
        layers.forEachIndexed { index, page -> key(site.uid, page) {
            val leaving = page === exiting
            val interactive = page === seeking
            LaunchedEffect(leaving, interactive, reduced) {
                if (leaving) {
                    page.offset.animateTo(1f, tween(if (reduced) 0 else 220, easing = CubicBezierEasing(.55f,.055f,.675f,.19f)))
                    nav.finishExit(page)
                } else if (!interactive) {
                    page.offset.animateTo(0f, tween(if (reduced) 0 else 320, easing = CubicBezierEasing(.215f,.61f,.355f,1f)))
                }
            }
            CompositionLocalProvider(LocalNav provides nav, LocalPageKey provides "$index:${page.route}", LocalPageActive provides (page === pages.lastOrNull())) {
                RetainedPage(layers.lastIndex - index <= 1, Modifier.graphicsLayer { translationX = size.width * page.offset.value }) {
                    PageFrame(site, nav, page.route, tab, ::setTab)
                }
            }
        }}
        LinkDialogs(site,nav);GalleryHost(site,nav)
        SnackbarHost(snack,Modifier.align(Alignment.BottomCenter).navigationBarsPadding())
        site.settingsRevision
        if(site.prefs.getBoolean("showFps",false))FpsIndicator()
    }
}
@Composable fun RootPages(site:Site,nav:Nav,tab:Int,content:@Composable (Int)->Unit){
    val active=LocalPageActive.current
    val visited=remember{mutableStateListOf(tab)}
    if(tab !in visited)visited.add(tab)
    val transition=androidx.compose.animation.core.updateTransition(tab,label="root pages")
    val reduced=android.provider.Settings.Global.getFloat(LocalContext.current.contentResolver,android.provider.Settings.Global.ANIMATOR_DURATION_SCALE,1f)==0f
    BoxWithConstraints(Modifier.fillMaxSize().clipToBounds()){
        val width=constraints.maxWidth.toFloat()
        visited.forEach{i->key(i){
            val offset by transition.animateFloat(transitionSpec={androidx.compose.animation.core.tween(if(reduced)0 else 260,easing=androidx.compose.animation.core.CubicBezierEasing(.215f,.61f,.355f,1f))},label="page $i"){selected->if(i==selected)0f else if(i<selected)-1f else 1f}
            CompositionLocalProvider(LocalPageActive provides (active&&i==tab), LocalHeaderTab provides i) {RetainedPage(i==tab||transition.isRunning,Modifier.fillMaxSize().graphicsLayer{translationX=offset*width}){content(i)}}
        }}
    }
}
private val LocalHeaderTab=staticCompositionLocalOf { -1 }
private val LocalHeaderTabs=staticCompositionLocalOf<MutableMap<Int, @Composable () -> Unit>?> { null }

@Composable fun HeaderTabs(content: @Composable () -> Unit) {
    val slots=LocalHeaderTabs.current ?: return
    val tab=LocalHeaderTab.current
    val current by rememberUpdatedState(content)
    DisposableEffect(slots,tab) {
        val render: @Composable () -> Unit = { current() }
        slots[tab]=render
        onDispose { if(slots[tab]===render) slots.remove(tab) }
    }
}

@Composable fun FrostedHeader(modifier: Modifier = Modifier, color:Color=LocalHeaderColor.current, materialAlpha:Float=.45f, content: @Composable ColumnScope.() -> Unit) {
    val border=MaterialTheme.colorScheme.outlineVariant.copy(alpha=.24f)
    Column(modifier.fillMaxWidth().backdrop(20.dp)
        .background(color.copy(alpha=materialAlpha))
        .background(androidx.compose.ui.graphics.Brush.verticalGradient(listOf(color.copy(alpha=.95f),color.copy(alpha=0f))))
        .drawWithContent{drawContent();drawLine(border,androidx.compose.ui.geometry.Offset(0f,size.height-.25.dp.toPx()),androidx.compose.ui.geometry.Offset(size.width,size.height-.25.dp.toPx()),.5.dp.toPx())}) {
        content()
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable fun PageFrame(site:Site,nav:Nav,route:String,tab:Int,setTab:(Int)->Unit) {
    site.settingsRevision
    val floating=site.prefs.getBoolean("floating",true)
    val glass=site.prefs.getBoolean("liquidGlass",false)
    val systemBottom=WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val toolbarHeight=if(route.startsWith("profile:"))maxOf(48.dp,with(LocalDensity.current){18.sp.toDp()}*1.2f+8.dp)else if(route.isNotEmpty())56.dp else if(tab==0)maxOf(64.dp,with(LocalDensity.current){46.sp.toDp()}+12.dp) else 76.dp
    val top=WindowInsets.statusBars.asPaddingValues().calculateTopPadding()+toolbarHeight
    val bottom=if(route.isEmpty() && floating) 56.dp+(if(systemBottom>0.dp)6.dp else 14.dp)+(if(!glass)systemBottom else 0.dp)+8.dp else 16.dp
    val title = when {
        route.isEmpty() -> listOf("源社区","社区","导读","我的")[tab]
        route.startsWith("thread:") -> "帖子详情"
        route.startsWith("forum:") -> nav.titles[route] ?: "源社区"
        route.startsWith("profile:") -> "个人主页"
        route.startsWith("search:") || route=="search" -> "搜索"
        route.startsWith("editor:") -> if(route.removePrefix("editor:").split(':').getOrNull(1).isNullOrEmpty()) "发布帖子" else "回复帖子"
        route.startsWith("my:") -> if(route.endsWith("mythread")) "我的帖子" else "我的收藏"
        route.startsWith("messages:") -> if(route.endsWith("mypm")) "私信" else "通知"
        route.startsWith("web:") -> nav.titles[route] ?: "原站"
        route.startsWith("native:") -> nav.titles[route] ?: nativeTitle(route.removePrefix("native:"))
        route.startsWith("license:") -> nav.titles[route] ?: "开源许可"
        else -> mapOf("login" to "登录源社区","settings" to "设置","history" to "阅读历史","appearance" to "个性化","reading" to "阅读与社区功能","messages" to "消息提醒","cloud" to "云盘","services" to "社区服务","account" to "我的账户","reply-tools" to "编辑回复菜单","promotion" to "访问推广","credits" to "我的积分","darkroom" to "小黑屋","profile-settings" to "资料设置","licenses" to "开源许可")[route] ?: "源社区"
    }
    val backdrop=rememberBackdrop()
    val headerTabs=remember(route,site.uid){mutableStateMapOf<Int,@Composable () -> Unit>()}
    CompositionLocalProvider(LocalBackdrop provides backdrop) {
    Box(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        ResponsivePageScroll(Modifier.fillMaxSize().recordBackdrop(backdrop).background(MaterialTheme.colorScheme.background).then(if(route.isEmpty() && !floating) Modifier.padding(bottom=68.dp+systemBottom) else Modifier)) {
            CompositionLocalProvider(LocalPageTop provides top,LocalPageBottom provides bottom,LocalNav provides nav, LocalHeaderTabs provides headerTabs) {
                key(site.uid,route) {
                    when {
                        route.isEmpty() -> RootPages(site,nav,tab) { rootTab ->
                            when(rootTab) {
                                0 -> FeedTabs(site,nav,listOf("圈子" to "circles","推荐" to "portal","关注" to "following"),"home")
                                1 -> ForumsPage(site,nav)
                                2 -> FeedTabs(site,nav,listOf("最新" to "newthread","热门" to "hot","精华" to "digest","回复" to "new","抢沙发" to "sofa"),"guide")
                                else -> AccountPage(site,nav)
                            }
                        }
                        route.startsWith("forum:") || route.startsWith("search:") || route.startsWith("my:") -> FeedPage(site,nav,route)
                        route.startsWith("thread:") -> ThreadPage(site,nav,route.substringAfter(':'))
                        route.startsWith("profile:") -> ProfilePage(site,nav,route.substringAfter(':'))
                        route.startsWith("editor:") -> EditorPage(site,nav,route.removePrefix("editor:"))
                        route.startsWith("web:") -> BrowserPage(site,route.removePrefix("web:"))
                        route.startsWith("video:") -> Video(route.removePrefix("video:"),nav::back)
                        route.startsWith("native:") -> NativePage(site,nav,route.removePrefix("native:"))
                        route == "settings" -> SettingsPage(site,nav)
                        route == "appearance" -> AppearancePage(site)
                        route == "reading" -> ReadingPage()
                        route == "messages" -> MessagesMenu(site,nav)
                        route == "services" -> ServicesPage(site,nav)
                        route == "account" -> AccountSettings(site,nav)
                        route == "reply-tools" -> ReplyToolsPage(site,nav)
                        route == "profile-settings" -> ProfileSettingsPage(site,nav)
                        route == "promotion" -> PromotionPage(site)
                        route == "cloud" -> CloudPage(site,nav)
                        route == "credits" -> CreditsPage(site,nav)
                        route == "darkroom" -> DarkroomPage(site,nav)
                        route.startsWith("messages:") -> MessagesPage(site,nav,route.substringAfter(':'))
                        route == "history" -> HistoryPage(site,nav)
                        route == "licenses" -> LicensesPage(nav)
                        route.startsWith("license:") -> LicensesPage(nav,route.substringAfter(':').toIntOrNull())
                        route == "login" -> Box(Modifier.padding(top=top)) {LoginPage(site,nav)}
                        route == "search" -> SearchPage(site,nav)
                    }
                }
            }
        }
        if(!route.startsWith("web:")&&!route.startsWith("video:")) FrostedHeader {
            Row(Modifier.fillMaxWidth().statusBarsPadding().height(toolbarHeight).padding(end=if(route.isEmpty() && tab==3)4.dp else 0.dp),verticalAlignment=Alignment.CenterVertically) {
                if(route.isNotEmpty()) Box(Modifier.width(56.dp),contentAlignment=Alignment.Center) {IconButton(onClick=tap(nav::back)) {Icon(Icons.AutoMirrored.Rounded.ArrowBack,"返回",Modifier.size(if(route.startsWith("profile:"))20.dp else 24.dp))}}
                Column(Modifier.weight(1f).padding(start=if(route.startsWith("profile:"))8.dp else 16.dp).combinedClickable(onClick=tap {nav.scrollTop?.invoke()},onDoubleClick=if(route.isEmpty()&&(tab==0||tab==2))tap{nav.refresh?.invoke()}else null),verticalArrangement=Arrangement.Center) {
                    if(route=="search"&&nav.titleContent!=null)nav.titleContent?.invoke()else Text(title,fontSize=18.sp,fontWeight=if(route.startsWith("profile:"))androidx.compose.ui.text.font.FontWeight.SemiBold else androidx.compose.ui.text.font.FontWeight.Bold,maxLines=1,overflow=androidx.compose.ui.text.style.TextOverflow.Ellipsis)
                    if(route.isEmpty()) Text(when(tab){1->"浏览版块与今日动态";3->"个人空间与设置";else->"更好的浏览体验"},style=MaterialTheme.typography.bodySmall,color=MaterialTheme.colorScheme.onSurfaceVariant)
                }
                if(route.isEmpty()) when(tab) {
                    3 -> IconButton(onClick=tap {nav.open("settings")}) {Icon(Icons.Outlined.Settings,"设置")}
                    1 -> {IconButton(onClick=tap {nav.open("search")}) {Icon(Icons.Rounded.Search,"搜索")}; IconButton(onClick=tap {nav.refresh?.invoke()}) {Icon(Icons.Rounded.Refresh,"刷新版块")}}
                    else -> {
                        IconButton(onClick=tap {nav.refresh?.invoke()}) {Icon(Icons.Rounded.Refresh,"刷新")}
                        IconButton(onClick=tap {nav.open("search")}) {Icon(Icons.Rounded.Search,"搜索")}
                        var menu by remember {mutableStateOf(false)}
                        Box {IconButton(onClick={menu=true}) {Icon(Icons.Rounded.MoreVert,"更多操作")}; DropdownMenu(menu,{menu=false}) {
                            if(tab==0) DropdownMenuItem(text={Text("浏览全部版块")},onClick={menu=false;setTab(1)})
                            DropdownMenuItem(text={Text("打开原站")},onClick={menu=false;nav.open("web:$ORIGIN/${if(tab==0)"portal.php" else "forum.php?mod=guide&view=newthread"}")})
                        }}
                    }
                }
                if(route.startsWith("forum:")) IconButton(onClick=tap {nav.open("search")}) {Icon(Icons.Rounded.Search,"搜索")}
                if(route.isNotEmpty()) nav.pageActions[LocalPageKey.current]?.invoke()
            }
            headerTabs[if(route.isEmpty())tab else -1]?.invoke()
        }
        if(route.isEmpty()) OriginalNavigation(tab,{i->if(i==tab && i==0)nav.scrollTop?.invoke() else setTab(i)},Modifier.align(Alignment.BottomCenter))
        if(route.startsWith("forum:")) OriginalFab(onClick={val editor="editor:${route.split(':')[1]}::";if(site.loggedIn)nav.open(editor)else nav.loginThen(editor)},modifier=Modifier.align(Alignment.BottomEnd).navigationBarsPadding().padding(16.dp)) {Icon(Icons.Outlined.Edit,"发帖")}




    }
}
}
@Composable fun Failure(message: String, retry: () -> Unit) {
    Column(Modifier.fillMaxWidth().padding(24.dp), horizontalAlignment=Alignment.CenterHorizontally) {
        Icon(Icons.Outlined.CloudOff,null,Modifier.size(40.dp),tint=MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(16.dp));Text(message,textAlign=androidx.compose.ui.text.style.TextAlign.Center)
        Spacer(Modifier.height(16.dp));FilledTonalButton(onClick=tap(retry)){Icon(Icons.Default.Refresh,null);Spacer(Modifier.width(8.dp));Text("重试")}
    }
}
@Composable fun SiteImage(url: String, description: String?, modifier: Modifier = Modifier,onError:((Throwable)->Unit)?=null,fallback:Boolean=false,scale:androidx.compose.ui.layout.ContentScale=androidx.compose.ui.layout.ContentScale.Crop,onSuccess:((android.graphics.drawable.Drawable)->Unit)?=null) {
    var failed by remember(url){mutableStateOf(false)}
    Box(modifier) {
        AsyncImage(imageRequest(url),description,Modifier.matchParentSize(),contentScale=scale,onError={failed=true;onError?.invoke(it.result.throwable)},onSuccess={failed=false;onSuccess?.invoke(it.result.drawable)})
        if(fallback&&failed)Box(Modifier.matchParentSize().background(MaterialTheme.colorScheme.surfaceContainerHighest),contentAlignment=Alignment.Center) {Icon(Icons.Outlined.Image,null)}
    }
}


