package ycoo.net.php

import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.*
import android.text.style.URLSpan
import android.text.style.ClickableSpan
import android.text.method.LinkMovementMethod
import android.widget.TextView
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.PlayCircle
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.*
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import coil.compose.AsyncImage
import androidx.compose.ui.graphics.asImageBitmap
import org.jsoup.nodes.Element
import org.jsoup.nodes.Node
import org.jsoup.nodes.TextNode

data class BodyPart(val html:String="",val image:String="",val video:String="",val preview:String=image,val poster:String="",val children:List<BodyPart>?=null,val link:String?=null,val copyright:Boolean=false)

private val bodyUrl = Regex("""https?://[A-Za-z0-9._~:/?#\[\]@!\x24&()*+,;=%-]+""", RegexOption.IGNORE_CASE)
private val bodyInlineWhitespace = Regex("[\\t\\r\\n\\u000c ]+")
private const val visibleUrlOnly = "data-ycoo-visible-url-only"
private fun Char.isBodyWhitespace() = isWhitespace() || this == '\u200b' || this == '\ufeff'
private fun String.hasBodyText() = any { !it.isBodyWhitespace() }

fun bodyParts(source:String,base:String="$ORIGIN/"):List<BodyPart> {
    val d=doc(source,base);d.select("script,style,iframe,object,embed").remove()
    // Preserve an anchor's scope when block boundaries split it into separate text fragments.
    d.select("a[href]").filter { bodyUrl.containsMatchIn(it.text()) }.forEach { it.attr(visibleUrlOnly, "1") }
    fun parse(nodes:List<Node>):List<BodyPart> {
        val result=mutableListOf<BodyPart>();val buffer=StringBuilder()
        var hasText = false
        fun flush() {
            if (hasText) result.add(BodyPart(html = buffer.toString()))
            buffer.clear()
            hasText = false
        }
        fun append(node:Node,parents:List<Element>) {
            if (!hasText) hasText = when(node) {
                is TextNode -> node.wholeText.hasBodyText()
                is Element -> node.text().hasBodyText()
                else -> false
            }
            parents.forEach { buffer.append("<${it.tagName()}${it.attributes().html()}>") }
            buffer.append(node.outerHtml())
            parents.asReversed().forEach { buffer.append("</${it.tagName()}>") }
        }
        fun visit(n:Node,href:String?=null,parents:List<Element> = emptyList()){
            if(n !is Element){append(n,parents);return}
            val tag=n.tagName();val url=if(tag=="a")n.attr("href")else href
            if(n.id()=="copyright"||tag=="blockquote"||n.classNames().any{it in setOf("locked","showhide","quote","comiis_quote")}) {
                flush()
                val children = parse(n.childNodes())
                if (children.isNotEmpty()) result.add(BodyPart(children=children,copyright=n.id()=="copyright"))
                return
            }
            if(tag=="img"){
                val full=listOf("file","zoomfile","data-src","src").firstNotNullOfOrNull{n.attr(it).takeIf(String::isNotBlank)}?.let{link(it,base)?.toString()}
                val preview=listOf("data-src","src","zoomfile","file").firstNotNullOfOrNull{n.attr(it).takeIf(String::isNotBlank)}?.let{link(it,base)?.toString()}
                flush();if(full!=null)result.add(BodyPart(image=full,preview=preview ?: full,link=url));return
            }
            if(tag=="video"){flush();val video=link(n.attr("src").ifBlank{n.attr("data-src")}.ifBlank{n.selectFirst("source")?.attr("src").orEmpty()},base);if(video!=null)result.add(BodyPart(video=video.toString(),poster=link(n.attr("poster"),base)?.toString().orEmpty()));return}
            if(tag=="source")return
            // Jsoup Element is iterable; add just this parent rather than its descendants.
            val nested = parents + listOf(n)
            if(tag in setOf("p","div","pre","ul","ol","li","h1","h2","h3","table","tr")){flush();if(tag=="li")buffer.append("• ");n.childNodes().forEach{visit(it,url,if(tag=="li")parents else nested)};flush();return}
            if(n.select("img,video,blockquote,.locked,.showhide,.quote,.comiis_quote,#copyright").isNotEmpty()){n.childNodes().forEach{visit(it,url,nested)};return}
            append(n,parents)
        }
        nodes.forEach{visit(it)};flush();return result
    }
    return parse(d.body().childNodes())
}
internal fun forumSpans(html:String, muted:Int, linkify:Boolean):SpannableStringBuilder {
    val result=SpannableStringBuilder()
    var breaks = 0
    fun walk(node:Node, pre:Boolean=false, href:String?=null, urlOnly:Boolean=false){
        if(node is TextNode){
            var text = if(pre) node.wholeText else node.wholeText.replace(bodyInlineWhitespace," ")
            if (!pre && (breaks > 0 || result.isEmpty())) {
                if (!text.hasBodyText()) return
                text = text.trimStart { it.isBodyWhitespace() }
            }
            if (result.isNotEmpty()) repeat(breaks) { result.append('\n') }
            breaks = 0
            val start = result.length
            result.append(text)
            if(href != null && !urlOnly && text.isNotBlank()) {
                result.setSpan(URLSpan(href), start, result.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            } else if(href != null || linkify) {
                for(match in bodyUrl.findAll(text)) {
                    var address = match.value.trimEnd('.', ',', ';', '!', '?')
                    if(address.endsWith(')') && address.count { it == ')' } > address.count { it == '(' }) address = address.dropLast(1)
                    if(link(address) == null) continue
                    val from = start + match.range.first
                    result.setSpan(URLSpan(href ?: address), from, from + address.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                }
            }
            return
        }
        if(node !is Element)return
        val tag=node.tagName()
        if(tag=="br") {
            if (pre) result.append('\n') else breaks = (breaks + 1).coerceAtMost(2)
            return
        }
        if(tag=="li" && node.text().hasBodyText())result.append("• ")
        val start=result.length
        val target = if(tag == "a") node.attr("href").takeIf(String::isNotBlank) else href
        val narrow = if(tag == "a") node.hasAttr(visibleUrlOnly) || bodyUrl.containsMatchIn(node.text()) else urlOnly
        node.childNodes().forEach{walk(it, pre || tag=="pre", target, narrow)}
        fun span(value:Any){if(result.length>start)result.setSpan(value,start,result.length,Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)}
        if(tag in setOf("b","strong","h1","h2","h3"))span(if(android.os.Build.VERSION.SDK_INT>=28)TypefaceSpan(android.graphics.Typeface.create(android.graphics.Typeface.DEFAULT,600,false))else StyleSpan(android.graphics.Typeface.BOLD))
        if(tag=="em"||node.hasClass("pstatus")){span(RelativeSizeSpan(.75f));span(ForegroundColorSpan(muted))}
        if(tag=="pre"||tag=="code")span(TypefaceSpan("monospace"))
    }
    doc(html).body().childNodes().forEach{walk(it)}
    return result
}
@Composable fun RichText(html:String,nav:Nav,modifier:Modifier=Modifier){
    val colors=MaterialTheme.colorScheme;val density=LocalDensity.current;val linkify=LocalSite.current.prefs.getBoolean("linkify",true)
    val styled=remember(html,linkify,colors.onSurfaceVariant,nav){forumSpans(html,colors.onSurfaceVariant.toArgb(),linkify).apply{
        getSpans(0,length,URLSpan::class.java).forEach{span->val start=getSpanStart(span);val end=getSpanEnd(span);removeSpan(span);setSpan(object:ClickableSpan(){override fun onClick(widget:android.view.View){nav.route(span.url)}},start,end,0)}
    }}
    AndroidView(factory={TextView(it).apply{setTextIsSelectable(true);movementMethod=LinkMovementMethod.getInstance();includeFontPadding=false;setLineSpacing(0f,1.55f)}},modifier=modifier.fillMaxWidth(),update={view->
        if(view.tag!==styled){view.text=styled;view.tag=styled};view.setTextSize(android.util.TypedValue.COMPLEX_UNIT_PX,with(density){16.sp.toPx()});view.setTextColor(colors.onSurface.toArgb());view.setLinkTextColor(colors.primary.toArgb())
    })
}
fun fitBodyImage(image:androidx.compose.ui.geometry.Size,maxWidth:Float):androidx.compose.ui.geometry.Size {
    if(image.width<=0f||image.height<=0f)return androidx.compose.ui.geometry.Size(maxWidth,100f)
    val scale=minOf(1f,maxWidth/image.width,440f/image.height)
    return image*scale
}
@Composable fun Body(source:String,nav:Nav,followImageLinks:Boolean=false){
    val parts=remember(source){bodyParts(source)}
    fun flatten(parts:List<BodyPart>):List<BodyPart> = parts.flatMap{if(it.children!=null)flatten(it.children)else listOf(it)}
    val images=remember(parts){flatten(parts).filter{it.image.isNotEmpty()}}
    val gallerySource=remember(source){Any()}
    val decoded=remember(source){mutableMapOf<Int,androidx.compose.ui.graphics.ImageBitmap>()}
    val origins=remember(source){mutableMapOf<Int,androidx.compose.ui.geometry.Rect>()}
    @Composable fun Render(list:List<BodyPart>,compact:Boolean=false){Column(verticalArrangement=Arrangement.spacedBy(if(compact)4.dp else 8.dp)) {
        for(part in list) when{
            part.children!=null->Surface(shape=RoundedCornerShape(12.dp),color=MaterialTheme.colorScheme.surfaceContainerHighest,border=BorderStroke(1.dp,MaterialTheme.colorScheme.outlineVariant),modifier=Modifier.fillMaxWidth()){Box(Modifier.padding(if(part.copyright)10.dp else 12.dp)){Render(part.children,compact=part.copyright)}}
            part.image.isNotEmpty()->{
                var imageSize by remember(part.preview){mutableStateOf(androidx.compose.ui.geometry.Size.Zero)};var loading by remember(part.preview){mutableStateOf(true)};var failed by remember(part.preview){mutableStateOf(false)}
                BoxWithConstraints(Modifier.fillMaxWidth()){
                    val fitted=fitBodyImage(imageSize,maxWidth.value)
                    val height=if(loading)100.dp else if(failed)80.dp else fitted.height.dp
                    val width=if(loading||failed)maxWidth else fitted.width.dp
                    Box(Modifier.width(width).height(height).onGloballyPositioned{origins[images.indexOf(part)]=androidx.compose.ui.geometry.Rect(it.positionInRoot(),androidx.compose.ui.geometry.Size(it.size.width.toFloat(),it.size.height.toFloat()))}.clip(RoundedCornerShape(12.dp)).clickable(onClick=tap{if(followImageLinks&&part.link!=null)nav.route(part.link)else nav.showGallery(images.map{it.image},images.indexOf(part),images.map{it.preview},origins.toMap(),coverOrigin=false,source=gallerySource,decoded=decoded.toMap())}),contentAlignment=Alignment.Center){
                        AsyncImage(imageRequest(part.preview),"查看图片",Modifier.fillMaxSize().gallerySource(nav,gallerySource,images.indexOf(part)),contentScale=ContentScale.Fit,onSuccess={s->(s.result.drawable as? android.graphics.drawable.BitmapDrawable)?.bitmap?.let{bitmap->decoded[images.indexOf(part)]=bitmap.asImageBitmap()};imageSize=androidx.compose.ui.geometry.Size(s.result.drawable.intrinsicWidth.toFloat(),s.result.drawable.intrinsicHeight.toFloat());loading=false;failed=false},onError={loading=false;failed=true})
                        if(loading)CircularProgressIndicator()else if(failed)Text("图片加载失败 · 点击重试查看")
                    }
                }
            }
            part.video.isNotEmpty()->OriginalCard(Modifier.fillMaxWidth().padding(horizontal=10.dp),elevation=0.dp) {
                Box(Modifier.fillMaxWidth().aspectRatio(16/9f).background(MaterialTheme.colorScheme.surfaceContainerHighest).clickable(onClick=tap{nav.open("video:${part.video}")}),contentAlignment=Alignment.Center){
                    if(part.poster.isNotEmpty())SiteImage(part.poster,null,Modifier.fillMaxSize())
                    Icon(Icons.Rounded.PlayCircle,"播放视频",Modifier.size(64.dp),tint=MaterialTheme.colorScheme.onSurface)
                    Text("视频 · 点击播放",Modifier.align(Alignment.BottomStart).padding(12.dp),style=MaterialTheme.typography.labelLarge.copy(background=MaterialTheme.colorScheme.surface.copy(alpha=.72f)),color=MaterialTheme.colorScheme.onSurface)
                }
            }
            else->RichText(part.html,nav)
        }
    }}
    Render(parts)
}
@Composable fun imageRequest(url:String):coil.request.ImageRequest{
    val context=LocalContext.current;val site=LocalSite.current;val epoch=site.epoch
    return remember(url,epoch){val u=link(url);val cookie=if(u?.isSite()==true)android.webkit.CookieManager.getInstance().getCookie(u.toString()).orEmpty()else""
        coil.request.ImageRequest.Builder(context).data(u?.toString()).addHeader("User-Agent",DESKTOP_UA).addHeader("X-Compose-Epoch","$epoch").apply{if(u?.isSite()==true){addHeader("Referer","$ORIGIN/");addHeader("Cookie",cookie);if(cookie.isNotEmpty()){diskCachePolicy(coil.request.CachePolicy.DISABLED);memoryCacheKey("$url:${java.security.MessageDigest.getInstance("SHA-256").digest(cookie.toByteArray()).joinToString(""){"%02x".format(it)}}")}}}.build()
    }
}
