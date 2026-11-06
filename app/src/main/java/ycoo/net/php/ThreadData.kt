package ycoo.net.php

import org.json.JSONObject

fun JSONObject.threadPurchaseUnlocked():Boolean =
    !isNull("forum_threadpay")&&optString("forum_threadpay") in setOf("","0","false")

fun enrichThreadPosts(posts:List<JSONObject>,source:String,allowBody:Boolean) {
    val d=doc(source)
    fun compact(s:String)=s.replace(Regex("\\s+|\u00a0"),"")
    for(p in posts) {
        val pid=p.optString("pid");if(!pid.matches(Regex("\\d+")))continue
        val node=d.getElementById("pid$pid") ?: continue
        val body=node.selectFirst(".comiis_messages")
        val first=p.optString("first")=="1"
        if(allowBody&&body!=null) {
            val apiText=compact(p.text("message"))
            if(apiText.isNotEmpty()&&compact(body.text()).contains(apiText))p.put("displayMessage",body.html())
        }else if(first&&body!=null) {
            // Comiis uses a separate quote immediately before the purchase panel for the public preview.
            val panel=body.children().firstOrNull {
                it.hasClass("comiis_quote")&&it.ownText().contains("本主题需向作者支付")&&
                    it.select("a").any {a->a.text().endsWith("购买主题")}
            }
            panel?.label(".kmren")?.takeIf {it.matches(Regex("已有\\s*[0-9]+\\s*人购买"))}?.let {p.put("displayPayCount",it)}
            panel?.previousElementSibling()?.takeIf {
                it.hasClass("comiis_quote")&&it.id().matches(Regex("postmessage_[0-9]+"))
            }?.let {p.put("displayPayPreview",it.html())}
        }
        node.label(".top_lev").takeIf {it.isNotBlank()}?.let {p.put("displayLevel",it)}
        node.label(".comiis_postli_time a").takeIf {it.isNotBlank()}?.let {p.put("displayCategory",it)}
        if(first)node.selectFirst("#copyright")?.let {p.put("displayCopyright",it.outerHtml())}
    }
}
fun hasForumFileAttachment(post:JSONObject,locked:Boolean):Boolean =
    !locked&&jsonRows(post.opt("attachments")).any {
        it.optString("isimage")!="1"&&(it.text("filename").isNotEmpty()||it.text("attachment").isNotEmpty())
    }

fun forumPostHtml(post:JSONObject,locked:Boolean=false):String {
    if(locked)return post.optString("displayPayPreview")
    val fragment=doc(post.optString("displayMessage",post.optString("message"))).body()
    val attachments=post.optJSONObject("attachments") ?: return fragment.html()
    attachments.keys().forEach {id->val item=attachments.optJSONObject(id) ?: return@forEach
        if(item.optString("isimage")!="1"||(item.optDouble("price",0.0)>0&&item.optString("payed")!="1"))return@forEach
        val path=item.optString("attachment");if(path.isBlank())return@forEach
        val url=link(item.optString("url")+path)?.toString() ?: return@forEach
        val existing=fragment.select("img").firstOrNull {img->img.attr("aid")==id||img.attributes().any {link(it.value)?.toString()==url||it.value==path}}
        if(existing!=null){existing.attr("file",url);return@forEach}
        val image=org.jsoup.nodes.Element("img").attr("src",url);val encoded=item.optString("aidencode")
        val a=fragment.select("a[href]").firstOrNull {encoded.isNotEmpty()&&it.attr("href").contains(encoded)}
        if(a!=null)a.replaceWith(image)else fragment.appendChild(image)
    }
    return fragment.html()
}
