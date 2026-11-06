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
    LaunchedEffect(controls,playing){if(controls&&playing){delay(4000);controls=false}}
    fun toggle(){runCatching{if(player.isPlaying)player.pause()else{player.play();controls=true}}.onFailure{error="视频播放失败"}}
    val opacity by animateFloatAsState(if(controls)1f else 0f,tween(180),label="video controls")
    Scaffold(topBar={
        FrostedHeader {
            TopAppBar(
                expandedHeight=56.dp,
                colors=TopAppBarDefaults.topAppBarColors(containerColor=Color.Transparent),
                title={Text("视频播放",fontSize=18.sp,fontWeight=androidx.compose.ui.text.font.FontWeight.Bold)},
                navigationIcon={IconButton(onClick=tap(close)){Icon(Icons.Rounded.ArrowBack,"返回")}}
            )
        }
    }){padding->
        when{error.isNotEmpty()->Box(Modifier.fillMaxSize().padding(padding),contentAlignment=Alignment.Center){Failure(error,{revision++})};!ready->Box(Modifier.fillMaxSize().padding(padding),contentAlignment=Alignment.Center){CircularProgressIndicator()};else->Column(Modifier.fillMaxSize().padding(padding)){
            Box(Modifier.weight(1f).fillMaxWidth().background(Color.Black),contentAlignment=Alignment.Center){
                Box(Modifier.fillMaxWidth().aspectRatio(ratio.coerceAtLeast(.01f))){
                    AndroidView(factory={PlayerView(it).apply{this.player=player;useController=false}},update={it.player=player},modifier=Modifier.fillMaxSize())
                    Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha=.24f*opacity)).clickable(onClick=tap{controls=!controls}),contentAlignment=Alignment.Center){if(controls)FilledIconButton(onClick=tap(::toggle),modifier=Modifier.size(56.dp)){Icon(if(playing)Icons.Rounded.Pause else Icons.Rounded.PlayArrow,if(playing)"暂停"else"播放",Modifier.size(36.dp))}}
                }
            }
            Surface(color=MaterialTheme.colorScheme.surfaceContainer){Column(Modifier.navigationBarsPadding().padding(start=16.dp,top=4.dp,end=16.dp,bottom=8.dp)){
                OriginalSlider(value=(scrub ?: position.toFloat()).coerceIn(0f,duration.toFloat()),onValueChange={scrub=it},valueRange=0f..duration.toFloat(),onValueChangeFinished={scrub?.let{player.seekTo(it.toLong());position=it.toLong()};scrub=null})
                Row(verticalAlignment=Alignment.CenterVertically){Text(formatDuration((scrub ?: position.toFloat()).toLong()),style=MaterialTheme.typography.labelMedium);Text(" / ");Text(formatDuration(duration),style=MaterialTheme.typography.labelMedium);Spacer(Modifier.weight(1f))
                    var menu by remember{mutableStateOf(false)}
                    Box{Text("${speed}×",Modifier.clickable{menu=true}.padding(12.dp));DropdownMenu(menu,{menu=false}){listOf(.5f,.75f,1f,1.25f,1.5f,2f).forEach{value->DropdownMenuItem(text={Text("${value}×")},onClick={menu=false;runCatching{player.setPlaybackSpeed(value);speed=value}.onFailure{site.status="无法调整播放速度"}})}}}
                    IconButton(onClick=tap(::toggle)){Icon(if(playing)Icons.Rounded.Pause else Icons.Rounded.PlayArrow,if(playing)"暂停"else"播放")}
                }
            }}
        }}
    }
}
fun formatDuration(milliseconds:Long):String {
    val seconds=(milliseconds/1000).coerceAtLeast(0)
    val minutes="${seconds/60%60}".padStart(2,'0')
    val tail="$minutes:${(seconds%60).toString().padStart(2,'0')}"
    return if(seconds>=3600)"${(seconds/3600).toString().padStart(2,'0')}:$tail"else tail
}
