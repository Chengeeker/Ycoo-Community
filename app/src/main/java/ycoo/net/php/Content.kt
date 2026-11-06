package ycoo.net.php

import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import org.json.JSONArray
import org.json.JSONObject
import org.jsoup.Jsoup
import org.jsoup.nodes.Element

const val ORIGIN = "https://ycoo.net"
const val DESKTOP_UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"
const val MOBILE_UA = "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36"
fun link(raw: String, base: String = "$ORIGIN/"): HttpUrl? {
    if (raw.isBlank()) return null
    val result = base.toHttpUrlOrNull()?.resolve(raw.trim()) ?: return null
    if (result.username.isNotEmpty() || result.password.isNotEmpty()) return null
    return if (result.host == "ycoo.net" && result.scheme == "http" && result.port == 80)
        result.newBuilder().scheme("https").build() else result
}
fun HttpUrl.isSite() = scheme == "https" && host == "ycoo.net" && port == 443 && username.isEmpty() && password.isEmpty()
fun threadId(url: HttpUrl): String? = if (!url.isSite()) null else
    Regex("^/thread-(\\d+)-").find(url.encodedPath)?.groupValues?.get(1)
        ?: url.queryParameter("tid")?.takeIf { url.encodedPath == "/forum.php" && url.queryParameter("mod") == "viewthread" && it.matches(Regex("\\d+")) }
fun profileId(url: HttpUrl): String? {
    if (!url.isSite() || url.queryParameter("do")?.let { it != "profile" } == true) return null
    return (Regex("^/space-uid-(\\d+)").find(url.encodedPath)?.groupValues?.get(1)
        ?: url.queryParameter("uid")?.takeIf { url.encodedPath == "/home.php" && url.queryParameter("mod") == "space" })
        ?.takeIf { it.matches(Regex("[1-9]\\d*")) }
}
fun plain(raw: String) = Jsoup.parseBodyFragment(raw).text()
fun JSONObject.text(key: String) = plain(optString(key).takeUnless { it == "null" } ?: "")
fun JSONArray.objects(): List<JSONObject> = (0 until length()).mapNotNull { optJSONObject(it) }
fun unwrap(source: String): String = if (source.contains("<![CDATA[") && source.contains("]]>"))
    source.substringAfter("<![CDATA[").substringBeforeLast("]]>") else source
fun doc(source: String, base: String = "$ORIGIN/") = Jsoup.parse(unwrap(source), base)
fun Element.label(selector: String) = selectFirst(selector)?.text().orEmpty()
fun Element.image(): String = listOf("file", "data-src", "src").firstNotNullOfOrNull { attr(it).takeIf(String::isNotBlank) }?.let { link(it, baseUri())?.toString() }.orEmpty()
fun avatar(uid: String): String {
    if (!uid.matches(Regex("[1-9]\\d{0,8}"))) return ""
    val id = uid.padStart(9, '0')
    return "$ORIGIN/data/avatar/${id.take(3)}/${id.substring(3,5)}/${id.substring(5,7)}/${id.takeLast(2)}_avatar_middle.jpg"
}

data class Topic(val id: String, val title: String, val author: String = "", val uid: String = "",
    val forum: String = "", val fid: String = "", val preview: String = "", val time: String = "",
    val replies: String = "", val views: String = "", val images: List<String> = emptyList(),
    val avatar: String = "", val pinned: Boolean = false, val level: String = "", val levelColor:String="",
    val gender:String="",val verificationIcon:String="",val verificationLabel:String="",val likes:String="") {
    fun json() = JSONObject().put("tid", id).put("subject", title).put("author", author).put("authorid", uid)
        .put("forumname", forum).put("fid", fid).put("message", preview).put("dateline", time).put("replies", replies)
        .put("views", views).put("images", JSONArray(images)).put("avatar", avatar).put("displayorder", if(pinned) 1 else 0).put("level", level)
        .put("levelColor",levelColor).put("gender",gender).put("verificationIcon",verificationIcon).put("verificationLabel",verificationLabel).put("likes",likes)
    companion object {
        fun from(j: JSONObject) = Topic(j.optString("tid", j.optString("id")), j.text("subject"), j.text("author"), j.optString("authorid"),
            j.text("forumname"), j.optString("fid"), j.text("message"), j.text("dateline"), j.optString("replies"), j.optString("views"),
            j.optJSONArray("images")?.let { a -> (0 until a.length()).mapNotNull { link(a.optString(it))?.toString() } }.orEmpty(),
            link(j.optString("avatar"))?.toString() ?: avatar(j.optString("authorid")), j.optInt("displayorder") > 0, j.text("level"),j.text("levelColor"),j.text("gender"),j.text("verificationIcon"),j.text("verificationLabel"),j.text("likes"))
    }
}
data class Entry(val title: String, val url: String, val image: String = "", val detail: String = "",val author:String="",val avatar:String="")
data class Batch(val topics: List<Topic>, val more: Boolean, val next: String? = null,
    val sections: Map<String, List<Entry>> = emptyMap(), val types: Map<String, String> = emptyMap())
class LoginWebRequired:IllegalStateException("站点返回了网页登录页面，请在网页中完成登录")

object Parse {
    fun mobile(source: String, page: Int): Batch {
        val d = doc(source)
        val rows = linkedMapOf<String, Topic>()
        d.select("#comiis_displayorder a[href]").forEach { a ->
            val id = link(a.attr("href"))?.let(::threadId) ?: return@forEach
            rows[id] = Topic(id, a.text().removePrefix("置顶").trim(), pinned = true)
        }
        d.select("li.forumlist_li").forEach { row ->
            val a = row.selectFirst(".mmlist_li_box h2 a, .forumlist_li_box h2 a") ?: return@forEach
            val id = link(a.attr("href"))?.let(::threadId) ?: return@forEach
            val author = row.selectFirst(".top_user")
            val uid = link(author?.attr("href").orEmpty())?.let(::profileId).orEmpty()
            val forum = row.selectFirst(".comiis_xznalist_bk a[href*=forum-]")
            val counts = row.select(".comiis_xznalist_bottom > ul > li")
            val topic = Topic(id, a.text().removePrefix("置顶").trim(), author?.text().orEmpty(), uid, forum?.text().orEmpty(),
                Regex("forum-(\\d+)").find(forum?.attr("href").orEmpty())?.groupValues?.get(1).orEmpty(),
                row.label(".list_body"), row.label(".forumlist_li_time"), counts.getOrNull(1)?.label("span").orEmpty(),
                counts.getOrNull(2)?.label("span").orEmpty(), row.select(".mmlist_li_box img, .forumlist_li_box img").map { it.image() }.filter { it.isNotBlank() }.distinct(),
                row.selectFirst(".top_tximg")?.image().orEmpty(), rows[id]?.pinned == true || a.label(".bg_del").contains("置顶"), row.label(".top_lev"))
            val level=row.selectFirst(".top_lev")
            val gender=row.selectFirst(".top_gender")
            val verification=row.selectFirst(".comiis_verify img")
            rows[id] = topic.copy(levelColor=Regex("background(?:-color)?\\s*:\\s*(#[0-9a-fA-F]{6})\\b").find(level?.attr("style").orEmpty())?.groupValues?.get(1) ?: if(level?.hasClass("bg_a")==true) "#FF9900" else "",
                gender=if(gender?.hasClass("bg_boy")==true)"male" else if(gender?.hasClass("bg_girl")==true)"female" else "",
                verificationIcon=verification?.image().orEmpty().takeIf {link(it)?.isSite()==true}.orEmpty(),verificationLabel=verification?.attr("title").orEmpty().ifBlank {verification?.attr("alt").orEmpty()},likes=counts.firstOrNull()?.label("span").orEmpty())
        }
        require(rows.isNotEmpty() || source.contains("comiis_") || source.contains("没有") || source.contains("暂无")) {
            d.label("#messagetext").ifBlank { "无法识别页面，请使用原站入口" }
        }
        val maximum = Regex("comiis_page(?:_list_\\d+)?\\s*<\\s*(\\d+)").find(source)?.groupValues?.get(1)?.toIntOrNull() ?: 50
        return Batch(rows.values.toList(), rows.isNotEmpty() && page < maximum)
    }
    fun portal(source: String): Map<String, List<Entry>> {
        val d = doc(source)
        return linkedMapOf("推荐" to ".comiis_mh_img35 li > a, .comiis_mh_img14 li > a", "快捷服务" to ".comiis_mh_hdico5 li a",
            "热门版块" to ".comiis_mh_hotbk li a", "七日排行" to ".comiis_mh_list19 li a", "置顶" to ".comiis_mh_img26 li a",
            "公告" to ".comiis_mh_gonggao li a").mapValues { (_, selector) ->
            d.select(selector).mapNotNull { a ->
                val url = link(a.attr("href")) ?: return@mapNotNull null
                val title = a.selectFirst(".kmtit, .album_tit, p")?.text() ?: a.attr("title").ifBlank { a.text() }
                if(title.isBlank()) null else Entry(title, url.toString(), a.selectFirst("img")?.image().orEmpty(), a.label(".comiis_tm, .album_txt, .f_d.y"),a.label(".kmuser"),a.selectFirst(".kmuser img")?.image().orEmpty())
            }
        }.filterValues { it.isNotEmpty() }
    }
    fun search(source: String, base: String): Batch {
        val d = doc(source, base)
        require(d.selectFirst(".result-list") != null || source.contains("没有找到") || source.contains("没有搜索到")) { "搜索页面暂不可用，请使用原站入口" }
        val topics = d.select(".result-list dt").mapNotNull { dt ->
            val a = dt.selectFirst("a") ?: return@mapNotNull null
            val id = link(a.attr("href"), base)?.let(::threadId) ?: return@mapNotNull null
            a.select("small").remove()
            val details = dt.nextElementSibling()
            val author = details?.selectFirst(".field-info a[href*=uid=]")
            Topic(id, a.text().replace(Regex("^\\d+\\s+"), ""), author?.text().orEmpty(),
                link(author?.attr("href").orEmpty())?.let(::profileId).orEmpty(), details?.label(".field-info a[href*=fid=]").orEmpty(),
                preview = details?.select("p:not(.field-info)")?.firstOrNull()?.text().orEmpty())
        }
        val page = base.toHttpUrl().queryParameter("p")?.toIntOrNull() ?: 1
        val next = d.select(".pagination a[href]").mapNotNull { link(it.attr("href"), base) }
            .firstOrNull { it.isSite() && it.queryParameter("p")?.toIntOrNull() == page + 1 }?.toString()
        return Batch(topics, next != null, next)
    }
    fun api(source: String, writing: Boolean = false,login:Boolean=false): JSONObject {
        val body = try { JSONObject(source.trim().removePrefix("\uFEFF")) } catch (_: Exception) { if(login)throw LoginWebRequired();error("站点返回网页，请通过网页登录或原站入口继续") }
        val message = body.optJSONObject("Message")
        val code = message?.optString("messageval").orEmpty()
        val success = code.contains("succeed") || code.contains("success")
        require(message == null || success) { plain(message?.optString("messagestr").orEmpty()).ifBlank { code } }
        require(!writing || success) { "服务器尚未确认操作成功，请先核对原站，草稿已保留" }
        return body.optJSONObject("Variables") ?: if(login)throw LoginWebRequired()else error("站点接口暂不可用")
    }
    fun webSession(source: String): JSONObject? {
        val d = doc(source)
        val scripts = d.select("script").joinToString("\n") { it.data() }
        val uid = Regex("\\bdiscuz_uid\\s*=\\s*['\"](\\d+)['\"]").find(scripts)?.groupValues?.get(1) ?: return null
        val hash = d.selectFirst("input[name=formhash]")?.attr("value")
            ?: Regex("\\bformhash\\s*=\\s*['\"]([a-zA-Z0-9]{8})['\"]").find(scripts)?.groupValues?.get(1).orEmpty()
        return JSONObject().put("member_uid", uid).put("member_username", d.label(".comiis_user_name, .comiis_myname, .vwmy")).put("formhash", hash)
    }
    fun darkroom(source: String): JSONObject = JSONObject(source.trim().removePrefix("\uFEFF").replace(Regex("\"(?:\\\\.|[^\"\\\\])*\"|([,{]\\s*)(\\d+)(\\s*:)")) {m->if(m.groupValues[2].isEmpty())m.value else "${m.groupValues[1]}\"${m.groupValues[2]}\"${m.groupValues[3]}"})
    fun originals(v:JSONObject,tid:String):Map<String,String> {
        require(v.optJSONObject("thread")?.optString("tid")==tid) {"图片所属帖子不匹配"}
        if(v.optString("forum_threadpay")=="1") return emptyMap()
        val a=v.optJSONArray("postlist")?.objects()?.firstOrNull {it.optString("first")=="1"}?.optJSONObject("attachments") ?: return emptyMap()
        return a.keys().asSequence().mapNotNull {id->
            val j=a.optJSONObject(id) ?: return@mapNotNull null
            if(j.optString("isimage")!="1" || (j.optDouble("price",0.0)>0 && j.optString("payed")!="1") || j.optString("attachment").isBlank()) null
            else link(j.optString("url")+j.optString("attachment"))?.let {id to it.toString()}
        }.toMap()
    }
}
fun thumbnailAid(raw:String):String? {
    val u=link(raw) ?: return null
    if(!u.isSite()) return null
    val m=Regex("^/data/attachment/image/(\\d{3})/(\\d{2})/(\\d{2})/(\\d{2})_\\d+_\\d+\\.(?:jpg|jpeg|png|webp)$",RegexOption.IGNORE_CASE).find(u.encodedPath) ?: return null
    return m.groupValues.drop(1).joinToString("").toLong().toString()
}
