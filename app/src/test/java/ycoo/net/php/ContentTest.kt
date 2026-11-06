package ycoo.net.php

import org.junit.Assert.*
import org.junit.Test

class ContentTest {
    private fun fixture(name:String)=requireNotNull(javaClass.classLoader?.getResource(name)).readText()
    @Test fun exactOriginAndRouting() {
        assertTrue(link("http://ycoo.net/forum.php")!!.isSite())
        listOf("https://ycoo.net.evil.test/", "https://ycoo.net:444/", "https://evil.test/").forEach {assertFalse(link(it)!!.isSite())}
        assertNull(link("https://secret@ycoo.net/")); assertNull(link("javascript:alert(1)")); assertNull(link("file:///data/"))
        assertEquals("154095",threadId(link("/thread-154095-1-1.html")!!))
        assertNull(threadId(link("https://elsewhere.test/forum.php?mod=viewthread&tid=1")!!))
        assertEquals("123",profileId(link("/home.php?mod=space&uid=123&do=profile")!!))
        assertNull(profileId(link("/home.php?mod=space&uid=123&do=album")!!))
    }
    @Test fun mobilePinnedOrderAndImages() {
        val b=Parse.mobile(fixture("mobile-forum.html"),1)
        assertEquals(listOf("149059","98450","26477","1419"),b.topics.take(4).map {it.id})
        assertTrue(b.topics.take(4).all {it.pinned})
        assertTrue(b.topics.any {it.images.isNotEmpty()})
        assertEquals(b.topics.size,b.topics.distinctBy {it.id}.size)
        assertTrue(b.topics.any {it.level.isNotEmpty()})
    }
    @Test fun portalKeepsAllConfiguredModules() {
        val s=Parse.portal(fixture("mobile-home.xml"))
        assertEquals(10,s["推荐"]?.size); assertEquals(5,s["快捷服务"]?.size)
        assertEquals(8,s["热门版块"]?.size); assertEquals(15,s["七日排行"]?.size); assertEquals(8,s["置顶"]?.size)
    }
    @Test fun feedAndSearchUseActualFixtures() {
        assertTrue(Parse.mobile(fixture("mobile-feed.xml"),1).topics.isNotEmpty())
        val b=Parse.search(fixture("search.html"),"$ORIGIN/plugin.php?id=twpx_xunsearch&q=test")
        assertTrue(b.topics.isNotEmpty())
        b.next?.let {assertTrue(link(it)!!.isSite()); assertEquals("2",link(it)!!.queryParameter("p"))}
    }
    @Test fun writesRequirePositiveConfirmation() {
        val ambiguous="""{"Variables":{"formhash":"abcd1234"}}"""
        assertEquals("abcd1234",Parse.api(ambiguous).getString("formhash"))
        assertThrows(IllegalArgumentException::class.java) {Parse.api(ambiguous,true)}
        assertThrows(IllegalArgumentException::class.java) {Parse.api("""{"Variables":{},"Message":{"messageval":"post_failed","messagestr":"拒绝"}}""",true)}
        Parse.api("""{"Variables":{},"Message":{"messageval":"post_reply_succeed"}}""",true)
    }
    @Test fun malformedDarkroomIsNotNetworkFailure() {
        assertEquals("Archive",Parse.darkroom(fixture("darkroom-response.txt")).getJSONObject("data").getJSONObject("28432").getString("username"))
    }
    @Test fun visitorLinkCannotSetSessionIdentity() {
        assertNull(Parse.webSession("<a href='home.php?mod=space&uid=5'>某用户</a>"))
        val v=Parse.webSession("<script>var discuz_uid='12'; var formhash='abcd1234';</script><div class='comiis_myname'>测试</div>")!!
        assertEquals("12",v.getString("member_uid")); assertEquals("测试",v.getString("member_username"))
    }
    @Test fun topicRoundTripPreservesCache() {
        val t=Topic("1","标题","作者","2",images=listOf("$ORIGIN/image.jpg"),pinned=true,level="Lv.7")
        assertEquals(t.copy(avatar=avatar("2")),Topic.from(t.json()))
    }
    @Test fun nativeFormsKeepHiddenFieldsAndOnlyCheckedValues() {
        val form=doc("""<form><input name="formhash" type="hidden" value="12345678"><input name="no" type="checkbox"><input name="yes" type="checkbox" checked value="1"><select name="type"><option value="1">一</option><option value="2" selected>二</option></select><textarea name="text">草稿</textarea><input name="disabled" disabled value="x"></form>""").selectFirst("form")!!
        assertEquals(mapOf("formhash" to "12345678","yes" to "1","type" to "2","text" to "草稿"),formValues(form))
    }
    @Test fun nativeContactsRemainStructured() {
        val c=parseNative(fixture("account-user-list.html"),"$ORIGIN/home.php?mod=space&do=friend&view=visitor&mobile=2")
        assertTrue(c.contacts.isNotEmpty())
        assertTrue(c.contacts.all {profileId(link(it.url)!!)!=null})
    }
    @Test fun bodyRetainsLinksAndMediaWithoutScript() {
        val p=bodyParts("<p>正文<a href='forum.php?mod=viewthread&tid=1'>链接</a></p><img file='a.jpg'><video><source src='b.mp4'></video><script>bad()</script>")
        assertTrue(p.any {it.html.contains("链接")}); assertEquals("$ORIGIN/a.jpg",p.first {it.image.isNotEmpty()}.image)
        assertEquals("$ORIGIN/b.mp4",p.first {it.video.isNotEmpty()}.video); assertFalse(p.any {it.html.contains("bad()")})
    }
}
