package ycoo.net.php

import android.app.Application
import android.graphics.Bitmap
import androidx.activity.BackEventCompat
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.test.core.app.ApplicationProvider
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.*
import org.junit.Assert.*
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[35],qualifiers="w393dp-h873dp-xhdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class VisualParityTest {
    @get:Rule val rule=createEmptyComposeRule()
    private lateinit var controller:org.robolectric.android.controller.ActivityController<ComponentActivity>
    private lateinit var activity:ComponentActivity
    @Before fun launch(){controller=Robolectric.buildActivity(ComponentActivity::class.java).setup().visible();activity=controller.get()}
    @After fun dispose(){controller.pause().stop().destroy()}
    private fun site():Site {
        val app=ApplicationProvider.getApplicationContext<Application>()
        app.getSharedPreferences("compose.v1",0).edit().clear().putBoolean("imported",true).putInt("themeMode",2).putInt("tab.0",3).commit()
        return Site(app,startSession=false)
    }
    private fun mock(site:Site,response:(HttpUrl)->String) {
        val client=OkHttpClient.Builder().addInterceptor {chain->
            Response.Builder().request(chain.request()).protocol(Protocol.HTTP_1_1).code(200).message("OK")
                .body(response(chain.request().url).toResponseBody("text/plain; charset=utf-8".toMediaType())).build()
        }.build()
        Site::class.java.getDeclaredField("client").apply{isAccessible=true}.set(site,client)
        coil.Coil.setImageLoader(coil.ImageLoader.Builder(activity).okHttpClient(client).build())
    }
    private fun layout(text:String):TextLayoutResult {
        val results=mutableListOf<TextLayoutResult>()
        rule.onNodeWithText(text,useUnmergedTree=true).performSemanticsAction(SemanticsActions.GetTextLayoutResult){it(results)}
        return results.single()
    }
    private fun capture(name:String){
        val output=File("build/previews/$name.png");output.parentFile!!.mkdirs()
        output.outputStream().use {rule.onRoot().captureToImage().asAndroidBitmap().compress(Bitmap.CompressFormat.PNG,100,it)}
    }
    @Test fun sharedTypographyAndStatisticsMatchFlutterRoles() {
        val site=site()
        var muted=Color.Unspecified
        activity.setContent{OriginalTheme(site){
            muted=MaterialTheme.colorScheme.onSurfaceVariant
            Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
                Text("默认正文")
                Text("次要文字",style=MaterialTheme.typography.bodySmall)
                Text("小标题",style=MaterialTheme.typography.titleSmall)
                OriginalTabs(listOf("圈子","推荐","关注"),1){}
                StatRow(listOf("主题" to "123","帖子" to "456","积分" to "789"))
                SectionTitle("账号设置")
            }
        }}
        assertEquals(14.sp,layout("默认正文").layoutInput.style.fontSize)
        assertEquals(muted,layout("次要文字").layoutInput.style.color)
        assertEquals(muted,layout("小标题").layoutInput.style.color)
        assertEquals(15.sp,layout("推荐").layoutInput.style.fontSize)
        assertEquals(FontWeight.SemiBold,layout("推荐").layoutInput.style.fontWeight)
        assertEquals(FontWeight.Normal,layout("圈子").layoutInput.style.fontWeight)
        assertTrue(rule.onNodeWithText("主题").getUnclippedBoundsInRoot().bottom<rule.onNodeWithText("123").getUnclippedBoundsInRoot().top)
        assertEquals(15.sp,layout("账号设置").layoutInput.style.fontSize)
        assertEquals(muted,layout("账号设置").layoutInput.style.color)
        capture("shared-dark-parity")
    }
    @Test fun formsKeepTheFlutterTransparentBackgroundAndDialogsUse18spTitles() {
        val site=site();val show=mutableStateOf(false);val backdrop=Color(0xff345678)
        activity.setContent{OriginalTheme(site){
            Box(Modifier.fillMaxSize().background(backdrop)) {
                OriginalTextField("内容",{},modifier=Modifier.fillMaxWidth().testTag("field"),label={Text("正文")},colors=originalFieldColors())
                if(show.value)OriginalDialog(onDismissRequest={},confirmButton={},title={Text("确认提交")},text={Text("检查显示样式")})
            }
        }}
        val image=rule.onNodeWithTag("field").captureToImage().asAndroidBitmap()
        assertEquals(backdrop.toArgb(),image.getPixel(3,3))
        rule.runOnIdle{show.value=true}
        assertEquals(18.sp,layout("确认提交").layoutInput.style.fontSize)
        assertEquals(FontWeight.Bold,layout("确认提交").layoutInput.style.fontWeight)
    }
    @Test fun editorFieldPreservesSelectionWhenInsertingText() {
        val site=site()
        val value=mutableStateOf(androidx.compose.ui.text.input.TextFieldValue("前正文后",androidx.compose.ui.text.TextRange(1,3)))
        activity.setContent{OriginalTheme(site){OriginalTextField(value.value,{value.value=it},Modifier.testTag("editor"),minLines=10)}}
        rule.onNodeWithTag("editor").performTextInput("替换")
        rule.runOnIdle{assertEquals("前替换后",value.value.text);assertEquals(androidx.compose.ui.text.TextRange(3),value.value.selection)}
    }
    @Test fun nativeTaskTabsWrapAtLargeTypeWithoutLosingEqualColumns() {
        val site=site();site.setting("textScale",1.4f)
        mock(site){"""<div id="ct"><ul class="tb"><li class="a"><a href="/home.php?mod=task">新任务</a></li><li><a href="/home.php?mod=task&amp;item=doing">进行中的任务</a></li><li><a href="/home.php?mod=task&amp;item=done">已完成的任务</a></li><li><a href="/home.php?mod=task&amp;item=failed">失败的任务</a></li></ul><p>任务内容</p></div>"""}
        val nav=Nav()
        activity.setContent{OriginalTheme(site){PageFrame(site,nav,"native:$ORIGIN/home.php?mod=task",0,{})}}
        rule.waitUntil(5000){rule.onAllNodesWithText("进行中的任务").fetchSemanticsNodes().isNotEmpty()}
        val text=layout("进行中的任务")
        assertEquals(2,text.lineCount)
        assertFalse(text.hasVisualOverflow)
        val tabs=rule.onAllNodes(isSelectable()).fetchSemanticsNodes()
        assertEquals(4,tabs.size)
        assertEquals(tabs.first().boundsInRoot.width,tabs.last().boundsInRoot.width,1f)
        capture("tasks-dark-large-parity")
    }
    @Test fun profileTabsStayBelowTheCoverAndPinAtTheToolbar() {
        val site=site()
        mock(site){url->if(url.encodedPath.contains("/api/"))"""{"Variables":{"space":{"uid":"12","username":"测试用户","views":"123","following":"45","follower":"67","group":{"grouptitle":"会员"}}}}"""else "<div class='comiis_space_profile'><li><span>用户ID</span><b class='profile_rs'>12</b></li></div>"}
        val nav=Nav()
        activity.setContent{OriginalTheme(site){PageFrame(site,nav,"profile:12",0,{})}}
        rule.waitUntil(5000){rule.onAllNodesWithText("测试用户").fetchSemanticsNodes().isNotEmpty()}
        assertTrue(rule.onNodeWithText("资料").getUnclippedBoundsInRoot().top>rule.onNodeWithText("测试用户").getUnclippedBoundsInRoot().bottom)
        assertEquals(Color.White,layout("会员").layoutInput.style.color)
        capture("profile-dark-parity")
        rule.runOnIdle{site.setting("themeMode",1)}
        assertEquals(Color.White,layout("会员").layoutInput.style.color)
        rule.runOnIdle{site.setting("themeMode",2)}
        rule.onNodeWithText("最后访问").performScrollTo()
        assertTrue(rule.onNodeWithText("资料").getUnclippedBoundsInRoot().top<110.dp)
        rule.onNodeWithText("资料").assertIsDisplayed()
        capture("profile-pinned-parity")
    }
    @Test fun accountAvatarStaysLoadedWhenTheIdentityCardScrollsAway() {
        val app=ApplicationProvider.getApplicationContext<Application>()
        app.getSharedPreferences("compose.v1",0).edit().clear().putBoolean("imported",true)
            .putString("viewer.uid","12").putString("viewer.name","测试用户").commit()
        val site=Site(app,startSession=false)
        mock(site){"""{"Variables":{"space":{"uid":"12","threads":"1","posts":"2","credits":"3"}}}"""}
        val png=java.io.ByteArrayOutputStream().apply {
            Bitmap.createBitmap(8,8,Bitmap.Config.ARGB_8888).apply{eraseColor(android.graphics.Color.RED)}
                .compress(Bitmap.CompressFormat.PNG,100,this)
        }.toByteArray()
        val client=OkHttpClient.Builder().addInterceptor {chain->
            Response.Builder().request(chain.request()).protocol(Protocol.HTTP_1_1).code(200).message("OK")
                .body(png.toResponseBody("image/png".toMediaType())).build()
        }.build()
        coil.Coil.setImageLoader(coil.ImageLoader.Builder(activity).okHttpClient(client).build())
        activity.setContent{OriginalTheme(site){AccountPage(site,Nav())}}
        val avatar=rule.onNodeWithContentDescription("测试用户 的头像",useUnmergedTree=true)
        rule.waitUntil(5000){rule.onAllNodesWithContentDescription("测试用户 的头像",useUnmergedTree=true).fetchSemanticsNodes().isNotEmpty()}
        val list=rule.onNode(hasScrollToIndexAction())
        list.performScrollToIndex(2)
        avatar.assertIsNotDisplayed()
        list.performScrollToIndex(0)
        avatar.assertIsDisplayed()
        rule.onNodeWithContentDescription("测试用户 的默认头像",useUnmergedTree=true).assertDoesNotExist()
    }
    @Test fun accountPageMovesOnTheFirstSmallReverseDragEvent() {
        val site=site()
        val nav=Nav()
        var slop=0f
        activity.setContent {OriginalTheme(site){
            slop=androidx.compose.ui.platform.LocalViewConfiguration.current.touchSlop
            PageFrame(site,nav,"",3,{})
        }}
        val list=rule.onNode(hasScrollToIndexAction())
        fun scrollPosition():Float=list.fetchSemanticsNode().config[androidx.compose.ui.semantics.SemanticsProperties.VerticalScrollAxisRange].value()
        val initial=scrollPosition()
        list.performTouchInput {
            down(center)
            moveBy(androidx.compose.ui.geometry.Offset(0f,-slop*.25f))
            cancel()
        }
        assertEquals(initial,scrollPosition(),0f)
        list.performTouchInput {
            down(center)
            moveBy(androidx.compose.ui.geometry.Offset(0f,-slop*4))
            advanceEventTime(110)
            up()
        }
        val before=scrollPosition()
        assertTrue(before>initial)
        list.performTouchInput {
            down(center)
            moveBy(androidx.compose.ui.geometry.Offset(0f,slop*.25f))
        }
        assertEquals(before-slop*.25f,scrollPosition(),1f)
        list.performTouchInput{cancel()}
        rule.runOnIdle{assertTrue(nav.current.isEmpty())}
    }
    @Test fun accountPageReversesAtBothEdgesWithoutStretch() {
        val site=site()
        val overscroll=object:androidx.compose.foundation.OverscrollFactory {
            override fun equals(other:Any?)=this===other
            override fun hashCode()=System.identityHashCode(this)
            override fun createOverscrollEffect():androidx.compose.foundation.OverscrollEffect =
                error("The account list must not attach a stretch effect")
        }
        activity.setContent {OriginalTheme(site){
            CompositionLocalProvider(androidx.compose.foundation.LocalOverscrollFactory provides overscroll) {
                AccountPage(site,Nav())
            }
        }}
        val list=rule.onNode(hasScrollToIndexAction())
        fun axis()=list.fetchSemanticsNode().config[androidx.compose.ui.semantics.SemanticsProperties.VerticalScrollAxisRange]
        assertEquals(0f,axis().value(),0f)
        list.performTouchInput {
            down(center)
            moveBy(androidx.compose.ui.geometry.Offset(0f,80f))
            moveBy(androidx.compose.ui.geometry.Offset(0f,-8f))
        }
        assertTrue(axis().value()>0f)
        list.performTouchInput{cancel()}

        list.performSemanticsAction(SemanticsActions.ScrollBy){it(0f,10000f)}
        val bottom=axis().value()
        assertEquals(axis().maxValue(),bottom,0f)
        list.performTouchInput {
            down(center)
            moveBy(androidx.compose.ui.geometry.Offset(0f,-80f))
            moveBy(androidx.compose.ui.geometry.Offset(0f,8f))
        }
        assertTrue(axis().value()<bottom)
        list.performTouchInput{cancel()}
    }
    @Test fun predictiveBackMovesThePageAndCancellationRestoresIt() {
        val site=site();val nav=Nav()
        activity.setContent{OriginalTheme(site){CommunityApp(site,nav)}}
        rule.onNodeWithContentDescription("设置").performClick()
        val before=rule.onNodeWithText("设置").getUnclippedBoundsInRoot().left
        rule.runOnIdle {
            activity.onBackPressedDispatcher.dispatchOnBackStarted(BackEventCompat(0f,300f,0f,BackEventCompat.EDGE_LEFT))
            activity.onBackPressedDispatcher.dispatchOnBackProgressed(BackEventCompat(100f,300f,.3f,BackEventCompat.EDGE_LEFT))
        }
        assertTrue(rule.onNodeWithText("设置").getUnclippedBoundsInRoot().left>before+80.dp)
        rule.runOnIdle{activity.onBackPressedDispatcher.dispatchOnBackCancelled()}
        rule.waitForIdle()
        assertEquals(before,rule.onNodeWithText("设置").getUnclippedBoundsInRoot().left)
        rule.mainClock.autoAdvance=false
        val exiting=nav.pages.last()
        rule.runOnIdle {
            activity.onBackPressedDispatcher.dispatchOnBackStarted(BackEventCompat(0f,300f,0f,BackEventCompat.EDGE_LEFT))
            activity.onBackPressedDispatcher.dispatchOnBackProgressed(BackEventCompat(100f,300f,.65f,BackEventCompat.EDGE_LEFT))
        }
        rule.mainClock.advanceTimeByFrame()
        assertEquals(.65f,exiting.offset.value,.001f)
        rule.runOnIdle{activity.onBackPressedDispatcher.onBackPressed()}
        var previous=.65f
        repeat(16) {
            rule.mainClock.advanceTimeByFrame()
            rule.runOnIdle {
                assertTrue("The exiting page must never return to its start",exiting.offset.value>=previous)
                if(nav.exiting==null)assertEquals(1f,exiting.offset.value,0f)
                previous=exiting.offset.value
            }
        }
        rule.mainClock.autoAdvance=true
        rule.waitForIdle()
        rule.onNodeWithText("我的内容").assertIsDisplayed()
    }
    @Test fun articleToolbarBackKeepsTheSameUnderlyingPageUntilExitCompletes() {
        val site=site();val nav=Nav()
        site.remember(Topic("123","本地测试文章"))
        mock(site) { """{"Variables":{"thread":{"subject":"本地测试文章"},"postlist":[]}}""" }
        activity.setContent{OriginalTheme(site){CommunityApp(site,nav)}}
        rule.onNodeWithText("阅读历史").performScrollTo().performClick()
        rule.mainClock.advanceTimeBy(400)
        rule.waitForIdle()
        val article=rule.onNodeWithText("本地测试文章",useUnmergedTree=true)
        val position=article.getUnclippedBoundsInRoot()
        val history=nav.pages.last()
        article.performTouchInput{click()}
        rule.mainClock.advanceTimeBy(400)
        rule.waitForIdle()
        val thread=nav.pages.last()
        assertEquals("thread:123",thread.route)
        assertEquals("Detail slide must have settled",0f,thread.offset.value,.001f)
        val title=rule.onNodeWithText("帖子详情")
        assertTrue("Detail bounds ${title.getUnclippedBoundsInRoot()}",title.isDisplayed())
        rule.mainClock.autoAdvance=false
        rule.onNodeWithContentDescription("返回").performSemanticsAction(SemanticsActions.OnClick) { it() }
        repeat(6) { rule.mainClock.advanceTimeByFrame(); rule.waitForIdle() }
        rule.runOnIdle {
            assertSame(thread,nav.exiting)
            assertSame(history,nav.pages.last())
            assertTrue("Exit must still be in progress: ${thread.offset.value}", thread.offset.value > 0f && thread.offset.value < 1f)
        }
        rule.mainClock.autoAdvance=true
        rule.waitForIdle()
        rule.runOnIdle{assertNull(nav.exiting);assertEquals(1f,thread.offset.value,0f)}
        assertEquals(position,article.getUnclippedBoundsInRoot())
    }
    @Test fun bodyImagesKeepIntrinsicSizeAndRespectBothBounds() {
        val small=androidx.compose.ui.geometry.Size(80f,120f)
        assertEquals(small,fitBodyImage(small,360f))
        assertEquals(androidx.compose.ui.geometry.Size(220f,440f),fitBodyImage(androidx.compose.ui.geometry.Size(600f,1200f),360f))
        assertEquals(androidx.compose.ui.geometry.Size(360f,180f),fitBodyImage(androidx.compose.ui.geometry.Size(1200f,600f),360f))
    }
    @Test fun glassDragUsesFlutterRubberBandAtBothEdges() {
        assertEquals(0f,glassDragFraction(50f,400f),.0001f)
        assertEquals(.5f,glassDragFraction(200f,400f),.0001f)
        assertEquals(-.06666667f,glassDragFraction(-100f,400f),.0001f)
        assertEquals(1.06666667f,glassDragFraction(500f,400f),.0001f)
    }
    @Test fun playbackTimesKeepTwoDigitsAndHours() {
        assertEquals("00:00",formatDuration(0));assertEquals("01:05",formatDuration(65_000))
        assertEquals("01:01:05",formatDuration(3_665_000))
    }
    @Test fun sliderKeepsTheRound20dpThumbAndAcceptsDragInput() {
        val site=site();val value=mutableFloatStateOf(.5f)
        activity.setContent{OriginalTheme(site){OriginalSlider(value.floatValue,{value.floatValue=it},Modifier.fillMaxWidth().testTag("slider"))}}
        rule.onNodeWithTag("slider-thumb",useUnmergedTree=true).assertWidthIsEqualTo(20.dp).assertHeightIsEqualTo(20.dp)
        rule.onNodeWithTag("slider").performTouchInput{swipe(center,androidx.compose.ui.geometry.Offset(width*.8f,center.y))}
        rule.runOnIdle{assertTrue(value.floatValue>.7f)}
    }

    @Test fun cloudGuestAndResponseErrorsRemainExplicit() {
        val site=site();val nav=Nav()
        activity.setContent{OriginalTheme(site){CloudPage(site,nav)}}
        rule.onNodeWithText("登录云盘").assertIsDisplayed()
        rule.onNodeWithContentDescription("上传文件").assertDoesNotExist()
        rule.onNodeWithText("登录云盘").performClick();assertEquals("login",nav.current);assertEquals("cloud",nav.afterLogin)
        assertEquals("1",cloudResponse("""{"sta":1}""").optString("sta"))
        listOf("<html>登录</html>","""{"sta":0,"msg":"拒绝"}""","""{"data":{}}""").forEach{assertTrue(runCatching{cloudResponse(it)}.isFailure)}
    }

    @Test fun avatarAndQrMarginsMatchTheOriginalWithoutLosingQrContent() {
        val site=site();val url="$ORIGIN/?fromuid=12"
        activity.setContent{OriginalTheme(site){Column{SiteAvatar("","访客");QrCode(url,"检查二维码",Modifier.testTag("qr"))}}}
        rule.onNodeWithContentDescription("访客 的默认头像").assertWidthIsEqualTo(32.dp).assertHeightIsEqualTo(32.dp)
        val bitmap=rule.onNodeWithTag("qr").captureToImage().asAndroidBitmap()
        val edge=(bitmap.width*10f/220).toInt()
        for(y in 0 until bitmap.height)for(x in 0 until edge-1){assertEquals(android.graphics.Color.WHITE,bitmap.getPixel(x,y));assertEquals(android.graphics.Color.WHITE,bitmap.getPixel(bitmap.width-1-x,y))}
        val pixels=IntArray(bitmap.width*bitmap.height);bitmap.getPixels(pixels,0,bitmap.width,0,0,bitmap.width,bitmap.height)
        val source=com.google.zxing.RGBLuminanceSource(bitmap.width,bitmap.height,pixels)
        val decoded=com.google.zxing.qrcode.QRCodeReader().decode(com.google.zxing.BinaryBitmap(com.google.zxing.common.HybridBinarizer(source)))
        assertEquals(url,decoded.text)
    }
}
