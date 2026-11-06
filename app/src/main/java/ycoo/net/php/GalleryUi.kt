package ycoo.net.php

import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.*
import androidx.compose.foundation.interaction.collectIsDraggedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.input.pointer.*
import androidx.compose.ui.layout.*
import androidx.compose.ui.platform.*
import androidx.compose.ui.semantics.*
import androidx.compose.ui.unit.*
import coil.compose.AsyncImage
import android.graphics.drawable.BitmapDrawable
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.painter.BitmapPainter
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlin.math.*

class GallerySession(images:List<String>,val initial:Int,val previews:List<String>,val origins:Map<Int,Rect>,val coverOrigin:Boolean=true,val source:Any?=null,decoded:Map<Int,ImageBitmap> = emptyMap()) {
    var images by mutableStateOf(images)
    var closing by mutableStateOf(false)
    var flying by mutableStateOf(true)
    var current by mutableIntStateOf(initial)
    val decoded=decoded.toList().toMutableStateMap()
    val sourceImages=decoded.toMap()
    val openingImage=decoded[initial]
    var resumed:GalleryFlightFrame?=null
    var snapshot:(()->GalleryFlightFrame?)?=null
}
fun Modifier.gallerySource(nav:Nav,source:Any,index:Int)=graphicsLayer {
    val gallery=nav.gallery
    alpha=if(gallery?.source===source&&gallery.flying&&gallery.current==index)0f else 1f
}
data class GalleryFlightFrame(val bitmap:ImageBitmap,val viewport:Rect,val plane:Rect,val opacity:Float=1f)
fun nextGalleryZoom(current:Float,longImage:Boolean)=if(current<=1.05f){if(longImage)3.5f else 2.5f}else if(current<=3.6f)6f else 1f
fun galleryHeroProgress(progress:Float,closing:Boolean):Float = if(closing)1f-FastOutSlowInEasing.transform(1f-progress)else FastOutSlowInEasing.transform(progress)
fun galleryImagePlane(image:Size,viewport:Size,cover:Boolean=false,zoom:Float=1f,offset:Offset=Offset.Zero):Rect {
    val scale=(if(cover)max(viewport.width/image.width,viewport.height/image.height)else min(viewport.width/image.width,viewport.height/image.height))*zoom
    val plane=image*scale
    return Rect(Offset((viewport.width-plane.width)/2,(viewport.height-plane.height)/2)+offset,plane)
}
fun galleryReturnSize(image:Size,origin:Size,viewport:Size,progress:Float,zoom:Float):Size {
    return androidx.compose.ui.geometry.lerp(galleryImagePlane(image,origin,true),galleryImagePlane(image,viewport,zoom=zoom),progress).size
}
fun galleryReturnFrame(start:GalleryFlightFrame,origin:Rect,cover:Boolean,progress:Float,targetImage:Size?=null):GalleryFlightFrame {
    val viewport=androidx.compose.ui.geometry.lerp(origin,start.viewport,progress)
    val pixels=Size(start.bitmap.width.toFloat(),start.bitmap.height.toFloat())
    val plane=if(cover)androidx.compose.ui.geometry.lerp(galleryImagePlane(targetImage ?: pixels,origin.size,true),start.plane,progress)
        else if(progress==1f)start.plane else {
            // ExtendedImage's contain shuttle retains zoom and recentres on a new layout.
            val zoom=start.plane.width/galleryImagePlane(pixels,start.viewport.size).width
            galleryImagePlane(pixels,viewport.size,zoom=zoom)
        }
    return GalleryFlightFrame(start.bitmap,viewport,plane)
}
fun clampGalleryOffset(offset:Offset,scale:Float,viewport:Size,image:Size):Offset {
    if(image.width<=0||image.height<=0)return Offset.Zero
    val fit=min(viewport.width/image.width,viewport.height/image.height)
    val x=max(0f,(image.width*fit*scale-viewport.width)/2);val y=max(0f,(image.height*fit*scale-viewport.height)/2)
    return Offset(offset.x.coerceIn(-x,x),offset.y.coerceIn(-y,y))
}
@Composable fun GalleryHost(site:Site,nav:Nav) {
    val session=nav.gallery ?: return
    if(session.images.isEmpty())return
    key(session){GalleryViewer(site,nav,session)}
}
@Composable private fun GalleryViewer(site:Site,nav:Nav,session:GallerySession) {
    val context=LocalContext.current;val scope=rememberCoroutineScope();val progress=remember{Animatable(0f)};val returning=remember{Animatable(1f)}
    val flightPaint=remember{android.graphics.Paint(android.graphics.Paint.FILTER_BITMAP_FLAG)}
    val backdrop=rememberBackdrop();var slide by remember{mutableFloatStateOf(0f)};var sliding by remember{mutableStateOf(false)}
    val pager=rememberPagerState(initialPage=session.initial.coerceIn(session.images.indices),pageCount={session.images.size})
    var chrome by remember{mutableStateOf(true)};var saving by remember{mutableStateOf(false)};var zoomed by remember{mutableStateOf(false)}
    var currentScale by remember{mutableFloatStateOf(1f)};var currentOffset by remember{mutableStateOf(Offset.Zero)}
    var returnStart by remember{mutableStateOf<GalleryFlightFrame?>(null)};var returnOpacity by remember{mutableFloatStateOf(1f)}
    val reduced=android.provider.Settings.Global.getFloat(context.contentResolver,android.provider.Settings.Global.ANIMATOR_DURATION_SCALE,1f)==0f
    LaunchedEffect(session.closing){if(!session.closing){progress.animateTo(1f,tween(if(reduced)0 else 330,easing=LinearEasing));session.flying=false}}
    fun save(){if(saving)return;saving=true;val url=session.images[pager.currentPage];scope.launch{try{saveGalleryImage(context,site,url);site.status="图片已保存至相册"}catch(e:Exception){if(e is CancellationException)throw e;site.status="保存失败：${e.message}"}finally{saving=false}}}
    val permission=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()){allowed->if(allowed)save()else site.status="未授予相册写入权限"}
    val controls by animateFloatAsState(if(chrome&&!sliding&&!session.closing&&!session.flying)1f else 0f,tween(140),label="gallery controls")
    CompositionLocalProvider(LocalBackdrop provides backdrop){BoxWithConstraints(Modifier.fillMaxSize()) {
        val full=Rect(0f,0f,constraints.maxWidth.toFloat(),constraints.maxHeight.toFloat())
        val origin=session.origins[pager.currentPage] ?: full
        val hasHero=session.origins.containsKey(pager.currentPage)
        fun frame():GalleryFlightFrame? {
            if(session.closing)return returnStart?.let{galleryReturnFrame(it,origin,session.coverOrigin,galleryHeroProgress(returning.value,true),session.sourceImages[pager.currentPage]?.let{image->Size(image.width.toFloat(),image.height.toFloat())}).copy(opacity=returnOpacity*returning.value)}
            val bitmap=(if(progress.value<1f)session.resumed?.bitmap ?: session.openingImage else null) ?: session.decoded[pager.currentPage] ?: return null
            val pixels=Size(bitmap.width.toFloat(),bitmap.height.toFloat())
            val t=galleryHeroProgress(progress.value,false)
            val rect=androidx.compose.ui.geometry.lerp(session.resumed?.viewport ?: origin,full,t)
            val shrink=(1-abs(slide)/(full.width/2)).coerceAtLeast(.8f)
            val visible=Rect(rect.center+Offset(slide,0f)-Offset(rect.width*shrink/2,rect.height*shrink/2),rect.size*shrink)
            val plane=session.resumed?.takeIf{progress.value<1f}?.let{androidx.compose.ui.geometry.lerp(it.plane,galleryImagePlane(pixels,full.size),t)}
                ?: galleryImagePlane(pixels,visible.size,zoom=currentScale,offset=currentOffset*shrink)
            return GalleryFlightFrame(bitmap,visible,plane,((session.resumed?.opacity ?: 0f)*(1-progress.value)+progress.value)*(1-abs(slide)/(full.width/2)).coerceIn(0f,1f))
        }
        val latestFrame by rememberUpdatedState(::frame)
        DisposableEffect(session){session.snapshot={latestFrame()};onDispose{session.snapshot=null}}
        fun close(){
            if(session.closing)return
            returnStart=frame();returnOpacity=returnStart?.opacity ?: progress.value
            session.flying=true;session.closing=true
            scope.launch{ returning.animateTo(0f,tween(if(reduced)0 else 200,easing=LinearEasing));if(nav.gallery===session)nav.gallery=null }
        }
        BackHandler{close()}
        val dragModifier=if(session.closing)Modifier else Modifier.pointerInput(session,zoomed){awaitEachGesture{
            val down=awaitFirstDown(requireUnconsumed=false);var accepted=false
            if(!zoomed&&progress.value==1f){val start=awaitHorizontalTouchSlopOrCancellation(down.id){change,over->
                if((pager.currentPage==0&&over>0)||(pager.currentPage==session.images.lastIndex&&over<0)){change.consume();accepted=true;slide=over;sliding=true}}
                if(start!=null&&accepted){val end=horizontalDrag(start.id){change->slide+=change.positionChange().x;change.consume()}
                    if(end&&abs(slide)>size.width/6f)close()else scope.launch{animate(slide,0f,animationSpec=tween(200)){value,_->slide=value};sliding=false}
                }
            }
        }}
        Box(Modifier.fillMaxSize().recordBackdrop(backdrop).drawBehind{
            val opacity=if(session.closing)returnOpacity*returning.value else ((session.resumed?.opacity ?: 0f)*(1-progress.value)+progress.value)*(1-abs(slide)/(full.width/2)).coerceIn(0f,1f)
            drawRect(Color.Black.copy(alpha=opacity))
        }.then(dragModifier)){
            // Keep the pager and decoder at the final viewport size throughout the Hero flight.
            HorizontalPager(pager,Modifier.fillMaxSize().graphicsLayer{
                alpha=if(hasHero&&session.flying)0f else if(session.closing)returning.value else progress.value
                translationX=slide;val shrink=(1-abs(slide)/(full.width/2)).coerceAtLeast(.8f);scaleX=shrink;scaleY=shrink
            },userScrollEnabled=!zoomed&&!session.flying,beyondViewportPageCount=0) {index->
                key(index){var scale by remember{mutableFloatStateOf(1f)};var offset by remember{mutableStateOf(Offset.Zero)};var dimensions by remember{mutableStateOf(Size.Zero)};var loaded by remember{mutableStateOf(false)};var failed by remember{mutableStateOf(false)};var retry by remember{mutableIntStateOf(0)};var animation by remember{mutableStateOf<Job?>(null)}
                    val transformState=rememberTransformableState{zoom,pan,_->animation?.cancel();scale=(scale*zoom).coerceIn(1f,8f);offset=clampGalleryOffset(offset+pan,scale,full.size,dimensions)}
                    val pageScale=scale;val pageOffset=offset
                    SideEffect{if(index==pager.currentPage){zoomed=pageScale>1.01f;currentScale=pageScale;currentOffset=pageOffset;session.current=index}}
                    val gestures=if(session.flying)Modifier else Modifier.transformable(transformState,canPan={scale>1.01f}).pointerInput(session,index){detectTapGestures(
                        onTap={point->if(point.x>=size.width/3f&&point.x<size.width*2/3f)chrome=!chrome else close()},
                        onDoubleTap={point->val target=nextGalleryZoom(scale,dimensions.height/dimensions.width.coerceAtLeast(1f)>2);val begin=scale;val start=offset;animation?.cancel();animation=scope.launch{animate(begin,target,animationSpec=tween(260,easing=CubicBezierEasing(.215f,.61f,.355f,1f))){value,_->scale=value;offset=clampGalleryOffset(start*value/begin+(Offset(size.width/2f,size.height/2f)-point)*(value/begin-1),value,full.size,dimensions)}}}
                    )}
                    Box(Modifier.fillMaxSize().then(gestures),contentAlignment=Alignment.Center){
                        val imageModifier=Modifier.fillMaxSize().graphicsLayer{scaleX=scale;scaleY=scale;translationX=offset.x;translationY=offset.y}
                        val preview=session.previews.getOrElse(index){session.images[index]}
                        val retained=session.decoded[index]
                        if(!loaded&&retained!=null)Image(retained,null,imageModifier,contentScale=ContentScale.Fit)
                        else if(!loaded&&preview!=session.images[index])AsyncImage(imageRequest(preview),null,imageModifier,contentScale=ContentScale.Fit,onSuccess={
                            val drawable=it.result.drawable
                            if(dimensions==Size.Zero)dimensions=Size(drawable.intrinsicWidth.toFloat(),drawable.intrinsicHeight.toFloat())
                            if(!loaded)(drawable as? BitmapDrawable)?.bitmap?.asImageBitmap()?.let{image->session.decoded[index]=image}
                        })
                        key(session.images[index],retry){AsyncImage(imageRequest(session.images[index]),"图片 ${index+1}",imageModifier,contentScale=ContentScale.Fit,placeholder=retained?.let{BitmapPainter(it)},onLoading={loaded=false;failed=false},onSuccess={
                            val drawable=it.result.drawable;loaded=true;failed=false;dimensions=Size(drawable.intrinsicWidth.toFloat(),drawable.intrinsicHeight.toFloat())
                            (drawable as? BitmapDrawable)?.bitmap?.asImageBitmap()?.let{image->session.decoded[index]=image}
                        },onError={failed=true})}
                        if(!loaded&&!failed&&retained==null&&preview==session.images[index])CircularProgressIndicator(color=Color.White)
                        if(failed&&!session.closing)TextButton(onClick={retry++;failed=false}){Icon(Icons.Rounded.Refresh,null);Text("图片加载失败，点击重试")}
                    }
                }
            }
            if(hasHero&&session.flying)Canvas(Modifier.fillMaxSize().testTag("gallery-flight")) {
                frame()?.let{flight->
                    val rect=flight.viewport;val plane=flight.plane
                    clipRect(rect.left,rect.top,rect.right,rect.bottom){translate(rect.left,rect.top){
                        drawContext.canvas.nativeCanvas.drawBitmap(flight.bitmap.asAndroidBitmap(),null,android.graphics.RectF(plane.left,plane.top,plane.right,plane.bottom),flightPaint)
                    }}
                }
            }
        }
        if(controls>0f&&!session.closing&&!sliding){
            Row(Modifier.fillMaxWidth().statusBarsPadding().padding(horizontal=16.dp,vertical=10.dp).alpha(controls),horizontalArrangement=Arrangement.SpaceBetween,verticalAlignment=Alignment.CenterVertically){
                GalleryButton("返回",Icons.Rounded.ArrowBack,onClick=::close)
                Surface(color=Color.Black.copy(alpha=.45f),shape=RoundedCornerShape(16.dp)){Text("${pager.currentPage+1} / ${session.images.size}",Modifier.padding(14.dp,6.dp),color=Color.White,fontWeight=androidx.compose.ui.text.font.FontWeight.Bold)}
                GalleryButton(if(saving)"正在保存"else"保存图片到相册",if(saving)Icons.Rounded.HourglassEmpty else Icons.Rounded.Download,enabled=!saving){if(Build.VERSION.SDK_INT<29&&context.checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE)!=PackageManager.PERMISSION_GRANTED)permission.launch(android.Manifest.permission.WRITE_EXTERNAL_STORAGE)else save()}
            }
        }
        if(session.images.size>1&&controls>0f&&!session.closing&&!sliding){
            val thumbs=rememberPagerState(initialPage=session.initial.coerceIn(session.images.indices),pageCount={session.images.size})
            val dragged by thumbs.interactionSource.collectIsDraggedAsState()
            LaunchedEffect(pager.settledPage){if(!dragged)thumbs.animateScrollToPage(pager.settledPage,animationSpec=tween(120))}
            LaunchedEffect(thumbs,dragged){if(dragged)snapshotFlow{thumbs.currentPage to thumbs.currentPageOffsetFraction}.collect{(page,fraction)->pager.scrollToPage(page,fraction)}}
            LaunchedEffect(dragged){if(!dragged&&thumbs.currentPage!=pager.currentPage)pager.animateScrollToPage(thumbs.currentPage,animationSpec=tween(120))}
            HorizontalPager(thumbs,Modifier.align(Alignment.BottomCenter).navigationBarsPadding().padding(bottom=32.dp).height(64.dp).fillMaxWidth().alpha(controls),pageSize=PageSize.Fixed(maxWidth*.16f),contentPadding=PaddingValues(horizontal=maxWidth*.42f),flingBehavior=PagerDefaults.flingBehavior(thumbs)) {i->
                Box(Modifier.fillMaxSize().padding(horizontal=3.dp,vertical=2.dp).semantics{selected=i==pager.currentPage;contentDescription="第 ${i+1} 张图片";role=Role.Button}.clip(RoundedCornerShape(8.dp)).border(2.dp,if(i==pager.currentPage)Color.White else Color.Transparent,RoundedCornerShape(8.dp)).clickable(onClick=tap{scope.launch{pager.scrollToPage(i);thumbs.animateScrollToPage(i,animationSpec=tween(120))}}).padding(2.dp)){
                    SiteImage(session.previews.getOrElse(i){session.images[i]},null,Modifier.fillMaxSize().clip(RoundedCornerShape(6.dp)))
                    if(i!=pager.currentPage)Box(Modifier.fillMaxSize().background(Color.White.copy(alpha=.5f)))
                }
            }
        }
    }}
}
@Composable fun GalleryButton(label:String,icon:androidx.compose.ui.graphics.vector.ImageVector,enabled:Boolean=true,onClick:()->Unit){
    val site=LocalSite.current;site.settingsRevision;val liquid=site.prefs.getBoolean("liquidGlass",false)
    var hold by remember{mutableStateOf(false)};var drag by remember{mutableStateOf(Offset.Zero)}
    val displacement by androidx.compose.animation.core.animateOffsetAsState(drag,spring(.8f,400f),label="glass stretch")
    val stretch by animateFloatAsState(if(hold)1+17f/48f else 1f,spring(.8f,400f),label="glass button")
    val action=tap(onClick)
    val currentAction by rememberUpdatedState(action)
    val interaction=if(!liquid)Modifier else Modifier.pointerInput(enabled){if(enabled)awaitEachGesture{
        val down=awaitFirstDown();down.consume();hold=true;var moved=false
        try{while(true){val change=awaitPointerEvent().changes.firstOrNull{it.id==down.id} ?: break
            if(!change.pressed){if(!moved&&change.uptimeMillis-down.uptimeMillis<viewConfiguration.longPressTimeoutMillis)currentAction();change.consume();break}
            val raw=change.position-down.position;drag=raw/(1+raw.getDistance()/density*.01f);if(raw.getDistance()>viewConfiguration.touchSlop)moved=true;change.consume()
        }}finally{hold=false;drag=Offset.Zero}
    }}
    Box(Modifier.size(48.dp).graphicsLayer{
        val d=displacement*.8f;val rx=abs(d.x)/size.width;val ry=abs(d.y)/size.height
        scaleX=stretch*(1+(rx*.8f).coerceAtMost(.3f))*(1-(ry*.3f).coerceAtMost(.15f));scaleY=stretch*(1+(ry*.8f).coerceAtMost(.3f))*(1-(rx*.3f).coerceAtMost(.15f))
        fun pivot(value:Float):Float{val u=(value/(20*density)).coerceIn(-1f,1f);val a=abs(u);return .5f-sign(u)*a*a*(3-2*a)*.5f}
        transformOrigin=TransformOrigin(pivot(d.x),pivot(d.y));translationX=d.x*.15f;translationY=d.y*.15f
    }.then(interaction).semantics{contentDescription=label;role=Role.Button;if(enabled)onClick{action();true}},contentAlignment=Alignment.Center){
        if(liquid)Box(Modifier.fillMaxSize().clip(CircleShape).backdrop(2.dp,GlassStyle(Color(0x66000000),thickness=32f,refractive=1.24f,chromatic=.025f,dark=true)))
        else Box(Modifier.size(44.dp)
            .dropShadow(CircleShape,androidx.compose.ui.graphics.shadow.Shadow(radius=7.dp,color=Color.Black.copy(alpha=.2f),offset=DpOffset(0.dp,2.dp)))
            .dropShadow(CircleShape,androidx.compose.ui.graphics.shadow.Shadow(radius=5.dp,color=Color.White.copy(alpha=.08f),offset=DpOffset(0.dp,(-1).dp)))
            .clip(CircleShape).backdrop(2.5.dp,GlassStyle(Color.Transparent,gallery=true)).background(Brush.linearGradient(listOf(Color(0xffeeeeee).copy(alpha=.30f),Color(0xff9e9e9e).copy(alpha=.20f),Color(0xff424242).copy(alpha=.36f)))).border(1.dp,Color.White.copy(alpha=.34f),CircleShape))
        if(liquid)Icon(icon,null,Modifier.size(22.dp),tint=Color.White)else IconButton(onClick=action,enabled=enabled,modifier=Modifier.size(48.dp)){Icon(icon,null,Modifier.size(24.dp),tint=Color.White)}
    }
}
