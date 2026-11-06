package ycoo.net.php

import android.graphics.Bitmap
import android.os.Build
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.layer.*
import androidx.compose.ui.layout.*
import androidx.compose.ui.platform.*
import androidx.compose.ui.unit.*
import kotlinx.coroutines.*

class Backdrop(val layer:GraphicsLayer) {
    var origin=Offset.Zero
    var frame=0L
    var recording=false
}
val LocalBackdrop=staticCompositionLocalOf<Backdrop?>{null}
@Composable fun rememberBackdrop():Backdrop {val layer=rememberGraphicsLayer();return remember(layer){Backdrop(layer)}}
fun Modifier.recordBackdrop(state:Backdrop)=onGloballyPositioned{state.origin=it.positionInRoot()}.drawWithContent{
    state.recording=true
    try{state.layer.record{this@drawWithContent.drawContent()}}finally{state.recording=false}
    state.frame++;drawLayer(state.layer)
}
data class GlassStyle(val color:Color,val radius:Float=9999f,val thickness:Float=10f,val refractive:Float=1.19f,val chromatic:Float=.008f,val indicator:Boolean=false,val interaction:Float=0f,val dark:Boolean=false,val rim:Float=1f,val gallery:Boolean=false)
fun glassUniforms(style:GlassStyle,width:Float,height:Float,density:Float):Map<String,FloatArray> {
    if(style.gallery)return mapOf("u_size" to floatArrayOf(width,height))
    val dprScale=density/3f;val shade=if(style.indicator&&!style.dark).12f else 0f
    return mapOf(
        "uSize" to floatArrayOf(width,height),"uGeometryOffset" to floatArrayOf(0f,0f),"uGeometrySize" to floatArrayOf(width,height),
        "uGlassColor" to floatArrayOf(style.color.red,style.color.green,style.color.blue,style.color.alpha),
        "uOpticalProps" to floatArrayOf(style.refractive,style.chromatic,style.thickness*dprScale,1f),
        "uLightConfig" to floatArrayOf(if(style.indicator)2f else .25f,0f,1.5f),"uLightDirection" to floatArrayOf(-.70710677f,-.70710677f),
        "uWhiten" to floatArrayOf(0f),"uWhitenGated" to floatArrayOf(1f),"uPinchStrength" to floatArrayOf(style.interaction),
        "uBackgroundFallback" to floatArrayOf(0f,0f,0f,0f),"uCaptureOffset" to floatArrayOf(0f,0f),"uEdgeConfig" to floatArrayOf(0f,1f,dprScale,0f),
        "uPlatformViewMode" to floatArrayOf(0f),"uBodyMode" to floatArrayOf(1f),"uTouchPosition" to floatArrayOf(0f,0f),"uTouchIntensity" to floatArrayOf(0f),
        "uRimConfig" to floatArrayOf(shade,style.rim,.2f),"uLensModel" to floatArrayOf(0f),"uFrost" to floatArrayOf(0f,0f,0f,1f),"uBodyShade" to floatArrayOf(0f),
        "uDpr" to floatArrayOf(density),"uRadius" to floatArrayOf(minOf(style.radius*density,width/2,height/2)),"uNativeEdge" to floatArrayOf(if(shade>0)1f else 0f)
    )
}
fun Modifier.backdrop(blur:Dp,glass:GlassStyle?=null,state:Backdrop?=null,overlay:Backdrop?=null):Modifier=composed {
    val backdrop=state ?: LocalBackdrop.current ?: return@composed this
    val context=LocalContext.current;val density=LocalDensity.current.density;val active=LocalPageActive.current
    val crop=rememberGraphicsLayer()
    var origin by remember{mutableStateOf(Offset.Zero)}
    var dimensions by remember{mutableStateOf(IntSize.Zero)}
    val blurPixels=blur.value*density
    // Keep real pixels from either side of a frosted header edge in the blur kernel.
    val margin=if(glass==null) kotlin.math.ceil(blurPixels*3).toInt() else 0
    val blurEffect=remember(blurPixels) {
        if(Build.VERSION.SDK_INT>=31 && blurPixels>0f)
            android.graphics.RenderEffect.createBlurEffect(blurPixels,blurPixels,android.graphics.Shader.TileMode.CLAMP)
        else null
    }
    var legacy by remember{mutableStateOf<ImageBitmap?>(null)}
    val shaderName=if(glass?.gallery==true)"gallery_glass_button"else "premium_glass"
    val shader=if(Build.VERSION.SDK_INT>=33&&glass!=null)remember(shaderName){android.graphics.RuntimeShader(context.assets.open("glass/$shaderName.agsl").bufferedReader().use{it.readText()})}else null
    val latestGlass by rememberUpdatedState(glass);val latestBlur by rememberUpdatedState(blur)
    if(Build.VERSION.SDK_INT<31||(glass!=null&&Build.VERSION.SDK_INT<33))LaunchedEffect(backdrop,overlay,active,shaderName,density){
        if(!active)return@LaunchedEffect
        var frame=-1L
        var overlayFrame=-1L
        var previousStyle:GlassStyle?=null
        var previousBlur=Dp.Unspecified
        var previousOrigin=Offset.Unspecified
        var previousSize=IntSize.Zero
        while(isActive) {
            val style=latestGlass
            val blurDp=latestBlur
            val size=dimensions
            val sampleOrigin=origin
            val currentOverlayFrame=overlay?.frame ?: 0L
            val changed=frame!=backdrop.frame || overlayFrame!=currentOverlayFrame || previousStyle!=style ||
                previousBlur!=blurDp || previousOrigin!=sampleOrigin || previousSize!=size
            if(changed && crop.size.width>0 && crop.size.height>0 && size.width>0 && size.height>0) {
                frame=backdrop.frame
                overlayFrame=currentOverlayFrame
                previousStyle=style
                previousBlur=blurDp
                previousOrigin=sampleOrigin
                previousSize=size
                val bitmap=crop.toImageBitmap().asAndroidBitmap()
                legacy=withContext(Dispatchers.Default) {
                    val blurred=legacyBlur(context,bitmap,blurDp.value*density)
                    if(style==null)blurred.asImageBitmap()else try {
                        LegacyGlass.render(context,shaderName,blurred,glassUniforms(style,size.width.toFloat(),size.height.toFloat(),density)).asImageBitmap()
                    }catch(e:Exception){if(e is CancellationException)throw e;blurred.asImageBitmap()}
                }
            }
            delay(32)
        }
    }
    this.onGloballyPositioned{origin=it.positionInRoot();dimensions=it.size}.drawWithCache{
        // A new effect inside onDraw invalidates the containing layer again, even at rest.
        crop.renderEffect=if(Build.VERSION.SDK_INT>=33&&shader!=null&&glass!=null){
            glassUniforms(glass,size.width,size.height,density).forEach{(k,v)->shader.setFloatUniform(k,v)}
            shader.setFloatUniform("textureSize",size.width,size.height)
            val refraction=android.graphics.RenderEffect.createRuntimeShaderEffect(shader,if(glass.gallery)"u_texture_input"else "uBackgroundTexture")
            (blurEffect?.let{android.graphics.RenderEffect.createChainEffect(refraction,it)} ?: refraction).asComposeRenderEffect()
        }else if(Build.VERSION.SDK_INT>=31&&glass==null)blurEffect?.asComposeRenderEffect()else null
        onDrawWithContent {
        if(backdrop.recording||overlay?.recording==true){drawContent();return@onDrawWithContent}
        val sampleSize=IntSize((size.width.toInt()+2*margin).coerceAtLeast(1),(size.height.toInt()+2*margin).coerceAtLeast(1))
        crop.record(size=sampleSize) {
            clipRect(0f,0f,sampleSize.width.toFloat(),sampleSize.height.toFloat()) {
                val position=origin-backdrop.origin
                translate(margin-position.x,margin-position.y){drawLayer(backdrop.layer)}
                if(overlay!=null) {
                    val barPosition=origin-overlay.origin
                    translate(margin-barPosition.x,margin-barPosition.y){drawLayer(overlay.layer)}
                }
            }
        }
        if(Build.VERSION.SDK_INT>=31&&(glass==null||Build.VERSION.SDK_INT>=33)){
            clipRect {translate(-margin.toFloat(),-margin.toFloat()){drawLayer(crop)}}
        }else legacy?.let{bitmap->
            if(bitmap.width==sampleSize.width&&bitmap.height==sampleSize.height) {
                clipRect {drawImage(bitmap,dstOffset=IntOffset(-margin,-margin),dstSize=sampleSize)}
            }
        }
        drawContent()
        }
    }
}
@Suppress("DEPRECATION")
private fun legacyBlur(context:android.content.Context,source:Bitmap,sigma:Float):Bitmap {
    if(sigma<.1f)return source
    val radius=(sigma/.4f).coerceAtLeast(1f);val scale=(radius/24f).coerceAtLeast(1f)
    val small=Bitmap.createScaledBitmap(source,(source.width/scale).toInt().coerceAtLeast(1),(source.height/scale).toInt().coerceAtLeast(1),true).copy(Bitmap.Config.ARGB_8888,true)
    val rs=android.renderscript.RenderScript.create(context)
    val input=android.renderscript.Allocation.createFromBitmap(rs,small);val output=android.renderscript.Allocation.createTyped(rs,input.type);val blur=android.renderscript.ScriptIntrinsicBlur.create(rs,android.renderscript.Element.U8_4(rs))
    try{blur.setRadius((radius/scale).coerceIn(.1f,25f));blur.setInput(input);blur.forEach(output);output.copyTo(small)}finally{blur.destroy();input.destroy();output.destroy();rs.destroy()}
    return if(small.width==source.width&&small.height==source.height)small else Bitmap.createScaledBitmap(small,source.width,source.height,true)
}
