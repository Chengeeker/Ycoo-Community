package ycoo.net.php

import android.app.Application
import android.graphics.Bitmap
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
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
@Config(sdk=[35])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class CloudUiTest {
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
    // Robolectric #8460: explicit width/height qualifiers can loop while a dialog text field focuses.
    @Test fun cloudPageKeepsNativeFoldersAndConfirmsRenameOnce() {
        val base=site();base.prefs.edit().putString("viewer.uid","12").putString("viewer.name","测试账户").commit()
        val site=Site(ApplicationProvider.getApplicationContext(),startSession=false)
        val mutations=java.util.concurrent.CopyOnWriteArrayList<String>()
        val client=OkHttpClient.Builder().addInterceptor {chain->
            val request=chain.request();val fields=request.body as? FormBody
            fun value(key:String)=fields?.let{f->(0 until f.size).firstOrNull{f.name(it)==key}?.let{f.value(it)}}
            val ac=value("ac")
            val body=when(ac) {
                "config" -> """{"sta":1,"data":{"storageType":"local"}}"""
                "getUserInfo" -> """{"sta":1,"data":{"capacity":"1024","spaceSize":"8192"}}"""
                "fileDisplay" -> """{"sta":1,"cList":[{"cid":"5","pid":"0","c_name":"原版文件夹"}],"fList":[{"id":"9","cid":"0","name":"测试文件.txt","sizeText":"1 KB","link":"https://ycoo.net/file.txt"}],"pid":"0","maxPage":2}"""
                "reName" -> {assertEquals("abcdefgh",value("formhash"));assertEquals("classify",value("type"));assertEquals("5",value("sid"));mutations.add(value("name").orEmpty());"""{"sta":1,"msg":"操作已完成"}"""}
                null -> "<script>var data={'formhash':'abcdefgh'};</script>"
                else -> error("Unexpected cloud operation $ac")
            }
            Response.Builder().request(request).protocol(Protocol.HTTP_1_1).code(200).message("OK").body(body.toResponseBody("text/plain".toMediaType())).build()
        }.build()
        Site::class.java.getDeclaredField("client").apply{isAccessible=true}.set(site,client)
        val nav=Nav();nav.route("$ORIGIN/plugin.php?id=bphp_clouds:index&mobile=2");assertEquals("cloud",nav.current)
        activity.setContent{OriginalTheme(site){PageFrame(site,nav,"cloud",0,{})}}
        rule.waitUntil(10000){rule.onAllNodesWithText("原版文件夹").fetchSemanticsNodes().isNotEmpty()}
        rule.onNodeWithText("已用 1024 / 8192 字节").assertIsDisplayed()
        rule.onNodeWithText("1 / 2").assertIsDisplayed()
        rule.onAllNodesWithContentDescription("更多操作")[0].performClick()
        rule.onNodeWithText("重命名").performClick()
        assertTrue(mutations.isEmpty())
        rule.onNode(hasSetTextAction() and hasText("原版文件夹")).assertIsFocused().performTextReplacement("重命名结果")
        rule.onNodeWithText("确认").performClick()
        rule.waitUntil(10000){rule.waitForIdle();mutations.size==1}
        rule.waitUntil(10000){rule.onAllNodes(hasContentDescription("更多操作") and isEnabled()).fetchSemanticsNodes().size==2}
        assertEquals(listOf("重命名结果"),mutations)
        rule.mainClock.advanceTimeByFrame();rule.waitForIdle()
        val upload=rule.onNodeWithContentDescription("上传文件")
        upload.assertIsDisplayed()
        val bounds=upload.fetchSemanticsNode().boundsInRoot
        val bitmap=rule.onRoot().captureToImage().asAndroidBitmap()
        var visible=false
        for(y in bounds.top.toInt() until bounds.bottom.toInt())for(x in bounds.left.toInt() until bounds.right.toInt()){
            val pixel=bitmap.getPixel(x,y)
            if(android.graphics.Color.red(pixel)>160&&android.graphics.Color.green(pixel)>160&&android.graphics.Color.blue(pixel)>160)visible=true
        }
        assertTrue("Upload glyph must be visible in the complete recorded page",visible)
        val output=File("build/previews/cloud-dark-parity.png");output.parentFile!!.mkdirs()
        output.outputStream().use{bitmap.compress(Bitmap.CompressFormat.PNG,100,it)}
    }
}
