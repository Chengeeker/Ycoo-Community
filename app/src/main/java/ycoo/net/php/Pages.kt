package ycoo.net.php

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.*
import org.json.JSONObject
import android.content.Intent
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.ui.autofill.ContentType
import androidx.compose.ui.semantics.*

@Composable fun EditorPage(site:Site,nav:Nav,route:String) {
    val args=route.split(':'); val fid=args[0]; val tid=args.getOrElse(1){""}; val quote=args.getOrElse(2){""}
    val owner=site.uid; val ticket=site.epoch; val key="draft.$owner.${if(tid.isEmpty()) "forum-$fid" else "thread-$tid"}.$quote"
    remember(key){val oldKey="draft.$owner.${tid.ifEmpty{fid}}";if(!site.prefs.contains("$key.message")&&site.prefs.contains("$oldKey.message")){site.prefs.edit().putString("$key.message",site.prefs.getString("$oldKey.message","" )).putString("$key.subject",site.prefs.getString("$oldKey.subject","" )).remove("$oldKey.message").remove("$oldKey.subject").apply()};true}
    var subject by remember {mutableStateOf(site.prefs.getString("$key.subject","")!!)}
    var message by remember {mutableStateOf(androidx.compose.ui.text.input.TextFieldValue(site.prefs.getString("$key.message","")!!))}
    var type by remember {mutableStateOf(site.prefs.getString("$key.type","")!!)}; var types by remember {mutableStateOf(emptyMap<String,String>())}
    var busy by remember {mutableStateOf(false)}; var sent by remember {mutableStateOf(false)}; var failure by remember {mutableStateOf("")}
    val scope=rememberCoroutineScope()
    fun save() {if(!sent && owner==site.uid && ticket==site.epoch) site.prefs.edit().putString("$key.subject",subject).putString("$key.message",message.text).putString("$key.type",type).apply()}
    fun send() {
        if(busy)return
        if(message.text.isBlank() || (tid.isEmpty() && subject.isBlank())) {site.status="请填写${if(tid.isEmpty())"标题和" else ""}正文";return}
        if(!site.loggedIn) {save();nav.open("login");return}
        busy=true;save();failure=""
        scope.launch {try {
            site.assertEpoch(ticket);site.api("checkpost",mapOf("fid" to fid))
            val query=mutableMapOf("fid" to fid,(if(tid.isEmpty())"topicsubmit" else "replysubmit") to "yes")
            if(tid.isNotEmpty())query["tid"]=tid
            if(quote.isNotEmpty())query["repquote"]=quote
            site.api(if(tid.isEmpty())"newthread" else "sendreply",query,mapOf("formhash" to site.formhash,"subject" to subject,"message" to message.text)+if(type.isEmpty())emptyMap()else mapOf("typeid" to type))
            site.assertEpoch(ticket);sent=true;site.prefs.edit().remove("$key.subject").remove("$key.message").remove("$key.type").apply()
            busy=false;nav.blockBack=false;site.status="服务器已确认发布成功";nav.invalidate(if(tid.isNotEmpty())"thread:$tid"else"forum:$fid");nav.back()
        } catch(e:Exception) {if(e is CancellationException)throw e;failure="${e.message}\n如果提交后连接中断，请先查看原帖确认，避免重复发布。草稿已保留。"} finally {busy=false}}
    }
    LaunchedEffect(Unit) {
        if(tid.isEmpty()) try {site.api("forumdisplay",mapOf("fid" to fid)).optJSONObject("threadtypes")?.optJSONObject("types")?.let {j->types=j.keys().asSequence().associateWith {j.text(it)};if(type !in types)type=types.keys.firstOrNull().orEmpty()}} catch(e:Exception) {if(e is CancellationException)throw e;failure=e.message.orEmpty()}
    }
    DisposableEffect(subject,message,type,sent) {onDispose {save()}}
    val active=LocalPageActive.current
    SideEffect {if(active)nav.blockBack=busy}
    DisposableEffect(active){onDispose{if(active)nav.blockBack=false}}
    PageActions(nav) {TextButton(onClick=tap(::send),enabled=!busy) {Text(if(busy)"提交中…" else "发布")}}
    BackHandler(busy&&active) {}
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).imePadding().padding(start=16.dp,top=LocalPageTop.current+16.dp,end=16.dp,bottom=24.dp)) {
        if(quote.isNotEmpty()) SectionCard {Text(nav.titles["quote:$quote"] ?: "引用回复 #$quote",Modifier.padding(16.dp))}
        if(tid.isEmpty()) {
            OriginalTextField(subject,{subject=it.take(80);save()},label={Text("帖子标题")},supportingText={Text("${subject.length}/80",Modifier.fillMaxWidth(),textAlign=androidx.compose.ui.text.style.TextAlign.End)},enabled=!busy,modifier=Modifier.fillMaxWidth(),colors=originalFieldColors())
            if(types.isNotEmpty()) {var expanded by remember {mutableStateOf(false)}
                Box {OriginalTextField(types[type].orEmpty(),{},label={Text("主题分类")},readOnly=true,enabled=!busy,modifier=Modifier.fillMaxWidth(),colors=originalFieldColors());Box(Modifier.matchParentSize().clickable(enabled=!busy){expanded=true})
                    DropdownMenu(expanded,{expanded=false}) {types.forEach {(id,name)->DropdownMenuItem(text={Text(name)},onClick={type=id;save();expanded=false})}}
                }
            };Spacer(Modifier.height(16.dp))
        }
        OriginalTextField(message,{message=it;save()},label={Text("正文")},placeholder={Text("输入内容，支持论坛 BBCode")},enabled=!busy,minLines=10,modifier=Modifier.fillMaxWidth(),colors=originalFieldColors())
        ComposerTools(site,nav,message,!busy) {message=it;save()}
        if(failure.isNotEmpty())Text(failure,Modifier.padding(top=16.dp),color=MaterialTheme.colorScheme.error)
        Spacer(Modifier.height(16.dp))
        OutlinedButton(enabled=!busy,onClick={save();nav.open("web:$ORIGIN/forum.php?mod=post&action=${if(tid.isEmpty())"newthread" else "reply"}&fid=$fid${if(tid.isNotEmpty())"&tid=$tid" else ""}")}) {
            androidx.compose.material3.Icon(androidx.compose.material.icons.Icons.Rounded.Attachment,null);Spacer(Modifier.width(8.dp));Text("图片、附件、投票与高级编辑")
        }
    }
}
@Composable fun LoginPage(site:Site,nav:Nav) {
    var name by rememberSaveable {mutableStateOf("")}; var password by remember {mutableStateOf("")}
    var answer by remember {mutableStateOf("")}; var question by rememberSaveable {mutableIntStateOf(0)}
    var busy by remember {mutableStateOf(false)}; var error by remember {mutableStateOf("")}
    var hide by remember{mutableStateOf(true)};var validate by remember{mutableStateOf(false)}
    val scope=rememberCoroutineScope();val focus=androidx.compose.ui.platform.LocalFocusManager.current
    val questions=listOf("未设置安全提问","母亲的名字","爷爷的名字","父亲出生的城市","您其中一位老师的名字","您个人计算机的型号","您最喜欢的餐馆名称","驾驶执照最后四位数字")
    fun login(){validate=true;if(busy||name.isBlank()||password.isEmpty()||(question>0&&answer.isEmpty()))return;focus.clearFocus();busy=true;error=""
        scope.launch{try{site.login(name.trim(),password,"$question",answer);password="";if(nav.current=="login")nav.back()}catch(e:LoginWebRequired){nav.open("web:$ORIGIN/member.php?mod=logging&action=login&mobile=2")}catch(e:Exception){if(e is CancellationException)throw e;error=e.message.orEmpty()}finally{busy=false}}}
    Box(Modifier.fillMaxSize(),contentAlignment=Alignment.TopCenter){Column(Modifier.widthIn(max=520.dp).fillMaxWidth().verticalScroll(rememberScrollState()).imePadding().padding(24.dp)) {
        Icon(Icons.Outlined.Forum,null,Modifier.size(56.dp).align(Alignment.CenterHorizontally),tint=MaterialTheme.colorScheme.primary)
        Spacer(Modifier.height(24.dp));Text("欢迎回到源社区",style=MaterialTheme.typography.headlineSmall);Spacer(Modifier.height(24.dp))
        OriginalTextField(name,{name=it},enabled=!busy,label={Text("UID / 用户名 / Email")},leadingIcon={Icon(Icons.Outlined.Person,null)},singleLine=true,isError=validate&&name.isBlank(),supportingText=if(validate&&name.isBlank()){{Text("请输入账户")}}else null,keyboardOptions=KeyboardOptions(imeAction=ImeAction.Next),keyboardActions=KeyboardActions(onNext={focus.moveFocus(androidx.compose.ui.focus.FocusDirection.Down)}),modifier=Modifier.fillMaxWidth().semantics{contentType=ContentType.Username},colors=originalFieldColors())
        Spacer(Modifier.height(16.dp))
        OriginalTextField(password,{password=it},enabled=!busy,label={Text("密码")},leadingIcon={Icon(Icons.Outlined.Lock,null)},trailingIcon={IconButton(onClick={hide=!hide}){Icon(if(hide)Icons.Outlined.Visibility else Icons.Outlined.VisibilityOff,if(hide)"显示密码"else"隐藏密码")}},visualTransformation=if(hide)PasswordVisualTransformation()else VisualTransformation.None,singleLine=true,isError=validate&&password.isEmpty(),supportingText=if(validate&&password.isEmpty()){{Text("请输入密码")}}else null,keyboardOptions=KeyboardOptions(imeAction=ImeAction.Done),keyboardActions=KeyboardActions(onDone={login()}),modifier=Modifier.fillMaxWidth().semantics{contentType=ContentType.Password},colors=originalFieldColors())
        Spacer(Modifier.height(16.dp));var expanded by remember {mutableStateOf(false)}
        Box {OriginalTextField(questions[question],{},enabled=!busy,readOnly=true,label={Text("安全提问")},trailingIcon={Icon(Icons.Rounded.ArrowDropDown,null)},modifier=Modifier.fillMaxWidth(),colors=originalFieldColors());Box(Modifier.matchParentSize().clickable(enabled=!busy,onClick=tap{expanded=true}).semantics{contentDescription="安全提问：${questions[question]}"});DropdownMenu(expanded,{expanded=false}){questions.forEachIndexed{i,q->DropdownMenuItem(text={Text(q)},onClick=tap{question=i;expanded=false})}}}
        if(question>0){Spacer(Modifier.height(16.dp));OriginalTextField(answer,{answer=it},enabled=!busy,label={Text("安全问题答案")},isError=validate&&answer.isEmpty(),supportingText=if(validate&&answer.isEmpty()){{Text("请输入答案")}}else null,modifier=Modifier.fillMaxWidth(),colors=originalFieldColors())}
        if(error.isNotEmpty())Text(error,Modifier.padding(vertical=16.dp),color=MaterialTheme.colorScheme.error)
        Spacer(Modifier.height(24.dp));Button(enabled=!busy,onClick=tap(::login),modifier=Modifier.fillMaxWidth()){if(busy)CircularProgressIndicator(Modifier.size(20.dp),strokeWidth=2.dp)else Text("登录")}
        Spacer(Modifier.height(12.dp));OutlinedButton(enabled=!busy,onClick=tap{nav.open("web:$ORIGIN/member.php?mod=logging&action=login&mobile=2")},modifier=Modifier.fillMaxWidth()){Text("网页登录 / 验证码验证")}
        TextButton(onClick=tap{nav.open("web:$ORIGIN/member.php?mod=register")},modifier=Modifier.fillMaxWidth()){Text("注册账户")}
        Spacer(Modifier.height(16.dp));Text("登录凭据只发送到源社区。密码不会保存在应用设置中；会话由系统 WebView Cookie 存储。")
    }
    }
}




