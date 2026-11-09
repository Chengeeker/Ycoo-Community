package ycoo.net.php

import android.app.Application
import android.content.Context
import android.webkit.CookieManager
import androidx.compose.runtime.*
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import okhttp3.*
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class Site @JvmOverloads constructor(app: Application,startSession:Boolean=true) : AndroidViewModel(app) {
    val prefs = app.getSharedPreferences("compose.v1", Context.MODE_PRIVATE)
    private val cookies = CookieManager.getInstance()
    private val client = OkHttpClient.Builder().connectTimeout(20, TimeUnit.SECONDS).readTimeout(30, TimeUnit.SECONDS)
        .followRedirects(false).followSslRedirects(false).retryOnConnectionFailure(false).build()
    private val sessionLock = Mutex()
    var uid by mutableStateOf(prefs.getString("viewer.uid", "0")!!); private set
    var username by mutableStateOf(prefs.getString("viewer.name", "")!!); private set
    var epoch by mutableIntStateOf(0); private set
    var formhash = ""; private set
    var status by mutableStateOf("")
    var settingsRevision by mutableIntStateOf(0)
    var verified by mutableStateOf(false); private set
    val loggedIn get() = uid != "0"
    private val feeds = mutableMapOf<String, Feed>()
    private val imageRequests=mutableMapOf<String,Deferred<Map<String,String>>>()
    suspend fun originals(tid:String):Map<String,String> {
        val key="$epoch.$uid.$tid"; val ticket=epoch
        val task=imageRequests.getOrPut(key) {viewModelScope.async {val v=api("viewthread",mapOf("tid" to tid,"page" to "1")); assertEpoch(ticket); Parse.originals(v,tid)}}
        return try {task.await()} finally {if(imageRequests[key]===task)imageRequests.remove(key)}
    }

    init {
        coil.Coil.setImageLoader(coil.ImageLoader.Builder(app).components {add(coil.decode.SvgDecoder.Factory())}.okHttpClient(mediaClient(this)).build())
        // Only copy preferences; never mutate Flutter's store during migration.
        if (!prefs.getBoolean("imported", false)) {
            val old = app.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val edit = prefs.edit()
            old.all.forEach { (raw, value) ->
                val key = raw.removePrefix("flutter.")
                if (key in setOf("themeMode", "dynamicColor", "pureBlack", "haptics", "textScale", "autoReplies", "autoSignIn", "floating","liquidGlass","color","replyTools","linkify","showFps") || key.startsWith("history.")||key.matches(Regex("draft\\.\\d+\\.\\d+\\.(subject|message)"))) {
                    when (value) {
                        is Boolean -> edit.putBoolean(key, value)
                        is Long -> edit.putInt(key, value.toInt())
                        is Int -> edit.putInt(key, value)
                        is String -> if (key == "textScale") value.removePrefix("VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu").toFloatOrNull()?.coerceIn(.8f,1.5f)?.let { edit.putFloat(key, it) } else edit.putString(key, value)
                    }
                }
            }
            runCatching { JSONObject(old.getString("flutter.session.viewer", "{}")!!) }.getOrNull()?.let {
                uid = it.optString("uid", "0"); username = it.optString("name")
                edit.putString("viewer.uid", uid).putString("viewer.name", username)
            }
            edit.putBoolean("imported", true).apply()
        }
        if(startSession)viewModelScope.launch { try { syncSession(); autoSign() } catch (e: Exception) { if(e !is CancellationException) status = e.message ?: "会话核对失败" } }
    }
    fun setting(key: String, value: Any) {
        prefs.edit().apply {
            when (value) { is Boolean -> putBoolean(key, value); is Int -> putInt(key, value); is Float -> putFloat(key, value); is String -> putString(key, value) }
        }.apply()
        settingsRevision++
    }
    fun assertEpoch(ticket: Int) { check(epoch == ticket) { "账户已切换，请重新加载" } }
    suspend fun request(path: String, data: Map<String, String>? = null, body:RequestBody?=null): String {
        var target = link(path) ?: error("无效地址")
        val ticket = epoch
        var fields = data
        var payload = body
        repeat(4) {
            require(target.isSite()) { "站点要求跳转外部页面，请使用原站入口" }
            val cookie = withContext(Dispatchers.Main) { assertEpoch(ticket); cookies.getCookie(target.toString()).orEmpty() }
            val request = Request.Builder().url(target).header("User-Agent", if(target.queryParameter("mobile") == "2" || target.encodedPath.startsWith("/api/mobile/")) MOBILE_UA else DESKTOP_UA)
                .header("Referer", "$ORIGIN/").header("Cache-Control", "no-cache, no-store")
            if(cookie.isNotBlank()) request.header("Cookie", cookie)
            fields?.let { values -> request.post(FormBody.Builder().apply { values.forEach { (k,v) -> add(k,v) } }.build()) }
            payload?.let {request.post(it)}
            val reply = withContext(Dispatchers.IO) {
                client.newCall(request.build()).execute().use { response ->
                    require(response.code in 200..399) { "服务器返回 ${response.code}，请稍后重试" }
                    Reply(response.code, response.header("Location"), response.headers("Set-Cookie"), response.body?.string().orEmpty())
                }
            }
            withContext(Dispatchers.Main) {
                assertEpoch(ticket)
                reply.cookies.forEach { cookies.setCookie(target.toString(), it) }
                cookies.flush()
            }
            if(reply.code < 300) return reply.body
            target = link(reply.location.orEmpty(), target.toString()) ?: error("站点跳转失败")
            if(reply.code !in setOf(307,308)){fields=null;payload=null}
        }
        error("站点跳转次数过多")
    }
    private data class Reply(val code: Int, val location: String?, val cookies: List<String>, val body: String)
    fun url(path: String, query: Map<String, String>) = requireNotNull(link(path)).newBuilder().apply { query.forEach { (k,v) -> setQueryParameter(k,v) } }.build().toString()
    suspend fun api(module: String, query: Map<String, String> = emptyMap(), data: Map<String, String>? = null): JSONObject {
        val ticket = epoch
        val body = request(url("/api/mobile/index.php", mapOf("module" to module, "version" to "4") + query), data)
        val result = withContext(Dispatchers.Default) { Parse.api(body, data != null && module in setOf("newthread", "sendreply", "favthread"),module=="login") }
        assertEpoch(ticket)
        if(result.has("formhash")) formhash = result.optString("formhash")
        return result
    }
    suspend fun syncSession() = sessionLock.withLock {
        val ticket = epoch
        var vars: JSONObject? = null
        try { vars = api("login", mapOf("_session" to System.nanoTime().toString())) } catch(e: Exception) {
            if(e is CancellationException) throw e
        }
        if(vars?.optString("member_uid", "0") in listOf(null, "", "0")) {
            val source = request("/home.php?mod=space&do=profile&mycenter=1&mobile=2&_session=${System.nanoTime()}")
            Parse.webSession(source)?.let { vars = it }
        }
        assertEpoch(ticket)
        val viewer = vars ?: error("无法确认登录状态；已有离线内容保留")
        val id = viewer.optString("member_uid", "0").ifBlank { "0" }
        var name = viewer.text("member_username")
        if(id != "0" && name.isBlank()) {
            name = if(uid == id && username.isNotBlank()) username else try {api("profile",mapOf("uid" to id)).optJSONObject("space")?.takeIf{it.optString("uid")==id}?.text("username").orEmpty()}catch(e:Exception){if(e is CancellationException)throw e;""}
        }
        assertEpoch(ticket)
        if(uid != id) { epoch++; feeds.clear() }
        uid = id; username = name; verified = true
        formhash = viewer.optString("formhash", formhash)
        prefs.edit().putString("viewer.uid", uid).putString("viewer.name", name).apply()
    }
    suspend fun login(name: String, password: String, question: String, answer: String) {
        epoch++; verified = false; feeds.clear()
        syncSession()
        try {
            api("login", mapOf("loginsubmit" to "yes", "loginfield" to "auto"), mapOf("username" to name, "password" to password,
                "questionid" to question, "answer" to answer, "cookietime" to "2592000", "formhash" to formhash))
        } catch (e: LoginWebRequired) {
            syncSession()
            if(!loggedIn) throw e
        }
        syncSession()
        check(loggedIn) { "登录未完成，请使用网页登录完成验证码" }
        clearCache()
    }
    suspend fun logout() {
        epoch++; verified = false
        val account = uid
        suspendCancellableCoroutine<Unit> { c -> cookies.removeAllCookies { if(c.isActive) c.resume(Unit) {} } }
        cookies.flush()
        uid = "0"; username = ""; formhash = ""; feeds.clear()
        prefs.edit().apply {
            prefs.all.keys.filter { it.startsWith("cache.$account.") || it.startsWith("position.$account.") || it.startsWith("draft.$account.") || it == "history.$account" }.forEach(::remove)
            remove("viewer.uid"); remove("viewer.name")
        }.apply()
        coil.Coil.imageLoader(getApplication()).memoryCache?.clear()
    }
    fun clearCache() {
        feeds.clear()
        prefs.edit().apply { prefs.all.keys.filter { it.startsWith("cache.") || it.startsWith("position.") }.forEach(::remove) }.apply()
        coil.Coil.imageLoader(getApplication()).memoryCache?.clear()
    }
    fun history(): List<Topic> = runCatching { JSONArray(prefs.getString("history.$uid", "[]")).objects().map(Topic::from) }.getOrDefault(emptyList())
    fun remember(topic: Topic) { prefs.edit().putString("history.$uid", JSONArray((listOf(topic) + history().filter { it.id != topic.id }).take(200).map { it.json() }).toString()).apply() }
    fun beginWebSessionChange() { epoch++; feeds.clear(); verified = false }
    private val signLock=Mutex()
    suspend fun autoSign() = signLock.withLock {
        if(!loggedIn || !verified || !prefs.getBoolean("autoSignIn", false)) return@withLock
        val ticket = epoch
        val d = doc(request("/k_misign-sign.html?mobile=2&_session=${System.nanoTime()}"))
        assertEpoch(ticket)
        val label = d.label("#signresult")
        if(label.contains("已签") || label.isBlank()||!prefs.getBoolean("autoSignIn",false)) return@withLock
        val hash = d.selectFirst("input[name=formhash]")?.attr("value") ?: Regex("formhash=([a-zA-Z0-9]{8})").find(d.html())?.groupValues?.get(1).orEmpty()
        if(hash.matches(Regex("[a-zA-Z0-9]{8}"))) request("/plugin.php?id=k_misign:sign&operation=qiandao&format=text&formhash=$hash&mobile=2")
    }
    suspend fun batch(view: String, page: Int, next: String? = null): Batch = withContext(Dispatchers.Default) {
        if(view.startsWith("search:")) {
            val sourceUrl = next ?: url("/plugin.php", mapOf("id" to "twpx_xunsearch", "q" to view.substringAfter(":"), "s" to "relevance", "syn" to "yes"))
            return@withContext Parse.search(request(sourceUrl), sourceUrl)
        }
        if(view.startsWith("forum:")) {
            val parts = view.split(":")
            val query = mapOf("fid" to parts[1], "page" to "$page") + if(parts.getOrNull(2).isNullOrEmpty()) emptyMap() else mapOf("typeid" to parts[2])
            val v = api("forumdisplay", query)
            val summaries = v.optJSONArray("forum_threadlist")?.objects()?.map(Topic::from).orEmpty()
            val mobile = try { Parse.mobile(request(url("/forum.php", query + mapOf("mod" to "forumdisplay", "mobile" to "2"))), page) } catch(e: Exception) { if(e is CancellationException) throw e; null }
            val types = v.optJSONObject("threadtypes")?.optJSONObject("types")
            val topics = mobile?.topics?.takeIf { it.isNotEmpty() }?.map { t ->
                val api = summaries.firstOrNull { it.id == t.id }
                if(api == null) t else t.copy(author = t.author.ifBlank { api.author }, uid = t.uid.ifBlank { api.uid },
                    preview = t.preview.ifBlank { api.preview }, replies = t.replies.ifBlank { api.replies }, views = t.views.ifBlank { api.views }, fid = parts[1])
            } ?: summaries
            return@withContext Batch(topics, mobile?.more ?: (page * v.optInt("tpp", 20) < (v.optJSONObject("forum")?.optInt("threads") ?: 0)),
                types = types?.keys()?.asSequence()?.associateWith { types.text(it) }.orEmpty())
        }
        val portals = mapOf("portal" to "28", "circles" to "72", "following" to "45", "following_forums" to "46", "following_friends" to "47")
        if(view in portals) {
            if(view.startsWith("following")) check(loggedIn) { "登录后查看关注动态" }
            val q = mutableMapOf("id" to "comiis_app_portal", "pid" to portals.getValue(view), "page" to "$page", "mobile" to "2", "inajax" to "1")
            if(page == 1) q["comiis_list"] = "yes"
            if(page > 1 && view.startsWith("following")) q["op"] = mapOf("following" to "user", "following_forums" to "bbs", "following_friends" to "friend").getValue(view)
            val b = Parse.mobile(request(url("/plugin.php", q)), page)
            val sections = if(page == 1 && view in setOf("portal", "circles")) Parse.portal(request(url("/plugin.php", q - "comiis_list" - "page" + ("istab" to "yes")))) else emptyMap()
            return@withContext b.copy(sections = sections)
        }
        if(view.startsWith("my:")) {
            check(loggedIn) { "请先登录" }
            val v = api(view.substringAfter(":"), mapOf("page" to "$page"))
            val raw = v.opt("list") ?: v.opt("data")
            val list = when(raw) {
                is JSONArray -> raw
                is JSONObject -> raw.optJSONArray("list") ?: JSONArray(raw.keys().asSequence().map {raw.opt(it)}.toList())
                else -> JSONArray()
            }
            val topics = list.objects().map {j -> if(!j.has("subject")) j.put("subject",j.optString("title")); Topic.from(j)}
            return@withContext Batch(topics, topics.isNotEmpty() && if(v.optInt("count")>0) page * v.optInt("perpage",20)<v.optInt("count") else topics.size>=v.optInt("perpage",20).coerceAtLeast(1))
        }
        return@withContext Parse.mobile(request("/forum.php?mod=guide&view=$view&page=$page&index=1&mobile=2"), page)
    }
    fun feed(view: String): Feed = feeds.getOrPut("$uid.$view") { Feed(this, view, uid, epoch) }
    fun run(action: suspend () -> Unit) = viewModelScope.launch { try { action() } catch(e: Exception) { if(e is CancellationException) throw e; status = e.message ?: "操作失败，请重试" } }
}

class Feed(private val site: Site, val view: String, private val account: String, private val ticket: Int) {
    var topics by mutableStateOf(emptyList<Topic>())
    var sections by mutableStateOf(emptyMap<String,List<Entry>>())
    var types by mutableStateOf(emptyMap<String,String>())
    var busy by mutableStateOf(false)
    var error by mutableStateOf("")
    var page = 0
    var more by mutableStateOf(true)
    var next: String? = null
    private val key = "cache.$account.$view"
    init {
        runCatching {
            val j = JSONObject(site.prefs.getString(key, "{}")!!)
            topics = j.optJSONArray("topics")?.objects()?.map(Topic::from).orEmpty()
            if(topics.isNotEmpty()) {
                page = j.optInt("page"); more = j.optBoolean("more"); next = j.optString("next").ifBlank { null }
                val s = j.optJSONObject("sections") ?: JSONObject()
                sections = s.keys().asSequence().associateWith { k -> s.getJSONArray(k).objects().map { Entry(it.getString("title"), it.getString("url"), it.optString("image"), it.optString("detail"),it.optString("author"),it.optString("avatar")) } }
                val t = j.optJSONObject("types") ?: JSONObject()
                types = t.keys().asSequence().associateWith { t.getString(it) }
            }
        }.onFailure { topics = emptyList(); page = 0; more = true }
    }
    suspend fun load(refresh: Boolean = false) {
        if(busy || (!refresh && !more)) return
        busy = true; error = ""
        try {
            site.assertEpoch(ticket)
            val requested = if(refresh) 1 else page + 1
            val batch = site.batch(view, requested, if(refresh) null else next)
            site.assertEpoch(ticket)
            topics = ((if(refresh) emptyList() else topics) + batch.topics).distinctBy { it.id }
            if(requested == 1) { sections = batch.sections; types = batch.types }
            page = requested; more = batch.more && batch.topics.isNotEmpty(); next = batch.next
            if(topics.size <= 200) {
                val s = JSONObject(); sections.forEach { (k,v) -> s.put(k, JSONArray(v.map { JSONObject().put("title",it.title).put("url",it.url).put("image",it.image).put("detail",it.detail).put("author",it.author).put("avatar",it.avatar) })) }
                site.prefs.edit().putString(key, JSONObject().put("topics",JSONArray(topics.map { it.json() })).put("page",page).put("more",more)
                    .put("next",next.orEmpty()).put("sections",s).put("types",JSONObject(types)).toString()).apply()
            }
        } catch(e: Exception) { if(e is CancellationException) throw e; error = e.message ?: "加载失败，请重试" } finally { busy = false }
    }
    fun savePosition(index: Int, offset: Int) {
        if(site.epoch != ticket || !site.prefs.contains(key) || topics.size>200) return
        site.prefs.edit().putInt("position.$account.$view.index",index).putInt("position.$account.$view.offset",offset).apply()
    }
}
