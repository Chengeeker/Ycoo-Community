package ycoo.net.php

import androidx.compose.runtime.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.repeatOnLifecycle
import kotlin.math.roundToInt

@Composable fun FpsIndicator(){
    var fps by remember{mutableIntStateOf(0)};val lifecycle=LocalLifecycleOwner.current.lifecycle
    LaunchedEffect(lifecycle){lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED){var start=0L;var frames=0
        while(true)withFrameNanos{time->if(start==0L)start=time;frames++;if(time-start>=1_000_000_000){fps=(frames*1e9/(time-start)).roundToInt();frames=0;start=time}}
    }}
    Surface(Modifier.statusBarsPadding().padding(start=4.dp),color=MaterialTheme.colorScheme.surfaceContainerHighest.copy(alpha=.85f),shape=RoundedCornerShape(6.dp)){Text("$fps FPS",Modifier.padding(6.dp,2.dp),style=MaterialTheme.typography.labelSmall)}
}
