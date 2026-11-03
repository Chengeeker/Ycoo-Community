# 源社区开发文档

更新：2026-11-03。当前版本 1.2.12+49，包名 ycoo.net.php，仅 arm64-v8a。最低 Android 7.0（API 24）。

## 约束与基线

- 站点 https://ycoo.net/portal.php，为 Discuz 社区。真实页面和服务端响应是业务唯一依据。
- Review 参考 Review 参考项目 当前工作区（3.12.0+214，基础提交 c4f86b3，存在未提交修改）。只读参考，不改动源项目。
- 已阅读 Review 的 DEVELOPMENT.md、docs/REVIEW_UI_REUSE_SPEC.md、docs/RETROSPECTIVE.md 和综合文档相关章节。
- 直接迁移 AppTheme、HapticFeedbackUtil、ReviewFrostedAppBar、ReviewPageScaffold、ReviewCard、ReviewPreferenceTile、ReviewSwitchTile、ReviewChoiceTile、AppSectionCard。导航保留标准 M3 分支并复用 Review 的可选液态玻璃悬浮栏实现；第三方包及许可文件保存在 packages/liquid_glass_widgets。
- BKS 为用户指定的 本地 BKS 文件（不随仓库发布）；密码只在被忽略的本机签名配置中使用，不写入文档或受版本管理的源码。签名中间文件排除版本管理；禁止回退 debug 签名。
- 图标使用站点原始文件，不裁切、不重新绘制、不缩放源图；Android 启动器的系统遮罩不由应用控制。
- 正式 APK 构建通过包名、ABI、Flutter 资源、完整图标字体、签名和对齐校验后，只保留项目根目录的最新版本 APK；清理项目根目录其他 APK 及 previous-releases 下的旧 APK。校验失败时不执行旧包清理。构建脚本日志存放于 build/logs，项目根目录不留日志文件。

## 实施清单（实现状态；账户和真机验收另列）

- [x] M3 主题、磨砂栏、导航、设置和触感迁移。
- [x] 门户/导读、版块目录、帖子列表及分页。
- [x] 帖子详情、正文链接/图片、图片打开过渡与缩放分页、直链视频播放、回复分页、用户主页。
- [x] 搜索、阅读历史、收藏、消息。
- [x] 登录持久化、发帖、回复；验证码和复杂插件保留原站入口。
- [x] 明暗/动态色/纯黑/字体/触感设置与缓存管理。
- [x] 原图标、固定包名、BKS 发布签名、arm64 APK。
- [x] 分析、自动化回归、APK 包名/架构/签名检查，标明真机边界。

## 已遇到的问题及防回归

- 本机 ycoo.net DNS 返回 198.18.0.16（代理 fake-ip），代理和直接访问均 TLS EOF；DoH 得到 154.31.203.239，指定真实 IP 仍失败。检索可读页面含缓存，不能据此宣称接口已验证。用户提示站点可能限制中国网络，核查单请求路线，不改全局代理。
- 不凭 Discuz 通用接口名称就假定站点开放接口；必须核对响应，未知/拦截显示错误和原站入口。
- 保留非空缓存及位置，恢复缓存不自动刷新；空内容允许联网。缓存按会话隔离，退出清理账户内容。
- 不伪造收藏/回复/支付成功，保留服务器错误信息和输入草稿。
- Review 图库依赖微博模型、HDR、Live Photo 与账号媒体服务；只迁移源社区可复用的 Hero、ExtendedImage 手势与视频播放能力，微博专属链路不适用。

## 验证记录

最终验证记录见下文；尚未进行真机验收。

## 2026-10-25 实施进展

- [x] Review M3 主题、磨砂顶栏、标准悬浮/贴底导航、卡片、设置行与触感直接迁移；悬浮导航可选液态玻璃。源许可保留在 LICENSE 和第三方声明。
- [x] 原生门户、最新发表/热门/最新回复/精华、版块目录、版块分类及帖子分页。
- [x] 原生帖子详情与回复分页、受限/购买提示、用户资料、正文链接和图片缩放查看；1.2.0 增加 Hero 打开/返回过渡和视频播放器。
- [x] 真实 Xunsearch 插件搜索与分页（并非默认 Discuz 搜索 HTML）。
- [x] 原生登录表单及安全提问、系统 WebView Cookie 共享与持久化；原站验证码登录备用入口。
- [x] 原生发帖/回复/引用、收藏操作、我的帖子/收藏/私信/通知列表代码路径。账户写入只在用户点击后发生，没有使用真实账户发布测试内容；这些路径仍待账户验收。
- [x] 按账户隔离的阅读历史（最多 200 条）、内容快照、主题/动态色/纯黑/字体/触感/导航设置。
- [x] 应用图标使用用户指定的 用户提供的 icon17.png 原始 PNG 字节；不重绘、不裁切、不缩放、不增加留白，launcher 输入和 assets/site-icon.png 保持与源文件一致。
- [x] 固定包名与 BKS 同证书签名配置；正式构建仅 arm64-v8a。最低 Android 7.0（API 24）。
- [ ] 真机登录态、写入、下载和图片手势验收；目前没有 ADB 设备。

### 实际站点契约（只读核对）

| 页面/能力 | 已核对来源 | 关键字段或选择器 |
|---|---|---|
| 版块 | /api/mobile/index.php?module=forumindex&version=4 | Variables.forumlist |
| 帖子列表 | module=forumdisplay&fid=2&version=4 | forum_threadlist、threadtypes.types、tpp |
| 帖子详情 | module=viewthread&tid=154625&version=4 | thread、postlist、ppp；付费内容保持服务器权限 |
| 用户资料 | module=profile&uid=1&version=4 | space，只展示白名单公开字段 |
| 门户 | /portal.php | #portal_block_677_content .kmlist；标题取 title 完整值 |
| 导读 | /forum.php?mod=guide&view=newthread | #threadlisttableid .kmlist、.km_subject、.kmfoot、.pg .nxt |
| 搜索 | /search.php 原站跳转到 /plugin.php?id=twpx_xunsearch | .result-list dt/dd、.pagination；当前页 +1 的 p 参数 |
| 账户权限 | module=myfavthread/mythread/mypm/mynotelist | 未登录响应有明确 login 错误，不以本地空列表冒充成功 |
| 写入入口 | module=newthread/sendreply/favthread | 已只读核对模块存在与游客拒绝响应，尚未用真实账户写入；必须收到明确 succeed/success 才提示完成 |

### 已修复的开发问题

1. **网络并非接口不可用**：用户给本机代理增加直连规则后，本地 HTTPS 和 API 正常。保留证书校验；不改全局代理、不内置国内代理、不固定 DoH 得到的 IP。
2. **中文目录 AOT 失败**：AGP 路径检查需要 android.overridePathCheck=true，但这不足以解决 gen_snapshot 对中文路径的编码。正式脚本使用临时 ASCII subst 盘符，JAVA_TOOL_OPTIONS 追加 UTF-8 与 Windows Unix-domain 临时目录参数；只解除自身创建的映射。
3. **flutter analyze 的 LSP 编码错误**：本环境中文路径的 flutter analyze 发生 LSP JSON 编码异常；使用 dart analyze --format machine lib test 可正常完成同一 Dart 静态分析。
4. **跨账号旧响应**：请求记录 sessionEpoch，切换账号后拒收旧响应与 Set-Cookie；根信息流重建，缓存和历史按 UID 分开，退出清除账户草稿、缓存和已解码图片。
5. **恢复缓存误刷新**：非空快照恢复不发起信息流请求；保持内存滚动位置；切换顶部类别/底栏不会主动刷新。内容超过 200 条后停止扩大磁盘快照，页码与已保存内容保持对应。
6. **误报发布成功**：没有明确服务器成功码的写入响应当作未确认，失败保留草稿；连接中断提示先查原帖，避免重复提交。成功返回时不能由返回回调把草稿再写回来，已有 widget 回归覆盖。
7. **测试截图挂起**：RenderRepaintBoundary.toImage 的文件输出需放入 tester.runAsync。截图是模拟数据的桌面渲染，仅检查布局，不冒充真实手机截图。
8. **游客首页提示重试/原站**：客户端原 User-Agent 标识 Android，站点为它返回另一套移动模板（HTTP 200，但门户/导读原生解析器所需的 #portal_block_677_content、#threadlisttableid 和 .kmlist 均缺失）。现场用 Windows Chrome User-Agent 重复请求时这些列表节点存在。改用已验证的桌面 Chrome User-Agent，让原生解析器拿到兼容模板；这是模板选择问题，不是要求游客登录或改权限。

### 有意保留的原站流程

注册/邀请、验证码、签到/圈子/排行等插件、付费主题购买、图片/附件上传、投票/高级编辑与附件下载保留原站入口。原生页面外壳是 M3，嵌入的网页保留原站样式，不能宣称网站每一个插件都已原生 M3 化。图片查看器复用 Review 使用的 extended_image，支持 Hero 打开/返回过渡、分页和手势缩放；直接视频源使用 video_player、M3 播放控件和 ReviewFrostedAppBar。当前仅识别正文 video/source 标签以及 mp4/m4v/mov/webm/m3u8 直链；iframe、第三方播放器网页、微博 HDR/Live Photo、下载和缩略条不适用于源社区或未迁移，仍走原站。

### 验证记录

- dart analyze --format machine lib test：通过（最终交付前复查）。
- flutter test --reporter expanded --timeout 45s：9 项通过；覆盖真实 HTML、搜索分页、跨域拒绝、过期响应、写入确认、历史隔离、M3 导航与缓存恢复、发布草稿。
- tool/check_site.py：forumindex、forumdisplay、viewthread、profile 4 项实时只读检查通过。
- 最终 arm64 release 已编译，包名、ABI、证书、16 KiB 对齐均通过；详见下方交付记录。
- ADB devices：无连接设备；未安装、不冒充真机验收。登录/发帖/回复/收藏/消息的账户端到端测试、真实网络图片和手势、付费/附件流程仍待用户设备验收。


### 打包复盘补充

- Flutter 3.47.1 的 Gradle 插件在不分 ABI 拆包时会在后续配置中重设 abiFilters，只有 defaultConfig.ndk 的 arm64 设置仍会被覆盖。已在 gradle.properties 设置 disable-abi-filtering=true，让项目的 arm64 过滤生效，并保留 jniLibs 的 ARM32/x86/x86_64 排除规则。最终必须以 APK 的 native-code 和 ZIP 中 lib/ 目录复核，不能只看 Flutter 命令参数。
- AAPT/zipalign 也不能直接读取本环境中文路径，因此签名和结构检查同样使用 ASCII 映射路径。
- 切换临时盘符后，旧 flutter_build.d 可能残留已移除盘符的输出，导致 Gradle 创建输出父目录时 parent 为 null。正式脚本只删除本项目生成的该 depfile，再重新构建，不清理源码或全局 Gradle 缓存。
- PowerShell 直接调用 Gradle 时，带点号的 `-Pflutter-version-name=1.0.0` 需作为单引号字符串传入，否则 PowerShell 会拆分参数，Gradle 报 `Task '.0.0' not found`；该失败发生在打包前，重试时引用完整参数。
- 在线重复编译在 Java HTTPS 依赖检查中长时间等待；依赖已经完整缓存时，可在映射路径的 android 目录通过 gradlew --offline --console=plain，并明确传入 -Ptarget-platform=android-arm64 等 Flutter 参数构建。不能省略目标架构，不能使用缺失依赖的离线模式冒充构建成功。
- 原始 BKS 导出的证书 SHA-256：3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975；APK 必须匹配该公开指纹。


## 1.0.0+1 首版交付记录（2026-10-25；图标已由后续更新替换）

- 文件：源社区_v1.0.0.apk
- 大小：25,797,345 字节（约 24.60 MiB）。
- 包名 ycoo.net.php；名称源社区；versionName=1.0.0，versionCode=1。
- minSdk=24，targetSdk=36，compileSdk=36。
- AAPT native-code 与 ZIP 的全部 lib/ 条目均仅 arm64-v8a。
- APK 签名 v2 验证成功，证书 SHA-256 与原始 BKS 导出值一致：3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975。
- zipalign -c -P 16 -v 4：Verification successful。
- APK SHA-256：E35EFD3E98BE15F7E0D02145375EC6101D0B8133A39F017DA0B67DB8101B027F（同时写入 release.sha256）。
- 最终 Android 编译：离线 Gradle assembleRelease，明确 android-arm64，BUILD SUCCESSFUL in 22s。在线重复构建曾受 Java HTTPS 握手等待影响；没有清理全局缓存或改变其他项目。
- Dart 静态分析最终复查无问题；9 项自动化回归全部通过；4 个公共接口实时只读检查通过。
- 初版图标使用站点 favicon；已由用户指定的 icon17.png 更新，详见图标更新记录。
- 未安装，未连接真机，未进行真实账号写操作。验证码、购买、附件/上传、高级编辑、站点插件仍通过原站页面完成；这些网页保留原站样式。
- 这是首个交付 APK，没有此前已安装版本需要替换；未修改原始 BKS 或 Review 源项目。本机签名转换文件保留，未来重新构建不需要用户重复输入别名/口令。


### 2026-10-25 图标更新

- 按用户最新指定，将 用户提供的 icon17.png 的原始字节复制到 assets/site-icon.png 及所有 mipmap-* / mipmap-nodpi 的 ic_launcher.png；未修改图片像素或尺寸。
- 源文件与每份应用图标资源 SHA-256：9D50CDD9B4F9ED1667F3D039175DABC4FCF3D2935687D4ABB043CD5CEF58BCAD。
- 已重新构建签名 ARM64 APK，构建后验证结果见更新的发布记录。




## 图标更新版 APK（2026-10-25）

- 按用户指定图片 用户提供的 icon17.png 更新应用图标。源图、assets/site-icon.png 和全部 mipmap 密度及 nodpi 的 ic_launcher.png SHA-256 均为 9D50CDD9B4F9ED1667F3D039175DABC4FCF3D2935687D4ABB043CD5CEF58BCAD；仅复制原始字节，未改尺寸/像素。
- 新 APK：源社区_v1.0.0.apk，30796041 字节；SHA-256 9E5BCC0163E0CD39D2CEC43141F1CC8282CAD03455B11880B248D74F38145FEE，release.sha256 已同步。
- 离线 Gradle assembleRelease 成功；aapt 确认包名 ycoo.net.php、版本 1.0.0、仅 arm64-v8a；apksigner V2 校验成功；zipalign 16 KiB 校验成功。
- 重建前的首版 APK 已自动保存在 previous-releases 作为回退。
- 这是静态包校验；未安装真机检查启动器显示效果。Android 会按设备密度显示图标，资源源图本身未缩放。



## 1.0.1+2 游客内容加载修复（2026-10-25）

- 将站点 HTML 请求的 User-Agent 改为经实测能返回原生解析器所需列表结构的桌面 Chrome UA；API 与登录状态处理不变。
- 版本升至 1.0.1+2；沿用包名 ycoo.net.php 与指定 BKS 签名，正式 APK 只包含 arm64-v8a。
- 真实站点对比记录：原 Android UA 的门户和导读响应分别约 71 KB / 170 KB，两个目标列表容器均缺失；Chrome UA 对应响应约 431 KB / 70 KB，分别包含门户 #portal_block_677_content 与导读 #threadlisttableid 下的 .kmlist 条目。请求均为未登录只读页面。
- 离线 Gradle assembleRelease 构建成功；AAPT 验证包名 ycoo.net.php、versionName 1.0.1 / versionCode 2、仅 arm64-v8a。APK 使用原 BKS 同一证书，签名 V2 校验和 16 KiB zipalign 校验成功。
- APK：源社区_v1.0.1.apk，30,796,045 字节；SHA-256 B07748004CF01B867B48AE1C3E0F577FD710EAAA681042280C51DD9758CBF74C，与 release.sha256 一致。


## 1.2.0+5 Review 媒体体验复用（2026-10-25）

- 用户要求继续复用 Review 的媒体体验。版本升至 1.2.0+5，包名和 BKS 签名不变，仍只发布 arm64-v8a。
- 帖子图片入口增加按正文实例隔离的 Hero 标签；打开与返回都连接缩略图和当前大图。Gallery 使用 Review 同样采用的 extended_image 8.3.1，按需创建分页项，支持手势缩放、拖动和重试；不批量预载原图。
- 帖子正文的 video/source 标签和 mp4、m4v、mov、webm、m3u8 直链使用 video_player 2.14.1 原生播放；应用栏复用 ReviewFrostedAppBar，播放、进度、倍速、错误重试和后台暂停控件使用 M3。原始 video_player_android 版本为 2.12.2。
- 视频与图片共用站点请求头策略：站点 Cookie 仅附加到精确的 https://ycoo.net 来源，外部媒体只发送通用 User-Agent。拒绝非 HTTP(S) 和包含 userinfo 的媒体 URI；http://ycoo.net 自动切到 HTTPS。
- 不支持的 iframe/第三方嵌入播放器仍走原站；没有迁移微博账号、HDR、Live Photo、下载、质量选择或缩略胶片栏。站外资源还受其跨域策略和网络可达性影响。
- dart analyze --format machine lib：通过，无 error；显示的 info 级 const 建议来自现有设置页面。
- 离线 Gradle assembleRelease 成功（32 秒）；使用临时 ASCII 盘符、Java 17 与已缓存依赖，未生成 debug 包。
- APK：源社区_v1.2.0.apk，34,220,760 字节；SHA-256 BD4995A3200D0152165DDBD59AEFBF3A1FE2F00BA1450BA2CADA83BF20924F95，release.sha256 已同步。
- AAPT 确认包名 ycoo.net.php、versionName=1.2.0、versionCode=5，native-code 仅 arm64-v8a；ZIP 的 lib/ 条目也仅有 arm64-v8a。
- apksigner v2 校验成功；签名证书 SHA-256 与指定 BKS 一致：3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975。zipalign -c -P 16 -v 4：Verification successful。
- 该次重建前相同版本但缺少中途错误反馈的 APK 已保存在 previous-releases/20261025-195332 作为回退。
- 本版本不运行自动化测试；未连接 ADB 设备，尚未在真机检查 Hero 时序、图片缩放和视频解码。包结构和签名检查不代表设备播放验收。


## 1.2.1+6 悬浮底栏间距调整（2026-10-25）

- 用户反馈四个入口在悬浮底栏中显得拥挤。将 Review 原先按三项导航使用的 2/3 屏宽改为 min(440dp, 可用屏宽 - 32dp)，两侧至少留 16dp；M3 与液态玻璃分支共用同一宽度计算，居中、圆角和高度保持原样。
- 排查首页、社区、导读、我的、设置、个性化和论坛列表的上下留白。主标签页按实际 M3/液态玻璃栏的可见高度计算悬浮遮挡净空；使用标准底栏时正文在底栏上方结束，改用 16dp 收尾。通过“我的”打开的设置/个性化页不显示根导航栏，末尾空白从 100dp 收到 24dp。页面顶部采用磨砂栏下方的状态栏 + 工具栏偏移，没有发现重复安全区，保留原有定位。
- dart analyze --format machine lib：通过，无 error；仅有既存设置页 const 建议。
- 离线 Gradle assembleRelease 成功（37 秒），仅构建 arm64-v8a。
- APK：源社区_v1.2.1.apk，34,220,760 字节；SHA-256 DCF357E997BAFF4F45F7D3B8A723DA9069EFC7B85F422BE45385D881171EDAC3，release.sha256 已同步。
- AAPT 确认包名 ycoo.net.php、versionName=1.2.1、versionCode=6，native-code 和 ZIP lib/ 条目均仅 arm64-v8a。
- apksigner v2 校验成功；证书 SHA-256 与指定 BKS 一致：3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975。zipalign -c -P 16 -v 4：Verification successful。
- 最终构建前同版本的 APK 已保存到 previous-releases/20261025-205638。
- 本次没有运行自动化测试或进行真机布局验收；留白修改基于嵌套 Scaffold、导航覆盖区域和页面 padding 的代码检查。




## 1.3.0+7 首页功能对齐与留白/触感修复（2026-10-26）

- 基准为用户提供的 用户提供的 base.apk；只读取 Lua/JSON，不安装、不执行其更新脚本。功能对照及真实入口见 docs/CLIENT_PARITY.md。
- 修正旧首页契约：参考客户端使用移动版 Comiis pid=28/72/44（推荐/圈子/关注），并非桌面 portal.php。原生解析真实模块和信息流；现场快照有轮播 10、服务 5、热门板块 8、七日榜 15、置顶区 8，数量与顺序以服务端配置为准。信息流保留置顶标记，论坛另外解析 #comiis_displayorder，避免遗漏独立置顶帖；分类元数据沿用 API。
- 删除重复根侧边栏；原有服务入口归入“我的 → 社区服务”。社区保留分类展开和版区/新帖/精选/热门；导读包含最新/热门/精华/回复/抢沙发。我的补齐原客户端八项内容入口及资料、头像、空间背景、访客、推广等实际页面。
- 头像使用站点 data/avatar/noavatar.svg 原始资源作为默认和失败回退，不再使用姓名首字占位。移动信息流保留作者、等级、图片、分类、实际计数；帖子图片使用已有 Hero 图库，视频沿用播放器。媒体仍按需加载，不批量预载原图。
- 纠正 1.2.1 的排查结论：FutureBuilder 下读取的 MediaQuery 已含 extendBodyBehindAppBar 的工具栏高度，再加工具栏导致社区顶部空白；现在于 Scaffold 外计算一次。我的嵌套 GridView 未明确 padding，自动继承上下安全区导致卡片大块空白；已设 padding=zero、primary=false。所有新增嵌套网格沿用该规则。
- 触感从 Material splash 的 confirm 接入，手指按下及滚动取消不震；共享卡片/偏好行/开关/导航（普通、悬浮、液态玻璃）补显式反馈。原始手势、链接、刷新、图片翻页/双击、播放器操作和字号拖动完成共用开关/去重；文字输入、连续缩放和播放进度不连续震动。开启开关立即预览，关闭后无反馈。
- 阅读设置增加自愿开启的自动签到（账户/日期隔离，仅明确成功才记录）、连续回复分页、URL 自动链接、可选 FPS；编辑工具支持 BBCode、排序及持久化自定义快捷回复。新增功能不执行未授权账户写入；自动签到必须用户开启。
- 网页宿主增加原生分享、页内查找、顶部/电脑版/外部打开、系统下载与文件选择、M3 JS 对话框。下载不向站外转发 Cookie；需要登录的附件仍可交由浏览器完成验证。Android 7–9 下载目录权限仅在选择系统下载时申请；Android 10+ 不申请旧存储权限。
- 原客户端自动更新地址为空，不伪造更新接口；其图片托管设置在源码中为注释功能，不新增虚假配置。
- 回归：全套 19 项通过。覆盖现场模块数量/顺序、置顶和缓存、下载 URI 边界、自动签到 opt-in/每日/账户/失败、BBCode 选择范围与快捷菜单持久化、两种底栏安全区和我的网格高度、共享触感开关/去重/滚动取消、原有会话安全与草稿。
- Windows 中文路径直接运行 shader 测试会遇到 gles_compat.glsl include 失败：临时 subst 为 ASCII 盘符、在映射目录 pub get --offline，再运行测试；测试结束释放映射。不要删除或改写第三方 shader 规避问题。
- 自动化布局截图保存在 build/previews（模拟视口，不是真机截图）。flutter_svg 不支持默认头像 SVG 的 filter 阴影，主体仍渲染，原始文件未改写。
- 尚未进行真实账号写入、真机振动、GPU 液态玻璃、图片动画/视频解码、网页上传和系统下载端到端验收；不能据静态/模拟检查宣称上述体验完成真机验收。

### 1.3.0 发布校验

- 离线 Gradle assembleRelease 成功（1 分 3 秒），只构建 android-arm64；Dart 分析无 error/warning，5 项既存 const 提示。
- APK：源社区_v1.3.0.apk，34,879,505 字节。SHA-256：F7AB20875BC7EEC6C77680BAD20BF63A074219B34CA6B8B3E334720DCDAB93D2，release.sha256 已同步。
- AAPT：包名 ycoo.net.php、版本 1.3.0 / code 7、minSdk 24；ZIP lib/ 条目全部为 arm64-v8a。
- apksigner V2 验证通过，证书 SHA-256：3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975，与指定 BKS 一致。zipalign -c -P 16 -v 4 成功。
- 首次 Gradle 命令未将 -Ptarget=lib/main.dart 等参数作为完整字符串传入 PowerShell，导致 .dart 被当作任务；改为每个 -P 参数整体加引号后构建成功。此为调用错误，未更改应用实现。
- 1.2.1 APK 及既有 previous-releases 保留以供回退。未自动安装到设备。

## 1.3.1+8 登录兼容、首页分栏与正文媒体修复（2026-10-26）

- 用户反馈登录出现“站点未返回可识别的数据”。本机只读 GET 登录接口正常返回 JSON；空凭据 POST 返回明确的密码校验错误 JSON，不代表真实账户成功。没有使用用户真实凭据，不能据此认定其设备上的响应原因。
- API 解码兼容 BOM；登录接口返回 HTML 时使用专门的验证分支。POST 后先核对共享 Cookie 对应的登录态，若已登录则继续；否则自动打开站点登录页完成验证码/网页验证，不再让用户停留于通用解析错误。仍保留站点实际 JSON 错误，绝不将解析失败当作登录成功，不把密码注入 WebView 或站外地址。
- 首页圈子/推荐/关注改成 AppBar.bottom 内的 M3 TabBar，删除正文标签。磨砂背景与底部分界随整个工具栏+分栏一起下移，正文净空只计一次；取消关注登录时回到原分栏。
- 七日榜标题单行、阅读数右对齐，基准字号下每行不超过 48dp；置顶区双列图文行，每项 64dp、缩略图 48dp，8 项四行。全部真实内容保留，不以截断数量换取密度。文字放大时仍由控件布局与截断处理。
- 现场核对用户第三张图的帖子 156963：接口正文同时含 br 与源码换行。原生此前逐个保留，导致空行翻倍；现在普通 HTML 折叠源码空白，br 保留，pre 代码块保留原始换行/缩进，块间纯空白不再生成额外段落。
- API 中部分图片仅在 post.attachments 中返回。现在合并图片附件到正文，替换已有缩略图的原图地址并去重，缺失的图片追加展示，使用现有 Hero/ExtendedImage 播放器；图片直链同样进入原生图库。只有非图片附件继续显示原站附件入口；未购买付费图片不从元数据拼接展示。
- 新增登录 BOM/HTML/会话确认、正文换行与代码块、附件去重及点击进入 GalleryPage、分栏磨砂边界、排行榜/置顶密度回归。全套 25 项通过。图片点击测试验证导航，未用模拟网络检查真实图片解码。
- 继续沿用指定图标、包名与 BKS 同证书；只构建 arm64-v8a，保留旧 APK 回退。真实账户登录、设备振动、GPU 与媒体实际播放尚需设备验收。

### 1.3.1 发布校验

- 离线 Gradle assembleRelease 成功（59 秒）；全套 25 项回归通过。Dart 分析无 error/warning，仅 5 项既存 const 提示。
- APK：源社区_v1.3.1.apk，34,945,041 字节；SHA-256：DCBB04F5BE482F47A0AEB12A20AE75A004B9A25E9282373FC7541B7A825C8994。release.sha256 已同步。
- AAPT 确认 ycoo.net.php、versionName=1.3.1 / code=8；ZIP lib/ 仅 arm64-v8a。apksigner V2 与指定证书校验成功；16 KiB zipalign 校验成功。
- 原 1.3.0 APK 保留回退；没有自动安装。真实账户及实际设备体验的验收边界同上。

## 1.3.2+9 网页与原生会话同步、置顶缩略图修复（后并入 1.4.0，未单独交付）（2026-10-26）

- 用户设备确认：跳转网页时已经登录，返回原生仍未登录。纠正 1.3.1 的假设：非 JSON 登录响应不等于确实存在验证码/安全验证；提示改为网页登录页面，不再直接宣称触发安全验证。
- Cookie 桥接按完整请求 URL 读取，并按实际响应 URL 写入 Set-Cookie，不再对所有路径固定使用根 URL。Android 侧限制为 https://ycoo.net、443、无 userinfo；外站不能调用该桥接获取站点 Cookie。读取不增加每次磁盘 flush，避免原生列表请求平白阻塞 UI。
- API 请求与 WebView 统一移动端 UA。会话核对添加时间戳和 no-cache/no-store，避免复用旧游客响应。其他列表的正常内容缓存策略不变。
- 会话身份一次性提交：登录 API 只解析数据，不在中途直接修改 uid。接口返回游客/HTML 时，再读取同源移动版个人中心，以服务端脚本的 discuz_uid 核对当前访问者；绝不从普通用户主页链接或图片推断登录。最终才更新身份并通知首页/我的，避免 API 游客与网页登录之间反复切换。
- HTML 身份分支同时提取可用的当前用户名和 formhash（表单、脚本或链接），保留真实站点权限；不凭 Cookie 存在或登录页面消失就宣称成功。网页往返前后递增 sessionEpoch，使此前仍在途的请求不能覆盖新的会话 Cookie 或身份。
- 本机未提供用户真实账号进行登录，不能断言其设备上是哪一项差异造成问题。新增模拟覆盖 Cookie 请求路径、相同 UA、登录请求禁缓存、网页登录/API 游客的合并、重复核对无中间登出，以及拒绝把普通资料链接当访问者身份。保留先前过期响应不写 Cookie 的回归。
- 置顶区卡片固定为 16dp 圆角；图片 8dp 圆角，四周留 8dp；外卡不再沿主题胶囊形状裁掉图片角。双列紧凑结构保留、行距 8dp，默认一项高 64dp；字号放大时按文字缩放增加高度。无需改动源缩略图或增加新图片依赖。
- 全套 27 项回归通过。置顶区额外断言图片相对卡片的偏移为 (8,8)，且外卡半径为 16dp；Dart 静态分析结果见发布校验。
- 继续保留原 APK 回退，只构建指定包名/BKS 同证书的 arm64-v8a 正式包。真实账户登录同步和 Android CookieManager 的设备行为仍需真机验收；不执行用户账号写入。

## 1.4.0+10 Review 原生图库与链接分流（2026-10-26）

- 用户明确补充：需要 Review 的原生图片播放器，不能从图库再跳到网页看图；站内帖子原生打开，外链像 Review/Telegram 一样放到内置浏览器。合并前面登录同步与置顶缩略图修复，不单独交付中途 1.3.2。
- 对照 Review 参考项目/lib/features/detail/presentation/widgets/image_gallery_page.dart、core/widgets/in_app_browser_page.dart、core/services/link_routing_service.dart，以及 Android saveMediaToGallery 实现。Review 源项目只读。
- 直接迁移 Review 的图库玻璃按钮类和 shaders/gallery_glass_button.frag；新文件 lib/core/widgets/review_gallery_glass_button.dart 保留玻璃/磨砂降级路径，只改公共类名、导入与 key。已有 MIT 许可保留。
- 源社区图库使用 Review 相同的黑底全屏叠层、玻璃返回/保存按钮、页码胶囊、缩略图条、ExtendedImage 手势及 SlidePage 退出机制；双击缩放有插值动画。移除图库的“打开原图网页”按钮，原图在原生查看器中加载。微博数据模型、账号服务、HDR 与 Live Photo 服务不迁入源社区。
- 图片路由透明，Hero push 捕获当前缩略图已解码帧作为原图加载期间预览，pop 保留图库侧飞行内容；只保留本次打开的一张预览，不整组预载原图。图条按可见项加载低解码尺寸，当前页/图条位置同步，原始图片缩放与重试保留。
- 保存图片复用 Review 的 Android MediaStore 流程：Android 10+ 写 Pictures/源社区，不申请旧存储权限；Android 7–9 用户点击保存后申请权限并继续保存。写入后台线程执行，失败删除本次创建的不完整条目；GIF/WebP 等保留原始字节。下载流上限 64MB，逐次验证重定向，Cookie 只发精确站点，HTML 登录页不能伪装图片写入相册。
- 新增 AppScope 向导航路由提供现有 Site/Settings。站内帖子伪静态及 forum.php?mod=viewthread&tid= 均走 ThreadPage；普通 HTTP(S) 外链走内置 BrowserPage。内置浏览器更新网页标题/来源，点击其中的站内帖子也转原生详情，直接图片转原生图库。明确选择“原站/电脑版/购买/非图片附件”时仍允许网页完成实际站点流程，避免购买入口变成重复原生详情。
- URI 路由严格匹配精确站点、无 userinfo、数字帖子 ID；外部域名同名路径和伪装子域名不原生接管。未知/非法协议不交给 WebView；内置浏览器不注入站点 Cookie 到外链，外部浏览器仅在用户明确点菜单时启动。
- 网页登录返回优先请求同源移动个人中心的当前访问者身份，不先重复调用登录接口；已确认正 UID 时直接提交统一身份，原生 API 不识别时不会再误判为验证码。无法从网页确认时仍回到正常会话核对，不凭页面出现就认定成功。
- 全套 31 项回归通过。新增原生图库组件/保存按钮存在、没有 BrowserPage、图片格式检查、站内链接路由及外域拒绝、网页登录返回优先核对的测试。静态分析无 error/warning，仅 5 项既存 const 提示。模拟测试不代表真实账号、GPU 手势时序、相册权限或系统 WebView 已完成设备验收。

### 1.4.0 最终发布校验

- 最后一次源码构建包含网页返回优先核对，离线 assembleRelease 成功（31 秒）；31 项回归全部通过。未生成不同包名或 debug 签名测试包。
- APK：源社区_v1.4.0.apk，35,013,122 字节。SHA-256：CFC8177927866A8FAF2E30F3B1A4B2E4C512BC953F465C11941FA0121CC55CE8，release.sha256 已同步。
- AAPT：ycoo.net.php，versionName=1.4.0 / versionCode=10；ZIP lib/ 仅 arm64-v8a，并确认包含 gallery_glass_button.frag。
- apksigner V2 通过；证书 SHA-256 3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975，与指定 BKS 相同。zipalign -c -P 16 -v 4 通过。
- 既有 1.3.1 APK 保留回退；未自动安装。真机网页登录同步、手势/Hero 时序、玻璃 GPU 和 Android 保存相册流程未进行实际设备验收。

## 1.5.0+11 用户名补全、签到/购买与站内页面原生适配（2026-10-26）

- 用户反馈：登录后只有 UID 无昵称，签到/付费主题等总进入 WebView。网页身份解析只能得到 discuz_uid，此前未补查询个人资料。现在仅在已核实正 UID 且昵称为空时请求 profile(uid)，核对 space.uid 后取真实 username；已有同 UID 昵称优先保留。完成补全再一次性更新会话，并检查 sessionEpoch，避免把旧账户姓名写到新账户。
- 本机只读实测 profile(uid=1) 返回 space.uid=1 / username=admin。没有使用用户真实账号；这证明该站公开资料契约，而非真实用户设备验收。
- 新增 NativeSitePage：站内非认证链接默认用 Flutter/M3 渲染内容、站内链接、图片和实际 HTML 表单，不使用 WebView 嵌套。保留服务端字段/隐藏凭据、复选框组、单选、下拉、文本和文件输入；仅接收同源表单 action，跨站表单不在原生宿主提交。复杂验证码/注册等明确认证页面及用户主动选择原站仍保留原流程。
- 每日签到为独立原生 SignPage：读取移动签到页的今日排名/连续/累计数据和实际 formhash，显示原生签到按钮及今日/月/总排行。按服务器原始 qiandao 请求提交，忙碌防重复，显示真实返回消息，再重新读取状态；不凭 HTTP 200 宣称签到成功。
- 付费主题按 API forum_threadpay 判断是否需要购买，避免已购买仍显示购买入口。原生购买页读取服务器真实购买表单和最新价格；确认后检查账户/会话、目标 tid 和价格，防止重复确认、错主题提交、价格变化时继续扣款。只在确认按钮后发送真实表单；提交后再次请求同主题 viewthread，确认无需付费才返回并刷新正文。费用/权限均由站点决定，不绕过付费权限，不自动重试扣费请求。
- 云盘为独立 NativeCloudPage：按该站实际 Vue 脚本及 utils.js 确认的 bphp_clouds:api 契约实现配置/空间/分页文件夹和文件列表/搜索、新建文件夹、重命名、删除、文件打开和下载；本地存储上传使用真实 upload/flag=2 协议。写入必须收到 sta=1；删除需要原生确认。第三方 OSS/七牛上传暂未迁移，不冒充上传成功。
- 站内普通表单可通过原生系统文件选择器上传。Android 仅允许读取本次用户选择过的 content URI，后台读取、最大 64MB，返回原文件名/类型；Dio 对含 MultipartFile 的表单发送 multipart 并克隆文件数据，使用户显式重试时可复用，不改其他普通表单编码。Cookie 仍只发精确站点，响应 Cookie 仍检查会话代次。
- 修复新云盘输入弹窗的生命周期：不能在 showDialog 返回时立即 dispose 仍在退出动画中的 TextEditingController；改由对话框 StatefulWidget.dispose 管理。原生表单摘要移除控件本身的文本，避免“确认购买”等按钮标签出现两遍。
- 范围边界：原生内容/表单适配不等于执行插件任意 JavaScript。农场游客请求只返回登录页面，尚无其登录后的游戏接口样本；复杂脚本动作不宣称完整适配。原生页可复制去除 Cookie/密码/表单值的结构信息（脚本资源路径、字段名、函数名），用于后续按实际插件接口继续适配，不导出原始私密 HTML。
- 已加入公开签到/排行页面的离线夹具、原生表单字段/同源边界、真实昵称补全、签到防重复/状态重读、购买取消/失败/变价/确认成功、云盘原生重命名、反馈信息脱敏及 multipart 复用回归。最终数量、构建与签名校验见发布记录。
- 尚未执行真实签到、购买扣费、云盘删除/上传或资料修改；账户写入回归全部使用模拟响应。真机账户、文件提供方和服务器限制仍需实际设备验收。

- 最终回归扩充至 44 项并全部通过；包括重复购买回调只确认/提交一次、multipart 保留 MIME 且可显式重试，以及文件选择/读取串行并在取消后释放状态。普通表单继续 x-www-form-urlencoded，只有存在文件时才 multipart。
- 原生业务页面 bootstrap/formhash、签到状态和购买权限/价格读取添加请求代次及 no-cache，避免复用游客或旧表单响应。原生表单提交保留 mobile=2，和共享 Cookie 对应的移动 UA 一致。
- 明确剩余工作：农场登录后脚本玩法、第三方云存储完整上传/移动/批量操作、复杂脚本编辑或外部支付流程不能仅靠通用表单宣称完成。后续依赖对应插件的真实认证页面结构/接口响应继续适配。当前版本不默认把这些站内链接送入 WebView；未支持的脚本操作显式提示并提供脱敏结构反馈。

### 1.5.0 最终发布校验

- 离线 Gradle assembleRelease 成功（44 秒），最终 44 项回归通过。Dart 分析无 error/warning；仅保留既存 5 项 const 及测试夹具 2 项括号风格提示。
- APK：源社区_v1.5.0.apk，35,210,446 字节；SHA-256：D2D514E3CCD94696BFCCBC189BB350DF72F4620381B906171CCC7BA560298D62，release.sha256 已同步。
- AAPT 验证包名 ycoo.net.php、版本 1.5.0 / code 11、minSdk 24；ZIP lib/ 全部 arm64-v8a。
- apksigner V2 校验通过，证书 SHA-256 3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975，与指定 BKS 一致。16 KiB zipalign 校验通过。
- 保留 1.4.0 等既有 APK 回退，没有自动安装或执行真实账号写入。农场登录后玩法及第三方云盘上传等剩余适配项不能据打包成功标为完成。

## 1.6.0+12 帖子信息层次与外链选择（2026-10-26）

- 用户参考图说明：正文不仅是文字和图片，还包含作者等级、分类、付费信息、编辑说明、隐藏内容区、引用和站点版权声明。此前 API 没有提供完整网页附加信息，HtmlContent 也把 div/blockquote 全部平铺，造成阅读结构丢失。
- 本机只读核对移动帖子 154095（黄果短剧订阅源）：网页同 PID 区块中存在 top_lev、分类和 #copyright，游客只能看到 5 星币购买提示；API 也仅返回购买提示。真实购买后的内容没有用游客响应猜测或绕过权限。
- 原生正文先按 API 显示，然后异步补取同页移动 HTML，不阻塞首屏，不增加媒体预载。只对匹配 PID 补等级/分类/楼主版权声明；失败保留 API 阅读，返回后核对 mounted、sessionEpoch 和该批帖子仍在当前列表，避免旧账户/刷新响应回写。
- 移动 HTML 正文只有在 API 已确认无需付费、且去除格式后的 API 正文完整出现在同 PID 网页正文中时才用于恢复分区结构；不替换原始 message、不从不匹配/购买受限页面展示隐藏正文。图片附件依然走原有权限和去重逻辑。
- HtmlContent 为 showhide/locked/quote/comiis_quote/blockquote/#copyright 恢复 M3 容器、边框、底色与紧凑内边距；支持嵌套，链接保留点击行为；标题和编辑说明有文字层级。正文卡片内边距改为 12dp，正文字号遵循原有主题/字体缩放。付费主题已解锁时仍保留价格和解锁状态，待购买时继续原生确认流程。
- 普通 HTTP(S) 外链统一先显示 M3 底部弹窗，完整可选择网址、继续访问、复制链接、浏览器打开；取消不跳转，复制不打开页面。浏览器打开使用现有 BrowserPage，JSON 保留完整路径/查询参数；继续访问沿原有文件下载或内置网页分流。站内帖子和原生图片/视频路径保持原有功能。
- 文件的“浏览器”选项也改为内置浏览器，并允许显式选择的初始文件 URL 导航，避免再次弹下载选择造成循环。WebView 对任意文件格式的呈现仍由系统 WebView 和服务器 Content-Type/Content-Disposition 决定，不承诺所有二进制文件可作为网页预览。
- 新增真实公开移动页夹具、PID/权限/内容匹配补全、隐藏区和版权声明嵌套边框、外部 JSON 点击确认/复制/取消回归。具体最终数量及签名校验见下方发布记录。
- 未使用真实账号验证购买后页面，没有自动安装；完整布局、WebView 对实际 JSON 的显示及设备字体缩放仍需真机验收。

### 1.6.0 最终发布校验

- 最终源码离线 assembleRelease 成功（32 秒），48 项回归全部通过；Dart 分析无 error/warning，仅既存 5 项 const 和测试夹具 2 项括号风格提示。
- APK：源社区_v1.6.0.apk，35,210,446 字节。SHA-256：6F7D4F51F0047226D00A39F7927A4940DBE2D562E6F1E9974F57F1A3DC63ECC1；release.sha256 已同步。
- AAPT：ycoo.net.php，versionName=1.6.0 / versionCode=12，minSdk24；ZIP lib/ 仅 arm64-v8a。apksigner V2 成功，证书 SHA-256 为 3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975；16KiB zipalign 成功。
- 保留 1.5.0 等既有 APK 回退，未自动安装。真实账号已解锁正文及系统 WebView 的文件预览仍未真机验收。

## 1.6.1+13 图库图片贴顶修复（2026-10-26）

- 用户在帖子 157330 中打开图片后，主图、顶部按钮及本应在底部的缩略图同时挤在屏幕上方。根因不是图片源尺寸：图库 Stack 仅有顶部 SafeArea 为非 Positioned 子节点，Stack 默认 loose 尺寸由该工具栏高度决定；Positioned.fill 的主图视口与 bottom 缩略图因此也落在同一矮区域。
- 修复为 StackFit.expand，图库明确占满 Scaffold 可用视口；顶部 SafeArea 使用 Positioned(top/left/right=0) 单独定位，原有底部缩略图继续使用系统底部安全区+16dp。不能只加 StackFit.expand 而让工具栏保持非定位，否则 Row 会随整屏高度拉伸并在垂直方向居中。
- 主图仍使用原有 BoxFit.contain、Hero 与加载预览、ExtendedImage 缩放/翻页/滑出、Review 玻璃按钮；无新依赖、不预载整组原图、不改图源或图片原始尺寸。
- 只读访问用户帖子：远程浏览工具不可达，本机移动网页可读取；游客响应没有用户截图中的两张图片，故不把本机游客读取当作实际账号图片播放验收。
- 新增 gallery_layout_test：393x873 竖屏、873x393 横屏，各覆盖单图/双图；断言主图页视口等于全屏、中心为屏幕中心、顶部返回不低于状态栏、缩略图在底部安全区上方；双图翻页及单击隐藏/显示工具栏后视口尺寸保持不变。网络图片解码及 Hero 真机时序不在该几何测试中冒充验收。
- 每次修复构建指定 BKS 同证书、ycoo.net.php、arm64-v8a 正式包，保留 1.6.0 回退；最终测试/签名记录见下。


### 1.6.1 最终发布校验

- 离线 assembleRelease 成功（30 秒），52 项回归通过。Dart 分析无 error/warning，仅既存 7 项风格提示。
- APK：源社区_v1.6.1.apk，35210446 字节；SHA-256：D643F534EF216CF8A2AAF493A5A64171A030E4B3BBC0314B304507B6ABC04671；release.sha256 已同步。
- AAPT：ycoo.net.php，1.6.1 / code13，minSdk24；ZIP lib/ 仅 arm64-v8a。apksigner V2 与指定 BKS 证书校验通过，16KiB zipalign 通过。
- 发布当时 1.6.0 APK 暂作回退；后续用户明确要求只保留最新 APK，已在本次整理中删除旧包。未安装到设备。真实图片解码、Hero/手势动画仍需设备验收。

## 本次产物目录整理（2026-10-26）

- 按用户要求，仅保留根目录最新正式 APK `源社区_v1.6.1.apk`；已删除 previous-releases 下 1.0.0 至 1.2.1 共 4 个旧 APK。后续由 tool/build_release.ps1 在新包校验成功后执行同一清理，失败时旧包保留。
- 将项目根目录 38 个 `.log` 移至 `build/logs/`。后续正式构建脚本使用 PowerShell transcript 将过程记录到该目录，根目录不输出日志。


## 1.6.2+14 帖子首屏稳定与论坛列表元数据（2026-10-27）

- 用户反馈帖子先出现部分内容，随后补入信息并整页跳变。此前 API 正文先 setState，移动版 HTML 再异步回写同一组帖子。现在每页并行请求两份数据，最多额外等补充 HTML 800ms，先合并再一次性提交；失败或超时只展示 API 正文，晚到响应不会二次改布局。HTML 正文继续受付费状态、PID 和正文匹配校验保护；提交前再次核对 sessionEpoch，避免等待期间账户切换后显示旧数据。
- “站务公告”版块置顶帖只有标题：移动版先解析精简置顶行，再对重复 tid 去重，因此作者、头像、时间和摘要缺失。现在按 tid 合并 forum_threadlist API 摘要，保留移动列表顺序、标题和图片，补齐缺失元数据。TopicTile 始终显示作者/头像区，服务器确实缺失作者时明确提示，不伪造昵称或简介。
- 版块快照如含无作者的旧置顶条目，不先显示残缺卡片，改为重载该版块；其他完整快照仍保持缓存优先、不自动刷新的既有行为。
- 核查通用帖子列表、搜索、阅读历史、我的帖子/收藏，均复用 TopicTile；没有另外的普通标题卡片渲染分支。首页门户的单条公告入口、七日榜与紧凑置顶模块按参考保持专用布局。账户端点未返回的作者/摘要不能伪造，也不为每条摘要额外发起详情请求。
- 新增回归覆盖 API 与移动补充信息同批提交、补充超时后不晚到更新、等待期间账户切换，以及残缺置顶缓存重载后显示作者/摘要。没有新增依赖或媒体批量预载。
- 取舍：额外等待最多 800ms；补充页面超时或不可达时使用 API 可用正文。真实网络与设备上的阅读效果仍需真机验收，不能用组件回归冒充。

### 1.6.2 最终发布校验

- 最终源码离线 assembleRelease 成功（34 秒）；全套 57 项回归通过，包含补充响应超时与会话切换保护。Dart 静态分析无 error/warning，仅 8 项风格提示。过程与校验日志存于 build/logs，根目录没有 .log 文件。
- APK：源社区_v1.6.2.apk，35,210,442 字节；SHA-256：1DF2153751F36EE2EEDEE3A3F8C8D40DEC8A7C727676D88CC02E602CBA921B77，release.sha256 已同步。
- AAPT：ycoo.net.php，versionName=1.6.2 / versionCode=14，minSdk24；ZIP lib/ 仅 arm64-v8a。apksigner 校验通过，证书 SHA-256：3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975，与指定 BKS 一致；16KiB zipalign 校验通过。
- 按用户要求，新包全部校验成功后删除根目录旧版 1.6.1 APK，只保留最新正式包；未自动安装，未执行真实账户写入或真机网络验收。
- 本次确认 aapt 对 Windows 中文绝对路径也会报 Illegal byte sequence；与编译相同，APK 身份、签名和对齐校验全程使用临时 ASCII 盘符，再由 PowerShell 复制到中文发布文件名。校验路径失败不代表 APK 损坏，不应重复重编译。


## 1.7.0+15 首页关注二级分栏（2026-10-27）

- 用户要求在首页“关注”下面增加“我的关注、关注版块、好友动态”二级顶部分栏，磨砂层和分界必须覆盖这两行分栏。
- 只读获取站点 pid=44 的 istab 响应，确认该页仅定义三个子页：45、46、47；其各自的首页请求分别为 `comiis_app_portal&pid=<子页>&page=1&comiis_list=yes&inajax=1`，后续页面分别携带 `op=user`、`op=bbs`、`op=friend`。游客响应三页皆为暂无数据，不能据此验证登录后的数据结构。此前应用把外层 44 当作帖子信息流，因此没有读取实际子页。
- 使用既有 M3 TabBar.secondary 放在主分栏之后，并一起放进 ReviewFrostedAppBar.bottom；PreferredSize、正文顶部安全区和 RefreshIndicator 边界按实际双层分栏增加 48dp。离开关注后恢复单层高度。沿用主题色、语义和全局触感设置。
- 三个子页使用独立 view/cacheKey、页码和加载代次，切换恢复各自缓存，当前内容不会被已离开的请求覆盖。未登录仍先走现有登录流程，取消登录恢复主分栏；账户变更沿用 sessionEpoch 和主页重建机制。首次请求与翻页采用站点实际参数，沿用同源 Cookie、帖子卡片和图片处理。
- 不将游客的空列表当作真实账户验收；需要真机登录且有关注用户、关注版块、好友动态的数据后核验三类页面解析、分页和跟随状态。站点若返回非帖子结构，现有帖子解析器可能需要根据实际授权页面调整。

### 1.7.0 最终发布校验

- 我的关注帖子卡片将作者状态显示为“已关注”；该按钮沿用现有用户资料入口。三个列表和页面顶部边界有组件回归，覆盖各子页请求参数、账号门槛、切换、独立缓存与分界位置。
- 最终源码离线 assembleRelease 成功（28 秒），全套 59 项回归通过，Dart 静态分析无 error/warning。过程和校验日志保存在 build/logs。
- APK：源社区_v1.7.0.apk，35,210,446 字节；SHA-256：C58C899CCDEB2D3CE3427074CC1E2402673EC93491B2D6302A369338FB0D7D24，release.sha256 已同步。
- AAPT：ycoo.net.php，versionName=1.7.0 / versionCode=15，minSdk24；ZIP lib/ 仅 arm64-v8a。apksigner 校验通过，证书 SHA-256 为 3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975，与指定 BKS 相同；16KiB zipalign 校验通过。验证后按用户要求删除根目录旧版 1.6.2 APK。
- 未连接真机或使用真实登录账户；模拟列表测试不能证明三个子页的真实授权数据结构和分页结果。构建成功不代表这些账号数据已验收。


## 1.7.1+16 首页顶栏与关注页留白（2026-10-27）

- 用户希望移除关注页两层分栏之间的线、整体上移首页分栏，并去除我的关注中的“社区动态”标题。首页工具栏在默认字号下从 76dp 调整为 64dp，字体放大时按需增高；分栏及正文偏移共用该高度，避免缩小工具栏后出现重复留白或遮挡。社区、我的等其他根页面的工具栏高度保持各自实现。
- 仅在显示二级关注分栏时，将一级 TabBar 的分界线设为透明，保留选中指示器；磨砂顶栏最下方分界仍由现有 ReviewFrostedAppBar 绘制。二级分栏底部和实际 AppBar 底部保持一致。
- 关注子页不再渲染门户模块，避免旧缓存中的 PortalData 额外生成“社区动态”标题；列表第一张卡片距磨砂顶栏底部 12dp。首页推荐和圈子原有模块与标题继续使用原布局。
- 扩充关注页组件回归，检查两行分栏间无额外距离、一级分界颜色、上移后的几何位置、旧门户数据不会插入社区动态，以及第一张帖子的位置。


### 1.7.1 最终发布校验

- 离线 assembleRelease 成功（30 秒），全套 59 项回归通过；检查了正常字号和 2 倍字体缩放下的首页顶栏布局。Dart 静态分析无 error/warning，过程与校验日志保存在 build/logs。
- APK：源社区_v1.7.1.apk，35,210,446 字节；SHA-256：9B0DD3777B8C2EA7216B5F200496E7F5EF58A2E0FD2CE401C6B6CB3326B4ACE1，release.sha256 已同步。
- AAPT：ycoo.net.php，1.7.1 / code 16，minSdk 24；ZIP lib/ 仅 arm64-v8a。apksigner 与指定 BKS 证书校验通过，16KiB zipalign 校验通过。新包通过校验后按用户要求删除旧版 1.7.0 APK。
- 未安装到真机；两级分栏的实际视觉效果、登录后的关注列表和不同厂商系统字体渲染仍需设备验收。


## 1.7.2+17 启动登录态与关注入口（2026-10-27）

- 用户反馈启动后立即点击关注会弹登录，但等加载或打开“我的”后才显示已登录。启动 syncSession 是异步操作，初始 uid=0 时原来的入口立即当作游客；成功后 HomePage 重建信息流，可能使在途的用户选择丢失。
- 关注入口复用启动会话核对的 Future，显示“正在确认登录状态”，核对成功后按真实身份进入关注或打开登录。启动核对失败时点击关注重试，同一时刻共享重试请求；再次失败提示网络错误并可再次点击重试，不将失败当作未登录。等待期间切到其他分栏时，不再跳回关注。
- 会话身份更新时，保留首页/导读页面实例与选中分栏，递增列表请求代次、清除当前内存列表，再按新 UID 恢复对应缓存；旧请求不回写新账户。无滚动位置时不调用 jumpTo。个人资料卡仍随 UID 变更重建。
- 登录 API 返回游客时，仍核对移动个人中心；若该核对请求失败，保留原有身份并抛出错误，不再将接口暂时的游客结果直接提交为退出登录。继续以服务端身份和 sessionEpoch 作为依据，不凭本地 Cookie 推测登录成功。
- 回归覆盖启动中点击关注、恢复登录、核对失败后重试、真正游客、等待期间切换分栏、核对失败不丢失原账号，以及切换后旧内容不残留。真实账号与 Android CookieManager 行为仍需设备验收。

### 1.7.2 最终发布校验

- Dart 静态分析完成，无 error；全量 Flutter 回归 65/65 通过，包含启动会话等待、重试、游客与分栏切换用例。
- 离线 `assembleRelease` 成功。AAPT 确认包名 `ycoo.net.php`、版本 `1.7.2` / code `17`、minSdk 24；APK 中 native library 仅 `arm64-v8a`。
- `apksigner` 验签及指定 BKS 证书指纹通过；16 KiB `zipalign` 检查通过。
- 正式包：`源社区_v1.7.2.apk`，35,210,446 字节；SHA-256：`4EFDF1CBAD9FE9A88E6E82FB666F413B5D258AF0E70E6910BD86A59C513710AA`，已同步 `release.sha256`。新包校验完成后按要求删除项目根目录旧版 1.7.1 APK；根目录仅保留当前正式包。构建与检查日志保存在 `build/logs`。
- 未连接 Android 真机；真实登录、启动后关注内容与系统 WebView 会话行为仍需设备验收。

## 1.7.3+18 帖子卡片内容与密度（2026-10-27）

- 对照用户给出的客户端图：卡片保留 M3 外观，等级徽章放回作者名旁，依据站点提供的颜色展示；支持站点给出的性别和同源认证图标。置顶使用状态标记，摘要和统计使用次要文字颜色，关注按钮及版块标签采用紧凑样式。
- 从移动信息流提取等级颜色、性别、认证图标与名称，字段通过 Topic 缓存和版块摘要合并保存；缺失字段不虚构。已有的旧快照仍按缓存优先恢复，新增标识需刷新列表后取得，不为每条帖子额外请求详情。
- 修复默认 SVG 头像未圆形裁剪；压缩卡片内容间距及正文与统计栏距离。统计项在宽度不足或放大字号时换行，头像、关注和点赞触控区域保留至少 48dp。
- 所有 TopicTile 调用点（首页/关注、导读、版块、搜索和个人列表）共享改动；原有图片图库和帖子点击路径保持原样。站点返回的计数和摘要仍以真实响应为准。
### 1.7.3 最终发布校验

- Dart 静态分析无 error/warning；Flutter 全量回归 67/67 通过。新增检查覆盖移动网页的等级颜色、性别、认证标识及缓存往返，同源限制，以及深色/浅色、正常/两倍字号的卡片布局与正文到标签间距。
- 离线 `assembleRelease` 成功；AAPT 确认包名 `ycoo.net.php`、版本 `1.7.3` / code `18`、minSdk 24。APK 中原生库仅 `arm64-v8a`；签名证书匹配指定 BKS，16 KiB zipalign 校验通过。
- 正式包：`源社区_v1.7.3.apk`，35,341,754 字节；SHA-256：`5E5FA13972795624BB0C95C3340368853349E28860235EA433767BB47D7FE286`。新包与构建产物哈希一致，检查通过后删除根目录旧版 1.7.2 APK；日志保存在 `build/logs`。
- 没有进行真机视觉或真实账号验收；旧缓存中新增加的作者标识在刷新对应列表后显示。
## 1.7.4+19 关注按钮和等级颜色（2026-10-27）

- 只读核对站点移动信息流和 `https://ycoo.net/source/plugin/comiis_app/cache/comiis_0_style.css?c2h`：`bg_a` 默认背景是 `#FF9900`，管理员示例 Lv.16 的行内背景是 `#FF0000`。现有移动版块夹具中同为 Lv.7 的用户分别有 `#333333` 和 `#4B3E2A`，说明颜色来自站点用户组样式，不能仅按等级号猜测。
- 移动帖子的等级颜色优先读取站点行内背景；无行内背景的 `.top_lev` 使用站点 `bg_a` 默认橙色。对缺少颜色的旧缓存先显示中性色并后台只读取首屏，按帖子 ID、作者 UID 和等级匹配后仅补颜色，不替换列表内容或滚动位置；会话和页面变更丢弃旧响应。旧缓存中首屏以外未匹配的帖子保持中性色，刷新对应列表后获取原色，避免后台无界拉取历史页。
- “关注”移除加号并使用 32dp 高的 M3 胶囊表面，保留 48dp 点击区域；大字号时按钮按内容增长。已关注状态及既有操作不变。
### 1.7.4 最终发布校验

- Dart 静态分析无 error/warning。完整回归 69/69 通过；最后增加对未知等级样式不猜测颜色的边界处理后，帖子卡片相关 9 项回归再次通过，包括站点默认色、同等级不同用户组颜色、旧缓存补色、过期会话响应和胶囊可点击区域。
- 最终源码离线 `assembleRelease` 成功。AAPT 确认包名 `ycoo.net.php`、版本 `1.7.4` / code `19`、minSdk 24；APK 原生库仅 `arm64-v8a`。签名证书匹配指定 BKS，16 KiB zipalign 校验通过。
- 正式包：`源社区_v1.7.4.apk`，35,341,754 字节；SHA-256：`80A97D6C519B2889B5B61993CF60F0B52491DBE980F3552813A05B97422C0024`。新包与构建产物哈希一致，检查通过后删除根目录旧版 1.7.3 APK；日志保存在 `build/logs`。
- 未进行真机视觉或真实账号验收。旧缓存中首屏以外尚未补到颜色的帖子保持中性色，刷新列表后按站点响应显示颜色。
## 1.7.5+20 旧等级颜色与个人统计稳定显示（2026-10-27）

- 用户指出 1.7.4 的旧缓存普通等级显示灰色。原因是旧快照没有 `levelColor`，界面把缺失值渲染成中性色，而站点 `.top_lev.bg_a` 的默认背景实际为 `#FF9900`。现在缺少颜色时先使用该站点默认橙色；有真实行内用户组颜色时优先使用原色，同等级可有不同用户组颜色。
- 旧快照补色不再仅处理首屏：按已缓存页数顺序逐页读取，最多对应现有快照上限 200 页，最多同时一个请求；按帖子 ID、作者 UID、等级核对后仅更新颜色，保留帖子、顺序及滚动位置。全部匹配、没有更多页、切换会话/列表或请求失败时停止；旧会话响应不写入新账户。
- “我的”原本先显示无统计栏的卡片，profile 请求返回后再插入统计栏造成跳变。现按已确认 UID 缓存主题/帖子/积分，首次无缓存时显示占位符并预留同一布局；成功响应必须 UID 一致且三个计数有效才更新和缓存。账户切换/会话变更丢弃过期响应，失败保留已验证缓存；清除内容缓存及退出登录沿用 `cache.` 清理规则。
- 只读核对站点 profile API 的公开 UID 1，响应包含 UID、threads、posts 和 credits；未使用真实用户账号。旧缓存若无可靠 UID 或站点不可用，暂用站点默认橙色，不能推断特殊用户组色。
### 1.7.5 最终发布校验

- Dart 静态分析无 error/warning；Flutter 全量回归 75/75 通过，覆盖普通等级默认色、多个缓存页的不同用户组原色、过期会话拒绝、个人统计缓存及无缓存布局、网络失败与 UID 不匹配。
- 离线 `assembleRelease` 成功。AAPT 确认包名 `ycoo.net.php`、版本 `1.7.5` / code `20`、minSdk 24，APK 原生库仅 `arm64-v8a`。签名证书与指定 BKS 匹配，16 KiB zipalign 校验通过。
- 正式包：`源社区_v1.7.5.apk`，35,341,754 字节；SHA-256：`129BA6B16526B262D38D426878B3702F336C0CE03B4EBA9A05B4974DB292CCF4`。复制后的哈希与构建产物一致，检查通过后删除根目录旧版 1.7.4 APK；日志保存在 `build/logs`。
- 未连接真机或使用真实账号验收。首次没有统计缓存时先显示占位符；成功取得本人资料后才缓存数字。旧帖子若缺失 UID 或站点离线，特殊组颜色无法确认时暂用默认橙色。
## 1.8.0+21 个人页图标与站点分栏（2026-10-27）

- 我的页面六个重复图标分别改为访客、推广、邀请、资料、头像、空间背景对应的 Material 图标；原入口、账户检查和动作保持不变。
- 通用 NativeSitePage 提取同源站点 `.comiis_topnv` 导航，及好友、心情、圈子、日志、相册等已识别的导航列表，放到 ReviewFrostedAppBar.bottom。使用页面真实 URL 原位切换，游客登录链接保留登录入口；未知脚本或跨域导航不擅自猜测，仍保留原内容。站点原导航从正文中移除，隐藏的对话框不再误显示。
- 社区的版区、新帖、精选、热门改为同页面顶部分栏；导读及版块分类、签到排行与日历从正文标签改为顶部分栏。磨砂层边界随 AppBar.bottom 高度变化；大字号或较多分栏支持横向滚动，内容顶部只计算一次工具栏和分栏高度。
- 本机游客心情页已核对 `.comiis_topnv` 与三个真实链接结构；好友、圈子等需要认证的实际内容未在开发账号上取得，不能以合成夹具断言全部站点脚本行为。仅常规同源链接可原生切换，复杂脚本动作仍有适配边界。
### 1.8.0 最终发布校验

- Dart 静态分析无 error/warning；完整 Flutter 回归 79/79 通过，覆盖原生导航同页切换、未识别脚本不误转换、圈子导航结构、普通和两倍字号下磨砂边界、社区分栏与内容间距，以及既有签到、购买和登录回归。
- 离线 `assembleRelease` 成功。AAPT 确认包名 `ycoo.net.php`、版本 `1.8.0` / code `21`、minSdk 24，APK 原生库仅 `arm64-v8a`；签名证书与指定 BKS 匹配，16 KiB zipalign 校验通过。
- 正式包：`源社区_v1.8.0.apk`，35,342,130 字节；SHA-256：`262D00B35E735FB6BF3D4806F98447D46F44090CE23636CD4A9ECF18C1811289`。复制后哈希与构建产物一致，检查通过后删除根目录旧版 1.7.5 APK；日志保存在 `build/logs`。
- 未将新包安装到设备，也未用真实登录账号验收好友、心情、圈子的全部站点响应；仅经游客样本和合成网页验证，未知站点脚本仍不能假定已适配。
## “我的”功能适配进行中（2026-10-27）

- 用户提供参考客户端的消息分类、资料设置、积分、访客互动、推广二维码、邀请购买及任务/勋章/道具/小黑屋入口。已只读核对公开 `profile(uid=1)`：`space.credits` 和 `space.extcredits2/3/4` 与 `Variables.extcredits` 的经验/贡献/星币名称来自站点，不推测账户余额。
- 使用本地 ZXing 解码用户提供的推广截图，确认链接为同源 `/?fromuid=<当前 UID>`；二维码组件复用 Review 的 `qr_flutter` 4.1.0（BSD-3-Clause）和 `qr` 3.0.2，依赖离线解析。推广二维码不含 Cookie、密码或自动分享。
- 只读核对参考客户端小黑屋 `forum.php?mod=misc&action=showdarkroom&ajaxdata=json`：`data` 为记录映射，`message` 形如 `1|<cid>`。原生列表按真实 CID 分页；不执行账户写入。消息分类采用 Discuz 提醒分类入口；私信列表用实际返回的另一方 UID 打开对应会话。
- 积分转账/充值及任务、勋章、道具、邀请继续使用站点返回的原生表单/页面渲染，未确认站点专有 JavaScript 的全部操作。真实账户访客互动、邀请购买以及微信/QQ 绑定仍缺少登录后的页面结构，已请求用户提供应用中脱敏的“复制页面适配信息”；不可猜测支付结果、账号绑定或写操作成功。
- 用户提供的登录页脱敏信息确认：好友页含 comiis_list_followmod 脚本动作；推广页无表单；资料页为含性别、生日等字段及 formhash 的 POST 表单。该信息不包含访客操作参数、账号绑定入口或邀请购买表单，不能据此构造写操作。
- 积分页监听账户和会话变化，变化后停止显示原账户数据或操作表单。二维码依赖许可证见 docs/QR_LICENSES.md。

### 1.9.0 发布校验

- Dart 静态分析通过，Flutter 全量测试 85/85 通过；离线正式构建成功。APK 包名 ycoo.net.php，版本 1.9.0+22，minSdk 24，仅 arm64-v8a；16 KiB 对齐通过，签名证书 SHA-256 为 3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975。
- 根目录正式包为 源社区_v1.9.0.apk，35,409,210 字节，SHA-256 4DA1D0B6E4FD6DE35BD7BD1C81775B296B8F9FD71B588F4EA9D559DBF422A2C9；复制后哈希一致，已删除旧根目录 APK。日志保存在 build/logs。
- 未安装新包或进行真实登录账户验收。访客互动、支付、绑定和部分插件脚本仍须结合站点实际响应继续适配；不得把通用页面渲染视为完整原生功能。

## 1.9.1 图片播放器画布居中（2026-10-27）

- Gallery 中每张 ExtendedImage 的手势画布固定填满 PageView 视口，原图保持 contain 并在全屏画布中心布局，避免其手势/定位区域跟随图片本身的尺寸变化。

- v1.9.1 正式包构建成功；APK 版本 1.9.1+23，包名 ycoo.net.php，ARM64 only，16 KiB zipalign 及指定证书签名通过。文件大小 35409210 字节，SHA-256 A17DDE963ACA27476B224BA725DBA9BD14CCBCBECC6940FB006227B0EC356848；旧根目录 APK 已删除。

## 1.9.2 缩略图列表居中（2026-10-27）

- 参考 Review 图片图库：缩略项窄于可用视口时在水平列表两侧补等量内边距，整组预览图居中；列表超过视口后不补边距，保留横向滑动和选中项定位。

- 发布版本标签按用户要求回退为 1.0.0，Android versionCode 保持 24 递增。

### 1.0.0+24 发布确认（2026-10-28）

- 按用户要求应用 versionName 回退为 1.0.0，versionCode 继续递增为 24；包名 ycoo.net.php、minSdk 24、仅 arm64-v8a。
- 缩略图列表复用 Review 的居中思路：可容纳时整组居中，溢出时保留横向滚动。图库布局检查 4/4 通过；离线正式构建成功。16 KiB 对齐、APK v2 签名和证书指纹均已核验。
- APK：源社区_v1.0.0.apk，35409206 字节，SHA-256：2550CF2C04B9558425F53F210E3C32D70442245113973B8CD29F5A12BF649D43。
- 本地构建与签名文件排除版本管理。GitHub 当前为空仓库，首推仅源码和项目文档。

## 1.0.0+25 Review 图片播放器行为复用（2026-10-28）

- 纠正前次误判：仅在 ListView 两侧加留白使整组居中，并不符合 Review 实际的当前缩略图居中机制。后续禁止再用固定条目宽度/偏移公式替代 PageController 分页定位。
- 对照 Review 参考项目/lib/features/detail/presentation/widgets/image_gallery_page.dart，迁移普通图片连廊的 PageController(viewportFraction=0.16)、64dp 高度、底部安全区+32dp、选中白框与未选中遮罩。
- 缩略图拖动时按小数页位置直接同步主图，松手后两端在 120ms 内共同吸附；主图手势接管时取消旧连廊惯性，以操作序号丢弃过时的动画完成回调。隐藏控件时保持控制器挂载，防止重新显示后重置选中项。
- 同步 Review 的原始指针点击判定与双击抑制、中间点击显示/隐藏、两侧点击返回、横向滑动关闭、140ms 控件淡入淡出和260ms 分段缩放；缩放最小1，最大8，长图首次双击3.5倍，普通图2.5倍，后续6倍再复原。仅当前页启用 Hero，避免返回时相邻图片同时飞回。
- 版本名保持用户指定的1.0.0，内部 versionCode 25。

### +25 发布校验

- 相关 Dart 分析通过；图库与帖子图片入口定向检查 9/9 通过，覆盖首末张选中居中、横竖屏、缩略图小数页实时同步、停止吸附、主图接管及双击/控件切换。测试遇到网络占位加载动画不停止时，使用有界帧推进并断言两个滚动控制器停止，不能只等待整个 Widget 树无动画。
- 离线正式构建成功；AAPT 确认 ycoo.net.php / versionName 1.0.0 / versionCode 25，仅 arm64-v8a；APK v2 签名证书匹配指定BKS，16 KiB对齐检查通过。APK 35409206 字节，SHA-256 6B99B6FBFB7CB2AC026AF89AF87D9AE029E9EADBDA8F3A278CBC2764BC97EEF8。
- 源码回退基线为 Git 提交 bf9ad11；根目录仅保留当前 源社区_v1.0.0.apk。尚未安装新包到真机进行实际缩放和拖动验收。

## 1.0.0+26 Review Hero 转场对齐（2026-10-28）

- 用户反馈图库打开与返回的图片在转场结束时跳变。根因是图库 Hero 只包住 ExtendedImage 子项，目标边界会受加载占位或图片本征尺寸影响；Review 则以整屏媒体画布作为 Hero 子树，保持飞行起止边界稳定。
- 将图库当前页 Hero 改为包裹固定全视口媒体画布，主图持续在该画布内用 contain 居中绘制；加载占位与原图替换不再改变 Hero 的目标尺寸。打开时捕获源图已解码帧作为预览，仍只保留当前一张。
- 对照 Review `image_gallery_page.dart` 的几何快照：返回到 `BoxFit.cover` 源缩略图时冻结完整图片平面，插值图像画布和圆角裁切，避免 cover 裁切被 Hero 飞行期间重新布局而在终点跳变；contain 源缩略图继续使用 Review 原生 Hero shuttle。
- 增加全屏 Hero 加载态边界断言和 cover 返回画布分支检查；定向图库与帖子图片入口检查 11/11 通过，目标文件 Dart 分析无错误/警告。分析与测试通过不代表已在真机验收图片加载时序、转场手感或 GPU 绘制。
- 直接 Gradle 构建时要同步更新被忽略的 `android/local.properties` 中 `flutter.versionCode`；它会覆盖 pubspec 的 versionCode。首次生成包仍报25，版本校验将其拒收、保留旧 APK；将本机值更新到26后重新构建才交付。正式 Flutter 构建脚本选中的临时 X: 映射被 Windows 拒绝，本次用可用的 V: 映射按项目 ARM64 Gradle 流程完成构建。
- 版本名保持用户指定的 1.0.0，内部 versionCode 26。AAPT 确认包名 ycoo.net.php、minSdk24、targetSdk36、仅 arm64-v8a；APK v2 签名证书与指定BKS匹配，16 KiB zipalign通过。APK `源社区_v1.0.0.apk`，35409206字节，SHA-256 `07C209D8FC14CA4C5A6F9195FCFDE5764266CEFFA806485AE757F67A8E775EAD`；AOT 中确认包含新的返回画布与缩略图代码。根目录仅保留该最新版，旧APK已替换删除。
- 最终 APK 尚未安装到真机；真实图片下载时序、Hero 过渡观感、缩放手势和 GPU 绘制仍待设备验收。源码提交不包含 APK、本机签名配置或 `android/local.properties`。

## 1.0.0+27 GreenNote 浅色液态玻璃同步（2026-10-28）

- 只更新可选液态玻璃悬浮底栏的浅色模式：同步 GreenNote 的白色玻璃壳与 rimLight=1、浅色折射选中镜片、白色细描边及主题色选中/未选中图标文字；原有深色参数保持不变。
- 图片播放器、缩略图连廊、手势与 Hero 转场没有修改。
- 定向测试覆盖浅色镜片样式和深色回归，2/2 通过；目标文件 `dart analyze --format machine` 通过。
- 离线 ARM64 正式构建成功。AAPT 确认包名 `ycoo.net.php`、versionName `1.0.0` / versionCode `27`、仅 `arm64-v8a`；APK v2 签名匹配指定 BKS 证书 SHA-256 `3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975`，16 KiB zipalign 校验通过。
- 正式包：`源社区_v1.0.0.apk`，35,409,206 字节，SHA-256 `DD0D7B3CA74215BECA0717964CF77191C751DBCDE397D8B327A7C465291DA3D1`；新包验证通过后已替换根目录旧包。Gradle 日志位于 `build/logs`。
- 未安装到设备；玻璃效果的实际观感与 GPU 表现仍待真机确认。

## 1.0.0+28 浅色液态玻璃悬浮底栏阴影（2026-10-28）

- 仅将浅色液态玻璃悬浮底栏外壳 `shadowElevation` 设为 0.55；深色仍为 0，其他玻璃胶囊与图片播放器均未修改。
- 定向浅色/深色底栏测试 2/2 通过，目标 Dart 分析通过。
- 离线 ARM64 正式构建成功。AAPT 确认包名 `ycoo.net.php`、versionName `1.0.0` / versionCode `28`、仅 `arm64-v8a`；APK v2 签名匹配指定 BKS 证书 SHA-256 `3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975`，16 KiB zipalign 校验通过。
- 正式包 `源社区_v1.0.0.apk`，35,409,206 字节，SHA-256 `9C3F8B3C6279E13C6FCDA7A5F5D0DFE46A303F49FEBF4F34BB3F12088FBDE587`；校验成功后替换了旧 APK，根目录仅保留最新版。Gradle 日志位于 `build/logs`。
- 未安装到设备；真机阴影观感与 GPU 表现待设备确认。

## 1.0.1+29 Lurk 悬浮底栏行为与尺寸（2026-10-28）

- 对照 `Lurk 参考项目/lib/features/home/presentation/main_scaffold.dart`：悬浮栏宽度采用 `min(440, 屏幕宽度 - 40) × 8/9`；点击切换禁用 indicatorPinchStrength 和 indicatorExpansion，只滑动选中镜片。未迁移 Lurk 的长按/拖动果冻手势。
- 只调整 ReviewNavigationBar 的悬浮导航和相应设置/测试；图库、图片播放器及其他玻璃胶囊保持原样。
- 定向测试覆盖点击镜片参数、浅/深色回归及 Lurk 尺寸，2/2 通过；目标 Dart 分析通过。
- 离线 ARM64 正式构建成功。AAPT 确认包名 `ycoo.net.php`、versionName `1.0.1` / versionCode `29`、仅 `arm64-v8a`；APK v2 签名匹配指定 BKS 证书 SHA-256 `3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975`，16 KiB zipalign 校验通过。
- 正式包 `源社区_v1.0.1.apk`，35,409,210 字节，SHA-256 `1E72E74260B85A4C6B162B12E428FE4004ACB1A5BCCC9A0EBA836F6014BC6DC0`；新包验证成功后删除根目录旧 APK，当前仅留此包。Gradle 日志位于 `build/logs`。
- 未安装到设备；底栏触感/液态效果的真机表现仍待确认。

## 1.0.2+30 主底栏平移切页（2026-10-28）

- 参考 `Lurk 参考项目/lib/features/home/presentation/main_scaffold.dart`：主底栏不同页面间使用 260ms `easeOutCubic` 双向平移；按页签顺序及 RTL 调整方向，中途再次切页从当前偏移连续开始。
- 保留访问后懒加载和页面状态；仅当前页接收指针，转场期间维持前后页 ticker。尊重系统减少动态效果设置，关闭动画时直接切换。内部分栏与图库转场不变。
- 定向 `following_tabs_test.dart` 8/8 通过，目标 Dart 分析无错误；转场断言覆盖新旧页面移动与返回首页不重复加载信息流。
- 发布脚本创建临时 subst 路径时被 Windows 拒绝；改用本机指向同一工作区的 ASCII `V:` 路径，执行离线 Gradle `assembleRelease` 成功。日志：`build/logs/release-20261028-home-tab-slide.log`。
- APK：`源社区_v1.0.2.apk`，35,409,210 字节，SHA-256 `9F4CFDC8F945BDA6BFC0BBBAF73EFB9E8CB6B99AE4CABB7C2CE02D809C515534`，`release.sha256` 已同步。
- AAPT 确认包名 `ycoo.net.php`、应用名“源社区”、versionName `1.0.2` / versionCode `30`、minSdk 24；APK 原生库仅 `arm64-v8a`。签名 v2 通过且证书 SHA-256 与指定 BKS 一致；16 KiB zipalign 校验通过。校验完成后根目录及 `previous-releases` 中旧 APK 已清理，只保留当前正式包。
- 未安装到设备；尚未进行真机页面切换视觉验收。

## 1.0.3+31 图库原图加载预览保持（2026-10-28）

- 帖子正文图片从 Discuz 的 `data-src` / `src` 选择可用预览源，图库仍以 `file` / `zoomfile` 等原图源作为高清主图；无单独预览时沿用原图地址。Hero 起点和底部缩略连廊优先使用预览图。
- Review 式全屏图库在原图解码期间保留已捕获的 Hero 帧；没有捕获帧但存在独立缩略图时显示该预览，原图加载完成后才替换，避免黑底等待。
- 定向 `content_regression_test.dart` 回归通过，覆盖 Discuz `src` 预览、`file` 原图传递和加载中的预览帧；改动文件 `dart analyze --format machine` 无诊断。
- 首次测试命令从中文工作路径触发本机 Impeller include 路径乱码；按既有构建约定改从 ASCII 临时映射运行，测试通过。未修改 shader、依赖或播放器动画。
- 离线 ARM64 `assembleRelease` 成功（36 秒）；Gradle 日志为 `build/logs/release-1.0.3-image-preview.log`。
- APK：`源社区_v1.0.3.apk`，35,409,210 字节，SHA-256 `55068FC3A8615BDB4251407069FF88E2FA64254BA9776BD114BADE55CEC40099`，`release.sha256` 已同步。
- AAPT 确认包名 `ycoo.net.php`、应用名“源社区”、versionName `1.0.3` / versionCode `31`、minSdk 24，ZIP 中原生库仅 `arm64-v8a`。APK v2 签名及证书 SHA-256 `3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975` 通过；16 KiB zipalign 校验成功。
- 验证完成后删除旧版根目录 APK 和 `previous-releases` 下旧 APK，只保留当前正式包。未安装到真机；设备图像切换观感尚未现场验收。

## 1.0.4+32 GreenNote 图库玻璃转场优化（2026-10-28）

- 对照 `GreenNote 参考项目/lib/features/feed/image_gallery_page.dart`：图库进场时玻璃控件透明且不可交互；液态玻璃开启时，返回转场移除顶部工具栏和缩略图玻璃控件子树，结束后页面随路由销毁。不开启液态玻璃时只按原有淡出行为处理。
- 图片画布、Hero 几何、缩略图居中及播放器手势不变；控件不在退场时参与玻璃渲染。
- `test/gallery_layout_test.dart`：8/8 通过，覆盖进场透明/禁用交互、完成后恢复和返回时移除控件；改动 Dart 文件定向 analyze 无诊断。
- 版本升至 `1.0.4+32`；离线 ARM64 `assembleRelease` 成功（1 分 24 秒）。AAPT 确认包名 `ycoo.net.php`、应用名“源社区”、versionName `1.0.4` / versionCode `32`、minSdk 24，APK 和 ZIP 原生库仅含 `arm64-v8a`。
- APK：`源社区_v1.0.4.apk`，35,409,206 字节，SHA-256 `040AB7C5E099F5A2BBCD7CA44834D0AC8835B92331433EBBB700305A6B11B889`；`release.sha256` 已同步。复制包与构建产物哈希一致。
- APK v2 签名验证通过；证书 SHA-256 `3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975` 与指定 BKS 一致。`zipalign -c -P 16 -v 4` 校验成功。
- 验证完成后删除根目录旧版 APK 及 `previous-releases` 下旧 APK，只保留当前正式包。Gradle 日志位于 `build/logs/release-1.0.4-gallery-glass-transition.log`。
- 未安装到真机；退场转场的 GPU 帧耗时尚未在设备上测量。

## 1.0.5+33 Hero 反向重开图像定位修复（2026-10-28）

- 对照 Review 3.13.1 历史修复：pop 途中再次 push 时 Flutter 会保留旧 Hero shuttle，但外层 Hero rect 已反向变化；若内部图片仍按首次飞行的动画值插值，图片平面会短暂错到视口左上角。
- 图片和圆角插值现在由当前 Hero 飞行视口尺寸推导；同尺寸边界保留原动画值兜底。未改路由曲线、Hero tag/起止几何、画布约束或缩放手势。
- 扩展 `test/gallery_layout_test.dart` 像素回归：固定过期动画值并改变 Hero 视口时，图片像素仍跟随视口；视口不变而旧动画值变化时，像素保持一致。图库定向检查 8/8 通过，`lib/pages/media.dart` 与测试文件定向 analyze 无诊断。
- 图库打开转场时长设为 330ms，返回保持 200ms；沿用现有淡入曲线及转场实现。
- 版本升至 `1.0.5+33`。ARM64 Release 构建成功（约 9 分 17 秒）。AAPT 确认包名 `ycoo.net.php`、应用名“源社区”、versionName `1.0.5` / versionCode `33`、minSdk 24，APK 原生库仅含 `arm64-v8a`。
- APK：`源社区_v1.0.5.apk`，34,985,289 字节，SHA-256 `795CC4A8B312E3FB2D1AC5346D1C1B9730E0E496D64C4AAA8AF518500CD2A845`，`release.sha256` 已同步。签名 v2 验证通过，证书 SHA-256 与指定 BKS 一致；`zipalign -c -P 16 -v 4` 校验成功。新包核验后删除旧 APK，项目根目录只保留此包。
- 构建脚本创建嵌套临时盘符被 Windows 拒绝；从已有 `V:` ASCII 映射直接运行 Flutter ARM64 发布构建成功。项目根目录遗留的 Flutter 日志已移至 `build/logs`。
- 未安装到设备；连续反向开合、330ms 打开时长的实际观感及帧耗时尚未真机验收。

## 1.0.6+34 Material 图标缺字修复（2026-10-28）

- 根据底栏/帖子操作图标乱码及图片播放器顶部按钮消失的截图排查，旧发布构建将 `MaterialIcons-Regular.otf` 裁剪到 7,048 字节；液态玻璃组件通过参数接收的图标字形因此不完整。正式构建改用 `--no-tree-shake-icons`，播放器和玻璃组件代码未改。
- `tool/build_release.ps1` 已同步禁用图标字体裁剪。Release APK 内完整 Material 图标字体为 1,645,184 字节；`FontManifest.json` 指向该资源。
- 版本升至 `1.0.6+34`。ARM64 Release 构建成功（451 秒）；AAPT 确认包名 `ycoo.net.php`、应用名“源社区”、versionName `1.0.6` / versionCode `34`，原生库仅 `arm64-v8a`。
- APK：`源社区_v1.0.6.apk`，35,954,942 字节，SHA-256 `D50C97071DC57DFA8262751980D4C15A85B9F3F276617850A8BB2D1DE97827C3`，`release.sha256` 已同步。签名 v2 验证通过，证书 SHA-256 与指定 BKS 一致；16 KiB zipalign 检查通过。验证后已删除旧 APK，仅保留最新正式包。
- 构建日志：`build/logs/release-1.0.6-icons.log`。未安装到设备，底栏及图库控件的实际显示尚未真机验收。

## 1.0.7+35 图库顶部玻璃按钮进场对齐（2026-10-28）

- 修复液态玻璃图库打开时按钮圆形玻璃背景先与图标错位、随后跳到位的问题。原因是工具栏 `AnimatedOpacity` 与玻璃按钮内部 `visibility` 使用了不同步的显示进度；现在两者共享同一进度逐个淡入。
- 保留 `StackFit.expand` 下顶部 `Positioned(top: 0, left: 0, right: 0)`，防止工具栏被拉伸成整屏高度；主图、Hero、缩略图居中和图片播放器动画不变。
- `test/gallery_layout_test.dart` 图库定向测试 8/8 通过；`dart analyze lib/pages/media.dart test/gallery_layout_test.dart` 无诊断。
- ARM64 Release 构建成功（457 秒）。AAPT 确认包名 `ycoo.net.php`、应用名“源社区”、versionName `1.0.7` / versionCode `35`、仅 `arm64-v8a`；Material 图标字体完整（1,645,184 字节）。
- APK：`源社区_v1.0.7.apk`，SHA-256 `2F1570B3FEDB7A56CA8CF6E8617383BA1F843E9E26875443E9E90F988D471FC6`；`release.sha256` 已同步。APK v2 签名证书 SHA-256 `3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975` 匹配指定 BKS；16 KiB zipalign 校验通过。验证后删除根目录旧版 APK，当前仅留该正式包。
- 构建日志位于 `build/logs/release-1.0.7-gallery-toolbar-alignment.log`。未安装到真机；按钮玻璃位置的真实设备动画观感仍待设备验收。


## 1.1.0+36 启动时后台自动签到（2026-11-03）

- 设置首页“偏好与功能”增加 Review/M3 自动签到开关，默认关闭并沿用已有 autoSignIn 值；从阅读子页移出，开启不强制导航到登录页。
- 启动时等待现有 syncSession 完成后读取签到页状态，仅未签到且凭据有效时复用原生 signNow 请求提交。页面只作为后台数据请求，不创建 WebView 或执行网页自动化；不弹 Snackbar、对话框或切换当前页面。
- 不再用本机日期缓存代替服务器今日状态；并发检查共用一个任务，结束（包括失败）释放。读取期间若账号/会话切换、退出登录或关闭开关，停止提交；网络或站点验证失败静默结束，不盲目重试写入，下次启动重新检查。
- SignData 与 signNow 移到 Site 数据层供原生签到页和自动流程共用；未识别签到按钮时返回空状态，防止把验证/登录页面当成未签到。
- 定向 reading_tools/native_site 回归 20/20 通过，涵盖关闭/游客不请求、服务端已签到不提交、未签到提交、并发仅一次、切换账号/关闭后不提交、失败后可重新检查和手动签到兼容；Dart 分析无 error/warning（既有风格 info）。
- 关于页面与 README 版本同步为 1.1.0+36。正式 ARM64 构建及包体验证结果见下方；未执行真实账号签到或真机安装。

### 1.1.0 最终发布校验

- ARM64 Release 构建成功（347.5 秒），日志 `build/logs/release-1.1.0-auto-sign.log`。包名 `ycoo.net.php`、versionName `1.1.0`、versionCode `36`；APK ZIP 原生库仅 `arm64-v8a`，MaterialIcons 完整字体 1,645,184 字节。
- APK：`源社区_v1.1.0.apk`，35,954,938 字节；SHA-256 `732E249A2C0996296F8F078959704BE07D30821A6115063A33CE626A1735274D`。APK v2 签名证书 SHA-256 `3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975` 匹配指定 BKS，16 KiB zipalign 检查通过。
- 复制后哈希一致才清理旧 APK，根目录只保留 1.1.0；release.sha256 已同步。源码回退基线为 Git f41cbcb，本次改动保留在工作区。
- 自动检查通过不等于真实账号签到验收；未安装到设备，未使用真实账号执行签到。站点登录过期、网络失败或要求验证时静默结束，下次启动重新检查。

## 1.2.0+37 用户个人主页与姓名入口（2026-11-03）

- 对照用户长图及站点公开 UID 34747 的移动资料页、桌面资料页和 profile API 进行适配。真实公开字段包含背景、头像、Lv.7/大会员、勋章、签名、530 主题/325 回复、关注/粉丝/好友/日志/相册/心情/人气、积分和扩展积分、在线/注册/访问时间；显示数据来自每次请求，不硬编码样例数字。离线夹具只保留公开资料字段和页面片段，不保存 Cookie、formhash、密码或 API 会话数据。
- 新增 data/profile.dart 和 pages/profile.dart。旧 thread.dart 导出保持各调用点兼容；首页、关注、社区/导读/搜索和个人帖子共用 TopicTile，用户名/等级区域与头像一样进入原生个人主页；回复、签到排行和用户列表原有整行入口继续复用。
- 页面按封面资料、图标/文字四分栏、资料详情和统计、底部互动栏组织。复用 M3 主题/按钮/Chip/列表与 ReviewFrostedBackdrop；分栏在封面下方吸顶，磨砂边界随字号与实际高度计算。普通字号左右对齐资料，大字号纵向排列，统计网格可降为双列，安全区保护底部操作。
- 资料、帖子、日志、相册按需读取并独立缓存，帖子包含主题/回复筛选与加载更多；移动信息流及标准帖子链接布局均可解析。相册封面与标题分开链接时按 albumid 合并，日志和相册详情沿用原生站内内容页及现有图片浏览器。访客或权限限制按站点登录/提示处理，不把登录页误判成空内容。
- 原生显示勋章图片和详情弹窗、站内勋章中心、个人签名、可扫码的主页二维码及复制链接；统计链接进入对应内容/关注/粉丝/好友/心情/访客列表。详情只展示已公开的资料与扩展积分，不遍历展示 profile API 的其它隐私字段。
- 关注/取消关注、加好友、打招呼、聊天和拉黑使用实时认证页面给出的实际同源链接和 NativeSitePage 原生表单，不构造认证散列或直接执行网页脚本。只接受当前目标用户和对应操作；跨站或不同目标链接被拒绝，写入动作先确认，再由既有表单处理真实服务端结果。站点不提供当前账号可用链接时明确提示，不能冒充成功。
- 修复通用 URL 路由过去将任何 uid 参数都当作主页的问题：只有空间根链接或 do=profile 才进入个人主页，日志/相册/内容/好友动作保留其真实目的地。openWeb 与 routeLink 共用此判定。
- 并发切换分栏各自加载；账号/会话变化时清空内容缓存，旧请求不能覆盖新账号数据，失败可手动重试。不会批量请求四个分栏，也不会自动执行关系写入。
- 相关 profile/native_site/content_regression/my_dashboard/reading_tools 回归 40 项通过；最后补充相册合并后主页定向 11 项全部通过，目标 Dart 分析无诊断。覆盖真实资料字段、用户名点击、同源与目标限制、内容路由、标准帖子行、相册封面合并、二维码、1x/2x 字号与吸顶分栏位置、在途切页。
- 设置中的后台自动签到改动继续保留；pubspec、关于页面和 README 同步 1.2.0+37。未用真实登录账号执行关注/好友/招呼/私信/拉黑，未安装到真机；登录态下页面内容和站点限制仍需设备实际验收。构建与包体核验见下方。

### 1.2.0 最终发布校验

- ARM64 Release 构建成功（253.3 秒），日志 `build/logs/release-1.2.0-profile.log`。包名 `ycoo.net.php`、versionName `1.2.0`、versionCode `37`；APK 原生库仅 `arm64-v8a`，MaterialIcons 字体完整（1,645,184 字节）。
- APK：`源社区_v1.2.0.apk`，36,086,014 字节。SHA-256 `D260693FA04C8D231A5B0710DA422B4BE925568FE16AA4A5628AF177437C5346`；复制后与构建产物一致，release.sha256 已同步。
- APK v2 签名验证通过，证书 SHA-256 `3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975` 匹配指定 BKS；16 KiB zipalign 通过。校验完成后清理根目录旧 APK，只保留 1.2.0。源码保留在工作区，基线 f41cbcb 可供回退。
- 未安装到真机；公开资料读取、组件回归和包体校验不能代替登录后的内容、权限、表单写入与真实设备观感验收。

## 1.2.1+38 个人主页身份显示与紧凑排版（2026-11-03）

- 用户截图显示管理员头像回退、等级空徽章、统计错行、底部按钮折行及功能区变成四排。只改个人主页模型/布局，保留后台自动签到和之前的原生主页功能。
- 根因一：移动资料页给出的头像为 ./data/avatar/... 相对地址，原先直接传入 Image.network 导致加载失败。模型统一规范化为有效 HTTP(S) 绝对地址；公开 UID 1 中号与小号头像均已只读核验 HTTP 200/image/jpeg。
- 根因二：站点性别图标与等级都使用 .kmlevs，管理员性别图标恰好位于 Lv.16 前，旧 querySelector 取到了私用字体图标。现在只读取 .kmlv 的 Lv 数字，不再把性别当等级。等级背景沿用有效站点用户组颜色，并计算对比文字色。
- 名称/头像/等级/用户组优先从已核对“用户ID”的同一页头读取；不把其它 UID 页面数据拼进当前用户。用户名缩为 24sp、头像直径 64dp，封面最小高度由 280dp 收为 224dp；不改真实昵称。
- 人气、关注、粉丝由混合 Text/TextButton 的 Wrap 改为三个等宽的 Row 单元，统一 13sp 字体、居中对齐及至少 48dp 触控高度。大字号在每列内统一显示计数/标签两行，不互相挤占或裁切。
- 八个功能固定为两排、每排四列，移除 maxWidth<350 或大字号时降到双列的旧规则；图标 22dp、文字 12sp，标签和计数分开显示，大字号仍可自然增长行高。
- 底部四个操作固定 Row + Expanded，图标 18dp、文字 12sp，单按钮最小 48dp；不再使用 Wrap，因此不会出现三上一下。
- 个人主页顶栏基准高度 48dp、标题 18sp、图标 20dp；吸顶分栏基准高度约 52dp，图标 18dp、文字 12sp。保留文字缩放时所需的自然高度，磨砂边界依实际高度一起变化。
- 新增管理员真实公开夹具，覆盖性别图标排在等级前和相对头像地址；夹具剔除会话字段。21 项主页回归通过，包含 320/360/393dp × 1/1.3/2 倍字号、底部同排、两排四列、统计对齐、正确昵称/头像URL/Lv.16 和既有导航/二维码；定向 Dart 分析无诊断。
- 上版受影响源码快照在 build/rollback/profile-1.2.0-source.zip，按原相对路径保存。pubspec、关于和 README 同步 1.2.1+38。未安装真机，正式包校验记录见下方。

### 1.2.1 最终发布校验

- ARM64 Release 构建成功（214.9 秒），日志 `build/logs/release-1.2.1-profile-density.log`。AAPT 确认包名 `ycoo.net.php`、versionName `1.2.1`、versionCode `38`；ZIP 原生库仅 `arm64-v8a`，完整 MaterialIcons 字体 1,645,184 字节。
- APK：`源社区_v1.2.1.apk`，36,086,014 字节；SHA-256 `F03365CB751A392C1EB2C4F1763407B6AFF74E94D8E08E899D98B9F27E47B954`。APK v2 签名证书 SHA-256 `3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975` 匹配指定 BKS；16 KiB zipalign 校验通过。
- 复制哈希一致后删除根目录旧 APK，只保留当前 1.2.1；release.sha256 已同步。正式包未安装到真机；上述头像来自公开站点只读核对，排版由 Flutter 组件几何检查，不能代替真实设备观感验收。


## 1.2.2+39 普通用户主页灰屏与帖子作者对齐（2026-11-03）

- 用当前公开移动信息流选取普通用户，再读取 profile API 和移动个人页复现。UID 16966（pgffgm）、25430、5427 的 API space.medals 均返回空字符串，而管理员及旧样例用户返回列表；原先强制转换 List 在页面构建时抛 TypeError，Release 表现为灰屏。修改前 pgffgm 组件测试已复现异常，修复后同样数据正常呈现。
- 主页模型只在勋章数据为列表或键控集合时读取条目，空字符串/空值作为无勋章；可选用户组和扩展积分也先校验类型，负数帖子计数不进入非法 clamp 边界。资料身份校验、账号切换保护及关系操作限制保留，不把错误内容伪装为成功。
- 三位真实普通用户的离线夹具只保留公开展示字段和主页片段，删除会话字段及脚本。新增回归直接构建每位用户的原生主页，确认姓名正确且无 ErrorWidget；覆盖可选字段为空的情况。
- 修复共享 TopicTile 作者区：头像、作者文字块及关注按钮垂直居中；姓名与等级共用文字基线，时间紧跟姓名行并左对齐，长名最多两行。性别/认证保留；头像和姓名入口仍均可进入用户主页。首页、关注、导读、版块、搜索及个人帖子列表共用同一处修复。
- profile/topic_author_layout/mobile_portal 定向回归 44/44 通过，涵盖 320/360/393dp × 1/1.3/2 倍字号、长名、头像/文字/按钮几何与文字基线。Dart 定向分析无 error/warning，home.dart 保留 11 项既有风格 info；不为本次修复扩改无关代码。
- 防回归教训：只测管理员和有勋章用户会漏掉站点“空集合返回空字符串”的实际契约；新增 API 字段应检查非空/空集合两类真实数据。布局断言用 getDryBaseline 读取文字基线，不在测试布局外调用受 debug 限制的 getDistanceToBaseline。
- pubspec、关于和 README 同步 1.2.2+39。修改前源码按相对路径保留于 build/rollback/profile-1.2.1-source.zip；构建日志放 build/logs。正式包静态校验记录见下方；未安装到真机或执行账号关系写入。


### 1.2.2 最终发布校验

- ARM64 Release 构建成功（267.2 秒），日志 build/logs/release-1.2.2-profile-gray.log。AAPT 确认包名 ycoo.net.php、versionName 1.2.2、versionCode 39；APK ZIP 原生库仅 arm64-v8a，MaterialIcons 完整字体 1,645,184 字节。
- APK：源社区_v1.2.2.apk，36,086,010 字节；SHA-256 7E216114A012BE56123E96C7376A1AD70F22FB65ABBFACF5E913EB186342CAC9。APK v2 签名证书 SHA-256 3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975 匹配指定 BKS；16 KiB zipalign 校验通过。复制后与构建产物哈希一致，release.sha256 已同步，删除旧 1.2.1 APK 后根目录仅留 1.2.2。
- Windows aapt 无法读取中文绝对路径，报 Illegal byte sequence；改用已有 V: ASCII 映射后包体检查通过。构建和 Android 打包工具均使用映射路径，不把该工具错误当成 APK 内容损坏。
- 定向测试 44/44 通过；未安装到真机，未用真实账号执行关注、好友或其它写入。普通用户实际设备访问和最终视觉仍需设备验收。


### 1.2.2 源码推送前核对

- 合并后台自动签到、完整原生个人主页及后续修复的源码、公开资料夹具与测试；profile/topic_author_layout/mobile_portal/reading_tools/native_site 合并定向回归 64/64 通过。
- 公开 README 和开发记录移除本地绝对路径及签名文件位置；仅保留相对路径和参考项目名称。APK、签名材料、会话凭据、本地配置、构建缓存、日志及回退 ZIP 不进入提交；release.sha256 保留为本地正式包校验值。
- 此次只同步源码与文档，没有改变 1.2.2 已核验 APK 的程序内容，也没有安装设备或执行账号写入。使用普通 fast-forward 推送，不改写历史。


## 1.2.3+40 同步 GreenNote 深色液态玻璃选中态（2026-11-03）

- 只读对照 GreenNote 1.9.20+170 的 review_navigation_bar.dart 和开发记录第227节：深色选中胶囊的玻璃 tint 与低质量后备 indicatorColor 均改为 0x26FFFFFF（约15%白色），bodyMode 使用 clear；选中图标/文字统一跟随 colorScheme.primary，未选中项保持白色。
- 改动只在源社区共享 ReviewNavigationBar 液态玻璃分支；不迁移 GreenNote 同期图片重入改动，不修改图片播放器。深色外壳仍为 0x66000000、无阴影；浅色白色外壳/0.55阴影/选中暗色玻璃/边缘高光不变。底栏尺寸、点击只移动镜片、切页动画、触控区域与非玻璃模式均保留。
- 没有新增覆盖图层、定时器、依赖或图片缓存；复用已有材质及 M3 主题色。预置深色主题与切换主题色两种情况下验证选中前景同步，保留浅色参数隔离断言、导航点击与触感/安全区回归；2个定向文件共7项通过，目标组件与测试 analyze 无诊断。
- 测试中玻璃库会叠放普通与选中两套标签，不能用 find.text 单一匹配点击；按实际导航栏矩形内目标位置点击，验证回调。原始匹配歧义是测试定位问题，不修改库渲染实现。
- 版本同步 1.2.3+40；上版相关源码快照在 build/rollback/dark-glass-1.2.2-source.zip，基线提交49d4770。构建日志统一存 build/logs；未安装真机，GPU折射与实际设备配色观感未验收。正式包校验记录见下方。


### 1.2.3 最终发布校验

- 原签名 ARM64 Release 构建成功（296.9秒），日志 build/logs/release-1.2.3-dark-glass.log。包名 ycoo.net.php、versionName 1.2.3、versionCode 40；原生库仅 arm64-v8a、MaterialIcons 字体完整（1,645,184字节）、APK v2 签名与原证书匹配、16 KiB zipalign 检查通过。
- 正式包源社区_v1.2.3.apk，36,086,014字节，SHA-256 BBD6309E7FA2BD7E031F853CF81829944F2FA576580B0BD8F9393C43775F9A55。构建产物与交付包哈希一致，release.sha256同步；核验后删除旧版APK，根目录仅保留1.2.3。
- 未改图片播放器或玻璃着色器，没有安装到设备；7项组件回归与静态包体验证不能替代手机深色模式下的GPU折射与主题色观感验收。源码保留在工作区，未自动推送。


## 1.2.4+41 修复深浅色底栏按住/拖动水珠过小（2026-11-03）

- 用户确认问题发生在深色和浅色的按住/滑动状态。对照1.2.2基线、1.2.3工作区与GreenNote实际组件/玻璃库，1.2.3只改静止深色配色，镜片扩展与pinch一直固定为0，遗漏了GreenNote在按住/拖动期间的启用逻辑；此前7项检查仅覆盖静止参数和普通点击，不能证明活动水珠尺寸与折射正确。
- 共享导航改为有状态组件；复用GreenNote交互阈值：按住220ms或横向超过Flutter触摸阈值后启用pinchStrength 0.7、horizontal 12dp / vertical 8dp扩展；松手保留250ms交接再恢复。短点按仍为0扩展/0形变，只平移选中镜片。外壳尺寸、页面切换动画、深色灰胶囊/主题前景、浅色阴影材质均保留，图片播放器和玻璃库未修改。
- 原始指针Listener不加入手势竞争；导航回调缓存至松手后统一提交，按住/拖动中不反复切页，取消或纵向手势不提交；沿用玻璃库已有拖动/弹簧/落点计算。仅启用/停用时重建，不在每次move事件中setState；定时器在新手势、关闭玻璃/悬浮模式及销毁时清理，旧回调不能覆盖新手势。
- 新增真实手势组件回归：深/浅色普通短点按没有活动大水珠；长按后实际GlassEffect布局高度64dp、宽度为槽位加24dp，渲染层pinch约0.7、折射率1.18、色散0.025；槽内移动连续跟随，松手只选一次页面；快速拖动后取消、开关玻璃及卸载不残留状态或定时器。
- liquid_glass_light_mode/ui_regression/following_tabs三个定向文件共17项通过，补充玻璃开关/卸载检查后玻璃文件4项再次通过。目标组件与测试静态分析无诊断。注意玻璃库会合并indicatorSettings，后续检验应读取实际GlassEffect参数和几何，不能只断言外层GlassTabBar配置。
- 版本同步1.2.4+41；修改前源码按相对路径备份build/rollback/glass-gesture-1.2.3-source.zip。日志放build/logs。未做手机GPU折射或连续触控录屏验收；正式ARM64包核验见下方。


### 1.2.4 最终发布校验

- 原签名ARM64 Release构建成功（359.0秒），日志build/logs/release-1.2.4-glass-gesture.log。包名ycoo.net.php、versionName 1.2.4、versionCode 41、非debuggable、原生库仅arm64-v8a；MaterialIcons完整字体1,645,184字节，V2签名与原证书匹配，16 KiB zipalign检查通过。
- 正式包源社区_v1.2.4.apk，36,086,014字节，SHA-256 513DABE747FBE3F2DB1E1DE98EE127AD6119EB5CD80F87BC4842DBB6044438F6。交付包与构建产物哈希一致，release.sha256同步；检查后删除旧1.2.3 APK，根目录仅留1.2.4。回退源码保存在build/rollback，当前源码未自动推送。
- 17项导航相关组件回归通过，最后补充模式切换/销毁后玻璃文件4项再次通过；目标组件及测试analyze无诊断。没有安装设备或测量手机GPU折射，实际按住/拖动观感仍需手机复测。


### 1.2.4 源码交付范围

- 按用户请求提交深色灰玻璃/主题色选中态与深浅色按住/拖动水珠修复；仅涉及共享导航组件、对应回归、1.2.4版本信息、公开开发记录与正式包校验值。图片播放器及玻璃库源码未变。
- 沿用已完成的17项导航相关回归、模式切换/销毁补充检查和目标静态分析；本次推送不改程序内容，不重复构建已核验的正式包。APK、签名、配置、日志及回退快照均留在本地。
- 普通fast-forward推送main，不改写旧历史；未做真机GPU折射或连续触控验收。

## 1.2.5+42 繁星开通使用原站流程（2026-11-03）

- 用户反馈“我的 → 繁星开通”不可用，并提供 https://ycoo.net/plugin.php?id=boan_group&frame=yes。旧入口带 mobile=2，统一 openWeb 又将该插件送入 NativeSitePage；通用 HTML/表单渲染不执行插件 JavaScript，不能据内容出现就判断完整交互可用。新增路由回归在修改前已复现该地址错误进入 NativeSitePage。
- 在共享 openWeb 中精确识别同源 /plugin.php、id=boan_group，直接交给现有 BrowserPage；“我的”使用用户提供的地址，不再额外添加 mobile=2。帖子/签到等处已有 mobile=2 的同插件链接同样走内置浏览器，其他插件及原生帖子/资料路由保留。复用既有系统 WebView Cookie、移动 UA、脚本对话框和错误/重试，不额外请求登录、不转交账号 Cookie 给外部浏览器，也不重建或自动提交开通表单。
- 当前只读现场核对：移动 UA 访问提供的 URL 返回移动登录页；桌面 UA 返回“请先登录”提示。没有登录后的插件页面/支付样本，因此选择用户允许的直接跳转，不推测开通接口或原生重写支付。该结果仅证明游客访问的登录要求，不证明登录后购买可用。
- 版本、关于、README、功能对照与两份开发记录同步 1.2.5+42。修改前完整源码保存在 build/rollback/star-membership-1.2.4-source.zip（基线 d51d8bd），原签名旧包保存在 build/rollback/star-membership-1.2.4.apk，供回退。
- 新增回归覆盖原始/移动/乱序参数链接、非目标插件与路径隔离、“我的”游客登录门槛及已登录后打开的精确地址。路由测试只捕获实际目标页面，不启动模拟 WebView，不把该测试当作网页或真机验收。定向验证及正式 ARM64 包核验见下方。

### 1.2.5 定向验证

- link_routing / my_dashboard / native_site 三个文件共 23/23 项通过，日志 build/logs/test-1.2.5-membership.log；包含繁星原站路由及游客门槛、非目标插件保持原生、原生主题购买取消/失败/变价/防重复等既有回归。捕获目标路由的测试没有启动 Android WebView。
- Dart 对 common.dart、home.dart 和路由测试的定向分析无 error/warning；home.dart 的 11 项既有风格 info 保留，测试辅助 Navigator 改为私有类以免新增公开组件 key 提示。
- Windows 中文工作路径再次触发既有 Impeller shader include 编码问题；从已经存在且核对指向本项目的 V: 映射运行后通过，未改第三方 shader。构建继续使用正式脚本的 ASCII 映射流程。测试滚动后需 pumpAndSettle 完成布局再点击，不能对仍在屏外的入口作无效点击并误判业务失败。
- ADB 当前存在无线连接设备；本次未安装、未操作设备或用户账号，登录后开通/付款和系统 WebView 视觉仍未实测。
### 1.2.5 发布资源异常与防回归

- 首次正式脚本报告构建成功（422.1 秒），包名/ARM64/签名/对齐均通过，但额外 ZIP 核验发现 APK 完全缺少 assets/flutter_assets；磁盘对应 release/flutter_assets 仅剩空目录。该包 35,116,361 字节，被拒绝交付并移至 build/rejected/membership-1.2.5-no-assets.apk。已从回退恢复有效的 1.2.4 根目录 APK 和校验值，确保重建失败时也保留可用包。
- 本次先在既有 V: 映射测试，又由 V: 脚本创建临时 X: 映射；构建依赖文件中混用物理 D: 与 X: 路径。当前证据不足以断言是哪一项工具缓存导致资源消失，不把签名有效或 Gradle 成功等同于包内容完整。只清理失败版本的 build/app/intermediates/flutter/release 和对应 .dart_tool/flutter_build/3d6fdde7bb4da44d68aa5e88ab9dcbb1，不清理全局缓存、源码或回退。
- 发布脚本新增 Assert-FlutterAssets：交付/清理旧包前检查非空 AssetManifest.bin，并将 APK MaterialIcons 字体长度与当前 Flutter SDK 原始字体比较。用完整 1.2.4 包和实际缺资源的失败包验证，前者通过、后者明确拒绝。该检查避免以后再次出现“签名/ABI 正常但资源为空”仍删除旧包的情况。
- 按已有打包复盘，后续从同一个 ASCII 映射目录以 Java 17、离线 Gradle assembleRelease、明确 android-arm64 与 tree-shake-icons=false 重建，避免嵌套映射和不必要的依赖检查；交付仍执行相同包名、版本、架构、资源、证书、对齐及哈希检查。
- 离线首次重建进一步明确报错：build_hooks 仍试图创建已经撤销的 X: 根目录；本项目 .dart_tool/hooks_runner/objective_c/.../input.json 中确有 X: 绝对路径。仅删除 release 输出及一个 build ID 不足以清理该缓存。本次已清理本项目 .dart_tool/hooks_runner 与 .dart_tool/flutter_build，并在同一 V: 目录重新 pub get --offline 后重建；未更新锁定依赖或删除全局 Pub/Gradle 缓存。该错误证明旧盘符缓存存在，但不单独证明首次资源丢失的全部原因。

### 1.2.5 最终发布校验

- 同一 V: ASCII 路径、Java 17、离线 Gradle assembleRelease 最终构建成功（56.6 秒），日志 build/logs/release-1.2.5-membership-offline-final.log；明确 android-arm64、版本 1.2.5 / code 42、tree-shake-icons=false，未生成 debug 或其他包名的安装包。
- 已用发布脚本新增资源断言再次检查最终包：assets/flutter_assets 共 14 项，AssetManifest.bin 存在且非空；MaterialIcons 完整字体 1,645,184 字节，与 SDK 原字体一致。此前的缺资源包未交付。
- AAPT：包名 ycoo.net.php、versionName 1.2.5、versionCode 42、minSdk 24、targetSdk 36、非 debuggable；APK ZIP 原生库仅 arm64-v8a。APK v2 签名验证通过，证书 SHA-256 为 3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975，匹配原 BKS；16 KiB zipalign 检查通过。
- 正式包：源社区_v1.2.5.apk，36,086,014 字节；SHA-256 A7E17A1803D0094A62878DFA49531A54D8F84FED4292CC54D95807F69E072A57。构建产物与交付文件哈希一致，release.sha256 同步；完整验证后删除根目录旧包，仅保留 1.2.5。有效 1.2.4 APK 与源码仍保存在 build/rollback；构建/分析/测试日志统一存 build/logs。
- 23 项定向回归通过；common.dart、home.dart 与路由测试分析无 error/warning，仅 home.dart 11 项既有风格 info。发布脚本经 PowerShell AST 解析无错误，资源断言用有效旧包、实际缺资源包及最终完整包检验，正确接受/拒绝。
- 没有安装到设备、使用真实账号开通或付款，也没有自动提交/推送源码；实际系统 WebView 登录保持、登录后的插件交互和付款仍需手机验收。


## 1.2.6+43 网页滚动与“我的”功能完整性（2026-11-03）

- 用户明确“长按水波纹”指普通按钮按压涟漪。本次不改液态玻璃底栏长按水珠逻辑，沿用 1.2.4 的导航交互。修改前工作区已有未提交 1.2.5 内容，已保留；对应源码快照在 build/rollback/web-my-pages-1.2.5-source.zip，原签名 1.2.5 APK 在 build/rollback/web-my-pages-1.2.5.apk。
- WebView Android 4.14.1 默认 Texture Layer Hybrid Composition。Flutter 官方说明该模式快速滚动可能卡顿（https://docs.flutter.dev/platform-integration/android/platform-views）；插件文档说明原生 Hybrid Composition 有 Flutter 侧性能权衡（https://pub.dev/packages/webview_flutter_android）。BrowserPage 现在显式使用 Android 原生合成，仅作用于网页宿主；顶栏改为实色 AppBar，移除不承载正文的 sigma=20 模糊；WebViewWidget 在 State 初始化后复用，重复进度值不再触发 setState。没有启用要求 Android 14+/Vulkan 的实验性 HCPP，没有全局降低刷新率或改网站脚本。
- 当前设备安装 1.2.5，系统 WebView 为 158.0.8127.2；读取 gfxinfo 返回应用处于后台 frozen，不能据此测量繁星页面帧率或断言全部卡顿来自客户端。上述是已确认的宿主合成/绘制路径优化；官网页面脚本、实际高刷表现和切换合成方式的设备收益仍需前台实测。

### “我的”逐项审计与路由（1.2.6；访客/任务/勋章由1.2.7纠正）

| 入口/功能 | 处理 | 当前实现依据与边界 |
| --- | --- | --- |
| 头像/我的空间、个人资料展示、个人帖子分栏 | 保留专用原生主页 | 已有 API + 匹配 UID 的公开页面模型、布局及账号隔离回归 |
| 我的帖子、我的收藏 | 保留原生列表 | 已有真实模块、帖子链接与权限处理 |
| 我的好友、日志、相册、圈子、心情、最近访客、粉丝 | 官网 | 此前只是通用 HTML/表单；无法完整保留社交弹层、评论/编辑、上传与管理脚本 |
| 消息分类与私信列表 | 保留原生入口/列表 | 已有独立列表和分类；私信会话/发送页面改为官网，保留站点完整编辑与消息流程 |
| 资料设置菜单 | 保留原生菜单，内部资料/密码安全/认证/头像/绑定走官网 | 条件字段、验证、裁剪上传及 OAuth 不以通用表单冒充完整支持；绑定地址仍从服务器发现，站外绑定保留离站确认 |
| 最近访客、邀请、繁星、任务、勋章、道具、空间背景 | 官网 | 旧页面依赖插件或 Discuz 脚本/异步操作；保留原站完整流程 |
| 积分“我的”与“记录” | 保留原生 | 余额和币种来自已核实的账户 profile；记录保留原有只读渲染 |
| 积分转账/充值 | 官网，嵌入原有分栏 | 校验、确认、支付流程交由站点；不自动提交、不保留重复顶栏 |
| 推广二维码、小黑屋 | 保留原生 | 已有 UID 推广编码和真实服务端记录解析 |
| 个性化、历史、夜间模式、设置/缓存/自动签到 | 保留原生 | 本地设置和已有专用业务逻辑，无需网页 |
| 社区服务：签到/排行、标签等普通只读列表 | 保留原生 | 已有专用签到与排行或只读内容解析，未据此宣称所有登录业务已实测 |
| 社区服务：农场、云盘、圈子、淘专辑 | 官网 | 独立游戏、Vue/第三方存储上传或完整管理操作不能由通用解析器提供；既有基础原生云盘代码保留，默认入口改为官网 |
| 门户原站、电脑版、注册/验证 | 官网 | 明确选择原站/电脑版时不再被通用原生页面强制加 mobile=2；注册/验证沿用原站 |

- 共用 requiresSiteWebView 精确匹配 https://ycoo.net:443、无 userinfo、路径和业务参数，不对所有插件或任意包含同名字符串的链接一刀切。普通通知、积分记录、原生帖子/用户主页、已完成的关注/好友/招呼/拉黑确认及主题购买保留；ProfilePage 的内容详情和动作统一调用既有 openWeb，以避免直接构造 NativeSitePage 绕过新路由。BrowserPage 继续共享系统 Cookie、保留协议/来源限制、错误重试和用户确认；不读取或导出账号凭据。
- 普通按钮的 HapticSplashFactory 改为 NoSplash 的子类，不再创建 InkSplash 的扩散/淡出动画；仍在 confirm 时触发已有全局触感，沿用防重复、关闭开关和取消手势不振动的规则。保留静态按压/焦点反馈，无须逐个按钮加覆盖配置。
- 回归采用安装依赖提供的 WebView 平台接口假实现，检验 Android 合成参数、WebView 实例稳定、内嵌页面不重复顶栏、错误重试和非法 URL 拒绝；不以这些组件检查冒充真机网页 FPS。新增路由完整矩阵、外域/端口/userinfo 隔离、积分分栏及绑定站外确认检查，保留个人主页/触感/主题购买等定向回归；结果与 APK 校验完成后补充。


### 1.2.6 定向验证与复盘

- browser / link_routing / account_features / profile / ui_regression / native_site 六个定向文件共 58/58 项通过，日志 build/logs/test-1.2.6-web.log。涵盖原生合成参数、同一 WebViewWidget 实例、无 BackdropFilter、内嵌官网单顶栏、错误重试、非法协议拒绝、全部官网路由和伪装地址隔离，以及积分余额/记录、私信收件人、绑定站外确认、普通按钮无涟漪/触感去重与取消不振动、主页/原生购买等原有回归。
- 原绑定入口测试只断言标签出现，未发现假 Site 将整数 mobile=2 直接传给 Uri.replace 后抛异常，页面实际停留在“读取失败，点击重试”。本次让假请求按真实 Dio 的查询参数编码规则转为字符串，并明确断言已取得可点击入口、同源打开官网、站外显示离站确认；不是将业务失败改成成功。
- WebViewPlatform 的 setter 不允许设回 null；假平台仅在原平台非空时恢复。NoSplash 的手工生命周期测试需先向 Material 注册再取消，真实按钮手势已有独立回归。测试工具误用不修改生产业务以迁就测试。
- 必要静态分析和包体核验结果在正式构建后补充。版本、关于、README、功能对照和两份开发文档同步 1.2.6+43。回退快照包含当前修改前的所有受影响文件，保留 1.2.5 未提交源改动；不自动提交或推送。

- 离线打包复盘：本机 Flutter Gradle 插件实际从 android/local.properties 的 flutter.versionName / flutter.versionCode 读取版本，-Pflutter-version-name / -Pflutter-version-code 并不能替代这两个值。首轮 1.2.6 源码构建的 Manifest 仍为 1.2.5+42，被额外版本核验拒绝交付；已只同步被忽略的 local.properties 至 1.2.6 / 43 后重打包。以后手动离线构建必须先按 pubspec 同步这两项，最后仍以 AAPT 结果为准；正常 flutter build 会自行同步。没有改变包名、签名或升级依赖。


### 1.2.6 最终发布校验

- 最终离线 Gradle assembleRelease 构建成功（38.1 秒），日志 build/logs/release-1.2.6-web-final.log。AAPT 确认包名 ycoo.net.php、versionName 1.2.6、versionCode 43、minSdk 24、targetSdk 36、非 debuggable；APK ZIP 原生库仅 arm64-v8a。未生成其他 ABI、debug 签名或其他包名的安装包。
- Flutter 资源 14 项完整，AssetManifest.bin 非空；MaterialIcons 字体 1,645,184 字节，与 SDK 原字体一致。APK v2 签名通过，证书 SHA-256 为 3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975，匹配原 BKS；16 KiB zipalign 校验通过。
- 正式包：源社区_v1.2.6.apk，36,086,014 字节，SHA-256 41D34C97AB643E8F4831137E08396528A23F6EC04FDCE1F183ADA7D626889071。交付包与构建产物哈希一致，release.sha256 已同步；全部核验后删除根目录旧包，根目录仅保留 1.2.6，1.2.5 回退 APK 和修改前源码仍在 build/rollback。
- 58/58 项定向回归通过。受影响源码与测试定向分析无 error/warning，仅 20 项既有风格 info；日志 build/logs/analyze-1.2.6-web.log。没有重复运行无关测试或改动玻璃库/底栏长按交互。
- 源码保留在当前工作区，未自动提交或推送；没有安装到手机、切换用户设备前台界面或执行真实账号写入。合成切换的实际 FPS 收益、Android 7–9 的 Flutter 侧合成代价、官网登录后各项操作及支付/上传仍未做设备验收，不能把组件与静态包检查称为真机流畅性证明。


## 1.2.7+44 小黑屋解码与原生页面范围纠正（2026-11-03）

- 用户指出最近访客、任务中心、我的勋章可以原生渲染，并要求移除更改头像和空间背景。1.2.6 将这些只读/简单内容与复杂脚本流程一起分到网页，判断范围过大。本版明确恢复三处原生入口；以后不能仅因页面含 JavaScript 或需要登录，就将简单列表整体判定为“原生困难”。先区分内容展示、详情弹窗与真正依赖脚本的业务写入。
- 修改前未提交的 1.2.5/1.2.6 改动已保留；源码快照 build/rollback/account-native-1.2.6-source.zip（lib/test/docs/tool 等，含之前未提交工作），原签名 APK build/rollback/account-native-1.2.6.apk。没有回滚网页宿主性能优化、普通按钮无涟漪或其他已接受改动。

### 小黑屋真实失败原因与修复

- 当前只读 GET https://ycoo.net/forum.php?mod=misc&action=showdarkroom&ajaxdata=json 返回 HTTP 200、Content-Type application/json，但 data 的 UID 键形如 {28432:{...}}，不是标准 JSON。Dio 自动 JSON 解码先抛出异常，异常没有 response 被 Site.request 误报为“连接源社区失败”。用相同真实响应和 Content-Type 的回归，在修改前已经复现用户看到的完全相同提示；不能把这种失败当作 DNS、代理或线路问题。
- 仅此接口切换为文本读取，由 Site.darkroom 负责处理已观察到的裸数字对象键，再交给严格 jsonDecode；完整匹配 JSON 字符串 token，保留原因文本中的 {123:、反斜杠及转义引号，绝不 eval 服务器文本。其他 API 的自动解码、证书、Cookie 来源和会话代次保护保留。
- 现场再读 cid=1，末页实际返回 {"message":"0|1","data":[]}；现在同时接受记录映射和真正的空数组末页。坏格式明确提示数据异常，不伪造空列表、不掩盖真实网络失败。列表按 CID 去重、续页和停止条件保持；不执行账号写入。

### 原生页面与入口

- 最近访客精确排除出网页路由，NativeSitePage 将页面实际返回的 .comiis_userlist01 记录渲染为 SiteAvatar 40dp + 姓名/说明的原生 ListTile，点击打开原生个人主页。UID 从合法同源 profile 链接读取，不从头像或任意链接猜身份；图片仅接收同源地址。公开 UID=1 的好友列表片段仅用于验证共享列表排版，不冒充当前登录用户的真实访客数据；未登录的“我的访客”现场响应仍要求登录。
- 任务中心恢复既有原生内容/标准表单/顶部分栏渲染，入口名称统一“任务中心”。现场游客任务请求跳转登录，未伪造认证后的任务数据或接口；任务领取/奖励等写入只由真实返回的表单和用户确认驱动，登录后操作未验收。
- “我的勋章”使用当前 UID 的 profile API，验证 space.uid 和会话代次后读取既有 UserProfile.medals，兼容实际存在的空字符串/空集合数据。现场公开 profile(uid=1) 当前有 15 枚勋章，字段为 name/image/description/medalid。复用已经验证的资料契约，不依赖登录后网页 JavaScript；跨账号或旧响应不能回写。
- 勋章中心的实际 HTML 中，弹窗脚本只展示名称、图片和说明；改为原生紧凑勋章列表和可滚动详情对话框。图片显示 40dp、解码限制 144px，列表按可见元素加载，不把所有小图放大为整屏原图。只替换已识别的详情弹窗；其他真实表单与非展示内容仍保留。官网现有“勋章中心/我的勋章”分栏在原生页内切换。
- 主“我的”移除更改头像和空间背景；资料设置移除重复“修改头像”入口。头像、空间背景的既有展示数据保留，不删除任何账号数据；其他功能入口保持当前路由。
- 版本、关于、README、功能对照与两份开发文档同步 1.2.7+44。回归与正式包结果见下方。打包沿用已成功的 V: ASCII 路径离线流程，先按 pubspec 同步忽略的 android/local.properties 版本，避免前次仅传 Gradle 参数却仍带旧 Manifest 版本的问题。


### 1.2.7 定向验证

- site / link_routing / account_features / native_site 四个定向文件共 48/48 项通过，日志 build/logs/test-1.2.7-account.log。真实非标准 JSON 响应与相同 Content-Type 在修复前复现“连接源社区失败”，修复后可读取 8 条记录及下一 CID；覆盖原因文本中的数字键片段/反斜杠/转义引号、实际空数组末页、坏格式拒绝、原生分页和空状态。
- 原生访客/任务/勋章组件检查确认没有 BrowserPage，访客头像为 40dp；勋章中心详情使用原生 AlertDialog。当前账号勋章覆盖已拥有/空字符串集合、错误 UID 及过期会话拒绝；沿用旧的空集合模型修复，不再强制将 medals 转成 List。根“我的”三处入口路由、我的勋章 action=log，以及主菜单/资料设置的头像入口移除均有回归。
- 公开原站夹具仅保留所需页面片段，不含 Cookie、登录凭据、脚本或会话字段；访客排版夹具来自公开好友列表，不宣称是认证用户访客样本。任务中心内容组件使用合成的标准 HTML 说明做渲染检查，不推测未登录时无法读取的任务领取接口。没有真实账号写入或安装真机。


### 1.2.7 最终发布校验

- 固定 V: ASCII 路径、Java 17、离线 Gradle assembleRelease 构建成功（57.1 秒），日志 build/logs/release-1.2.7-account.log。打包前已同步 local.properties 的 1.2.7 / 44；AAPT 确认包名 ycoo.net.php、versionName 1.2.7、versionCode 44、minSdk 24、targetSdk 36、非 debuggable，ZIP 原生库仅 arm64-v8a。
- Flutter 资源 14 项、非空 AssetManifest.bin 和完整 MaterialIcons 字体 1,645,184 字节校验通过；APK v2 签名通过，证书 SHA-256 3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975 匹配原 BKS；16 KiB zipalign 校验通过。
- 正式包源社区_v1.2.7.apk，36,086,014 字节；SHA-256 09FA36C0604BF37CA14A72DC9748A03894D5B04010F20B3B30E7292A8D46D740。交付包与构建产物一致，release.sha256 同步。1.2.6 回退包哈希与旧正式包一致（41D34C97AB643E8F4831137E08396528A23F6EC04FDCE1F183ADA7D626889071），完整核验后根目录只留 1.2.7。
- 48/48 项定向回归通过；受影响源码/测试分析无 error/warning，有 24 项风格 info，日志 build/logs/analyze-1.2.7-account.log。没有修改全局网络/代理/证书、其他项目或玻璃库，没有更新依赖。
- 未自动安装、提交或推送。小黑屋协议和公开勋章资料已实时只读核对；真实登录账号下的访客名单、任务领取/奖励、勋章操作和最终手机视觉仍未验收。组件测试与静态 APK 检查不能替代这些设备/账号验收。


## 1.2.8+45 任务分栏、勋章按钮与访客误报修复（2026-11-03）

- 当前工作区包含此前未提交工作，全部保留；修改前源快照 build/rollback/account-layout-1.2.7-source.zip，原签名 1.2.7 回退包 build/rollback/account-layout-1.2.7.apk。只修改用户指定的四处布局/提示，继续使用原账号、包名和签名。
- 任务中心原通用规则把超过三个分栏设为可滚动并左对齐，导致四栏挤在左边。现在仅对同源任务页面的四个分栏使用固定等宽、TabAlignment.fill，横向内边距 4dp；其他页面继续沿用原适配规则。标签字体继承实际主题，大字号允许多行并增加栏高，保留完整辅助功能文字，不以压缩字号强塞内容。
- 勋章“立即申请”从已返回 HTML 的真实链接提取，不手工构造申请接口。支持普通 href 和脚本弹窗中包含的同源 URL 字面量；只接受 home.php?mod=medal 的业务地址，拒绝伪装域名/userinfo，已有 medalid 时核对当前行 ID。原查询参数和表单 hash 原样保留；只在用户点击后沿既有原生页面流程导航，不执行网页 JavaScript 或自动提交。
- 每行申请按钮置于右侧 104dp 固定列，名称/说明与按钮在同一行，内容长短不改变按钮横坐标。复用 ListTile，在标题区域使用可伸展文字列和按钮列，避开 ListTile.trailing 对高度的限制；大字号时按钮自然增高、文字可换行。无申请入口的已拥有勋章不伪造申请按钮，原生详情弹窗保持。
- 访客页“此插件仍可能包含未适配的脚本操作”是误报。现场已有 HTML 的 #comiis_followmod 隐藏弹窗包含 popup.close/comiis_list_followmod；脚本收集发生在隐藏节点/网页外壳清理前，所以已从原生页面移除的节点仍被计入。现在警告只统计清理后仍在内容树中的实际操作，再排除已有原生替代的行/弹窗；真实可见未知脚本仍提示，不整页屏蔽。
- 小黑屋仅在每条 AppSectionCard 增加 bottom=8dp，不改共享卡片或其他页面间距。原 CID 分页、解码、资料入口及空状态保持。
- 新回归在修改前复现访客误报和任务四栏左挤；修复后验证 320dp 窄屏、任务 1/2 倍字号四栏中心等距及标签完整高度、申请按钮 1/2/3 倍字号同列同宽及文字完整、实际链接参数保留/非法目标拒绝、只读导航不发生 POST，以及小黑屋可见卡片间隙为 8dp。申请链接夹具为合成脱敏数据，不宣称已执行真实账号申请。最终定向测试与 APK 校验见下方。

### 1.2.8 最终发布校验

- 32/32 项定向回归通过，日志 build/logs/test-1.2.8-layout.log；受影响源码和测试的定向分析无 error/warning，26 项风格 info，日志 build/logs/analyze-1.2.8-layout.log。git diff --check 通过。
- 沿用已有 V: ASCII 路径、Java 17 与离线 Gradle，assembleRelease 成功（53 秒），日志 build/logs/release-1.2.8-layout.log。构建前同步 local.properties 的版本 1.2.8 / 45，未更新依赖或全局配置。
- AAPT 确认包名 ycoo.net.php、versionName 1.2.8、versionCode 45、minSdk 24、targetSdk 36、非 debuggable；ZIP 原生库仅 arm64-v8a。14 项 Flutter 资源、非空 AssetManifest.bin、完整 MaterialIcons 字体 1,645,184 字节通过检查。原证书 SHA-256 3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975 与 v2 签名通过，16 KiB zipalign 通过，记录 build/logs/verify-1.2.8-layout.log。
- 正式包源社区_v1.2.8.apk，36,086,010 字节；SHA-256 6A4FDE64EEB7C850A6F01BF53B82977C3EDD62B419985D51134F7EFC0FA5E866。交付包与构建产物哈希一致，release.sha256 已同步。1.2.7 回退包哈希与旧正式包一致（09FA36C0604BF37CA14A72DC9748A03894D5B04010F20B3B30E7292A8D46D740），全部核验后根目录只保留最新 1.2.8 APK；旧包与修改前源码快照仍在 build/rollback。
- 没有自动安装、提交或推送，没有真实账号写入。四等分和按钮位置属于组件测试验收，不能替代手机视觉检查；登录账号的访客数据、任务操作和勋章申请流程仍需真实账号/设备验收，不能将合成夹具的只读导航测试视为真实申请成功。

### GitHub 同步范围（2026-11-03）

- 用户明确要求推送 GitHub；同步 origin（Chengeeker/Ycoo-Community）的 main 分支，包含此前未提交的 1.2.5–1.2.8 累计修复、脱敏测试夹具、构建资源校验和开发文档。
- 提交前 fetch 确认 HEAD 与 origin/main 均为 d51d8bd，没有远端分叉；沿用 1.2.8 已完成的定向测试和正式包静态检查，不因仅提交/推送重复构建。
- 签名/本地配置、登录信息、构建日志/回退文件和 APK 保持忽略，不加入 Git；本次只同步源码，不创建 GitHub Release。真实设备/账号验收边界沿用上述发布记录。

## 1.2.9+46 设置分组对齐与阅读设置统一（2026-11-03）

- 修改基线为已推送的 1285753（1.2.8+45），工作区原本干净。修改前正式包与源码快照分别保存在 build/rollback/settings-1.2.8.apk、build/rollback/settings-1.2.8-source.zip；保留原包名、签名和 arm64-v8a。
- 全局检索页面的分组标题/卡片及共享标题调用，发现设置页 4 处和个性化页 5 处共用 _SettingsSectionTitle，原 16dp 起始缩进只对齐图标列，未对齐选项文字。共享标题默认起始缩进改为 56dp（卡片内 16dp + 24dp 图标 + 16dp 间隔）；明暗模式的 RadioListTile 控件实际占位不同，使用 72dp，组件测试核对实际文字边界，不用图标可见尺寸猜单选控件占位。其他页面的资料字段、原生正文标题和网格栏目不套用列表文字缩进。
- 阅读与社区功能沿用已有 AppSectionCard 与 ReviewSwitchTile，补齐 16dp 页面边距、24dp 卡片圆角和四行图标，选项文字共用同一列；没有新造外观组件或改动共享卡片/开关行为。
- 自动签到从设置首页移入阅读与社区功能，沿用 autoSignIn 键、默认关闭、原来的说明和 Settings.set；不重置已保存值、不在进入页面或移动开关时触发签到。实际后台签到的并发、会话和关闭保护代码未变，原自动签到回归保留。
- 关于窗口补上 assets/site-icon.png 原图，补入 pubspec 资源清单，显示 48dp、解码缓存宽度 144px，避免按原始大图长期解码；不改动原 PNG 或启动器图标，不依赖远程图片请求。名称和版本信息保持原生 AboutDialog 流程。
- 定向测试在修复前复现标题错位；修复后 16/16 项通过（settings_ui_test / reading_tools_test），覆盖设置和个性化的 320dp 宽度、深浅色、1/2 倍字号下全部 9 个标题边界，阅读设置在 320dp/2 倍字号的卡片归属/文字列/滚动、自动签到原值和切换持久化、关于图标资源加载，以及原签到并发/账号切换/关闭保护。日志 build/logs/test-1.2.9-settings.log。
- 定向分析无 error/warning，有 11 项既有风格 info，日志 build/logs/analyze-1.2.9-settings.log。仅使用组件与静态检查，不宣称已完成真机视觉或真实账号签到验收；正式包校验结果见下方。

### 1.2.9 最终发布校验

- 固定已有 V: 映射、Java 17 和离线 Gradle assembleRelease 构建成功（57 秒），日志 build/logs/release-1.2.9-settings.log。AAPT 确认包名 ycoo.net.php、versionName 1.2.9、versionCode 46、minSdk 24、targetSdk 36、非 debuggable；ZIP 原生库仅 arm64-v8a。
- Flutter 资源 15 项，AssetManifest.bin 非空、MaterialIcons 完整字体 1,645,184 字节校验通过。新增打包的 site-icon.png 为 924,494 字节，SHA-256 9D50CDD9B4F9ED1667F3D039175DABC4FCF3D2935687D4ABB043CD5CEF58BCAD 与项目原始 PNG 一致；未修改启动器图标或原图文件。
- APK v2 签名及原证书 SHA-256 3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975 校验通过；16 KiB zipalign 校验通过。完整记录 build/logs/verify-1.2.9-settings.log。
- 正式包源社区_v1.2.9.apk，37,010,686 字节，SHA-256 8238EDB1A49AE33A420B55499E831C660DCB6569383F031697B1B570A212E664；交付文件与构建产物一致，release.sha256 同步。核对 1.2.8 回退包与旧正式包哈希均为 6A4FDE64EEB7C850A6F01BF53B82977C3EDD62B419985D51134F7EFC0FA5E866 后，根目录仅保留最新包；回退包和源码快照留在 build/rollback。
- 16/16 定向测试通过，定向分析无 error/warning（11 项风格 info）。没有更新依赖、改变网站请求/签到逻辑或全局配置。未安装真机、执行真实账号签到、提交或推送；组件布局检查与静态包检查不替代真机视觉验收。

## 1.2.10+47 标题对齐基准纠正（2026-11-03）

- 用户明确：小标题应与整行内容起始处、即图标左侧对齐，而非文字左侧。1.2.9 将“内容左侧”理解成文字列，属于需求理解错误；1.2.9 的文字列对齐记录和测试不作为后续设计规范。
- 设置页 4 处和个性化页 5 处统一使用卡片内起始 16dp 的标题缩进，移除 56dp 文字列缩进及单选组 72dp 特例，不再为单选组另设标题偏移。标题与图标/首个单选控件整体的起始边界一致，保留与卡片外边缘的 16dp 间距。
- 保留 1.2.9 的阅读设置卡片/图标、自动签到入口移动和原状态、关于原始应用图标；没有改动网站请求或签到逻辑。已有未提交源码全部保留。修改前快照 build/rollback/settings-align-1.2.9-source.zip，原签名回退包 build/rollback/settings-align-1.2.9.apk。
- 回归改为比较标题与实际图标/单选控件左边界，并明确断言距离卡片边缘 16dp，防止再次用文字列作为预期。10/10 项设置组件检查通过，覆盖 320dp、深浅色、1/2 倍字号及原阅读设置/自动签到状态/关于图标；日志 build/logs/test-1.2.10-alignment.log。真机视觉验收仍未进行，正式包校验见下方。

### 1.2.10 关于窗口按 Review 样式补齐（同轮追加）

- 用户在本轮标题修正打包期间指出关于窗口仍很草率，要求参考 Review，特别是图标圆角。只读核对 Review 当前 settings_view.dart 的 _showAboutDialog（项目 3.14.7+245），其图标 72dp / 圆角 18dp、窗口圆角 20dp、内容内边距 20/24/20/16、居中名称与版本标签、底部居中圆角按钮；没有修改 Review 项目。
- 源社区移植相应布局参数，使用原图的运行时 ClipRRect 圆角展示、72dp 图标和 216px 解码缓存，原 PNG 文件和启动器图标均不修改。窗口保留真实应用说明和开源许可入口，不复制 Review 专有功能文案。
- 标题/版本使用居中 Wrap 以兼容 320dp 与两倍字号，内容可滚动，操作区保留关闭和原生许可页。字体样式从当前主题派生，保留字体设置与系统缩放。仍由原设置行提供一次点击触感，不重复添加触感回调。
- 同一 1.2.10+47 的标题修正中间包尚未交付；原中间包已保留在 build/rollback/about-1.2.10-align-only.apk，源码快照为同目录 about-1.2.10-align-only-source.zip，正式交付以本轮关于窗口更新后的重建包为准。
- 更新后 13 项正式设置组件回归及 1 项本地渲染检查全部通过，日志 build/logs/test-1.2.10-about.log。核对圆角、72dp 尺寸、原始资源、居中位置、窄屏深浅色/两倍字号、关闭及许可页可达，标题仍对齐图标左侧。
- 本地渲染图 build/evidence/about-1.2.10/light.png 和 dark-large.png 已实际打开检查。渲染使用 Windows 中文字体模拟，仅供布局检查，不是 Android 真机截图；早期预览中未继承主题字体导致测试 Ahem 方框，已改为派生主题字体并重渲染。临时预览脚本/图片位于忽略的 build 目录，不加入源码仓库。

### 1.2.10 最终交付校验（包含关于窗口更新）

- 最终源码经定向分析无 error/warning（11 项既有风格 info），13 项设置回归和 1 项本地渲染检查通过。最终日志 build/logs/analyze-1.2.10-about.log、test-1.2.10-about.log；不以 Windows 组件渲染代替 Android 真机视觉验收。
- 使用同一 V: 映射、Java 17、离线 Gradle assembleRelease 重建成功（57 秒），日志 build/logs/release-1.2.10-about.log。AAPT 确认 ycoo.net.php / 1.2.10 / 47、minSdk 24、targetSdk 36，非 debuggable，原生库仅 arm64-v8a。
- 15 项 Flutter 资源、非空 AssetManifest.bin、完整 MaterialIcons 字体 1,645,184 字节通过检查；原图 PNG 长度 924,494 字节及 SHA-256 9D50CDD9B4F9ED1667F3D039175DABC4FCF3D2935687D4ABB043CD5CEF58BCAD 与项目原始文件一致。圆角仅在 UI 中裁剪，没有重绘或修改原文件。
- APK v2 签名和原证书 SHA-256 3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975 一致，16 KiB zipalign 通过；完整记录 build/logs/verify-1.2.10-about.log。
- 最终包源社区_v1.2.10.apk 为 37,010,686 字节，SHA-256 6F64A2F18A96432B9169F5F6D9AC25DA618779B661E2C0E3F68647DA68B13C47，交付包与构建产物一致，release.sha256 已更新。它替换了尚未交付的同版本标题修正中间包（SHA-256 AF7D66CFE2183270245D97E55850077266645A75E239F634719181E3F780EF07）；中间包和 1.2.9 回退包均已核验并留在 build/rollback，根目录仅保留最终最新包。
- 开发文档、README、功能对照和关于版本同步。未更新依赖、修改 Review 源码或全局配置，没有安装真机、执行真实账号操作、提交或推送。

## 1.2.11+48 关于文案简化与开源仓库入口（2026-11-03）

- 用户要求去掉产品界面中的“复用自 Review”，补上开源仓库地址。设置行副标题只显示版本号，关于说明移除技术复用文案；保留现有开源许可入口与仓库 LICENSE，不把技术说明继续放在主界面。
- 关于窗口新增“开源仓库”卡片，展示 github.com/Chengeeker/Ycoo-Community，点击使用既有 openWeb 打开 https://github.com/Chengeeker/Ycoo-Community；地址已核对当前 origin 远端。复用现有外链确认、复制及浏览器流程，不引入新依赖或外链例外。
- 保留圆角图标、名称/版本标签、图标列标题对齐及自动签到入口调整。已有未提交改动全部保留，修改前源快照 build/rollback/about-link-1.2.10-source.zip、原签名回退包 build/rollback/about-link-1.2.10.apk。
- 13 项设置组件回归及 1 项本地渲染检查通过，覆盖深浅色/320dp/两倍字号、设置和关于窗口无“复用自”或 Review 文案、显示完整仓库路径、点击进入现有外链确认且地址准确、许可页/关闭入口及已有布局。日志 build/logs/test-1.2.11-about-link.log。定向分析无 error/warning（11 项既有风格 info），日志 build/logs/analyze-1.2.11-about-link.log。
- 组件渲染图位于 build/evidence/about-1.2.11，已检查布局；使用桌面中文字体模拟，不能视作真机验收。正式包结果随后补充，不自动安装或推送。

### 1.2.11 最终交付校验

- 离线 Gradle assembleRelease 成功（1 分 2 秒），日志 build/logs/release-1.2.11-about-link.log。包名 ycoo.net.php、versionName 1.2.11、versionCode 48、minSdk 24、targetSdk 36，非 debuggable；ZIP 原生库仅 arm64-v8a。
- 15 项 Flutter 资源、非空 AssetManifest.bin、完整 MaterialIcons 字体 1,645,184 字节及原图 PNG 哈希均通过校验；原证书 SHA-256 3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975 / APK v2 签名通过，16 KiB zipalign 通过，记录 build/logs/verify-1.2.11-about-link.log。
- 正式包源社区_v1.2.11.apk，37,010,686 字节，SHA-256 C9EEDC94D89180E46DE8411914CCC4F125EEE8C6F64BE1928F0FFDF3F0E8AEAB；交付文件与构建产物一致，release.sha256 同步。1.2.10 回退包与旧正式包哈希一致（6F64A2F18A96432B9169F5F6D9AC25DA618779B661E2C0E3F68647DA68B13C47），全部检查后根目录仅保留最新 1.2.11 APK。
- 最终 13 项设置回归和 1 项本地渲染检查通过；定向分析无 error/warning（11 项风格 info）。未更新依赖、删除许可证文件、安装真机、执行真实账号操作、提交或推送。仓库按钮验证到准确的外链确认地址，未在测试中启动真实 GitHub 网页；静态和桌面组件检查不替代真机验收。

## 1.2.12+49 我的页设置图标右边缘对齐（2026-11-03）

- 用户要求“我的”页设置按钮与卡片右边框对齐。实际几何测量显示：320dp 下卡片右边缘 x=304，设置图标右边缘 x=308，向右多出 4dp。
- 仅在 MyDashboardPage 的 ReviewFrostedAppBar 设置 actionsPadding.end=4，将可见设置图标右边缘移到卡片右边框；复用现有 actionsPadding 参数，不修改共享顶栏、卡片边距或 IconButton 的内部布局/点击范围。
- 修改前保留原签名 1.2.11 回退包 build/rollback/dashboard-align-1.2.11.apk 和完整工作区源码快照 dashboard-align-1.2.11-source.zip。此前未提交的设置/关于等工作全部保留，不回滚已接受的改动。
- 新增几何回归在修复前复现 4dp 偏差，修复后验证 320/393dp、1/2 倍字号时图标与卡片右边缘一致、实际 IconButton 点击区域至少 48×48dp、点击可打开设置。my_dashboard_test 和 settings_ui_test 共 19/19 通过，保留统计缓存、旧会话拒绝、关于仓库入口/许可页及此前设置布局检查；日志 build/logs/test-1.2.12-dashboard-align.log。
- 同步版本 1.2.12+49。仅组件/静态检查，不宣称 Android 真机视觉验收；正式构建校验结果见下方。

### 1.2.12 最终交付校验

- 离线 Gradle assembleRelease 成功（50 秒），日志 build/logs/release-1.2.12-dashboard-align.log；AAPT 确认 ycoo.net.php / versionName 1.2.12 / versionCode 49、minSdk 24、targetSdk 36、非 debuggable，原生库仅 arm64-v8a。
- 15 项 Flutter 资源、非空 AssetManifest.bin、完整 MaterialIcons 字体 1,645,184 字节和原始图标哈希校验通过；APK v2 / 原证书 SHA-256 3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975、16 KiB zipalign 全部通过，记录 build/logs/verify-1.2.12-dashboard-align.log。
- 正式包源社区_v1.2.12.apk，37,010,686 字节，SHA-256 36F0D490D138428F00761F26C3F63ADDBAA1A292919501CF0B6A41B003D528DB，与构建产物一致，release.sha256 同步。核对 1.2.11 回退包与旧正式包哈希一致后，根目录仅保留最新 APK，旧包和源码快照保留在 build/rollback。
- 19/19 定向测试通过，定向分析无 error/warning（11 项既有风格 info），日志 build/logs/analyze-1.2.12-dashboard-align.log。未改变共享组件、依赖、网站接口或全局配置；未安装真机、使用真实账号验收、提交或推送。组件几何和静态包检查不能替代真机视觉验收。

### 1.2.12 GitHub 同步范围（2026-11-03）

- 用户明确要求推送 GitHub。本次同步 origin（Chengeeker/Ycoo-Community）的 main，包含 1.2.9–1.2.12 累计的设置卡片/自动签到入口、标题图标列对齐、关于窗口及仓库入口、我的页设置图标对齐，以及对应测试和开发文档。
- 提交前 fetch 确认本地 HEAD 与 origin/main 均为 1285753119c2332d807ac81f4548ba5891d32702，没有远端分叉。核对现有 19 项回归、定向分析及 1.2.12 正式包静态检查；仅提交和推送不重复构建。
- APK 文件哈希与 release.sha256 一致；签名、本地配置、构建缓存、截图、日志和回退包均不加入 Git，不创建 GitHub Release。真机/账号验收边界保持上述记录。
