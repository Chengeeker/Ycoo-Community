package ycoo.net.php

import android.os.Build

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.*
import org.json.JSONObject

data class ActionEntry(val label:String,val icon:ImageVector,val route:String,val subtitle:String?=null)
fun accountOpen(site:Site,nav:Nav,route:String,title:String?=null) {if(title!=null)nav.titles[route]=title;if(site.loggedIn) nav.open(route) else nav.loginThen(route)}

@Composable fun AccountPage(site:Site,nav:Nav) {
    val s=MaterialTheme.colorScheme
    val accountAvatar=if(site.loggedIn) {
        val size=with(androidx.compose.ui.platform.LocalDensity.current){60.dp.roundToPx()}
        val request=imageRequest(avatar(site.uid))
        key(site.uid,site.epoch) {
            coil.compose.rememberAsyncImagePainter(
                remember(request,size){request.newBuilder().size(size).build()},
                contentScale=androidx.compose.ui.layout.ContentScale.Crop
            )
        }
    }else null
    var stats by remember(site.uid) {mutableStateOf<JSONObject?>(runCatching {JSONObject(site.prefs.getString("identity.${site.uid}","{}")!!)}.getOrNull())}
    LaunchedEffect(site.uid) {if(site.loggedIn) try {
        val id=site.uid; val ticket=site.epoch; val p=site.api("profile",mapOf("uid" to id)).optJSONObject("space")
        if(p?.optString("uid")==id&&listOf("threads","posts","credits").all {p.optString(it).toLongOrNull()?.let {n->n>=0}==true}) {site.assertEpoch(ticket); stats=p; site.prefs.edit().putString("identity.$id",JSONObject().put("threads",p.opt("threads")).put("posts",p.opt("posts")).put("credits",p.opt("credits")).toString()).apply()}
    } catch(e:Exception) {if(e is CancellationException) throw e}}
    val shortcuts=listOf(
        ActionEntry("我的空间",Icons.Outlined.HomeWork,"profile:${site.uid}"),ActionEntry("我的帖子",Icons.Outlined.Article,"my:mythread"),
        ActionEntry("我的收藏",Icons.Outlined.BookmarkBorder,"my:myfavthread"),ActionEntry("我的好友",Icons.Outlined.People,"web:$ORIGIN/home.php?mod=space&do=friend&mobile=2"),
        ActionEntry("我的日志",Icons.Outlined.Book,"web:$ORIGIN/home.php?mod=space&do=blog&view=me&mobile=2"),ActionEntry("我的相册",Icons.Outlined.PhotoLibrary,"web:$ORIGIN/home.php?mod=space&do=album&view=me&mobile=2"),
        ActionEntry("我的圈子",Icons.Outlined.Groups,"web:$ORIGIN/group.php?mod=my&mobile=2"),ActionEntry("我的心情",Icons.Outlined.Mood,"web:$ORIGIN/home.php?mod=space&do=doing&view=me&mobile=2"))
    LazyColumn(
        contentPadding=PaddingValues(start=16.dp,top=LocalPageTop.current+12.dp,end=16.dp,bottom=LocalPageBottom.current),
        verticalArrangement=Arrangement.spacedBy(16.dp),
        overscrollEffect=null
    ) {
        item {SectionCard(color=MaterialTheme.colorScheme.settingsCardColor()) {
            Row(Modifier.fillMaxWidth().clickable(onClick=tap {accountOpen(site,nav,"profile:${site.uid}")}).padding(if(site.loggedIn)PaddingValues(start=20.dp,top=12.dp,end=16.dp,bottom=8.dp)else PaddingValues(20.dp)).heightIn(min=72.dp),verticalAlignment=Alignment.CenterVertically) {
                if(accountAvatar!=null) {
                    val modifier=Modifier.size(60.dp).clip(CircleShape)
                    if(accountAvatar.state is coil.compose.AsyncImagePainter.State.Success) {
                        androidx.compose.foundation.Image(accountAvatar,"${site.username} 的头像",modifier,contentScale=androidx.compose.ui.layout.ContentScale.Crop)
                    }else {
                        coil.compose.AsyncImage("file:///android_asset/default-avatar.svg","${site.username} 的默认头像",modifier)
                    }
                }else Surface(shape=CircleShape,color=s.primaryContainer,modifier=Modifier.size(60.dp)) {Box(contentAlignment=Alignment.Center) {Icon(Icons.Outlined.Person,null,tint=s.onPrimaryContainer)}}
                Spacer(Modifier.width(16.dp)); Column(Modifier.weight(1f)) {
                    Text(if(site.loggedIn)site.username else "登录源社区",fontSize=15.sp,lineHeight=20.25.sp,fontWeight=androidx.compose.ui.text.font.FontWeight.SemiBold)
                    Text(if(site.loggedIn)"UID ${site.uid} · 查看个人空间" else "登录后查看帖子、收藏和消息",fontSize=12.5.sp,lineHeight=17.5.sp,color=s.onSurfaceVariant)
                }; Icon(Icons.Rounded.ChevronRight,null)
            }
            if(site.loggedIn) {OriginalDivider(Modifier.padding(horizontal=16.dp),space=1.dp); StatRow(listOf("主题" to stats?.optString("threads","—").orEmpty(),"帖子" to stats?.optString("posts","—").orEmpty(),"积分" to stats?.optString("credits","—").orEmpty()))}
        }}
        item {SectionCard(color=MaterialTheme.colorScheme.settingsCardColor()) {Column(Modifier.padding(start=8.dp,top=12.dp,end=8.dp,bottom=8.dp)) {
            Text("我的内容",Modifier.padding(start=8.dp,end=8.dp,bottom=8.dp),style=MaterialTheme.typography.titleMedium)
            shortcuts.chunked(4).forEach {row-> Row {row.forEachIndexed {i,a-> Column(Modifier.weight(1f).height(86.dp).clip(RoundedCornerShape(16.dp)).clickable(onClick=tap {accountOpen(site,nav,a.route,a.label)}),horizontalAlignment=Alignment.CenterHorizontally,verticalArrangement=Arrangement.Center) {
                Icon(a.icon,null,Modifier.size(28.dp),tint=listOf(s.primary,s.tertiary,s.secondary,s.error)[i]); Spacer(Modifier.height(8.dp)); Text(a.label,style=MaterialTheme.typography.labelMedium,maxLines=1,overflow=TextOverflow.Ellipsis)
            }}}}
        }}}
        item {SectionCard(color=MaterialTheme.colorScheme.settingsCardColor()) {
            Preference("消息提醒",Icons.Outlined.NotificationsNone,tint=s.primary,onClick={accountOpen(site,nav,"messages")})
            Preference("我的私信",Icons.Outlined.Mail,tint=s.secondary,onClick={accountOpen(site,nav,"messages:mypm")})
            Preference("个性化",Icons.Outlined.Palette,tint=s.tertiary,onClick={nav.open("appearance")})
            Preference("阅读历史",Icons.Rounded.History,tint=s.primary,onClick={nav.open("history")})
            Preference("社区服务",Icons.Outlined.Explore,tint=s.secondary,onClick={nav.open("services")})
            val dark=LocalDark.current
            Preference("夜间模式",Icons.Outlined.DarkMode,switchStyle=true,onClick={site.setting("themeMode",if(dark)1 else 2)},trailing={Switch(dark,{site.setting("themeMode",if(it)2 else 1)})})
            listOf(ActionEntry("访问推广",Icons.Outlined.Send,"promotion"),ActionEntry("资料设置",Icons.Outlined.Badge,"profile-settings"),
                ActionEntry("我的积分",Icons.Outlined.AccountBalanceWallet,"credits"),ActionEntry("小黑屋",Icons.Outlined.Block,"darkroom"),
                ActionEntry("最近访客",Icons.Rounded.DirectionsWalk,"native:$ORIGIN/home.php?mod=space&do=friend&view=visitor&mobile=2"),
                ActionEntry("邀请好友",Icons.Rounded.PersonAddAlt1,"web:$ORIGIN/home.php?mod=spacecp&ac=invite&mobile=2"),
                ActionEntry("繁星开通",Icons.Outlined.Stars,"web:$ORIGIN/plugin.php?id=boan_group&frame=yes"),
                ActionEntry("任务中心",Icons.Outlined.TaskAlt,"native:$ORIGIN/home.php?mod=task&mobile=2"),
                ActionEntry("我的勋章",Icons.Outlined.WorkspacePremium,"native:$ORIGIN/home.php?mod=medal&action=log&mobile=2"),
                ActionEntry("我的道具",Icons.Outlined.AutoFixHigh,"web:$ORIGIN/home.php?mod=magic&mobile=2")).forEach {a->
                Preference(a.label,a.icon,tint=if(a.route=="darkroom")s.error else if(a.route=="credits")s.primary else s.secondary,onClick={if(a.route=="darkroom")nav.open(a.route) else accountOpen(site,nav,a.route,a.label)})
            }
        }}
    }
}
@Composable fun SiteAvatar(uid:String,name:String,size:androidx.compose.ui.unit.Dp=32.dp,url:String=avatar(uid)) {
    val image=url.ifBlank {avatar(uid)}
    Box(Modifier.size(size).clip(CircleShape),contentAlignment=Alignment.Center) {
        coil.compose.AsyncImage("file:///android_asset/default-avatar.svg","$name 的默认头像",Modifier.fillMaxSize())
        if(image.isNotBlank()&&!image.substringBefore("?").endsWith(".svg",true)) SiteImage(image,"$name 的头像",Modifier.fillMaxSize())
    }
}

@Composable fun SettingsPage(site:Site,nav:Nav) {
    var about by remember {mutableStateOf(false)}
    LazyColumn(contentPadding=PaddingValues(start=16.dp,top=LocalPageTop.current+16.dp,end=16.dp,bottom=24.dp)) {
        item {SectionTitle("账号设置"); SectionCard(color=MaterialTheme.colorScheme.settingsCardColor()) {Preference("我的账户",Icons.Outlined.AccountCircle,onClick={nav.open("account")})}; Spacer(Modifier.height(16.dp))}
        item {SectionTitle("偏好与功能"); SectionCard(color=MaterialTheme.colorScheme.settingsCardColor()) {
            Preference("阅读历史",Icons.Rounded.History,onClick={nav.open("history")})
            Preference("个性化",Icons.Outlined.Palette,onClick={nav.open("appearance")})
            Preference("阅读与社区功能",Icons.Outlined.AutoStories,onClick={nav.open("reading")})
            Preference("编辑回复菜单",Icons.Outlined.EditNote,onClick={nav.open("reply-tools")})
        }; Spacer(Modifier.height(16.dp))}
        item {SectionTitle("内容与服务"); SectionCard(color=MaterialTheme.colorScheme.settingsCardColor()) {
            Preference("清除内容缓存",Icons.Outlined.CleaningServices,"保留账户和阅读历史",onClick={site.clearCache(); site.status="内容缓存已清除"})
            Preference("社区服务",Icons.Outlined.Explore,onClick={nav.open("services")})
        }; Spacer(Modifier.height(16.dp))}
        item {SectionTitle("关于与支持"); SectionCard(color=MaterialTheme.colorScheme.settingsCardColor()) {Preference("关于源社区",Icons.Outlined.Info,onClick={about=true})}}
    }
    if(about) AboutDialog(nav) {about=false}
}
@OptIn(ExperimentalLayoutApi::class)
@Composable fun AppearancePage(site:Site) {
    site.settingsRevision
    LazyColumn(contentPadding=PaddingValues(start=16.dp,top=LocalPageTop.current+12.dp,end=16.dp,bottom=24.dp),verticalArrangement=Arrangement.spacedBy(16.dp)) {
        item { AppearanceModes(site.prefs.getInt("themeMode",0), { site.setting("themeMode",it) },
            site.prefs.getBoolean("pureBlack",false), { site.setting("pureBlack",it) }) }
        item { AppearancePalette(site.prefs.getBoolean("dynamicColor",false), { site.setting("dynamicColor",it) },
            site.prefs.getInt("color",0), { site.setting("color",it) }) }
        item { FontWeightSetting(site.prefs.getBoolean("customFontWeight", false), site.prefs.getInt("fontWeightDelta", 0), "源社区",
            hapticsEnabled = site.prefs.getBoolean("haptics", true), onReset = { site.setting("customFontWeight", false) },
            onCommit = { site.setting("fontWeightDelta", it); site.setting("customFontWeight", true) }) }
        item {
            val delta = if (site.prefs.getBoolean("customFontWeight", false)) LocalAppWeightDelta.current else systemFontWeightDelta()
            val type = MaterialTheme.typography
            MaterialTheme(typography = type.copy(bodyMedium = type.bodyMedium.copy(fontWeight = androidx.compose.ui.text.font.FontWeight((400 + delta).coerceIn(100, 900))))) {
                FontSizeSetting(site.prefs.getFloat("textScale", 1f)) { site.setting("textScale", it) }
            }
        }
        item {AppearanceSection("底部导航") {SettingSwitch("floating","使用悬浮底栏",Icons.Rounded.Dock,default=true,tint=MaterialTheme.colorScheme.primary)}}
        item {AppearanceSection("显示效果") {SettingSwitch("liquidGlass","使用液态玻璃效果",Icons.Rounded.BlurOn,tint=MaterialTheme.colorScheme.primary)
            if(site.prefs.getBoolean("liquidGlass",false) && site.prefs.getBoolean("floating",true)) NavigationGlassChoice(site.prefs.getBoolean("translucentNavigationGlass",false), hapticsEnabled = site.prefs.getBoolean("haptics",true)) { site.setting("translucentNavigationGlass",it) }
        }}
        item {AppearanceSection("触感与震动") {SettingSwitch("haptics","触感与震动反馈",Icons.Rounded.Vibration,default=true,tint=MaterialTheme.colorScheme.primary)}}
    }
}
@Composable fun ReadingPage() {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(start=16.dp,top=LocalPageTop.current+12.dp,end=16.dp,bottom=24.dp)) {SectionCard(color=MaterialTheme.colorScheme.settingsCardColor()) {
        SettingSwitch("autoReplies","自动加载回复",Icons.Outlined.Forum,default=true)
        SettingSwitch("linkify","URL 自动链接",Icons.Rounded.Link,default=true)
        SettingSwitch("showFps","显示 FPS",Icons.Rounded.Speed)
        SettingSwitch("autoSignIn","自动签到",Icons.Outlined.EventAvailable,"登录后启动应用时自动签到")
    }}
}
@OptIn(ExperimentalLayoutApi::class)
@Composable fun AboutDialog(nav:Nav,close:()->Unit) {
    val s=MaterialTheme.colorScheme
    androidx.compose.ui.window.Dialog(onDismissRequest=close){Surface(shape=RoundedCornerShape(20.dp),color=s.surfaceContainerHigh){Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(start=20.dp,top=24.dp,end=20.dp,bottom=16.dp),horizontalAlignment=Alignment.CenterHorizontally){
        coil.compose.AsyncImage("file:///android_asset/site-icon.png",null,Modifier.size(72.dp).clip(RoundedCornerShape(18.dp)))
        Spacer(Modifier.height(14.dp));FlowRow(horizontalArrangement=Arrangement.spacedBy(8.dp,Alignment.CenterHorizontally),verticalArrangement=Arrangement.spacedBy(8.dp)){
            Text("源社区",fontSize=21.sp,fontWeight=androidx.compose.ui.text.font.FontWeight.Bold,letterSpacing=.2.sp)
            Surface(shape=RoundedCornerShape(8.dp),color=s.primaryContainer){Text("v${BuildConfig.VERSION_NAME}",Modifier.padding(8.dp,2.5.dp),fontSize=12.sp,fontWeight=androidx.compose.ui.text.font.FontWeight.Bold,color=s.onPrimaryContainer)}
        }
        Spacer(Modifier.height(6.dp));Text("Material 3 社区客户端",fontSize=13.sp,color=s.onSurfaceVariant)
        Spacer(Modifier.height(16.dp));Text("基于源论坛的第三方客户端。社区内容与账户权限由原站提供。",fontSize=12.5.sp,lineHeight=16.875.sp,color=s.onSurfaceVariant)
        Spacer(Modifier.height(14.dp));SectionCard(color=s.settingsCardColor(s.surfaceContainerHigh)) {Row(Modifier.fillMaxWidth().heightIn(min=72.dp).clickable(onClick=tap{nav.route("https://github.com/Chengeeker/Ycoo-Community");close()}).padding(horizontal=16.dp,vertical=8.dp),verticalAlignment=Alignment.CenterVertically){Icon(Icons.Rounded.Code,null,Modifier.size(20.dp),tint=s.primary);Spacer(Modifier.width(16.dp));Column(Modifier.weight(1f)){Text("开源仓库",fontSize=13.sp);Text("github.com/Chengeeker/Ycoo-Community",fontSize=11.sp,color=s.onSurfaceVariant)};Icon(Icons.Rounded.OpenInNew,null,Modifier.size(16.dp),tint=s.primary)}}
        Spacer(Modifier.height(16.dp));Row(horizontalArrangement=Arrangement.spacedBy(8.dp),verticalAlignment=Alignment.CenterVertically){TextButton(onClick={close();nav.open("licenses")}){Text("开源许可")};Button(onClick=close,shape=RoundedCornerShape(12.dp),contentPadding=PaddingValues(24.dp,10.dp)){Text("我知道了")}}
    }}}
}
@Composable fun MessagesMenu(site:Site,nav:Nav) {
    val entries=listOf(ActionEntry("我的消息",Icons.Outlined.Forum,"messages:mypm"),ActionEntry("我的粉丝",Icons.Outlined.People,"web:$ORIGIN/home.php?mod=space&do=follow&view=follower"),
        ActionEntry("我的帖子",Icons.Outlined.Article,"native:$ORIGIN/home.php?mod=space&do=notice&view=mypost"),ActionEntry("坛友互动",Icons.Outlined.Diversity3,"native:$ORIGIN/home.php?mod=space&do=notice&view=interactive"),
        ActionEntry("系统提醒",Icons.Outlined.Notifications,"native:$ORIGIN/home.php?mod=space&do=notice&view=system"),ActionEntry("应用提醒",Icons.Outlined.Apps,"native:$ORIGIN/home.php?mod=space&do=notice&view=userapp"))
    Column(Modifier.padding(start=16.dp,top=LocalPageTop.current+16.dp,end=16.dp)) {SectionCard(color=MaterialTheme.colorScheme.settingsCardColor()) {entries.forEach {a-> Preference(a.label,a.icon,tint=MaterialTheme.colorScheme.primary,onClick={accountOpen(site,nav,a.route,a.label)})}}}
}
@Composable fun ServicesPage(site:Site,nav:Nav) {
    val entries=linkedMapOf("门户原站" to "/portal.php","每日签到" to "/k_misign-sign.html?mobile=2","开心农场" to "/plugin.php?id=jnfarm&mobile=2","心情墙" to "/home.php?mod=space&do=doing&view=all&mobile=2","云盘" to "/plugin.php?id=bphp_clouds:index&mobile=2","淘专辑" to "/forum.php?mod=collection&op=all&mobile=2","圈子" to "/group.php?mod=index&mobile=2","排行榜" to "/misc.php?mod=ranklist&type=member&view=credit&mobile=2","标签" to "/misc.php?mod=tag&mobile=2","访问推广" to "promotion","小黑屋" to "darkroom","当前在线" to "/forum.php?showoldetails=yes&mobile=no#online","电脑版" to "/forum.php?mobile=no","注册与邀请" to "/member.php?mod=register&mobile=2")
    LazyColumn(contentPadding=PaddingValues(top=LocalPageTop.current,bottom=16.dp)) {entries.forEach {(label,url)->item {SiteListItem(headlineContent={Text(label)},modifier=Modifier.clickable(onClick=tap{when(url){"promotion"->accountOpen(site,nav,url);"darkroom"->nav.open(url);else->nav.route(url)}}),trailingContent={Icon(Icons.Rounded.OpenInNew,null)})}}}
}
@Composable fun AccountSettings(site:Site,nav:Nav) {
    var error by remember {mutableStateOf("")}; var busy by remember {mutableStateOf(true)}; var confirm by remember {mutableStateOf(false)}
    LaunchedEffect(Unit) {try {site.syncSession()} catch(e:Exception) {if(e is CancellationException)throw e; error=e.message.orEmpty()} finally {busy=false}}
    if(busy) {Box(Modifier.fillMaxSize(),contentAlignment=Alignment.Center) {CircularProgressIndicator()}; return}
    LazyColumn(contentPadding=PaddingValues(start=16.dp,top=LocalPageTop.current+16.dp,end=16.dp,bottom=24.dp),verticalArrangement=Arrangement.spacedBy(24.dp)) {
        if(error.isNotEmpty()) item {Failure(error,{site.run {site.syncSession(); error=""}})}
        item {SectionCard(color=MaterialTheme.colorScheme.settingsCardColor()) {SiteListItem(headlineContent={Text(if(site.loggedIn)site.username else "尚未登录")},supportingContent=if(site.loggedIn){{Text("UID ${site.uid}")}}else null,contentPadding=PaddingValues(20.dp),modifier=Modifier.clickable(onClick=tap{accountOpen(site,nav,"profile:${site.uid}")}),leadingContent={if(site.loggedIn)SiteAvatar(site.uid,site.username,40.dp)else Box(Modifier.size(40.dp).background(MaterialTheme.colorScheme.primaryContainer,CircleShape),contentAlignment=Alignment.Center){Icon(Icons.Outlined.Person,null,tint=MaterialTheme.colorScheme.onPrimaryContainer)}},trailingContent={Icon(Icons.Rounded.ChevronRight,null)})}}
        item {SectionCard(color=MaterialTheme.colorScheme.settingsCardColor()) {listOf(ActionEntry("我的收藏",Icons.Outlined.BookmarkBorder,"my:myfavthread"),ActionEntry("我的帖子",Icons.Outlined.Article,"my:mythread"),ActionEntry("私信",Icons.Outlined.Mail,"messages:mypm"),ActionEntry("通知",Icons.Outlined.NotificationsNone,"messages:mynotelist")).forEach {a->Preference(a.label,a.icon,onClick={accountOpen(site,nav,a.route,a.label)})}}}
        if(site.loggedIn) item {OutlinedButton(onClick={confirm=true},modifier=Modifier.fillMaxWidth()) {Text("退出登录")}}
    }
    if(confirm) OriginalDialog(onDismissRequest={confirm=false},title={Text("退出当前账户？")},text={Text("将清除此应用的登录会话、账户缓存和本机阅读历史。")},confirmButton={Button(onClick={confirm=false;site.run {site.logout()}}) {Text("退出")}},dismissButton={TextButton(onClick={confirm=false}) {Text("取消")}})
}
