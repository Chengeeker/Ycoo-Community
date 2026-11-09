package ycoo.net.php

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.media3.common.*
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.PlayerView
import kotlinx.coroutines.*

@androidx.annotation.OptIn(androidx.media3.common.util.UnstableApi::class)
@OptIn(ExperimentalMaterial3Api::class)
@Composable fun Video(url:String,close:()->Unit){
    val context=LocalContext.current;val site=LocalSite.current;val scope=rememberCoroutineScope();var revision by remember{mutableIntStateOf(0)}
    val player=remember(url,revision,site.epoch){ExoPlayer.Builder(context).setMediaSourceFactory(DefaultMediaSourceFactory(OkHttpDataSource.Factory(mediaClient(site)).setUserAgent(DESKTOP_UA))).build()}
    var error by remember(player){mutableStateOf("")};var ready by remember(player){mutableStateOf(false)};var playing by remember(player){mutableStateOf(false)};var ratio by remember(player){mutableFloatStateOf(16/9f)}
    var controls by remember(player){mutableStateOf(true)};var position by remember(player){mutableLongStateOf(0)};var duration by remember(player){mutableLongStateOf(1)};var scrub by remember(player){mutableStateOf<Float?>(null)};var speed by remember(player){mutableFloatStateOf(1f)}
    val owner=LocalLifecycleOwner.current
    val activity = androidx.activity.compose.LocalActivity.current
    var fullscreen by remember { mutableStateOf(false) }
    var menu by remember(player) { mutableStateOf("") }
    var interaction by remember { mutableIntStateOf(0) }
    val qualityOptions = rememberVideoTrackChoices(player)
    var selectedQuality by remember(player) { mutableStateOf("自动") }
    DisposableEffect(activity) {
        val previous = activity?.requestedOrientation
        onDispose { if (previous != null) activity.requestedOrientation = previous }
    }
    fun rotate() {
        fullscreen = !fullscreen
        activity?.requestedOrientation = if (fullscreen) android.content.pm.ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
            else android.content.pm.ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        interaction++
    }
    androidx.activity.compose.BackHandler(enabled = fullscreen) { rotate() }
    val active=LocalPageActive.current
    LaunchedEffect(active){if(!active)player.pause()}
    DisposableEffect(player,owner){
        val listener=object:Player.Listener{
            override fun onPlaybackStateChanged(state:Int){ready=state==Player.STATE_READY||state==Player.STATE_ENDED;duration=player.duration.coerceAtLeast(1)}
            override fun onIsPlayingChanged(value:Boolean){playing=value;if(!value)controls=true}
            override fun onPlayerError(e:PlaybackException){error="视频播放失败"}
            override fun onVideoSizeChanged(size:VideoSize){ratio=if(size.height>0)size.width*size.pixelWidthHeightRatio/size.height else 16/9f}
        }
        val observer=LifecycleEventObserver{_,event->if(event==Lifecycle.Event.ON_PAUSE||event==Lifecycle.Event.ON_STOP)player.pause()}
        player.addListener(listener);owner.lifecycle.addObserver(observer);player.setMediaItem(MediaItem.fromUri(url));player.prepare();player.playWhenReady=true
        onDispose{owner.lifecycle.removeObserver(observer);player.removeListener(listener);player.release()}
    }
    LaunchedEffect(player,playing){while(playing){position=player.currentPosition;delay(200)};position=player.currentPosition}
    LaunchedEffect(controls,playing,menu,interaction){if(controls&&playing&&menu.isEmpty()){delay(4000);controls=false}}
    fun toggle(){runCatching{if(player.isPlaying)player.pause()else{player.play();controls=true}}.onFailure{error="视频播放失败"}}
    Box(Modifier.fillMaxSize().background(Color.Black)) {
        AndroidView(factory = { PlayerView(it).apply { useController = false; this.player = player } },
            update = { it.player = player }, modifier = Modifier.fillMaxSize())
        Box(Modifier.fillMaxSize().clickable(interactionSource = null, indication = null, onClick = tap { controls = !controls; interaction++ }))
        if (error.isNotEmpty()) Box(Modifier.align(Alignment.Center)) { Failure(error, { revision++ }) }
        else if (!ready) CircularProgressIndicator(Modifier.align(Alignment.Center), color = Color.White.copy(alpha = .7f))
        if (controls || !ready || error.isNotEmpty())
            ReviewVideoTop(Modifier.align(Alignment.TopCenter), "视频播放", fullscreen = fullscreen, close = { if (fullscreen) rotate() else close() })
        if (controls && ready && error.isEmpty()) ReviewVideoBottom(
            Modifier.align(Alignment.BottomCenter), position, duration, player.bufferedPosition.coerceAtLeast(0), playing, speed, fullscreen,
            quality = selectedQuality.takeIf { qualityOptions.isNotEmpty() },
            onPlay = ::toggle, onSpeed = { menu = "speed"; interaction++ }, onQuality = { menu = "quality"; interaction++ },
            onFullscreen = ::rotate, onSeek = { player.seekTo(it); position = it; interaction++ })
    }
    val dismiss: () -> Unit = { menu = ""; interaction++ }
    if (menu == "speed") ReviewVideoChoices("播放倍速", standardVideoSpeeds.map { "${it}X" }, "${speed}X", dismiss) {
        val requested = it.removeSuffix("X").toFloat()
        runCatching { player.setPlaybackSpeed(requested); speed = requested }.onFailure { site.status = "无法调整播放速度" }
    }
    if (menu == "quality" && qualityOptions.isNotEmpty())
        ReviewVideoChoices("清晰度选择", listOf("自动") + qualityOptions.keys, selectedQuality, dismiss) {
            selectVideoTrack(player, qualityOptions[it]); selectedQuality = it
        }
    LaunchedEffect(qualityOptions.isEmpty()) { if (qualityOptions.isEmpty() && menu == "quality") dismiss() }
}
fun formatDuration(milliseconds:Long):String {
    val seconds=(milliseconds/1000).coerceAtLeast(0)
    val minutes="${seconds/60%60}".padStart(2,'0')
    val tail="$minutes:${(seconds%60).toString().padStart(2,'0')}"
    return if(seconds>=3600)"${(seconds/3600).toString().padStart(2,'0')}:$tail"else tail
}
