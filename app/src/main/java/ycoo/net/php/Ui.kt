package ycoo.net.php

import android.os.Build
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.interaction.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.*
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.*
import androidx.compose.ui.unit.*
import kotlinx.coroutines.flow.collectLatest
import org.json.JSONArray
import androidx.compose.ui.input.pointer.*
import androidx.compose.foundation.gestures.*
import kotlinx.coroutines.*

val LocalSite=staticCompositionLocalOf<Site> {error("Missing Site")}
val LocalPageTop=staticCompositionLocalOf {0.dp}
val LocalPageBottom=staticCompositionLocalOf {16.dp}
val LocalDark=staticCompositionLocalOf {false}
val LocalCardColor=staticCompositionLocalOf {Color.White}
val LocalHeaderColor=staticCompositionLocalOf {Color.White}
val paletteNames=listOf("经典红","活力橙","极光蓝","翡翠绿","优雅紫","樱花粉","青碧色","经典黑灰")
val paletteSeeds=listOf(0xfffa2f3a,0xffff8200,0xff1976d2,0xff2e7d32,0xff7b1fa2,0xffe91e63,0xff00897b,0xff455a64).map {Color(it)}

@OptIn(ExperimentalMaterial3Api::class)
@Composable fun OriginalTheme(site:Site,content:@Composable ()->Unit) {
    site.settingsRevision
    val context=LocalContext.current
    val dark=when(site.prefs.getInt("themeMode",0)){1->false;2->true;else->isSystemInDarkTheme()}
    val black=dark && site.prefs.getBoolean("pureBlack",false)
    val palettes=remember {JSONArray(context.assets.open("theme-palettes.json").bufferedReader().use {it.readText()})}
    val p=palettes.getJSONObject(site.prefs.getInt("color",0).coerceIn(0,7)*2+if(dark)1 else 0)
    fun c(key:String)=Color(p.getLong(key))
    val base=if(dark) darkColorScheme() else lightColorScheme()
    var scheme=base.copy(primary=c("primary"),onPrimary=c("onPrimary"),primaryContainer=c("primaryContainer"),onPrimaryContainer=c("onPrimaryContainer"),
        secondary=c("secondary"),onSecondary=c("onSecondary"),secondaryContainer=c("secondaryContainer"),onSecondaryContainer=c("onSecondaryContainer"),
        tertiary=c("tertiary"),onTertiary=c("onTertiary"),tertiaryContainer=c("tertiaryContainer"),onTertiaryContainer=c("onTertiaryContainer"),
        error=c("error"),onError=c("onError"),errorContainer=c("errorContainer"),onErrorContainer=c("onErrorContainer"),outline=c("outline"),outlineVariant=c("outlineVariant"),
        surface=c("surface"),onSurface=c("onSurface"),onSurfaceVariant=c("onSurfaceVariant"),surfaceTint=c("primary"),inverseSurface=c("inverseSurface"),inverseOnSurface=c("inverseOnSurface"),inversePrimary=c("inversePrimary"),
        surfaceDim=c("surfaceDim"),surfaceBright=c("surfaceBright"),surfaceContainerLowest=c("surfaceContainerLowest"),surfaceContainerLow=c("surfaceContainerLow"),surfaceContainer=c("surfaceContainer"),surfaceContainerHigh=c("surfaceContainerHigh"),surfaceContainerHighest=c("surfaceContainerHighest"),
        background=if(dark) Color(0xff111215) else c("surface"),onBackground=c("onSurface"))
    if(Build.VERSION.SDK_INT>=31 && site.prefs.getBoolean("dynamicColor",false)) {
        scheme=if(dark) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        scheme=scheme.copy(background=if(dark) Color(0xff111215) else scheme.surface)
    }
    if(black) scheme=scheme.copy(background=Color.Black,surface=Color.Black,surfaceContainer=Color(0xff121212),surfaceContainerHigh=Color(0xff181818),surfaceContainerHighest=Color(0xff222222))
    val weightDelta = if (site.prefs.getBoolean("customFontWeight", false)) site.prefs.getInt("fontWeightDelta", 0).coerceIn(-300, 300) else 0
    val typography=Typography(
        titleLarge=TextStyle(fontSize=22.sp,lineHeight=28.sp,fontWeight=FontWeight.Bold,letterSpacing=0.sp),
        titleMedium=TextStyle(fontSize=16.sp,lineHeight=24.sp,fontWeight=FontWeight.SemiBold,letterSpacing=0.sp),
        titleSmall=TextStyle(fontSize=14.sp,lineHeight=20.sp,fontWeight=FontWeight.SemiBold,letterSpacing=0.sp,color=scheme.onSurfaceVariant),
        bodyLarge=TextStyle(fontSize=16.sp,lineHeight=24.sp,letterSpacing=0.sp),
        bodyMedium=TextStyle(fontSize=14.sp,lineHeight=20.sp,letterSpacing=0.sp),
        bodySmall=TextStyle(fontSize=12.sp,lineHeight=16.sp,letterSpacing=0.sp,color=scheme.onSurfaceVariant),
        labelLarge=TextStyle(fontSize=14.sp,lineHeight=20.sp,fontWeight=FontWeight.SemiBold,letterSpacing=0.sp),
        labelMedium=TextStyle(fontSize=12.sp,lineHeight=16.sp,fontWeight=FontWeight.Medium,letterSpacing=0.sp),
        labelSmall=TextStyle(fontSize=11.sp,lineHeight=16.sp,fontWeight=FontWeight.Medium,letterSpacing=0.sp))
    val platformResolver = LocalFontFamilyResolver.current
    val configuration = LocalConfiguration.current
    val customWeight = site.prefs.getBoolean("customFontWeight", false)
    val resolver = remember(context, configuration, platformResolver, customWeight, weightDelta) {
        if (!customWeight) platformResolver else {
            val neutral = android.content.res.Configuration(configuration).apply {
                if (Build.VERSION.SDK_INT >= 31) fontWeightAdjustment = 0
            }
            createFontFamilyResolver(context.createConfigurationContext(neutral))
        }
    }
    val density=LocalDensity.current
    val textScale=site.prefs.getFloat("textScale",1f)
    val appDensity=remember(density,textScale) {object:Density by density {
        override val fontScale=density.fontScale*textScale
        override fun TextUnit.toDp():Dp=with(density){this@toDp.toDp()}*textScale
        override fun Dp.toSp():TextUnit=with(density){(this@toSp/textScale).toSp()}
    }}
    CompositionLocalProvider(LocalSite provides site,LocalDark provides dark,LocalCardColor provides (if(dark) Color(if(black)0xff121212 else 0xff1b1c20) else scheme.surfaceContainerLowest),
        LocalHeaderColor provides (if(dark) Color(if(black)0xff000000 else 0xff111215) else scheme.surface),
        LocalDensity provides appDensity,
        LocalFontFamilyResolver provides resolver,
        LocalAppWeightDelta provides weightDelta,
        LocalRippleConfiguration provides null,LocalIndication provides NoPressIndication) {
        MaterialTheme(colorScheme=scheme,typography=typography) {
            CompositionLocalProvider(LocalContentColor provides scheme.onSurface) { ProvideTextStyle(typography.bodyMedium,content) }
        }
    }
}
private object NoPressIndication:IndicationNodeFactory {
    override fun create(interactionSource:InteractionSource):androidx.compose.ui.node.DelegatableNode=object:Modifier.Node(),androidx.compose.ui.node.DrawModifierNode {
        override fun androidx.compose.ui.graphics.drawscope.ContentDrawScope.draw() {drawContent()}
    }
    override fun equals(other:Any?)=other===this
    override fun hashCode()=javaClass.hashCode()
}
@Composable fun tap(action:()->Unit):()->Unit {
    val site=LocalSite.current; val haptic=LocalHapticFeedback.current
    return {if(site.prefs.getBoolean("haptics",true)) haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove); action()}
}
@Composable fun SectionCard(modifier:Modifier=Modifier,color:Color=Color.Unspecified,content:@Composable ColumnScope.()->Unit) {
    val s=MaterialTheme.colorScheme
    Surface(modifier.fillMaxWidth(),shape=RoundedCornerShape(24.dp),color=if(color!=Color.Unspecified) color else if(s.surface==Color.Black) s.surfaceContainer else s.surfaceContainerLow) {Column(content=content)}
}
@Composable fun OriginalFab(onClick:()->Unit,modifier:Modifier=Modifier,content:@Composable ()->Unit) {
    FloatingActionButton(onClick=tap(onClick),modifier=modifier,shape=RoundedCornerShape(20.dp),
        containerColor=MaterialTheme.colorScheme.primaryContainer,contentColor=MaterialTheme.colorScheme.onPrimaryContainer,
        elevation=FloatingActionButtonDefaults.elevation(defaultElevation=1.5.dp,pressedElevation=3.dp),content=content)
}
@OptIn(ExperimentalMaterial3Api::class)
@Composable fun OriginalBottomSheet(onDismissRequest:()->Unit,content:@Composable ColumnScope.()->Unit) {
    ModalBottomSheet(onDismissRequest=onDismissRequest,containerColor=if(LocalDark.current&&MaterialTheme.colorScheme.surface==Color.Black)Color(0xff141414)else MaterialTheme.colorScheme.surfaceContainerLow,
        shape=RoundedCornerShape(topStart=28.dp,topEnd=28.dp),tonalElevation=0.dp,
        dragHandle={Box(Modifier.padding(vertical=20.dp).size(38.dp,4.5.dp).background(MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha=.4f),CircleShape))},content=content)
}
@Composable fun SiteListItem(headlineContent:@Composable ()->Unit,modifier:Modifier=Modifier,supportingContent:(@Composable ()->Unit)?=null,leadingContent:(@Composable ()->Unit)?=null,trailingContent:(@Composable ()->Unit)?=null,contentPadding:PaddingValues=PaddingValues(horizontal=16.dp,vertical=3.dp)){
    val scheme=MaterialTheme.colorScheme
    Row(modifier.fillMaxWidth().padding(contentPadding).heightIn(min=if(supportingContent==null)56.dp else 72.dp),verticalAlignment=Alignment.CenterVertically) {
        if(leadingContent!=null) {Box(Modifier.widthIn(min=40.dp),contentAlignment=Alignment.CenterStart) {CompositionLocalProvider(LocalContentColor provides scheme.onSurfaceVariant,content=leadingContent)};Spacer(Modifier.width(16.dp))}
        Column(Modifier.weight(1f).padding(vertical=8.dp)) {
            ProvideTextStyle(TextStyle(fontSize=15.sp,lineHeight=20.25.sp,fontWeight=FontWeight.SemiBold,color=scheme.onSurface),headlineContent)
            if(supportingContent!=null)ProvideTextStyle(TextStyle(fontSize=12.5.sp,lineHeight=17.5.sp,color=scheme.onSurfaceVariant),supportingContent)
        }
        if(trailingContent!=null){Spacer(Modifier.width(16.dp));CompositionLocalProvider(LocalContentColor provides scheme.onSurfaceVariant,content=trailingContent)}
    }
}
@Composable fun OriginalCard(modifier:Modifier=Modifier,radius:Dp=22.dp,elevation:Dp=1.dp,content:@Composable ()->Unit) {
    Surface(modifier,shape=RoundedCornerShape(radius),color=LocalCardColor.current,contentColor=MaterialTheme.colorScheme.onSurface,
        shadowElevation=elevation,border=if(radius==22.dp)BorderStroke(.8.dp,if(MaterialTheme.colorScheme.surface==Color.Black)Color.White.copy(alpha=.12f)else MaterialTheme.colorScheme.outlineVariant.copy(alpha=if(LocalDark.current).2f else .25f))else null,content=content)
}

@Composable fun OriginalDivider(modifier:Modifier=Modifier,space:Dp=16.dp) {
    val s=MaterialTheme.colorScheme
    Box(modifier.fillMaxWidth().height(space),contentAlignment=Alignment.Center) {
        HorizontalDivider(thickness=.5.dp,color=if(s.surface==Color.Black)Color.White.copy(alpha=.1f)else s.outlineVariant.copy(alpha=if(LocalDark.current).2f else .3f))
    }
}

@Composable fun originalFieldColors()=TextFieldDefaults.colors(
    focusedContainerColor=Color.Transparent,unfocusedContainerColor=Color.Transparent,
    disabledContainerColor=Color.Transparent,errorContainerColor=Color.Transparent,
    unfocusedIndicatorColor=MaterialTheme.colorScheme.onSurfaceVariant)

@OptIn(ExperimentalMaterial3Api::class)
@Composable fun OriginalTextField(
    value:String,onValueChange:(String)->Unit,modifier:Modifier=Modifier,enabled:Boolean=true,readOnly:Boolean=false,
    label:(@Composable ()->Unit)?=null,placeholder:(@Composable ()->Unit)?=null,leadingIcon:(@Composable ()->Unit)?=null,trailingIcon:(@Composable ()->Unit)?=null,
    supportingText:(@Composable ()->Unit)?=null,isError:Boolean=false,
    visualTransformation:androidx.compose.ui.text.input.VisualTransformation=androidx.compose.ui.text.input.VisualTransformation.None,
    keyboardOptions:androidx.compose.foundation.text.KeyboardOptions=androidx.compose.foundation.text.KeyboardOptions.Default,
    keyboardActions:androidx.compose.foundation.text.KeyboardActions=androidx.compose.foundation.text.KeyboardActions.Default,
    singleLine:Boolean=false,minLines:Int=1,maxLines:Int=if(singleLine)1 else Int.MAX_VALUE,colors:TextFieldColors=originalFieldColors()
) {
    val interaction=remember {MutableInteractionSource()}
    val scheme=MaterialTheme.colorScheme
    androidx.compose.foundation.text.BasicTextField(value,onValueChange,modifier.fillMaxWidth().defaultMinSize(minHeight=56.dp),enabled,readOnly,
        textStyle=appWeightStyle(MaterialTheme.typography.bodyLarge).copy(color=scheme.onSurface.copy(alpha=if(enabled)1f else .38f)),
        keyboardOptions=keyboardOptions,keyboardActions=keyboardActions,singleLine=singleLine,minLines=minLines,maxLines=maxLines,
        visualTransformation=visualTransformation,interactionSource=interaction,cursorBrush=SolidColor(if(isError)scheme.error else scheme.primary),
        decorationBox={inner->TextFieldDefaults.DecorationBox(value,inner,enabled,singleLine,visualTransformation,interaction,
            isError=isError,label=label,placeholder=placeholder,leadingIcon=leadingIcon,trailingIcon=trailingIcon,supportingText=supportingText,
            shape=RectangleShape,colors=colors,contentPadding=PaddingValues(start=0.dp,end=0.dp,top=if(label==null)8.dp else 16.dp,bottom=8.dp))})
}

@Composable fun OriginalDialog(onDismissRequest:()->Unit,confirmButton:@Composable ()->Unit,dismissButton:(@Composable ()->Unit)?=null,title:(@Composable ()->Unit)?=null,text:(@Composable ()->Unit)?=null) {
    AlertDialog(onDismissRequest=onDismissRequest,confirmButton=confirmButton,dismissButton=dismissButton,
        title=title?.let{{ProvideTextStyle(TextStyle(fontSize=18.sp,fontWeight=FontWeight.Bold,color=MaterialTheme.colorScheme.onSurface),it)}},
        text=text?.let{{ProvideTextStyle(MaterialTheme.typography.bodyMedium.copy(color=MaterialTheme.colorScheme.onSurfaceVariant),it)}},shape=RoundedCornerShape(28.dp))
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable fun OriginalTextField(value:androidx.compose.ui.text.input.TextFieldValue,onValueChange:(androidx.compose.ui.text.input.TextFieldValue)->Unit,
    modifier:Modifier=Modifier,enabled:Boolean=true,label:(@Composable ()->Unit)?=null,placeholder:(@Composable ()->Unit)?=null,minLines:Int=1,colors:TextFieldColors=originalFieldColors()) {
    val interaction=remember {MutableInteractionSource()}
    val scheme=MaterialTheme.colorScheme
    androidx.compose.foundation.text.BasicTextField(value,onValueChange,modifier.fillMaxWidth().defaultMinSize(minHeight=56.dp),enabled=enabled,
        textStyle=appWeightStyle(MaterialTheme.typography.bodyLarge).copy(color=scheme.onSurface.copy(alpha=if(enabled)1f else .38f)),minLines=minLines,
        interactionSource=interaction,cursorBrush=SolidColor(scheme.primary),
        decorationBox={inner->TextFieldDefaults.DecorationBox(value.text,inner,enabled,false,androidx.compose.ui.text.input.VisualTransformation.None,interaction,
            label=label,placeholder=placeholder,shape=RectangleShape,colors=colors,contentPadding=PaddingValues(start=0.dp,end=0.dp,top=if(label==null)8.dp else 16.dp,bottom=8.dp))})
}
@Composable fun Preference(title:String,icon:ImageVector?=null,subtitle:String?=null,tint:Color=MaterialTheme.colorScheme.onSurfaceVariant,onClick:(()->Unit)?=null,switchStyle:Boolean=false,trailing:(@Composable ()->Unit)?=null) {
    Row(Modifier.fillMaxWidth().then(if(onClick!=null) Modifier.clickable(onClick=tap(onClick)) else Modifier).heightIn(min=(if(subtitle==null)56.dp else 72.dp)+if(switchStyle)6.dp else 0.dp).padding(horizontal=16.dp,vertical=8.dp),verticalAlignment=Alignment.CenterVertically) {
        if(icon!=null) {Icon(icon,null,Modifier.size(24.dp),tint=tint); Spacer(Modifier.width(16.dp))}
        Column(Modifier.weight(1f)) {Text(title,style=MaterialTheme.typography.titleMedium.let{if(switchStyle)it.copy(lineHeight=21.6.sp)else it}); if(subtitle!=null) Text(subtitle,style=MaterialTheme.typography.bodyMedium.let{if(switchStyle)it.copy(lineHeight=19.6.sp)else it},color=MaterialTheme.colorScheme.onSurfaceVariant)}
        Spacer(Modifier.width(16.dp)); if(trailing!=null) trailing() else Icon(Icons.Rounded.ChevronRight,null,Modifier.size(24.dp),tint=MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
@Composable fun SettingSwitch(key:String,title:String,icon:ImageVector,subtitle:String?=null,default:Boolean=false,tint:Color=MaterialTheme.colorScheme.onSurfaceVariant) {
    val site=LocalSite.current; site.settingsRevision
    Preference(title,icon,subtitle,tint=tint,onClick={site.setting(key,!site.prefs.getBoolean(key,default))},switchStyle=true,trailing={Switch(site.prefs.getBoolean(key,default),{site.setting(key,it)})})
}
@Composable fun SectionTitle(title:String,modifier:Modifier=Modifier) {
    Text(title,modifier.padding(start=16.dp,top=14.dp,end=16.dp,bottom=4.dp),fontSize=15.sp,fontWeight=FontWeight.Bold,color=MaterialTheme.colorScheme.onSurfaceVariant)
}
@Composable fun StatRow(values:List<Pair<String,String>>) {
    Row(Modifier.fillMaxWidth().padding(vertical=12.dp)) {values.forEach { (label,value) -> Column(Modifier.weight(1f),horizontalAlignment=Alignment.CenterHorizontally) {
        Text(label,style=MaterialTheme.typography.labelMedium,color=MaterialTheme.colorScheme.onSurfaceVariant);Spacer(Modifier.height(4.dp));Text(value,style=MaterialTheme.typography.titleMedium)
    }}}
}
@Composable fun filterTabHeight() = maxOf(48.dp, with(LocalDensity.current){14.sp.toDp()}+28.dp)

@OptIn(ExperimentalMaterial3Api::class)
@Composable fun OriginalTabs(
    labels: List<String>,
    selected: Int,
    scroll: Boolean = false,
    height: Dp = 48.dp,
    secondary: Boolean = false,
    divider: Boolean = true,
    maxLines: Int = 1,
    onSelected: (Int) -> Unit
) {
    val scheme = MaterialTheme.colorScheme
    val tabs: @Composable () -> Unit = {
        labels.forEachIndexed { index, label ->
            if(maxLines>1) Tab(selected=selected==index,onClick=tap{onSelected(index)},modifier=Modifier.height(height),selectedContentColor=scheme.primary,unselectedContentColor=scheme.onSurfaceVariant) {
                Text(label,Modifier.padding(horizontal=4.dp),fontSize=15.sp,lineHeight=18.sp,maxLines=maxLines,overflow=androidx.compose.ui.text.style.TextOverflow.Ellipsis,textAlign=androidx.compose.ui.text.style.TextAlign.Center,fontWeight=if(selected==index)FontWeight.SemiBold else FontWeight.Normal)
            } else
            Tab(
                selected = selected == index,
                onClick = tap { onSelected(index) },
                modifier = Modifier.height(height),
                selectedContentColor = if(secondary)scheme.onSurface else scheme.primary,
                unselectedContentColor = scheme.onSurfaceVariant,
                text = { Text(label, fontSize = 15.sp, maxLines = 1, fontWeight = if (selected == index) FontWeight.SemiBold else FontWeight.Normal) }
            )
        }
    }
    val line: @Composable () -> Unit = { if (divider) HorizontalDivider(color = scheme.outlineVariant) }
    when {
        scroll -> PrimaryScrollableTabRow(selected, edgePadding=0.dp, containerColor=Color.Transparent, divider=line, tabs=tabs)
        secondary -> SecondaryTabRow(selected, containerColor=Color.Transparent, divider=line, tabs=tabs)
        else -> PrimaryTabRow(selected, containerColor=Color.Transparent, divider=line, tabs=tabs)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable fun OriginalSlider(value:Float,onValueChange:(Float)->Unit,modifier:Modifier=Modifier,valueRange:ClosedFloatingPointRange<Float> = 0f..1f,steps:Int=0,label:String?=null,onValueChangeFinished:(()->Unit)?=null) {
    val s=MaterialTheme.colorScheme
    val interaction=remember {MutableInteractionSource()}
    val pressed by interaction.collectIsPressedAsState()
    val dragged by interaction.collectIsDraggedAsState()
    val rtl=LocalLayoutDirection.current==LayoutDirection.Rtl
    Slider(value,onValueChange,modifier=modifier.padding(horizontal=14.dp),valueRange=valueRange,steps=steps,onValueChangeFinished=onValueChangeFinished,interactionSource=interaction,
        thumb={Box(Modifier.size(20.dp).testTag("slider-thumb"),contentAlignment=Alignment.Center) {
            Box(Modifier.matchParentSize().shadow(if(pressed||dragged)6.dp else 1.dp,CircleShape).background(s.primary,CircleShape))
            if((pressed||dragged)&&label!=null) androidx.compose.ui.window.Popup(alignment=Alignment.TopCenter,offset=IntOffset(0,with(LocalDensity.current){(-40).dp.roundToPx()})) {
                Box(Modifier.padding(bottom=6.dp).drawBehind {
                    drawRoundRect(s.primary,cornerRadius=CornerRadius(size.height/2))
                    drawPath(Path().apply{moveTo(size.width/2,size.height+6.dp.toPx());lineTo(size.width/2-10.dp.toPx(),size.height-4.dp.toPx());lineTo(size.width/2+10.dp.toPx(),size.height-4.dp.toPx());close()},s.primary)
                }.heightIn(min=28.dp).widthIn(min=28.dp).padding(horizontal=4.dp),contentAlignment=Alignment.Center) {
                    Text(label,fontSize=12.sp,lineHeight=16.sp,fontWeight=FontWeight.Medium,color=s.onPrimary)
                }
            }
        }},
        track={state->Canvas(Modifier.fillMaxWidth().height(4.dp)) {
            val fraction=((state.value-valueRange.start)/(valueRange.endInclusive-valueRange.start)).coerceIn(0f,1f)
            val y=size.height/2
            val start=if(rtl)size.width else 0f
            val end=if(rtl)0f else size.width
            val active=start+(end-start)*fraction
            drawLine(s.surfaceContainerHighest,androidx.compose.ui.geometry.Offset(start,y),androidx.compose.ui.geometry.Offset(end,y),4.dp.toPx(),StrokeCap.Round)
            drawLine(s.primary,androidx.compose.ui.geometry.Offset(start,y),androidx.compose.ui.geometry.Offset(active,y),6.dp.toPx(),StrokeCap.Round)
            if(steps>0)for(i in 0..steps+1) {
                val part=i.toFloat()/(steps+1)
                drawCircle((if(part<=fraction)s.onPrimary else s.onSurfaceVariant).copy(alpha=.38f),1.dp.toPx(),androidx.compose.ui.geometry.Offset(start+(end-start)*part,y))
            }
        }})
}

fun glassDragFraction(x:Float,width:Float):Float {
    val fraction=((x/width).coerceIn(0f,1f)-.125f)/.75f
    return when {fraction<0f->-(-fraction*.4f).coerceAtMost(.3f);fraction>1f->1f+((fraction-1f)*.4f).coerceAtMost(.3f);else->fraction}
}
@Composable fun OriginalNavigation(selected:Int,onSelected:(Int)->Unit,modifier:Modifier=Modifier) {
    val site=LocalSite.current; site.settingsRevision
    val s=MaterialTheme.colorScheme; val dark=LocalDark.current
    val labels=listOf("首页","社区","导读","我的")
    val icons=listOf(Icons.Outlined.DynamicFeed,Icons.Outlined.GridView,Icons.Outlined.AutoStories,Icons.Outlined.Person)
    val active=listOf(Icons.Rounded.DynamicFeed,Icons.Rounded.GridView,Icons.Rounded.AutoStories,Icons.Rounded.Person)
    val floating=site.prefs.getBoolean("floating",true); val glass=site.prefs.getBoolean("liquidGlass",false)
    val inset=WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    if(!floating) {
        NavigationBar(modifier.height(68.dp+inset),containerColor=if(dark) {if(s.surface==Color.Black)Color.Black else Color(0xff16171b)} else s.surfaceContainer,windowInsets=WindowInsets.navigationBars) {
            labels.forEachIndexed {i,label-> NavigationBarItem(selected==i,tap {onSelected(i)},icon={Icon(if(selected==i)active[i] else icons[i],label)},label={Text(label,fontSize=12.sp,fontWeight=if(selected==i)FontWeight.Bold else FontWeight.Medium)},colors=NavigationBarItemDefaults.colors(selectedIconColor=s.onPrimaryContainer,selectedTextColor=s.primary,indicatorColor=s.primaryContainer,unselectedIconColor=s.onSurfaceVariant,unselectedTextColor=s.onSurfaceVariant))}
        }; return
    }
    var glassGpuFailed by remember(glass) { mutableStateOf(false) }
    val choose by rememberUpdatedState(onSelected);val current by rememberUpdatedState(selected)
    val density=LocalDensity.current;val haptic=LocalHapticFeedback.current;val scope=rememberCoroutineScope()
    var held by remember(glass){mutableStateOf(false)}
    var finger by remember(glass){mutableStateOf<Float?>(null)}
    var swayTarget by remember(glass){mutableFloatStateOf(0f)}
    val sway by animateFloatAsState(swayTarget,spring(1f,631.655f),label="navigation sway")
    var release by remember(glass){mutableStateOf<Job?>(null)}
    val lens by animateFloatAsState(if(held)1f else 0f,spring(dampingRatio=.85f,stiffness=438.649f),label="navigation droplet")
    BoxWithConstraints(modifier.fillMaxWidth(),contentAlignment=Alignment.BottomCenter) {
        val width=minOf(440.dp,(maxWidth-40.dp).coerceAtLeast(40.dp))*8/9
        val bottom=if(inset>0.dp)6.dp else 14.dp
        val scene = LocalBackdrop.current
        if (glass && !glassGpuFailed && scene != null) {
            RedNoteGlassNavigation(
                scene, width, labels, icons, active, selected, onSelected, Modifier.padding(bottom = bottom),
                onFailure = { glassGpuFailed = true },
            )
            return@BoxWithConstraints
        }
        val item=(width-8.dp)/4
        val target=finger?.let{item*3*glassDragFraction(with(density){it.toDp()}.value-4,(width-8.dp).value)} ?: item*selected
        val travel=remember(glass){Animatable(target,Dp.VectorConverter)}
        LaunchedEffect(target,glass,finger==null){travel.animateTo(target,if(glass){if(finger==null)spring(.85f,322.273f)else spring(.86f,1754.596f)}else tween(240,easing=CubicBezierEasing(.215f,.61f,.355f,1f)))}
        val position=travel.value
        val gestures=if(!glass)Modifier else Modifier.pointerInput(width) {
            awaitEachGesture {
                val down=awaitFirstDown(requireUnconsumed=false,pass=PointerEventPass.Initial)
                release?.cancel()
                held=false
                finger=null
                var horizontal=false
                var cancelled=false
                var released=false
                val hold=scope.launch {
                    delay(220)
                    held=true
                    finger=down.position.x
                    if(site.prefs.getBoolean("haptics",true))haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                }
                try {
                    while(true) {
                        val event=awaitPointerEvent(PointerEventPass.Initial)
                        val change=event.changes.firstOrNull{it.id==down.id} ?: break
                        val delta=change.position-down.position
                        if(event.changes.size>1)cancelled=true
                        if(!horizontal&&!cancelled&&delta.getDistance()>18.dp.toPx()) {
                            horizontal=kotlin.math.abs(delta.x)>kotlin.math.abs(delta.y)
                            cancelled=!horizontal
                            hold.cancel()
                            held=horizontal
                        }
                        if(cancelled) {
                            hold.cancel()
                            held=false
                            finger=null
                            change.consume()
                        } else if(held) {
                            val deltaDp=(change.position.x-change.previousPosition.x)/density.density
                            swayTarget=if(kotlin.math.abs(deltaDp)>4f)(deltaDp*.08f).coerceIn(-.75f,.75f)else 0f
                            finger=change.position.x
                            change.consume()
                        }
                        if(!change.pressed) {
                            released=true
                            if(held&&!cancelled) {
                                val index=((change.position.x-4.dp.toPx())/item.toPx()).toInt().coerceIn(0,3)
                                if(index!=current) {
                                    if(site.prefs.getBoolean("haptics",true))haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                    choose(index)
                                }
                            }
                            break
                        }
                    }
                } finally {
                    hold.cancel()
                    finger=null
                    swayTarget=0f
                    if(released&&held)release=scope.launch{delay(250);held=false} else held=false
                }
            }
        }
        val expansion=if(glass)lens.coerceIn(0f,1f) else 0f
        val pressScale=1f+.06f*expansion
        val distortion=(kotlin.math.abs(travel.velocity.value/(item.value*3)*2)/10).coerceIn(0f,1f)*.56f*expansion
        val lensWidth=(item+24.dp*lens.coerceAtLeast(0f))*pressScale*(1-distortion*.5f)
        val lensHeight=(48.dp+16.dp*lens.coerceAtLeast(0f))*pressScale*(1+distortion*.3f)
        val center=4.dp+position+item/2
        fun androidx.compose.ui.graphics.drawscope.DrawScope.pillPath():Path {
            val halfWidth=lensWidth.toPx()/2
            val halfHeight=lensHeight.toPx()/2
            val x=center.toPx()
            val y=size.height/2
            return Path().apply{addRoundRect(RoundRect(Rect(x-halfWidth,y-halfHeight,x+halfWidth,y+halfHeight),CornerRadius(halfHeight)))}
        }
        val inactive=if(glass&&dark)Color.White else s.onSurfaceVariant
        val foreground: @Composable (Boolean, Modifier) -> Unit = { selectedLayer, rowModifier ->
            Row(rowModifier.fillMaxSize().padding(horizontal=4.dp)) {
                labels.forEachIndexed { index,label ->
                    val highlighted=if(glass)selectedLayer else selected==index
                    val color=if(highlighted){if(glass)s.primary else s.onSecondaryContainer}else inactive
                    val interaction=if(selectedLayer)Modifier.graphicsLayer{scaleX=1+.15f*expansion;scaleY=scaleX}
                        else Modifier.semantics{this.selected=selected==index;role=Role.Tab}.clickable(onClick=tap{onSelected(index)})
                    Column(Modifier.weight(1f).fillMaxHeight().then(interaction),
                        verticalArrangement=Arrangement.Center,horizontalAlignment=Alignment.CenterHorizontally) {
                        Icon(if(highlighted)active[index]else icons[index],null,Modifier.size(if(glass)24.dp else 22.dp),tint=color)
                        Spacer(Modifier.height(if(glass)4.dp else 2.dp))
                        Text(label,fontSize=if(glass)11.sp else 11.5.sp,lineHeight=14.sp,fontWeight=if(highlighted)FontWeight.SemiBold else if(glass)FontWeight.Medium else FontWeight.Normal,color=color,maxLines=1)
                    }
                }
            }
        }
        Box(Modifier.padding(bottom=bottom+if(glass)0.dp else inset).offset(x=if(glass)sway.dp else 0.dp).width(width).height(56.dp).then(gestures),contentAlignment=Alignment.Center) {
            val bar = rememberBackdrop()
            val chrome = rememberBackdrop()
            Box(Modifier.fillMaxSize().then(if(glass)Modifier.recordBackdrop(bar) else Modifier),contentAlignment=Alignment.Center) {
                val chromeShape=RoundedCornerShape(32.dp)
                val chromeSurface=if(glass) {
                    Modifier.backdrop(2.dp,GlassStyle(if(dark)Color(0x66000000)else Color(0xf0ffffff),dark=dark,rim=if(dark)0f else 1f))
                }else Modifier.background(s.surfaceContainerHigh)
                Box(Modifier.fillMaxSize().then(if(glass)Modifier.recordBackdrop(chrome) else Modifier)
                    .shadow(if(glass){if(dark)0.dp else 3.dp}else 8.dp,chromeShape)
                    .clip(chromeShape).then(chromeSurface).padding(4.dp)) {
                    if(!glass)Box(Modifier.align(Alignment.CenterStart).offset(x=position).width(item).fillMaxHeight()
                        .background(s.secondaryContainer,RoundedCornerShape(28.dp)))
                }
                val rest=(1f-expansion/.15f).coerceIn(0f,1f)
                if(glass&&rest>0f)Box(Modifier.offset(x=center-width/2).requiredSize(item,48.dp).clip(RoundedCornerShape(999.dp))
                    .backdrop(6.dp*rest,overlay=chrome).background((if(dark)Color.White else Color.Black).copy(alpha=.15f*rest)))

                if(glass) {
                    foreground(false,Modifier.drawWithContent{clipPath(pillPath(),ClipOp.Difference){this@drawWithContent.drawContent()}})
                    foreground(true,Modifier.clearAndSetSemantics{}.drawWithContent{clipPath(pillPath()){this@drawWithContent.drawContent()}})
                }else foreground(false,Modifier)
            }
            if(glass) {
                // Keep the shader ready, but stop legacy bitmap capture while the lens is hidden.
                CompositionLocalProvider(LocalPageActive provides (LocalPageActive.current&&expansion>.001f)) {
                Box(Modifier.offset(x=center-width/2).requiredSize(lensWidth,lensHeight)
                    .graphicsLayer{alpha=expansion}.clip(RoundedCornerShape(999.dp))
                    .then(if(expansion>.001f)Modifier.testTag("navigation-droplet")else Modifier)
                    .backdrop(0.dp,GlassStyle(if(dark)Color(0x26ffffff)else Color(0x18000000),thickness=20f,refractive=1.18f,chromatic=.025f,indicator=true,interaction=(1-(1-expansion)*(1-expansion))*.7f,dark=dark,rim=if(dark)0f else .35f),overlay=bar))
                }
            }
            if(glass&&!dark)Box(Modifier.fillMaxSize().border(1.dp,Color(0xf5ffffff),RoundedCornerShape(999.dp)))
        }
    }
}
