package ycoo.net.php

import android.app.Application
import android.graphics.Bitmap
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
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

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[35],qualifiers="w393dp-h873dp-xhdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class GalleryAnimationTest {
    @get:Rule val rule=createEmptyComposeRule()
    private lateinit var controller:org.robolectric.android.controller.ActivityController<ComponentActivity>
    private lateinit var activity:ComponentActivity
    @Before fun launch(){controller=Robolectric.buildActivity(ComponentActivity::class.java).setup().visible();activity=controller.get()}
    @After fun dispose(){controller.pause().stop().destroy()}
    private fun bitmap(color:Int)=Bitmap.createBitmap(200,100,Bitmap.Config.ARGB_8888).apply{eraseColor(color)}.asImageBitmap()

    @Test fun heroUsesFlutterForwardAndFlippedReverseCurves(){
        assertEquals(.77556f,galleryHeroProgress(.5f,false),.0002f)
        assertEquals(.22444f,galleryHeroProgress(.5f,true),.0002f)
        for(closing in listOf(false,true)){
            assertEquals(0f,galleryHeroProgress(0f,closing),0f)
            assertEquals(1f,galleryHeroProgress(1f,closing),0f)
        }
    }
    @Test fun returnKeepsTheZoomedPannedPlaneAndEndsAtTheCoverCrop(){
        val image=bitmap(android.graphics.Color.RED)
        val origin=Rect(20f,80f,120f,180f)
        val plane=galleryImagePlane(Size(200f,100f),Size(400f,800f),zoom=2f,offset=Offset(40f,-30f))
        assertEquals(Rect(-160f,170f,640f,570f),plane)
        val start=GalleryFlightFrame(image,Rect(0f,0f,400f,800f),plane)
        assertEquals(start,galleryReturnFrame(start,origin,true,1f))
        val end=galleryReturnFrame(start,origin,true,0f)
        assertEquals(origin,end.viewport)
        assertEquals(Rect(-50f,0f,150f,100f),end.plane)
        val croppedPreview=galleryReturnFrame(start,origin,true,0f,targetImage=Size(80f,80f))
        assertEquals(Rect(0f,0f,100f,100f),croppedPreview.plane)
        val contained=galleryReturnFrame(start,origin,false,1f)
        assertEquals(start.plane,contained.plane)
        val middle=galleryReturnFrame(start,origin,true,.5f)
        assertEquals(Rect(-105f,85f,395f,335f),middle.plane)
    }
    @Test fun retainedPreviewStaysOpaqueInFlightAndReentryContinuesFromTheClosingFrame(){
        val app=ApplicationProvider.getApplicationContext<Application>()
        app.getSharedPreferences("compose.v1",0).edit().clear().putBoolean("imported",true).commit()
        val site=Site(app,startSession=false);val nav=Nav();val owner=Any()
        val retained=bitmap(android.graphics.Color.RED)
        val bytes=java.io.ByteArrayOutputStream().apply{bitmap(android.graphics.Color.GREEN).asAndroidBitmap().compress(Bitmap.CompressFormat.PNG,100,this)}.toByteArray()
        coil.Coil.setImageLoader(coil.ImageLoader.Builder(activity).okHttpClient(OkHttpClient.Builder().addInterceptor{chain->Response.Builder().request(chain.request()).protocol(Protocol.HTTP_1_1).code(200).message("OK").body(bytes.toResponseBody("image/png".toMediaType())).build()}.build()).build())
        val origin=Rect(40f,120f,240f,260f);val urls=listOf("$ORIGIN/hero-original.png")
        val session=nav.showGallery(urls,origins=mapOf(0 to origin),source=owner,decoded=mapOf(0 to retained))
        rule.mainClock.autoAdvance=false
        activity.setContent{OriginalTheme(site){Box(Modifier.fillMaxSize().background(Color.Green)){GalleryHost(site,nav)}}}
        rule.mainClock.advanceTimeBy(176);rule.waitForIdle()
        rule.onNodeWithTag("gallery-flight").assertExists()
        val frame=session.snapshot!!.invoke()!!
        assertSame(retained,frame.bitmap)
        val pixels=rule.onRoot().captureToImage().asAndroidBitmap()
        java.io.File("build/previews/gallery-opening-retained.png").apply{parentFile.mkdirs()}.outputStream().use{pixels.compress(Bitmap.CompressFormat.PNG,100,it)}
        val fraction=(frame.viewport.width-origin.width)/(pixels.width-origin.width)
        assertTrue("Hero must already be past linear halfway ($fraction)",fraction in .65f.. .95f)
        assertEquals(android.graphics.Color.RED,pixels.getPixel(frame.viewport.center.x.toInt(),frame.viewport.center.y.toInt()))
        assertTrue(android.graphics.Color.green(pixels.getPixel(5,5)) in 40..220)
        rule.mainClock.advanceTimeBy(600);rule.waitForIdle()
        rule.onNodeWithTag("gallery-flight").assertDoesNotExist()
        rule.runOnIdle{activity.onBackPressedDispatcher.onBackPressed()}
        rule.mainClock.advanceTimeBy(80);rule.waitForIdle()
        val closingPixels=rule.onRoot().captureToImage().asAndroidBitmap()
        java.io.File("build/previews/gallery-closing-plane.png").outputStream().use{closingPixels.compress(Bitmap.CompressFormat.PNG,100,it)}
        lateinit var next:GallerySession
        rule.runOnIdle{
            val before=session.snapshot!!.invoke()
            next=nav.showGallery(urls,origins=mapOf(0 to origin),source=owner,decoded=mapOf(0 to retained))
            assertEquals(before,next.resumed)
        }
        rule.mainClock.advanceTimeBy(600);rule.waitForIdle()
        rule.runOnIdle{assertSame(next,nav.gallery);assertFalse(next.closing);assertFalse(next.flying)}
        rule.onNodeWithContentDescription("返回").assertIsDisplayed()
        rule.onNodeWithContentDescription("图片 1").performTouchInput{doubleClick(center)}
        rule.mainClock.advanceTimeBy(400);rule.waitForIdle()
        val zoomed=next.snapshot!!.invoke()!!
        assertEquals(pixels.width*2.5f,zoomed.plane.width,2f)
        rule.mainClock.autoAdvance=true
    }
}
