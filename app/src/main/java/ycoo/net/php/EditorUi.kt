package ycoo.net.php

import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import org.json.JSONArray
import org.json.JSONObject

@Composable fun PageActions(nav:Nav,content:@Composable ()->Unit) {
    val current by rememberUpdatedState(content)
    val key=LocalPageKey.current
    DisposableEffect(nav,key) {val render:@Composable ()->Unit={current()};nav.pageActions[key]=render;onDispose {if(nav.pageActions[key]===render)nav.pageActions.remove(key)}}
}
data class ReplyTool(val title:String,val before:String,val after:String,val placeholder:String,val custom:Boolean=false) {
    fun json()=JSONObject().put("title",title).put("before",before).put("after",after).put("placeholder",placeholder).put("custom",custom)
}
val defaultReplyTools=listOf(
    ReplyTool("加粗","[b]","[/b]","文字"),ReplyTool("斜体","[i]","[/i]","文字"),ReplyTool("下划线","[u]","[/u]","文字"),ReplyTool("删除线","[s]","[/s]","文字"),
    ReplyTool("字号文字","[size=4]","[/size]","文字"),ReplyTool("颜色文字","[color=#ff0000]","[/color]","文字"),ReplyTool("彩色文字","[color=#00a080]","[/color]","文字"),
    ReplyTool("URL 超链接","[url]","[/url]","https://"),ReplyTool("Email 超链接","[email]","[/email]","name@example.com"),ReplyTool("网络图片","[img]","[/img]","https://"),
    ReplyTool("水平线","[hr]","",""),ReplyTool("对齐文本","[align=center]","[/align]","文字"),ReplyTool("代码文本","[code]","[/code]","代码"),ReplyTool("引用文本","[quote]","[/quote]","引用"),
    ReplyTool("隐藏文本","[hide]","[/hide]","隐藏内容"),ReplyTool("网络视频","[media=mp4,500,375]","[/media]","https://"),ReplyTool("表格","[table][tr][td]","[/td][/tr][/table]","内容"),ReplyTool("列表","[list][*]","[/list]","内容"),ReplyTool("联系QQ","[qq]","[/qq]","QQ号码"))
fun loadReplyTools(raw:String?):List<ReplyTool> = runCatching {JSONArray(raw).objects().map {ReplyTool(it.getString("title"),it.optString("before"),it.optString("after"),it.optString("placeholder"),it.optBoolean("custom"))}}.getOrNull()?.takeIf {it.isNotEmpty()} ?: defaultReplyTools
fun applyReplyTool(value:TextFieldValue,tool:ReplyTool):TextFieldValue {
    val start=value.selection.min.coerceIn(0,value.text.length); val end=value.selection.max.coerceIn(start,value.text.length)
    val content=if(tool.custom || start==end)tool.placeholder else value.text.substring(start,end)
    val inserted=tool.before+content+tool.after
    return TextFieldValue(value.text.replaceRange(start,end,inserted),if(tool.custom || content.isEmpty())TextRange(start+inserted.length) else TextRange(start+tool.before.length,start+tool.before.length+content.length))
}
@Composable fun ComposerTools(site:Site,nav:Nav,value:TextFieldValue,enabled:Boolean,onValue:(TextFieldValue)->Unit) {
    site.settingsRevision
    Row(verticalAlignment=Alignment.CenterVertically) {
        Row(Modifier.weight(1f).horizontalScroll(rememberScrollState()),horizontalArrangement=Arrangement.spacedBy(8.dp)) {loadReplyTools(site.prefs.getString("replyTools",null)).forEach {t->AssistChip(onClick=tap {onValue(applyReplyTool(value,t))},enabled=enabled,label={Text(t.title)})}}
        IconButton(onClick=tap {nav.open("reply-tools")},enabled=enabled) {Icon(Icons.Rounded.Tune,"编辑回复菜单")}
    }
}
@Composable fun ReplyToolsPage(site:Site,nav:Nav) {
    val tools=remember {loadReplyTools(site.prefs.getString("replyTools",null)).toMutableStateList()}
    val keys=remember {java.util.IdentityHashMap<ReplyTool,Int>()}
    var add by remember {mutableStateOf(false)}; var title by remember {mutableStateOf("")}; var content by remember {mutableStateOf("")}
    fun save() {site.setting("replyTools",JSONArray().apply {tools.forEach {put(it.json())}}.toString())}
    PageActions(nav) {IconButton(onClick=tap {add=true}) {Icon(Icons.Rounded.Add,"添加快捷回复")}}
    val state=rememberLazyListState(); val density=LocalDensity.current; var dragIndex by remember {mutableIntStateOf(-1)}; var distance by remember {mutableFloatStateOf(0f)}
    LazyColumn(state=state,contentPadding=PaddingValues(top=LocalPageTop.current,bottom=24.dp)) {
        itemsIndexed(tools,key={_,t->keys.getOrPut(t){keys.size}}) {index,t->
            val onStart=tap {dragIndex=index;distance=0f}
            SiteListItem(modifier=Modifier.pointerInput(t) {detectDragGesturesAfterLongPress(onDragStart={onStart()},onDragEnd={dragIndex=-1;save()},onDragCancel={dragIndex=-1;save()}) {change,amount->
                change.consume();distance+=amount.y
                val h=state.layoutInfo.visibleItemsInfo.firstOrNull {it.index==dragIndex}?.size ?: with(density){56.dp.roundToPx()}
                if(kotlin.math.abs(distance)>h/2) {val next=(dragIndex+if(distance>0)1 else -1).coerceIn(0,tools.lastIndex); if(next!=dragIndex) {tools.add(next,tools.removeAt(dragIndex));dragIndex=next;distance=0f}}
            }},headlineContent={Text(t.title)},supportingContent=if(t.custom){{Text(t.placeholder,maxLines=2,overflow=androidx.compose.ui.text.style.TextOverflow.Ellipsis)}}else null,
                leadingContent={Icon(Icons.Rounded.DragHandle,"长按拖动排序")},trailingContent=if(t.custom){{IconButton(onClick={tools.remove(t);save()}) {Icon(Icons.Rounded.DeleteOutline,"删除快捷回复")}}}else null)
        }
    }
    if(add) OriginalDialog(onDismissRequest={add=false},title={Text("添加快捷回复")},text={Column {
        OriginalTextField(title,{title=it.take(20)},label={Text("菜单名称")},supportingText={Text("${title.length}/20",Modifier.fillMaxWidth(),textAlign=androidx.compose.ui.text.style.TextAlign.End)},colors=originalFieldColors()); OriginalTextField(content,{content=it},minLines=2,maxLines=5,label={Text("回复内容")},colors=originalFieldColors())
    }},dismissButton={TextButton(onClick={add=false}) {Text("取消")}},confirmButton={Button(onClick={if(title.isNotBlank()&&content.isNotEmpty()){tools.add(ReplyTool(title.trim(),"","",content,true));save();add=false;title="";content=""}}) {Text("添加")}})
}

