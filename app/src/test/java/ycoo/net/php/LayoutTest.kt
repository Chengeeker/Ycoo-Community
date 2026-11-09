package ycoo.net.php

import android.app.Application
import android.graphics.Bitmap
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.unit.dp
import androidx.test.core.app.ApplicationProvider
import org.junit.Rule
import org.junit.Test
import org.junit.Before
import org.junit.After
import org.junit.Assert.*
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Robolectric
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.ResponseBody.Companion.toResponseBody

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[35],qualifiers="w393dp-h873dp-xhdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class LayoutTest {
    @get:Rule val rule=createEmptyComposeRule()
    private lateinit var controller:org.robolectric.android.controller.ActivityController<ComponentActivity>
    private lateinit var activity:ComponentActivity
    @Before fun launch(){controller=Robolectric.buildActivity(ComponentActivity::class.java).setup().visible();activity=controller.get()}
    @After fun dispose(){controller.pause().stop().destroy()}
    private fun site(dark:Boolean):Site {
        val app=ApplicationProvider.getApplicationContext<Application>()
        app.getSharedPreferences("compose.v1",0).edit().clear().putBoolean("imported",true).putInt("themeMode",if(dark)2 else 1).putInt("tab.0",3).commit()
        return Site(app,startSession=false)
    }
    private fun capture(name:String){
        rule.waitForIdle()
        val file=File("build/previews/$name.png");file.parentFile.mkdirs()
        file.outputStream().use{rule.onRoot().captureToImage().asAndroidBitmap().compress(Bitmap.CompressFormat.PNG,100,it)}
    }
    @Test fun originalAccountGroupsAndSettingsRemainReachable(){
        val site=site(false)
        activity.setContent{OriginalTheme(site){CommunityApp(site)}}
        rule.onNodeWithText("登录源社区").assertIsDisplayed()
        rule.onNodeWithText("我的内容").assertIsDisplayed()
        rule.onNodeWithText("我的相册").assertIsDisplayed()
        capture("my-light")
        rule.onNodeWithContentDescription("设置").performClick()
        rule.waitForIdle()
        rule.onNodeWithText("账号设置").assertIsDisplayed()
        rule.onNodeWithText("清除内容缓存").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("保留账户和阅读历史").assertIsDisplayed()
        capture("settings-light")
        rule.onNodeWithText("个性化").performScrollTo().performClick()
        rule.waitForIdle()
        val settingsList = rule.onNode(hasScrollToIndexAction())
        settingsList.performScrollToNode(hasText("动态取色"))
        val dynamicTitle = mutableListOf<androidx.compose.ui.text.TextLayoutResult>()
        rule.onNodeWithText("动态取色", useUnmergedTree=true).performSemanticsAction(
            androidx.compose.ui.semantics.SemanticsActions.GetTextLayoutResult
        ) { it(dynamicTitle) }
        assertEquals(1, dynamicTitle.single().lineCount)
        rule.onNodeWithText("从 Android 12+ 壁纸自动提取主色调").assertDoesNotExist()
        settingsList.performScrollToNode(hasText("使用液态玻璃效果"))
        rule.onNodeWithText("控制液态玻璃控件；当前应用于悬浮底栏").assertDoesNotExist()
        rule.onNode(hasScrollToIndexAction()).performScrollToNode(hasText("使用悬浮底栏"))
        rule.onNodeWithText("居中显示悬浮式导航栏").assertDoesNotExist()
        rule.onNodeWithText("使用悬浮底栏").performClick()
        rule.runOnIdle{assertFalse(site.prefs.getBoolean("floating",true))}
        rule.runOnIdle{activity.onBackPressedDispatcher.onBackPressed()}
        rule.waitForIdle()
        rule.onNodeWithText("账号设置").performScrollTo().assertIsDisplayed()
    }
    @Test @Config(sdk=[28]) fun unsupportedDynamicColorKeepsThePresetColorsAvailable() {
        val site=site(false)
        site.setting("dynamicColor",true)
        activity.setContent { OriginalTheme(site) { AppearancePage(site) } }
        rule.onNode(hasScrollToIndexAction()).performScrollToNode(hasText("经典红"))
        rule.onNodeWithText("经典红").assertIsDisplayed()
        rule.onNodeWithText("动态取色").assertIsNotEnabled()
    }
    @Test fun darkThemeAndLargeTypeCanRenderWithoutClippingControls(){
        val site=site(true);site.setting("textScale",1.4f)
        activity.setContent{OriginalTheme(site){CommunityApp(site)}}
        rule.onNodeWithContentDescription("设置").assertIsDisplayed()
        rule.onNodeWithText("我的内容").assertIsDisplayed()
        rule.onNodeWithText("社区服务").performScrollTo().assertIsDisplayed()
        capture("my-dark-large")
    }
    @Test fun darkPortalUsesLightForegroundAndPlacesContentBelowTheHeaderTabs() {
        val site=site(true)
        site.prefs.edit().putInt("tab.0",0).putString("cache.0.portal",
            """{"topics":[{"tid":"10","subject":"样例主题"}],"page":1,"more":false,"sections":{"快捷服务":[{"title":"每日签到","url":"/k_misign-sign.html"}],"热门版块":[{"title":"样例版块","url":"/forum-42-1.html"}],"七日排行":[{"title":"排名甲","url":"/thread-11-1-1.html"},{"title":"排名乙","url":"/thread-12-1-1.html"}]}}"""
        ).commit()
        var foreground=0
        activity.setContent {
            OriginalTheme(site) {
                foreground=MaterialTheme.colorScheme.onSurface.toArgb()
                CommunityApp(site)
            }
        }
        val title=rule.onNodeWithText("源社区")
        val selectedTab=rule.onNodeWithText("推荐")
        val announcement=rule.onNodeWithText("公告")
        assertTrue(selectedTab.getUnclippedBoundsInRoot().top>title.getUnclippedBoundsInRoot().bottom)
        assertTrue(announcement.getUnclippedBoundsInRoot().top>selectedTab.getUnclippedBoundsInRoot().bottom)
        for(node in listOf(title,announcement,rule.onNodeWithText("每日签到"))) {
            val bitmap=node.captureToImage().asAndroidBitmap()
            val pixels=IntArray(bitmap.width*bitmap.height)
            bitmap.getPixels(pixels,0,bitmap.width,0,0,bitmap.width,bitmap.height)
            assertTrue("Missing theme foreground in ${node.fetchSemanticsNode()}",pixels.any {
                kotlin.math.abs(android.graphics.Color.red(it)-android.graphics.Color.red(foreground))<=4 &&
                    kotlin.math.abs(android.graphics.Color.green(it)-android.graphics.Color.green(foreground))<=4 &&
                    kotlin.math.abs(android.graphics.Color.blue(it)-android.graphics.Color.blue(foreground))<=4
            })
        }
        val shortcut = rule.onNodeWithText("每日签到").getUnclippedBoundsInRoot()
        val forumHeading = rule.onNodeWithText("热门板块").getUnclippedBoundsInRoot()
        assertTrue(forumHeading.top - shortcut.bottom in 12.dp..30.dp)
        rule.onNodeWithText("排名甲").assertHeightIsEqualTo(44.dp)
        rule.onNodeWithText("排名乙").assertHeightIsEqualTo(44.dp)
        capture("portal-dark-frost")
    }
    @Test fun communityBoardsUseCompactRowsAndTheOfficialCountRule() {
        val site = site(true)
        val nav = Nav()
        site.prefs.edit().putString("cache.0.forums", """
            {"forumlist":[
                {"fid":"21","name":"书源发布","todayposts":"85","threads":"10","posts":"10000"},
                {"fid":"106","name":"悬赏问答","todayposts":"0","threads":"9005","posts":"40295"},
                {"fid":"113","name":"音视频区","todayposts":"0","threads":"587","posts":"8078"},
                {"fid":"91","name":"开源阅读","todayposts":"0","threads":"60","posts":"123456789"},
                {"fid":"99","name":"未分类版块","todayposts":"0","posts":"0"}],
              "catlist":[{"name":"书源交流","forums":["21","106"]},{"name":"网络资源","forums":["113","91"]}]}
        """.trimIndent()).commit()
        activity.setContent { OriginalTheme(site) { ForumsPage(site, nav) } }
        rule.onNodeWithText("全部版块").assertDoesNotExist()
        rule.onNodeWithText("书源发布").assertHeightIsEqualTo(70.dp)
        rule.onNodeWithText("今日: 85").assertIsDisplayed()
        rule.onNodeWithText("帖数: 40295").assertIsDisplayed()
        rule.onNodeWithText("帖数: 8078").assertIsDisplayed()
        rule.onNodeWithText("未分类版块").assertIsDisplayed()
        rule.onNodeWithText("帖数: 0").assertIsDisplayed()
        rule.runOnIdle { site.setting("textScale", 1.8f) }
        val layouts = mutableListOf<androidx.compose.ui.text.TextLayoutResult>()
        rule.onNodeWithText("帖数: 123456789", useUnmergedTree = true)
            .performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.GetTextLayoutResult) { it(layouts) }
        assertFalse(layouts.single().hasVisualOverflow)
        rule.onNodeWithText("音视频区").performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.OnClick) { it() }
        rule.runOnIdle { assertEquals("forum:113", nav.current) }
    }
    @Test fun topicProfileHitTargetsStopBeforeTheFollowButtonGap() {
        val site = site(false)
        val nav = Nav()
        val topic = Topic("45", "测试文章", author = "岚", uid = "123", avatar = "$ORIGIN/avatar.svg")
        activity.setContent { OriginalTheme(site) { TopicRow(site, topic, nav) } }
        val author = rule.onNodeWithText("岚", useUnmergedTree = true)
        val follow = rule.onNodeWithText("关注")
        val authorBounds = author.fetchSemanticsNode().boundsInRoot
        val followBounds = follow.fetchSemanticsNode().boundsInRoot
        val root = rule.onRoot()
        val density = activity.resources.displayMetrics.density
        val x = followBounds.left - 12 * density
        assertTrue(x > authorBounds.right + 48 * density)
        val gap = Offset(x, authorBounds.center.y) - root.fetchSemanticsNode().boundsInRoot.topLeft
        root.performTouchInput { click(gap) }
        rule.runOnIdle { assertEquals("thread:45", nav.current); nav.back() }

        author.performTouchInput { click() }
        rule.runOnIdle { assertEquals("profile:123", nav.current); nav.back() }
        rule.onNodeWithContentDescription("岚 的默认头像", useUnmergedTree = true).performTouchInput { click() }
        rule.runOnIdle { assertEquals("profile:123", nav.current); nav.back() }
        follow.performTouchInput { click() }
        rule.runOnIdle { assertEquals("login", nav.current) }
    }
    @Test fun navigationDropletExpandsPastTheBarAndSelectsOnlyOnRelease() {
        val site=site(true)
        site.setting("liquidGlass",true)
        val selection=mutableIntStateOf(0)
        val changes=mutableListOf<Int>()
        activity.setContent {
            OriginalTheme(site) {
                val backdrop=rememberBackdrop()
                Box(Modifier.fillMaxSize()) {
                    Box(Modifier.fillMaxSize().recordBackdrop(backdrop).background(MaterialTheme.colorScheme.tertiaryContainer))
                    CompositionLocalProvider(LocalBackdrop provides backdrop) {
                        OriginalNavigation(selection.intValue,{selection.intValue=it;changes.add(it)},Modifier.align(Alignment.BottomCenter))
                    }
                }
            }
        }
        val renderer = rule.onNodeWithTag("navigation-glass-gpu")
        for (dark in listOf(true, false)) {
            rule.runOnIdle { site.setting("themeMode", if (dark) 2 else 1); selection.intValue = 0; changes.clear() }
            rule.onNode(hasContentDescription("社区") and isNotSelected()).performTouchInput { click() }
            rule.runOnIdle { assertEquals(listOf(1), changes); selection.intValue = 0; changes.clear() }
            rule.mainClock.advanceTimeBy(600)
            val bounds = renderer.getUnclippedBoundsInRoot()
            fun lensPosition() = renderer.fetchSemanticsNode().config[NavigationLensPosition]
            fun expansion() = renderer.fetchSemanticsNode().config[NavigationLensExpansion]
            val home = rule.onNode(hasContentDescription("首页") and isSelected())
            rule.mainClock.autoAdvance = false
            home.performTouchInput { down(center) }
            rule.mainClock.advanceTimeByFrame()
            home.performTouchInput { moveBy(Offset(width.toFloat(), 0f)) }
            repeat(20) { rule.mainClock.advanceTimeByFrame(); rule.waitForIdle() }
            assertEquals(1f, lensPosition(), .13f)
            assertEquals(0f, expansion(), 0f)
            home.performTouchInput { cancel() }
            rule.mainClock.advanceTimeBy(400)
            rule.runOnIdle { assertTrue(changes.isEmpty()) }
            home.performTouchInput { down(center) }
            rule.mainClock.advanceTimeBy(640)
            assertTrue(renderer.fetchSemanticsNode().config[NavigationLensExpansion] > .99f)
            assertEquals(0f, lensPosition(), .1f)
            repeat(3) { step ->
                home.performTouchInput { advanceEventTime(80); moveBy(Offset(width.toFloat(), 0f)) }
                rule.mainClock.advanceTimeBy(280)
                assertEquals(bounds, renderer.getUnclippedBoundsInRoot())
                assertEquals("The GPU lens must follow each move", (step + 1).toFloat(), lensPosition(), .13f)
                rule.runOnIdle { assertTrue(changes.isEmpty()) }
            }
            home.performTouchInput { up() }
            repeat(6) { rule.mainClock.advanceTimeByFrame(); rule.waitForIdle() }
            assertTrue(expansion() in .01f.. .95f)
            rule.mainClock.advanceTimeBy(800)
            rule.mainClock.autoAdvance = true
            rule.runOnIdle { assertEquals(listOf(3), changes) }
            assertEquals(0f, renderer.fetchSemanticsNode().config[NavigationLensExpansion], .01f)
        }
    }
    @Test fun postLinksExcludeSurroundingProseAndKeepExplicitLabels() {
        val share = "https://pan.baidu.com/s/test?pwd=1234"
        val bare = "https://example.org/share"
        val html = """<a href="$share">正文不应可点<b>加粗的正文</b><div>$share</div></a>
            <p>另一段：$bare，后续正文<b>接续的文字</b></p>
            <p><a href="$share">网盘下载</a></p>"""
        fun links(linkify: Boolean) = bodyParts(html).flatMap { part ->
            val text = forumSpans(part.html, 0, linkify)
            text.getSpans(0, text.length, android.text.style.URLSpan::class.java).map { span ->
                text.substring(text.getSpanStart(span), text.getSpanEnd(span)) to span.url
            }
        }
        assertEquals(listOf(share to share, bare to bare, "网盘下载" to share), links(true))
        assertEquals(listOf(share to share, "网盘下载" to share), links(false))
        val adjacent = forumSpans("$bare<b>正文</b>", 0, true)
        val span = adjacent.getSpans(0, adjacent.length, android.text.style.URLSpan::class.java).single()
        assertEquals(bare, adjacent.substring(adjacent.getSpanStart(span), adjacent.getSpanEnd(span)))
    }
    @Test fun postSpacingDropsEmptyBlocksAndAttachmentBulletsButKeepsParagraphs() {
        val url = "https://example.org/share"
        val article = """
            <div><br>&nbsp;</div>
            <div>正文<br><br>&nbsp;<br><br><a href="$url">$url</a><br><br></div>
            <ul>
                <li>&nbsp;<br></li>
                <li><img src="/attachment/sample.jpg"></li>
                <li><br></li>
            </ul>
            <div id="copyright">
                <div><h3>版权声明</h3></div>
                <div>
                    <p>第一项声明</p>
                    <p>&nbsp;<br></p>
                    <p>本帖地址: <a href="$url">$url</a></p>
                </div>
            </div>
        """.trimIndent()
        val parts = bodyParts(article)
        assertEquals(3, parts.size)
        assertEquals("正文\n\n$url", forumSpans(parts[0].html, 0, true).toString())
        assertEquals("$ORIGIN/attachment/sample.jpg", parts[1].image)
        assertTrue(parts[2].copyright)
        assertEquals(parts[2].children.toString(), listOf("版权声明", "第一项声明", "本帖地址: $url"), parts[2].children!!.map {
            forumSpans(it.html, 0, true).toString().trim()
        })
        assertEquals("• 正常项目", forumSpans(bodyParts("<ul><li>正常项目</li></ul>").single().html, 0, true).toString())
        assertEquals("代码\n\n\n  保留缩进", forumSpans("<pre>代码\n\n\n  保留缩进</pre>", 0, true).toString())

        val site = site(true)
        activity.setContent { OriginalTheme(site) { Body(article.replace("<img src=\"/attachment/sample.jpg\">", ""), Nav()) } }
        rule.waitForIdle()
        fun textViews(view: android.view.View): List<android.widget.TextView> = when(view) {
            is android.widget.TextView -> listOf(view)
            is android.view.ViewGroup -> (0 until view.childCount).flatMap { textViews(view.getChildAt(it)) }
            else -> emptyList()
        }
        rule.runOnIdle {
            val texts = textViews(activity.window.decorView)
            assertEquals(4, texts.size)
            assertEquals(3, texts.first().lineCount)
            fun top(view: android.view.View) = IntArray(2).also(view::getLocationInWindow)[1]
            val title = texts[1]
            val clause = texts[2]
            val gap = (top(clause) - top(title) - title.height) / activity.resources.displayMetrics.density
            assertEquals(4f, gap, .5f)
        }
    }
    @Test fun originalGlassShadersCompileAndNavigationRenders(){
        val site=site(false);site.setting("liquidGlass",true)
        val app=ApplicationProvider.getApplicationContext<Application>()
        for(name in listOf("premium_glass","gallery_glass_button")){
            val shader=android.graphics.RuntimeShader(app.assets.open("glass/$name.agsl").bufferedReader().use{it.readText()})
            val style=GlassStyle(androidx.compose.ui.graphics.Color.White,indicator=name=="interactive_indicator",gallery=name=="gallery_glass_button")
            glassUniforms(style,200f,100f,2f).forEach{(key,value)->shader.setFloatUniform(key,value)}
            shader.setFloatUniform("textureSize",200f,100f)
        }
        activity.setContent{OriginalTheme(site){CommunityApp(site)}}
        rule.onNodeWithText("我的内容").assertIsDisplayed();capture("my-glass-light")
        rule.onNode(hasContentDescription("我的") and isSelected()).performTouchInput{down(center);advanceEventTime(260);moveBy(androidx.compose.ui.geometry.Offset(-20f,0f));up()}
        rule.waitForIdle()
    }
    @Test fun loginValidationKeepsCredentialsAndDoesNotSubmitEmptyInput(){
        val site=site(false);val nav=Nav()
        activity.setContent{OriginalTheme(site){LoginPage(site,nav)}}
        rule.onNodeWithText("登录",useUnmergedTree=true).performScrollTo().performClick()
        rule.onNodeWithText("请输入账户").assertExists();rule.onNodeWithText("请输入密码").assertExists()
        rule.onNodeWithText("密码",substring=false).performTextInput("local-test-only")
        rule.onNodeWithContentDescription("显示密码").performClick()
        rule.onNodeWithText("local-test-only").assertExists()
        capture("login")
    }
    @Test fun galleryClosingCanReopenWithoutOldCloseRemovingTheNewViewer(){
        val site=site(false);val nav=Nav();val bytes=java.io.ByteArrayOutputStream().apply{Bitmap.createBitmap(32,24,Bitmap.Config.ARGB_8888).apply{eraseColor(android.graphics.Color.RED)}.compress(Bitmap.CompressFormat.PNG,100,this)}.toByteArray()
        coil.Coil.setImageLoader(coil.ImageLoader.Builder(activity).okHttpClient(okhttp3.OkHttpClient.Builder().addInterceptor{chain->okhttp3.Response.Builder().request(chain.request()).protocol(okhttp3.Protocol.HTTP_1_1).code(200).message("OK").body(bytes.toResponseBody("image/png".toMediaType())).build()}.build()).build())
        val first=nav.showGallery(listOf("$ORIGIN/test.png"))
        activity.setContent{OriginalTheme(site){GalleryHost(site,nav)}}
        rule.waitUntil(5000){rule.onAllNodesWithContentDescription("返回").fetchSemanticsNodes().isNotEmpty()}
        rule.mainClock.autoAdvance=false
        rule.runOnIdle{assertSame(first,nav.showGallery(listOf("$ORIGIN/ignored.png")));activity.onBackPressedDispatcher.onBackPressed()}
        rule.mainClock.advanceTimeBy(80);rule.waitForIdle()
        rule.runOnIdle{assertTrue(first.closing)}
        var second:GallerySession?=null;rule.runOnIdle{second=nav.showGallery(listOf("$ORIGIN/test.png"))}
        rule.mainClock.advanceTimeBy(600);rule.waitForIdle()
        rule.runOnIdle{assertSame(second,nav.gallery);assertFalse(second!!.closing)}
        rule.onNodeWithContentDescription("返回").assertIsDisplayed()
        capture("gallery")
        rule.mainClock.autoAdvance=true
    }
    @Test fun flutterPreferencesHistoryAndDraftsAreImportedWithoutWritingBack(){
        val app=ApplicationProvider.getApplicationContext<Application>();val old=app.getSharedPreferences("FlutterSharedPreferences",0)
        old.edit().clear().putString("flutter.textScale","VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu1.2").putString("flutter.draft.12.34.message","保留的草稿").putString("flutter.history.12","[]").putString("flutter.session.viewer","{\"uid\":\"12\",\"name\":\"测试\"}").commit()
        val before=old.all.toMap();app.getSharedPreferences("compose.v1",0).edit().clear().commit()
        val site=Site(app,startSession=false)
        assertEquals("12",site.uid);assertFalse(site.verified);assertEquals(1.2f,site.prefs.getFloat("textScale",0f),.001f);assertEquals("保留的草稿",site.prefs.getString("draft.12.34.message",null));assertEquals(before,old.all)
        val epoch=site.epoch;site.clearCache();assertEquals(epoch,site.epoch);assertEquals(before,old.all)
        old.edit().clear().commit()
    }
}
