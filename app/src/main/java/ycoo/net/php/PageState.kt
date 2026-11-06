package ycoo.net.php

import android.os.SystemClock
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.PointerType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.LocalViewConfiguration
import androidx.compose.ui.platform.ViewConfiguration
import androidx.compose.ui.semantics.clearAndSetSemantics
import kotlin.math.abs

val LocalPageActive=staticCompositionLocalOf{true}
val LocalPageKey=staticCompositionLocalOf{"root"}
@Composable fun RetainedPage(visible:Boolean,modifier:Modifier=Modifier,content:@Composable ()->Unit){
    Layout(content=content,modifier=modifier.then(if(LocalPageActive.current)Modifier else Modifier.clearAndSetSemantics{})){measurables,constraints->
        val places=measurables.map{it.measure(constraints)}
        layout(constraints.maxWidth,constraints.maxHeight){if(visible)places.forEach{it.place(0,0)}}
    }
}

private class ReverseScrollConfiguration(private val system:ViewConfiguration) :
    ViewConfiguration by system, NestedScrollConnection {
    var lastDelta=0f
        private set
    var lastScrollTime=0L
        private set
    var reversing=false
    override val touchSlop:Float get()=if(reversing)0f else system.touchSlop

    override fun onPostScroll(consumed:Offset,available:Offset,source:NestedScrollSource):Offset {
        if(abs(consumed.y)>abs(consumed.x)) {
            lastDelta=consumed.y
            lastScrollTime=SystemClock.uptimeMillis()
        }
        return Offset.Zero
    }
}

@Composable internal fun ResponsivePageScroll(modifier:Modifier=Modifier,content:@Composable ()->Unit) {
    val system=LocalViewConfiguration.current
    val configuration=remember(system){ReverseScrollConfiguration(system)}
    val gestures=Modifier.pointerInput(configuration) {
        awaitEachGesture {
            val down=awaitFirstDown(requireUnconsumed=false,pass=PointerEventPass.Initial)
            val previousDelta=configuration.lastDelta
            if(down.type!=PointerType.Touch||previousDelta==0f||SystemClock.uptimeMillis()-configuration.lastScrollTime>200L)return@awaitEachGesture
            try {
                do {
                    val event=awaitPointerEvent(PointerEventPass.Initial)
                    val change=event.changes.singleOrNull() ?: break
                    if(!change.pressed||change.id!=down.id)break
                    val movement=change.position-down.position
                    // Ignore subpixel noise; once direction is clear, keep the entire first delta.
                    configuration.reversing=abs(movement.y)>=1f&&abs(movement.y)>abs(movement.x)&&movement.y*previousDelta<0f
                }while(true)
            }finally {
                configuration.reversing=false
            }
        }
    }
    Box(modifier.nestedScroll(configuration).then(gestures)) {
        CompositionLocalProvider(LocalViewConfiguration provides configuration,content=content)
    }
}
