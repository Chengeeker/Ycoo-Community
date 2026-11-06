package ycoo.net.php

import android.content.Context
import android.graphics.RenderEffect
import android.graphics.RuntimeShader
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.VelocityTracker
import androidx.compose.animation.core.SpringSpec
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInteropFilter
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.*
import androidx.annotation.RequiresApi
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.*
import androidx.compose.ui.graphics.layer.GraphicsLayer
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.*

// RedNote Compose GlassGpu, GlassMotion and GlassNavigation source, with the four source-community tabs wired in.
@RequiresApi(33)
internal class GlassOptics(context: Context) {
    val shader =
        RuntimeShader(
            context.assets.open("glass/navigation_glass.agsl").bufferedReader().use { it.readText() }
        )

    fun configure(
        size: Size,
        shape: Rect,
        density: Float,
        dark: Boolean,
        lens: Boolean = false,
        pressed: Float = 0f,
        dragging: Boolean = false,
        kind: Int = 0,
        touch: Float = 0f,
    ) {
        val fade = if (lens) pressed.coerceIn(.001f, 1f) else 1f
        val dpr = density / 3f
        val ri = if (lens) 1f + .18f * fade else if (kind == 1) 1.24f else 1.16f
        val thickness = (if (lens) 20f * fade else if (kind == 1) 32f else 10f) * dpr
        val rgb =
            if (lens) {
                if (dark) 1f else 0f
            } else {
                if (dark || kind == 1) 0f else 1f
            }
        shader.apply {
            setFloatUniform("uSize", size.width, size.height)
            setFloatUniform("shape", shape.center.x, shape.center.y, shape.width, shape.height)
            setFloatUniform("uGeometryOffset", shape.left, shape.top)
            setFloatUniform("uGeometrySize", shape.width, shape.height)
            setFloatUniform(
                "uGlassColor",
                rgb,
                rgb,
                rgb,
                (if (lens) {
                    if (dark) 38f / 255 else 24f / 255
                } else {
                    if (dark || kind == 1) .4f else 240f / 255
                }) * fade,
            )
            setFloatUniform(
                "uOpticalProps",
                ri,
                if (lens || kind == 1) .025f * fade else .008f,
                thickness,
                1f,
            )
            setFloatUniform(
                "uLightConfig",
                (if (lens) 2f else .25f) * fade,
                0f,
                if (lens || kind == 1) 1.5f else 1f,
            )
            setFloatUniform("uLightDirection", -.7071068f, .7071068f)
            setFloatUniform("uWhiten", 0f)
            setFloatUniform("uWhitenGated", 1f)
            setFloatUniform(
                "uPinchStrength",
                if (lens && dragging) .7f * (1 - (1 - fade) * (1 - fade)) else 0f,
            )
            setFloatUniform("uBackgroundFallback", 0f, 0f, 0f, 0f)
            setFloatUniform("uCaptureOffset", 0f, 0f)
            setFloatUniform("uEdgeConfig", 0f, fade, dpr, 0f)
            setFloatUniform("uPlatformViewMode", 0f)
            setFloatUniform("uBodyMode", 1f)
            setFloatUniform("uTouchPosition", shape.center.x, shape.center.y)
            setFloatUniform("uTouchIntensity", (if (kind == 1) touch else pressed) * .125f)
            setFloatUniform(
                "uRimConfig",
                if (lens && !dark) .12f * fade else 0f,
                (if (kind == 1) 0f
                else if (dark) {
                    if (lens || kind == 3) 0f else .12f
                } else {
                    if (lens) .35f else 1f
                }) * fade,
                .2f,
            )
            setFloatUniform("uLensModel", 0f)
            setFloatUniform("uFrost", 0f, 0f, 0f, 1f)
            setFloatUniform("uBodyShade", 0f)
            setFloatUniform("uNativeEdge", if (!dark && lens) 1f else 0f)
        }
    }

    fun effect(): androidx.compose.ui.graphics.RenderEffect =
        RenderEffect.createRuntimeShaderEffect(shader, "background").asComposeRenderEffect()
}

@RequiresApi(33)
@Composable
internal fun GlassNavigationGpu(
    backdrop: Backdrop,
    tabCount: Int,
    labels: GraphicsLayer,
    activeLabels: GraphicsLayer,
    lens: Float,
    pressed: Float,
    dark: Boolean,
    sceneColor: Color,
    modifier: Modifier,
    onFailure: () -> Unit,
) {
    val context = LocalContext.current
    val optics = remember {
        runCatching { GlassOptics(context) to GlassOptics(context) }.getOrNull()
    }
    if (optics == null) {
        LaunchedEffect(Unit) { onFailure() }
        return
    }
    val crop = rememberGraphicsLayer()
    val blurred = rememberGraphicsLayer()
    val body = rememberGraphicsLayer()
    val underPill = rememberGraphicsLayer()
    val pillBlur = rememberGraphicsLayer()
    val combined = rememberGraphicsLayer()
    val water = rememberGraphicsLayer()
    var origin by remember { mutableStateOf(Offset.Zero) }
    var velocity by remember { mutableFloatStateOf(0f) }
    val currentLens by rememberUpdatedState(lens)
    val hasWater = pressed > .001f
    LaunchedEffect(hasWater) {
        if (!hasWater) velocity = 0f
        else {
            var lastFrame = withFrameNanos { it }
            var lastLens = currentLens
            while (true) {
                val frame = withFrameNanos { it }
                velocity = (currentLens - lastLens) * 1_000_000_000f / (frame - lastFrame)
                lastFrame = frame
                lastLens = currentLens
            }
        }
    }
    val density = androidx.compose.ui.platform.LocalDensity.current.density
    val bodyBlur = remember(density) { navBlurEffect(1.5f * density) }
    val frostBlur = remember(density) { navBlurEffect(6f * density) }
    val bodyEffects =
        remember(dark, density) { mutableMapOf<Size, androidx.compose.ui.graphics.RenderEffect>() }
    Box(
        modifier
            .onGloballyPositioned { origin = it.positionInRoot() }
            .drawWithCache {
                val w = size.width
                val h = size.height
                val d = density
                val dimensions = IntSize(w.roundToInt(), h.roundToInt())
                val bar = Rect(20 * d, 15 * d, w - 20 * d, h - 15 * d)
                val slot = (bar.width - 8 * d) / tabCount
                val cx = 24 * d + slot * (lens + .5f)
                val jelly = jellyScale(velocity, pressed)
                val lw = (slot * (1 + .06f * pressed) + 24 * d * pressed) * jelly[0]
                val lh = (48 * d * (1 + .06f * pressed) + 16 * d * pressed) * jelly[1]
                val pill = Rect(cx - lw / 2, h / 2 - lh / 2, cx + lw / 2, h / 2 + lh / 2)
                val mask =
                    Path().apply { addRoundRect(RoundRect(pill, CornerRadius(minOf(lw, lh) / 2))) }
                val resting = 1f - pressed
                blurred.renderEffect = bodyBlur
                pillBlur.renderEffect = frostBlur
                pillBlur.alpha = resting
                body.renderEffect =
                    bodyEffects[size]
                        ?: run {
                            bodyEffects.clear()
                            optics.first.configure(size, bar, d, dark)
                            optics.first.effect().also { bodyEffects[size] = it }
                        }
                water.alpha = pressed
                if (hasWater) {
                    optics.second.configure(
                        size,
                        pill,
                        d,
                        dark,
                        lens = true,
                        pressed = pressed,
                        dragging = true,
                    )
                    water.renderEffect = optics.second.effect()
                }
                onDrawBehind {
                    // Retain GPU display lists; never read these layers into CPU bitmaps.
                    crop.record(this, layoutDirection, dimensions) {
                        drawRect(sceneColor)
                        translate(backdrop.origin.x - origin.x, backdrop.origin.y - origin.y) {
                            drawLayer(backdrop.layer)
                        }
                    }
                    blurred.record(this, layoutDirection, dimensions) { drawLayer(crop) }
                    body.record(this, layoutDirection, dimensions) { drawLayer(blurred) }
                    underPill.record(this, layoutDirection, dimensions) {
                        drawLayer(crop)
                        drawLayer(body)
                    }
                    pillBlur.record(this, layoutDirection, dimensions) { drawLayer(underPill) }
                    combined.record(this, layoutDirection, dimensions) {
                        drawLayer(body)
                        if (resting > .001f)
                            clipPath(mask) {
                                drawLayer(pillBlur)
                                drawRect(
                                    (if (dark) Color.White else Color.Black).copy(
                                        alpha = 38f / 255 * resting
                                    )
                                )
                            }
                        clipPath(mask, ClipOp.Difference) { drawLayer(labels) }
                        clipPath(mask) { drawLayer(activeLabels) }
                    }
                    drawLayer(combined)
                    if (hasWater) {
                        water.record(this, layoutDirection, dimensions) {
                            drawLayer(crop)
                            drawLayer(combined)
                        }
                        drawLayer(water)
                    }
                }
            }
    )
}

private fun navBlurEffect(sigma: Float): BlurEffect {
    val radius = maxOf(.01f, (sigma - .5f) / .57735f)
    return BlurEffect(radius, radius, TileMode.Clamp)
}

// Same duration/bounce conversion and anchored stretch as the retained glass renderer.
internal fun glassSpring(milliseconds: Int, bounce: Float): SpringSpec<Float> =
    spring(
        dampingRatio = if (bounce > 0) 1 - bounce else 1 / (1 + bounce),
        stiffness = (4 * PI * PI / (milliseconds / 1000.0).pow(2)).toFloat(),
    )

internal fun jellyScale(velocity: Float, pressure: Float = 1f): FloatArray {
    val distortion =
        if (velocity.isFinite()) (abs(velocity) / 10).coerceIn(0f, 1f) * .8f * .7f * pressure
        else 0f
    return floatArrayOf(1 - distortion * .5f, 1 + distortion * .3f)
}

@Composable
internal fun navigationGlassMotion(
    selected: Int,
    touching: Boolean,
    dragging: Boolean,
    target: Float,
    longPressed: Boolean,
): Pair<Float, Float> {
    val held = touching && dragging
    val water = touching && longPressed
    val lens by
        animateFloatAsState(
            if (held) target else selected.toFloat(),
            glassSpring(if (held) 150 else 350, if (held) .14f else .15f),
            label = "glass-position",
        )
    val press by
        animateFloatAsState(
            if (water) 1f else 0f,
            if (water) glassSpring(300, .15f) else tween(240, easing = FastOutSlowInEasing),
            label = "glass-thickness",
        )
    return lens to press.coerceIn(0f, 1f)
}

internal val NavigationLensPosition = SemanticsPropertyKey<Float>("NavigationLensPosition")
internal val NavigationLensExpansion = SemanticsPropertyKey<Float>("NavigationLensExpansion")

@RequiresApi(33)
@Composable
internal fun RedNoteGlassNavigation(
    backdrop: Backdrop,
    barWidth: Dp,
    labelNames: List<String>,
    icons: List<ImageVector>,
    activeIcons: List<ImageVector>,
    selected: Int,
    choose: (Int) -> Unit,
    modifier: Modifier,
    onFailure: () -> Unit,
) {
    val tabCount = labelNames.size
    val site = LocalSite.current
    val density = LocalDensity.current
    val rootView = LocalView.current
    val scope = rememberCoroutineScope()
    val onChoose by rememberUpdatedState(choose)
    val dark = LocalDark.current
    val colors = MaterialTheme.colorScheme
    val unselected = if (dark) Color.White else colors.onSurfaceVariant
    val labelsLayer = rememberGraphicsLayer()
    val selectedLayer = rememberGraphicsLayer()
    var touching by remember { mutableStateOf(false) }
    var dragging by remember { mutableStateOf(false) }
    var longPressed by remember { mutableStateOf(false) }
    var target by remember { mutableFloatStateOf(selected.toFloat()) }
    val (lens, press) = navigationGlassMotion(selected, touching, dragging, target, longPressed)
    var origin by remember { mutableStateOf(Offset.Zero) }
    var vertical by remember { mutableStateOf(false) }
    var velocity by remember { mutableStateOf<VelocityTracker?>(null) }
    var hold by remember { mutableStateOf<Job?>(null) }
    DisposableEffect(Unit) {
        onDispose {
            hold?.cancel()
            velocity?.recycle()
        }
    }
    Box(modifier.width(barWidth).height(56.dp)) {
        Box(Modifier.requiredSize(barWidth + 40.dp, 86.dp).align(Alignment.Center)) {
            if (!dark) Box(
                Modifier.align(Alignment.Center).size(barWidth, 56.dp).glassEdgeShadow(
                    GlassShadow(4.4f, 1.1f, Color.Black.copy(alpha = .033f)),
                    GlassShadow(1.1f, .55f, Color.Black.copy(alpha = .011f)),
                )
            )
            GlassNavigationGpu(
                backdrop, tabCount, labelsLayer, selectedLayer, lens, press, dark,
                colors.background,
                Modifier.fillMaxSize().testTag("navigation-glass-gpu").semantics {
                    this[NavigationLensPosition] = lens
                    this[NavigationLensExpansion] = press
                },
                onFailure,
            )
            GlassTabLabels(barWidth, labelNames, icons, unselected, labelsLayer, FontWeight.Medium)
            GlassTabLabels(barWidth, labelNames, activeIcons, colors.primary, selectedLayer, FontWeight.SemiBold)
        }
        Row(
            Modifier.fillMaxSize().pointerInteropFilter { event ->
                val x = event.x
                val y = event.y
                when (event.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        dragging = false
                        longPressed = false
                        hold?.cancel()
                        velocity?.recycle()
                        velocity = VelocityTracker.obtain().also { it.addMovement(event) }
                        origin = Offset(x, y)
                        vertical = false
                        touching = true
                        target =
                            (x / (barWidth.value * density.density) * tabCount - .5f).coerceIn(0f, (tabCount - 1).toFloat())
                        hold =
                            scope.launch {
                                delay(220)
                                longPressed = true
                                dragging = true
                                if (site.prefs.getBoolean("haptics", true))
                                    rootView.performHapticFeedback(
                                        HapticFeedbackConstants.LONG_PRESS
                                    )
                            }
                    }
                    MotionEvent.ACTION_MOVE -> {
                        velocity?.addMovement(event)
                        val dx = x - origin.x
                        val dy = y - origin.y
                        if (hypot(dx, dy) > 18 * density.density) {
                            hold?.cancel()
                            if (abs(dx) > abs(dy)) dragging = true
                            else if (!dragging) vertical = true
                        }
                        if (!vertical)
                            target =
                                (x / (barWidth.value * density.density) * tabCount - .5f).coerceIn(
                                    0f,
                                    (tabCount - 1).toFloat(),
                                )
                    }
                    MotionEvent.ACTION_UP,
                    MotionEvent.ACTION_CANCEL -> {
                        hold?.cancel()
                        val wasDragging = dragging
                        touching = false
                        velocity?.addMovement(event)
                        velocity?.computeCurrentVelocity(1000)
                        val speed = (velocity?.xVelocity ?: 0f) / density.density
                        val slot =
                            floor(x / (barWidth.value * density.density) * tabCount)
                                .toInt()
                                .coerceIn(0, tabCount - 1)
                        if (event.actionMasked == MotionEvent.ACTION_UP && !vertical) {
                            val chosen =
                                if (wasDragging && abs(speed) >= 800 && slot == selected)
                                    (selected + if (speed > 0) 1 else -1).coerceIn(0, tabCount - 1)
                                else slot
                            if (!wasDragging || chosen != selected) {
                                if (site.prefs.getBoolean("haptics", true))
                                    rootView.performHapticFeedback(
                                        HapticFeedbackConstants.CLOCK_TICK
                                    )
                                onChoose(chosen)
                            }
                        }
                        velocity?.recycle()
                        velocity = null
                        dragging = false
                        longPressed = false
                    }
                }
                true
            }
        ) {
            labelNames.forEachIndexed { i, label ->
                Box(
                    Modifier.weight(1f).fillMaxHeight().semantics {
                        contentDescription = label
                        role = Role.Tab
                        this.selected = selected == i
                        onClick {
                            onChoose(i)
                            true
                        }
                    }
                )
            }
        }
    }
}

@Composable
private fun GlassTabLabels(
    barWidth: Dp,
    names: List<String>,
    icons: List<ImageVector>,
    color: Color,
    layer: GraphicsLayer,
    weight: FontWeight,
) {
    Box(
        Modifier.fillMaxSize()
            .drawWithContent { layer.record { this@drawWithContent.drawContent() } }
            .clearAndSetSemantics {}
    ) {
        Row(Modifier.align(Alignment.Center).size(barWidth, 56.dp).padding(horizontal = 4.dp)) {
            names.forEachIndexed { index, name ->
                Column(
                    Modifier.weight(1f).fillMaxHeight(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Icon(icons[index], null, Modifier.size(24.dp), tint = color)
                    Spacer(Modifier.height(4.dp))
                    Text(
                        name,
                        fontSize = 11.sp,
                        lineHeight = 14.sp,
                        fontWeight = weight,
                        color = color,
                    )
                }
            }
        }
    }
}

