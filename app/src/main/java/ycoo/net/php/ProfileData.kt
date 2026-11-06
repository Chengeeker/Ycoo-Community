package ycoo.net.php

import kotlinx.coroutines.*
import org.json.JSONObject

class UserProfile(val uid:String,val space:JSONObject,val credits:JSONObject,val source:String) {
    val document=doc(source).also {d->if(d.select(".comiis_space_profile li").none {row->row.children().any {it.tagName()=="span"&&it.text().trim()=="用户ID"}&&row.label(".profile_rs").trim()==uid}){d.body().empty();d.select("style").remove()}}
    val header=if(document.select(".comiis_space_profile li").any {row->row.children().any {it.tagName()=="span"&&it.text().trim()=="用户ID"}&&row.label(".profile_rs").trim()==uid})document.selectFirst(".comiis_space_tx")else null
    val name=header?.label("h2").orEmpty().ifBlank {space.text("username")}
    val avatar=header?.selectFirst(".user_img img")?.image()?.ifBlank {null} ?: avatar(uid)
    val cover=Regex("\\.comiis_space_box\\s*\\{[^}]*background\\s*:\\s*url\\(['\"]?([^)'\"\\s]+)").find(document.select("style").joinToString("\n"){it.data()})?.groupValues?.get(1).orEmpty()
    val level=Regex("\\bLv\\.\\s*(\\d+)",RegexOption.IGNORE_CASE).find(header?.label(".kmlv").orEmpty())?.let {"Lv.${it.groupValues[1]}"}.orEmpty()
    val levelColor=space.optJSONObject("group")?.text("color").orEmpty()
    val group=header?.label(".kmlev").orEmpty().ifBlank {space.optJSONObject("group")?.text("grouptitle").orEmpty()}
    val signature=document.label(".profile_face").ifBlank {space.text("sightml")}
    val verification=document.label(".comiis_space_profile .comiis_verify").ifBlank {document.select(".comiis_space_profile .comiis_verify img").map {it.attr("title").ifBlank {it.attr("alt")}}.filter {it.isNotBlank()}.joinToString(" · ")}
    val medals=jsonRows(space.opt("medals"))
    val followed=document.label("#followmod").let {it.contains("取消")||it.contains("已关注")}
    fun count(key:String):String = if(key=="replies") {val p=space.optInt("posts",-1);val t=space.optInt("threads",-1);if(p<0||t<0)"—"else (p-t).coerceIn(0,p).toString()}else space.text(key).ifBlank {"—"}
}
suspend fun Site.userProfile(uid:String):UserProfile=coroutineScope {
    require(uid.matches(Regex("[1-9]\\d*"))){"无效的用户 ID"};val ticket=epoch
    val api=async {api("profile",mapOf("uid" to uid))}
    val web=async {try {request("/home.php?mod=space&uid=$uid&do=profile&mobile=2&_session=${System.nanoTime()}")}catch(e:Exception){if(e is CancellationException)throw e;""}}
    val v=api.await();val source=web.await();assertEpoch(ticket);val p=v.optJSONObject("space")
    require(p!=null&&p.optString("uid")==uid&&p.text("username").isNotEmpty()){"站点未返回对应用户的资料"}
    withContext(Dispatchers.Default){UserProfile(uid,p,v.optJSONObject("extcredits") ?: JSONObject(),source)}
}
fun profileAction(source:String,uid:String,kind:String):String? {
    for(a in doc(source).select("#followmod,.comiis_space_foot a,a[id^=a_friend_],a[id^=a_sendpm_]")) {
        val href=a.attr("href");val candidates=listOf(href)+Regex("['\"]((?:https://ycoo\\.net/|/)?home\\.php\\?[^'\"\\s<>]+)['\"]").findAll("$href ${a.attr("onclick")}").map {it.groupValues[1]}.toList()
        for(raw in candidates) {val u=link(raw) ?: continue
            if(!u.isSite()||u.encodedPath!="/home.php"||u.queryParameter("mod")!="spacecp")continue
            val ids=listOf("uid","fuid","touid").mapNotNull {u.queryParameter(it)}
            if(ids.isEmpty()||ids.any {it!=uid})continue
            val ac=u.queryParameter("ac");val op=u.queryParameter("op")
            if(when(kind){"follow"->ac=="follow";"friend"->ac=="friend"&&op!="ignore";"block"->ac=="friend"&&op=="ignore";"poke"->ac=="poke";"pm"->ac=="pm";else->false})return u.toString()
        }
    };return null
}
fun profileEntries(source:String,kind:String,user:UserProfile,replies:Boolean=false):List<Any> {
    if(kind=="thread")runCatching {Parse.mobile(source,1).topics}.getOrNull()?.takeIf {it.isNotEmpty()}?.let {return it}
    val d=doc(source);val root=d.selectFirst(".comiis_bodybox,#ct") ?: d.body()
    root.select(".comiis_sidenv_box,.comiis_leftnv,.comiis_space_box,.comiis_space_foot,.comiis_topnv,script,style").remove()
    val entries=linkedMapOf<String,Any>()
    for(a in root.select("a[href]")) {val url=link(a.attr("href"))?.takeIf {it.isSite()} ?: continue
        if(kind=="thread") {val id=threadId(url) ?: continue;val title=a.attr("title").ifBlank {a.text()};if(title.isBlank()||entries.containsKey(id))continue
            var row=a.parent();while(row!=null&&row.tagName() !in listOf("li","tr","tbody"))row=row.parent()
            val author=row?.selectFirst("a[href*=uid]");entries[id]=Topic(id,title,author?.text() ?: if(replies)""else user.name,author?.let {link(it.attr("href"))?.let(::profileId)} ?: if(replies)""else user.uid,preview=row?.label(".list_body,.list-content,.comiis_pyqtxt").orEmpty())
        } else {val parameter=if(kind=="blog")"blogid"else"albumid";val id=url.queryParameter(parameter)?.takeIf {it.matches(Regex("[1-9]\\d*"))} ?: continue
            val old=entries[id] as? Entry;val img=a.selectFirst("img");val title=old?.title.orEmpty().ifBlank {a.text()}.ifBlank {a.attr("title")}.ifBlank {img?.attr("alt").orEmpty()}
            entries[id]=Entry(title,url.toString(),old?.image.orEmpty().ifBlank {img?.image().orEmpty()})
        }
    }
    return entries.map {(id,entry)->if(entry is Entry&&entry.title.isBlank())entry.copy(title="${if(kind=="blog")"日志"else"相册"} $id")else entry}
}
