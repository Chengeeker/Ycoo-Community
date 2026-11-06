package ycoo.net.php

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.*
import org.jsoup.nodes.Element
import org.json.JSONObject

fun nativeTitle(raw:String):String {
    val u=link(raw) ?: return "社区服务"
    return when {
        u.encodedPath.startsWith("/k_misign") -> "每日签到"
        u.queryParameter("mod")=="task" -> "任务中心"
        u.queryParameter("mod")=="medal" -> if(u.queryParameter("action")=="log") "我的勋章" else "勋章中心"
        u.queryParameter("view")=="visitor" -> "最近访客"
        u.queryParameter("do")=="notice" -> mapOf("mypost" to "我的帖子","interactive" to "坛友互动","system" to "系统提醒","userapp" to "应用提醒")[u.queryParameter("view")] ?: "通知"
        u.queryParameter("action")=="pay" -> "购买主题"
        u.queryParameter("mod")=="ranklist" -> "排行榜"
        u.queryParameter("mod")=="tag" -> "标签"
        u.queryParameter("ac")=="credit" -> "积分记录"
        else -> "社区服务"
    }
}

fun nativePage(raw:String):Boolean {
    val u=link(raw) ?: return false
    if(!u.isSite()) return false
    if(u.encodedPath=="/member.php" && u.queryParameter("mod") in setOf("logging","register"))return false
    return !requiresWebView(u)
}
fun requiresWebView(u:okhttp3.HttpUrl):Boolean = when(u.encodedPath) {
    "/plugin.php"->u.queryParameter("id") in setOf("boan_group","comiis_app_homestyle","jnfarm")
    "/group.php"->true
    "/forum.php"->u.queryParameter("mod")=="collection"
    "/home.php"->u.queryParameter("mod")=="magic" || (u.queryParameter("mod")=="space" && !(u.queryParameter("do")=="friend"&&u.queryParameter("view")=="visitor") && u.queryParameter("do") in setOf("friend","blog","album","doing","follow","pm")) || (u.queryParameter("mod")=="spacecp"&&(u.queryParameter("ac") in setOf("avatar","invite","profile","pm")||(u.queryParameter("ac")=="credit"&&u.queryParameter("op") in setOf("transfer","buy"))))
    else->false
}
data class NativePart(val kind:String,val index:Int=0,val html:String="")
data class NativeContent(val tabs:List<Entry>,val contacts:List<Entry>,val medals:List<Entry>,val html:String,val forms:List<Element>,val login:Boolean=false,val message:String="",val info:String="",val scripts:Boolean=false,val selected:Int=0,val parts:List<NativePart> = emptyList())
fun isThreadPurchaseForm(form:Element,base:String,tid:String):Boolean {
    val target=link(form.attr("action").ifBlank{base},base) ?: return false
    if(!form.attr("method").equals("post",true)||!target.isSite()||target.encodedPath!="/forum.php"||
        target.queryParameter("mod")!="misc"||target.queryParameter("action")!="pay")return false
    val queryTid=target.queryParameterValues("tid")
    val formTid=form.select("[name=tid]:not([disabled])").map {it.attr("value")}
    return (queryTid.isNotEmpty()||formTid.isNotEmpty())&&
        (queryTid.isEmpty()||queryTid==listOf(tid))&&(formTid.isEmpty()||formTid==listOf(tid))
}

fun parseNative(source:String,base:String):NativeContent {
    val d=doc(source,base)
    val root=d.selectFirst(".comiis_bodybox, #ct, #messagetext") ?: d.body()
    val login=root.selectFirst("#loginform")!=null
    val safe=link(base)!!.newBuilder().query(null).fragment(null).apply {listOf("id","mod","do","op","action","operation","ac").forEach {key->link(base)!!.queryParameter(key)?.let {addQueryParameter(key,it)}}}.build()
    val info=JSONObject().put("page",safe.toString()).put("scripts",org.json.JSONArray(d.select("script[src]").mapNotNull {link(it.attr("src"),base)?.takeIf {u->u.isSite()&&u.encodedPath.startsWith("/source/plugin/") }?.newBuilder()?.query(null)?.fragment(null)?.build()?.toString()}.distinct()))
        .put("forms",org.json.JSONArray(root.select("form").map {f->JSONObject().put("method",f.attr("method").ifBlank {"get"}).put("fields",org.json.JSONArray(f.select("[name]").map {it.attr("name")}.distinct()))})).toString()
    val scriptCandidates=root.select("[onclick],a[href^=javascript:]").filter {it.tagName()!="button"&&(it.attr("onclick").isNotBlank()||it.attr("href").length>13)}
    var selected=0;var tabs=emptyList<Entry>()
    val knownTabs=listOf(setOf("我的好友","我的关注","我的粉丝","最近来访","我看过谁","好友请求","黑名单"),setOf("圈子话题","我的话题","我参与的","我管理的"),setOf("我的心情","好友心情","随便看看"),setOf("我的日志","好友日志","随便看看"),setOf("我的相册","好友相册","随便看看"))
    for(n in root.select(".comiis_topnv,.tb,ul")){val links=n.select("li a[href]");val labels=links.map{it.text().trim()}.toSet()
        if(links.size<2||(!n.hasClass("comiis_topnv")&&!n.hasClass("tb")&&!knownTabs.any{it.containsAll(labels)}))continue
        fun active(a:Element)=listOf("f_0","active","current","on","a").any{a.hasClass(it)||a.parent()?.hasClass(it)==true}
        val candidates=links.mapNotNull{a->val href=a.attr("href").trim();val target=when{href.startsWith("javascript:")&&href.contains("member.php?mod=logging")->"";active(a)&&(href.isEmpty()||href=="#"||href=="javascript:;")->base;href.isNotEmpty()&&href!="#"->link(href,base)?.takeIf{it.isSite()}?.toString();else->null};if(a.text().isBlank()||target==null)null else Entry(a.text(),target)}
        if(candidates.size==links.size){tabs=candidates;selected=links.indexOfFirst(::active).coerceAtLeast(0);n.remove();break}
    }
    root.select("script,style,link,.comiis_sidenv_box,#comiis_foot_box,#comiis_post_btn,#mask,#comiis_menu_bg,#comiis_alert,.comiis_head,iframe,object,embed").remove()
    root.select("[hidden],[aria-hidden=true],[style]").filter {it.tagName() !in setOf("input","textarea","select")&&(it.hasAttr("hidden")||it.attr("aria-hidden")=="true"||Regex("(?:^|;)\\s*display\\s*:\\s*none\\b",RegexOption.IGNORE_CASE).containsMatchIn(it.attr("style")))}.forEach {it.remove()}
    val structured=mutableMapOf<org.jsoup.nodes.Node,NativePart>();var contactIndex=0;var medalIndex=0
    val contacts=root.select(".comiis_userlist01 li").mapNotNull {row ->
        val a=row.selectFirst(".tit a[href]") ?: return@mapNotNull null
        val url=link(a.attr("href"),base) ?: return@mapNotNull null
        val id=profileId(url) ?: return@mapNotNull null
        val entry=Entry(a.text(),url.toString(),row.selectFirst("img")?.image() ?: avatar(id),row.text())
        structured[row]=NativePart("contact",contactIndex++);entry
    }
    val medals=root.select(".comiis_medal_box li, .comiis_medal_list li, .mgcl li").mapNotNull {row ->
        val img=row.selectFirst("img") ?: return@mapNotNull null
        val a=row.select("a[href]").firstOrNull {it.text().trim()=="立即申请"}
        val candidates=listOf(a?.attr("href").orEmpty()) + Regex("['\"]([^'\"]*home\\.php\\?[^'\"]+)['\"]").findAll(a?.attr("onclick").orEmpty()+" "+a?.attr("href").orEmpty()).map {it.groupValues[1]}.toList()
        val id=row.selectFirst("[id^=medal_]")?.id()?.removePrefix("medal_")
        val url=candidates.mapNotNull {link(it,base)}.firstOrNull {it.isSite() && it.queryParameter("mod")=="medal" && !it.queryParameter("action").isNullOrEmpty() && (it.queryParameter("medalid")==null || it.queryParameter("medalid")==id)}
        val title=row.label(".tit").ifBlank {img.attr("alt")}.ifBlank {img.attr("title")}.ifBlank {row.text()}
        val result=Entry(title,url?.toString().orEmpty(),img.image(),row.label(".txt"))
        a?.remove();structured[row]=NativePart("medal",medalIndex++);result
    }
    val purchaseTid=link(base)?.takeIf {it.encodedPath=="/forum.php"&&it.queryParameter("action")=="pay"}?.queryParameter("tid")
    val forms=if(purchaseTid!=null)root.select("form").filter{isThreadPurchaseForm(it,base,purchaseTid)}.take(1)
        else root.select("form").filter{link(it.attr("action").ifBlank{base},base)?.isSite()==true}
    val parts=mutableListOf<NativePart>();val buffer=StringBuilder()
    fun flush(){if(buffer.isNotBlank()){parts.add(NativePart("html",html=buffer.toString()));buffer.clear()}}
    fun walk(node:org.jsoup.nodes.Node){val item=structured[node];when{
        item!=null->{flush();parts.add(item);if(item.kind=="medal"&&node is Element)node.children().filter{child->child.classNames().none{it in setOf("list02_limg","tit","txt")}}.forEach(::walk)}
        node is Element&&node.tagName()=="form"->{flush();val i=forms.indexOf(node);if(i>=0)parts.add(NativePart("form",i))}
        node is Element&&(node.selectFirst("form")!=null||structured.keys.any{it is Element&&it.parents().contains(node)})->node.childNodes().forEach(::walk)
        else->buffer.append(node.outerHtml())
    }}
    if(!login)root.childNodes().forEach(::walk);flush()
    val visibleActions=root.select("[onclick],a[href^=javascript:]").toSet()
    val scriptActions=scriptCandidates.any {node->node in visibleActions&&(listOf(node)+node.parents()).mapNotNull {structured[it]}.firstOrNull()?.let {it.kind!="contact"&&!(it.kind=="medal"&&node.attr("onclick").trim().startsWith("popup.open("))}!=false}
    return NativeContent(tabs,if(login)emptyList()else contacts,if(login)emptyList()else medals,parts.filter{it.kind=="html"}.joinToString(""){it.html},if(login)emptyList()else forms,login,root.label("#messagetext,.comiis_password_top"),info,scriptActions,selected,parts)
}
fun formValues(form:Element):MutableMap<String,String> {
    val values=linkedMapOf<String,String>()
    form.select("input[name],textarea[name],select[name]").filterNot {it.hasAttr("disabled")}.forEach {field ->
        val type=field.attr("type").lowercase()
        if(type in setOf("submit","button","file","reset") || (type in setOf("radio","checkbox") && !field.hasAttr("checked"))) return@forEach
        values[field.attr("name")]=when(field.tagName()) {
            "textarea" -> field.text()
            "select" -> (field.selectFirst("option[selected]") ?: field.selectFirst("option"))?.let {it.attr("value").ifBlank {it.text()}}.orEmpty()
            else -> field.attr("value").ifBlank {if(type=="checkbox") "on" else ""}
        }
    }
    return values
}

