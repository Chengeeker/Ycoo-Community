package ycoo.net.php

import org.junit.Assert.*
import org.junit.Test
import org.json.JSONObject
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.TextFieldValue

class MigrationTest {
    @Test fun mixedImageParagraphsKeepFormattingAndLinks(){
        val parts=bodyParts("<b>前<img src='a.jpg'><a href='/forum.php'>后</a></b>")
        assertEquals(3,parts.size);assertEquals(parts[0].html,"前",doc(parts[0].html).selectFirst("b")?.text());assertEquals(parts[2].html,"/forum.php",doc(parts[2].html).selectFirst("b a")?.attr("href"));assertEquals("$ORIGIN/a.jpg",parts[1].image)
    }
    @Test fun mismatchedProfileHtmlCannotReplacePublicApiIdentity(){
        val user=UserProfile("12",JSONObject().put("username","正确用户").put("sightml","正确签名"),JSONObject(),"<div class='comiis_space_tx'><h2>其他人</h2></div><div class='profile_face'>其他签名</div><div class='comiis_space_profile'><li><span>用户ID</span><b class='profile_rs'>13</b></li></div><a id='followmod'>已关注</a>")
        assertEquals("正确用户",user.name);assertEquals("正确签名",user.signature);assertFalse(user.followed);assertTrue(user.document.body().children().isEmpty())
    }
    @Test fun galleryReturnInterpolatesTheImagePlaneFromFullViewToCoverCrop(){
        val image=androidx.compose.ui.geometry.Size(200f,100f);val tile=androidx.compose.ui.geometry.Size(100f,100f);val screen=androidx.compose.ui.geometry.Size(400f,800f)
        assertEquals(image,galleryReturnSize(image,tile,screen,0f,2f));assertEquals(androidx.compose.ui.geometry.Size(800f,400f),galleryReturnSize(image,tile,screen,1f,2f))
    }
    @Test fun androidViewModelFactoryCanConstructTheApplicationModel(){
        assertNotNull(Site::class.java.getConstructor(android.app.Application::class.java))
    }
    @Test fun htmlLoginRequiresWebVerificationAndErrorCodesStayErrors(){
        assertThrows(LoginWebRequired::class.java){Parse.api("<html>验证</html>",login=true)}
        assertThrows(IllegalArgumentException::class.java){Parse.api("""{"Message":{"messageval":"login_invalid","messagestr":"密码错误"},"Variables":{}}""",login=true)}
    }
    @Test fun nativePartsKeepOriginalOrderAndHiddenFormFields(){
        val page=parseNative("<div id='ct'><p>之前</p><form action='/home.php'><input hidden name='token' value='keep'><button>提交</button></form><p>之后</p></div>","$ORIGIN/home.php?mod=task")
        assertEquals(listOf("html","form","html"),page.parts.map{it.kind});assertEquals(listOf("keep"),initialFormValues(page.forms.first())["token"])
        val tabs=parseNative("<div id='ct'><ul><li class='a'><a href='#'>我的好友</a></li><li><a href='/home.php?mod=space&do=friend&view=visitor'>最近来访</a></li></ul></div>","$ORIGIN/home.php?mod=space&do=friend")
        assertEquals(2,tabs.tabs.size);assertEquals(0,tabs.selected)
    }
    private fun fixture(name:String)=requireNotNull(javaClass.classLoader?.getResource(name)).readText()
    @Test fun darkroomConversionDoesNotModifyQuotedText(){
        val j=Parse.darkroom("""{12:{"message":"内容 {123: 不得修改,456: 也不修改","quote":"\\\"123:"}}""")
        assertEquals("内容 {123: 不得修改,456: 也不修改",j.getJSONObject("12").getString("message"))
    }
    @Test fun editorToolsRespectSelectionAndCustomReplacement(){
        val text=TextFieldValue("前正文后",TextRange(1,3))
        val bold=applyReplyTool(text,defaultReplyTools.first())
        assertEquals("前[b]正文[/b]后",bold.text);assertEquals(TextRange(4,6),bold.selection)
        val custom=applyReplyTool(text,ReplyTool("回复","","","新内容",true))
        assertEquals("前新内容后",custom.text);assertEquals(TextRange(4),custom.selection)
        assertEquals(19,loadReplyTools("broken").size)
    }
    @Test fun profileActionsRejectMismatchedIdsAndOrigins(){
        fun html(url:String)="<a id='followmod' href=\"$url\">关注</a>"
        assertNotNull(profileAction(html("/home.php?mod=spacecp&ac=follow&fuid=12&hash=abc"),"12","follow"))
        assertNull(profileAction(html("/home.php?mod=spacecp&ac=follow&fuid=12&uid=13"),"12","follow"))
        assertNull(profileAction(html("https://evil.test/home.php?mod=spacecp&ac=follow&fuid=12"),"12","follow"))
        assertNull(profileAction(html("/home.php?mod=spacecp&ac=friend&op=ignore&uid=12"),"12","friend"))
        assertNotNull(profileAction("""<a id="followmod" href="javascript:popup.open('home.php?mod=spacecp&ac=follow&fuid=12&hash=abc')">关注</a>""","12","follow"))
    }
    @Test fun nativeFormsKeepRepeatedCheckboxesAndProtectLogin(){
        val f=doc("""<form><input name="ids[]" type="checkbox" value="1" checked><input name="ids[]" type="checkbox" value="2" checked><input name="ids[]" type="checkbox" value="3"><input name="group" type="radio" value="one"><input name="group" type="radio" value="two" checked><input type="hidden" name="token" value="secret"></form>""").selectFirst("form")!!
        assertEquals(listOf("1","2"),initialFormValues(f)["ids[]"]);assertEquals(listOf("two"),initialFormValues(f)["group"])
        val p=parseNative("<div id='ct'><form id='loginform'><input name='password' value='secret'></form></div>","$ORIGIN/home.php?mod=task&uid=123&formhash=secret")
        assertTrue(p.login);assertTrue(p.forms.isEmpty());assertFalse(p.info.contains("secret"));assertFalse(p.info.contains("123"));assertTrue(p.info.contains("password"))
    }
    @Test fun bodyRestorationRequiresSameVisibleContent(){
        val p=JSONObject().put("pid","1").put("message","允许内容").put("first","1")
        val html="<div id='pid1'><span class='top_lev'>Lv.5</span><div class='comiis_messages'><b>允许内容</b></div></div>"
        enrichThreadPosts(listOf(p),html,false);assertFalse(p.has("displayMessage"));assertEquals("Lv.5",p.getString("displayLevel"))
        enrichThreadPosts(listOf(p),html,true);assertTrue(p.getString("displayMessage").contains("<b>"))
        val hidden=JSONObject().put("pid","1").put("message","无权阅读")
        enrichThreadPosts(listOf(hidden),html,true);assertFalse(hidden.has("displayMessage"))
    }
    @Test fun imageAttachmentsRespectPaymentAndIdentity(){
        val image=JSONObject().put("isimage","1").put("price","2").put("url","$ORIGIN/").put("attachment","test.jpg")
        val p=JSONObject().put("first","1").put("message","正文").put("attachments",JSONObject().put("123",image))
        assertFalse(forumPostHtml(p).contains("test.jpg"));image.put("payed","1");assertTrue(forumPostHtml(p).contains("test.jpg"))
        val v=JSONObject().put("thread",JSONObject().put("tid","10")).put("postlist",org.json.JSONArray().put(p)).put("forum_threadpay","1")
        assertTrue(Parse.originals(v,"10").isEmpty());v.put("forum_threadpay","0");assertEquals("$ORIGIN/test.jpg",Parse.originals(v,"10")["123"])
        assertThrows(IllegalArgumentException::class.java){Parse.originals(v,"11")}
    }
    @Test fun lockedFirstPostUsesOnlyThePublicPreviewAndHidesAttachments() {
        val post=JSONObject("""{"pid":"11","first":"1","message":"付费主题, 价格 5 星币","attachments":{"21":{"isimage":"0","filename":"文件.zip"},"22":{"isimage":"1","url":"/","attachment":"private.jpg"}}}""")
        val html="""
            <div id="pid11"><div class="comiis_messages">
                <div id="postmessage_12" class="comiis_quote bg_h">作者公开预览<br>第二行</div>
                <div class="comiis_quote bg_h"><span class="kmren">已有 454 人购买</span>
                    本主题需向作者支付 <strong>5星币</strong> 才能浏览 <a href="javascript:;">购买主题</a>
                </div>
                <p>其余网页内容</p>
            </div><div id="copyright">版权声明</div></div>
        """
        enrichThreadPosts(listOf(post),html,false)
        val locked=forumPostHtml(post,true)
        assertEquals("作者公开预览 第二行",plain(locked))
        assertTrue(locked.contains("<br>"))
        assertFalse(locked.contains("价格")||locked.contains("其余网页内容")||locked.contains("private.jpg"))
        assertEquals("已有 454 人购买",post.optString("displayPayCount"))
        assertTrue(post.optString("displayCopyright").contains("版权声明"))
        assertFalse(hasForumFileAttachment(post,true))
        assertTrue(hasForumFileAttachment(post,false))
        assertFalse(hasForumFileAttachment(JSONObject("""{"attachments":{"21":{}}}"""),false))
        val wrong=JSONObject("""{"pid":"12","first":"1","message":"付费主题, 价格 5 星币"}""")
        enrichThreadPosts(listOf(wrong),html,false)
        assertEquals("",forumPostHtml(wrong,true))
    }
    @Test fun purchaseAcceptsOnlyTheMatchingPostFormAndExplicitUnlockState() {
        val url="$ORIGIN/forum.php?mod=misc&action=pay&tid=11&mobile=2"
        val form="""<form method="post" action="/forum.php?mod=misc&amp;action=pay&amp;paysubmit=yes">
            <input type="hidden" name="tid" value="11"><button name="paysubmit">购买</button>
        </form>"""
        val page=parseNative(form.replace("value=\"11\"","value=\"12\"")+form+form.replace("method=\"post\"","method=\"get\""),url)
        assertEquals(1,page.forms.size)
        assertEquals(listOf("11"),initialFormValues(page.forms.single())["tid"])
        assertFalse(JSONObject().threadPurchaseUnlocked())
        assertFalse(JSONObject("""{"forum_threadpay":"1"}""").threadPurchaseUnlocked())
        assertFalse(JSONObject("""{"forum_threadpay":null}""").threadPurchaseUnlocked())
        assertTrue(JSONObject("""{"forum_threadpay":"0"}""").threadPurchaseUnlocked())
    }
    @Test fun richBodyRetainsFramesAndPreviewUrls(){
        val parts=bodyParts("<blockquote>引用</blockquote><img src='small.jpg' file='full.jpg'><video poster='poster.jpg' src='movie.mp4'></video>")
        assertTrue(parts.first().children!!.first().html.contains("引用"));assertEquals("$ORIGIN/full.jpg",parts[1].image);assertEquals("$ORIGIN/small.jpg",parts[1].preview);assertEquals("$ORIGIN/poster.jpg",parts[2].poster)
    }
    @Test fun signAndMedalFixturesAreRecognized(){
        assertTrue(SignData.parse(fixture("signin.html")).stats.isNotEmpty())
        val medals=parseNative(fixture("medal-applications.html"),"$ORIGIN/home.php?mod=medal").medals
        assertTrue(medals.isNotEmpty());assertTrue(medals.any{it.url.isNotBlank()});assertTrue(medals.filter{it.url.isNotBlank()}.all{link(it.url)!!.isSite()})
    }
    @Test fun galleryZoomAndImageFormatMatchOriginal(){
        assertEquals(2.5f,nextGalleryZoom(1f,false));assertEquals(3.5f,nextGalleryZoom(1f,true));assertEquals(6f,nextGalleryZoom(2.5f,false));assertEquals(1f,nextGalleryZoom(6f,false))
        assertEquals("png" to "image/png",galleryImageFormat(byteArrayOf(137.toByte(),80,78,71,0,0,0,0,0,0,0,0)))
        assertNull(galleryImageFormat("<html>login</html>".toByteArray()))
    }
    @Test fun originalWebViewBoundariesAreRetained(){
        listOf("/plugin.php?id=jnfarm","/group.php","/home.php?mod=spacecp&ac=credit&op=buy").forEach{assertFalse(nativePage(it))}
        listOf("/plugin.php?id=bphp_clouds:index","/home.php?mod=task","/home.php?mod=medal","/home.php?mod=space&do=friend&view=visitor","/home.php?mod=spacecp&ac=credit&op=log").forEach{assertTrue(nativePage(it))}
    }
}
