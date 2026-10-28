# 源社区开发文档

更新：2026-10-28。当前版本 1.0.2+30，包名 ycoo.net.php，仅 arm64-v8a。最低 Android 7.0（API 24）。

## 约束与基线

- 站点 https://ycoo.net/portal.php，为 Discuz 社区。真实页面和服务端响应是业务唯一依据。
- Review 参考 D:/App/Review 当前工作区（3.12.0+214，基础提交 c4f86b3，存在未提交修改）。只读参考，不改动源项目。
- 已阅读 Review 的 DEVELOPMENT.md、docs/REVIEW_UI_REUSE_SPEC.md、docs/RETROSPECTIVE.md 和综合文档相关章节。
- 直接迁移 AppTheme、HapticFeedbackUtil、ReviewFrostedAppBar、ReviewPageScaffold、ReviewCard、ReviewPreferenceTile、ReviewSwitchTile、ReviewChoiceTile、AppSectionCard。导航保留标准 M3 分支并复用 Review 的可选液态玻璃悬浮栏实现；第三方包及许可文件保存在 packages/liquid_glass_widgets。
- BKS 为用户指定的 D:/Download/backup/infinitycm.bks；密码只在被忽略的本机签名配置中使用，不写入文档或受版本管理的源码。签名中间文件排除版本管理；禁止回退 debug 签名。
- 图标使用站点原始文件，不裁切、不重新绘制、不缩放源图；Android 启动器的系统遮罩不由应用控制。
- 正式 APK 构建通过包名、ABI、签名和对齐校验后，只保留项目根目录的最新版本 APK；清理项目根目录其他 APK 及 previous-releases 下的旧 APK。校验失败时不执行旧包清理。构建脚本日志存放于 build/logs，项目根目录不留日志文件。

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
- [x] 应用图标使用用户指定的 D:/Download/图片/icon17.png 原始 PNG 字节；不重绘、不裁切、不缩放、不增加留白，launcher 输入和 assets/site-icon.png 保持与源文件一致。
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

- 文件：D:/App/源社区/源社区_v1.0.0.apk
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

- 按用户最新指定，将 D:/Download/图片/icon17.png 的原始字节复制到 assets/site-icon.png 及所有 mipmap-* / mipmap-nodpi 的 ic_launcher.png；未修改图片像素或尺寸。
- 源文件与每份应用图标资源 SHA-256：9D50CDD9B4F9ED1667F3D039175DABC4FCF3D2935687D4ABB043CD5CEF58BCAD。
- 已重新构建签名 ARM64 APK，构建后验证结果见更新的发布记录。




## 图标更新版 APK（2026-10-25）

- 按用户指定图片 D:/Download/图片/icon17.png 更新应用图标。源图、assets/site-icon.png 和全部 mipmap 密度及 nodpi 的 ic_launcher.png SHA-256 均为 9D50CDD9B4F9ED1667F3D039175DABC4FCF3D2935687D4ABB043CD5CEF58BCAD；仅复制原始字节，未改尺寸/像素。
- 新 APK：D:/App/源社区/源社区_v1.0.0.apk，30796041 字节；SHA-256 9E5BCC0163E0CD39D2CEC43141F1CC8282CAD03455B11880B248D74F38145FEE，release.sha256 已同步。
- 离线 Gradle assembleRelease 成功；aapt 确认包名 ycoo.net.php、版本 1.0.0、仅 arm64-v8a；apksigner V2 校验成功；zipalign 16 KiB 校验成功。
- 重建前的首版 APK 已自动保存在 previous-releases 作为回退。
- 这是静态包校验；未安装真机检查启动器显示效果。Android 会按设备密度显示图标，资源源图本身未缩放。



## 1.0.1+2 游客内容加载修复（2026-10-25）

- 将站点 HTML 请求的 User-Agent 改为经实测能返回原生解析器所需列表结构的桌面 Chrome UA；API 与登录状态处理不变。
- 版本升至 1.0.1+2；沿用包名 ycoo.net.php 与指定 BKS 签名，正式 APK 只包含 arm64-v8a。
- 真实站点对比记录：原 Android UA 的门户和导读响应分别约 71 KB / 170 KB，两个目标列表容器均缺失；Chrome UA 对应响应约 431 KB / 70 KB，分别包含门户 #portal_block_677_content 与导读 #threadlisttableid 下的 .kmlist 条目。请求均为未登录只读页面。
- 离线 Gradle assembleRelease 构建成功；AAPT 验证包名 ycoo.net.php、versionName 1.0.1 / versionCode 2、仅 arm64-v8a。APK 使用原 BKS 同一证书，签名 V2 校验和 16 KiB zipalign 校验成功。
- APK：D:/App/源社区/源社区_v1.0.1.apk，30,796,045 字节；SHA-256 B07748004CF01B867B48AE1C3E0F577FD710EAAA681042280C51DD9758CBF74C，与 release.sha256 一致。


## 1.2.0+5 Review 媒体体验复用（2026-10-25）

- 用户要求继续复用 Review 的媒体体验。版本升至 1.2.0+5，包名和 BKS 签名不变，仍只发布 arm64-v8a。
- 帖子图片入口增加按正文实例隔离的 Hero 标签；打开与返回都连接缩略图和当前大图。Gallery 使用 Review 同样采用的 extended_image 8.3.1，按需创建分页项，支持手势缩放、拖动和重试；不批量预载原图。
- 帖子正文的 video/source 标签和 mp4、m4v、mov、webm、m3u8 直链使用 video_player 2.14.1 原生播放；应用栏复用 ReviewFrostedAppBar，播放、进度、倍速、错误重试和后台暂停控件使用 M3。原始 video_player_android 版本为 2.12.2。
- 视频与图片共用站点请求头策略：站点 Cookie 仅附加到精确的 https://ycoo.net 来源，外部媒体只发送通用 User-Agent。拒绝非 HTTP(S) 和包含 userinfo 的媒体 URI；http://ycoo.net 自动切到 HTTPS。
- 不支持的 iframe/第三方嵌入播放器仍走原站；没有迁移微博账号、HDR、Live Photo、下载、质量选择或缩略胶片栏。站外资源还受其跨域策略和网络可达性影响。
- dart analyze --format machine lib：通过，无 error；显示的 info 级 const 建议来自现有设置页面。
- 离线 Gradle assembleRelease 成功（32 秒）；使用临时 ASCII 盘符、Java 17 与已缓存依赖，未生成 debug 包。
- APK：D:/App/源社区/源社区_v1.2.0.apk，34,220,760 字节；SHA-256 BD4995A3200D0152165DDBD59AEFBF3A1FE2F00BA1450BA2CADA83BF20924F95，release.sha256 已同步。
- AAPT 确认包名 ycoo.net.php、versionName=1.2.0、versionCode=5，native-code 仅 arm64-v8a；ZIP 的 lib/ 条目也仅有 arm64-v8a。
- apksigner v2 校验成功；签名证书 SHA-256 与指定 BKS 一致：3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975。zipalign -c -P 16 -v 4：Verification successful。
- 该次重建前相同版本但缺少中途错误反馈的 APK 已保存在 previous-releases/20261025-195332 作为回退。
- 本版本不运行自动化测试；未连接 ADB 设备，尚未在真机检查 Hero 时序、图片缩放和视频解码。包结构和签名检查不代表设备播放验收。


## 1.2.1+6 悬浮底栏间距调整（2026-10-25）

- 用户反馈四个入口在悬浮底栏中显得拥挤。将 Review 原先按三项导航使用的 2/3 屏宽改为 min(440dp, 可用屏宽 - 32dp)，两侧至少留 16dp；M3 与液态玻璃分支共用同一宽度计算，居中、圆角和高度保持原样。
- 排查首页、社区、导读、我的、设置、个性化和论坛列表的上下留白。主标签页按实际 M3/液态玻璃栏的可见高度计算悬浮遮挡净空；使用标准底栏时正文在底栏上方结束，改用 16dp 收尾。通过“我的”打开的设置/个性化页不显示根导航栏，末尾空白从 100dp 收到 24dp。页面顶部采用磨砂栏下方的状态栏 + 工具栏偏移，没有发现重复安全区，保留原有定位。
- dart analyze --format machine lib：通过，无 error；仅有既存设置页 const 建议。
- 离线 Gradle assembleRelease 成功（37 秒），仅构建 arm64-v8a。
- APK：D:/App/源社区/源社区_v1.2.1.apk，34,220,760 字节；SHA-256 DCF357E997BAFF4F45F7D3B8A723DA9069EFC7B85F422BE45385D881171EDAC3，release.sha256 已同步。
- AAPT 确认包名 ycoo.net.php、versionName=1.2.1、versionCode=6，native-code 和 ZIP lib/ 条目均仅 arm64-v8a。
- apksigner v2 校验成功；证书 SHA-256 与指定 BKS 一致：3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975。zipalign -c -P 16 -v 4：Verification successful。
- 最终构建前同版本的 APK 已保存到 previous-releases/20261025-205638。
- 本次没有运行自动化测试或进行真机布局验收；留白修改基于嵌套 Scaffold、导航覆盖区域和页面 padding 的代码检查。




## 1.3.0+7 首页功能对齐与留白/触感修复（2026-10-26）

- 基准为用户提供的 D:/Download/base.apk；只读取 Lua/JSON，不安装、不执行其更新脚本。功能对照及真实入口见 docs/CLIENT_PARITY.md。
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
- APK：D:/App/源社区/源社区_v1.3.0.apk，34,879,505 字节。SHA-256：F7AB20875BC7EEC6C77680BAD20BF63A074219B34CA6B8B3E334720DCDAB93D2，release.sha256 已同步。
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
- APK：D:/App/源社区/源社区_v1.3.1.apk，34,945,041 字节；SHA-256：DCBB04F5BE482F47A0AEB12A20AE75A004B9A25E9282373FC7541B7A825C8994。release.sha256 已同步。
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
- 对照 D:/App/Review/lib/features/detail/presentation/widgets/image_gallery_page.dart、core/widgets/in_app_browser_page.dart、core/services/link_routing_service.dart，以及 Android saveMediaToGallery 实现。Review 源项目只读。
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
- APK：D:/App/源社区/源社区_v1.4.0.apk，35,013,122 字节。SHA-256：CFC8177927866A8FAF2E30F3B1A4B2E4C512BC953F465C11941FA0121CC55CE8，release.sha256 已同步。
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
- APK：D:/App/源社区/源社区_v1.5.0.apk，35,210,446 字节；SHA-256：D2D514E3CCD94696BFCCBC189BB350DF72F4620381B906171CCC7BA560298D62，release.sha256 已同步。
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
- APK：D:/App/源社区/源社区_v1.6.0.apk，35,210,446 字节。SHA-256：6F7D4F51F0047226D00A39F7927A4940DBE2D562E6F1E9974F57F1A3DC63ECC1；release.sha256 已同步。
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
- APK：D:/App/源社区/源社区_v1.6.1.apk，35210446 字节；SHA-256：D643F534EF216CF8A2AAF493A5A64171A030E4B3BBC0314B304507B6ABC04671；release.sha256 已同步。
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
- APK：D:/App/源社区/源社区_v1.6.2.apk，35,210,442 字节；SHA-256：1DF2153751F36EE2EEDEE3A3F8C8D40DEC8A7C727676D88CC02E602CBA921B77，release.sha256 已同步。
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
- APK：D:/App/源社区/源社区_v1.7.0.apk，35,210,446 字节；SHA-256：C58C899CCDEB2D3CE3427074CC1E2402673EC93491B2D6302A369338FB0D7D24，release.sha256 已同步。
- AAPT：ycoo.net.php，versionName=1.7.0 / versionCode=15，minSdk24；ZIP lib/ 仅 arm64-v8a。apksigner 校验通过，证书 SHA-256 为 3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975，与指定 BKS 相同；16KiB zipalign 校验通过。验证后按用户要求删除根目录旧版 1.6.2 APK。
- 未连接真机或使用真实登录账户；模拟列表测试不能证明三个子页的真实授权数据结构和分页结果。构建成功不代表这些账号数据已验收。


## 1.7.1+16 首页顶栏与关注页留白（2026-10-27）

- 用户希望移除关注页两层分栏之间的线、整体上移首页分栏，并去除我的关注中的“社区动态”标题。首页工具栏在默认字号下从 76dp 调整为 64dp，字体放大时按需增高；分栏及正文偏移共用该高度，避免缩小工具栏后出现重复留白或遮挡。社区、我的等其他根页面的工具栏高度保持各自实现。
- 仅在显示二级关注分栏时，将一级 TabBar 的分界线设为透明，保留选中指示器；磨砂顶栏最下方分界仍由现有 ReviewFrostedAppBar 绘制。二级分栏底部和实际 AppBar 底部保持一致。
- 关注子页不再渲染门户模块，避免旧缓存中的 PortalData 额外生成“社区动态”标题；列表第一张卡片距磨砂顶栏底部 12dp。首页推荐和圈子原有模块与标题继续使用原布局。
- 扩充关注页组件回归，检查两行分栏间无额外距离、一级分界颜色、上移后的几何位置、旧门户数据不会插入社区动态，以及第一张帖子的位置。


### 1.7.1 最终发布校验

- 离线 assembleRelease 成功（30 秒），全套 59 项回归通过；检查了正常字号和 2 倍字体缩放下的首页顶栏布局。Dart 静态分析无 error/warning，过程与校验日志保存在 build/logs。
- APK：D:/App/源社区/源社区_v1.7.1.apk，35,210,446 字节；SHA-256：9B0DD3777B8C2EA7216B5F200496E7F5EF58A2E0FD2CE401C6B6CB3326B4ACE1，release.sha256 已同步。
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
- 正式包：`D:/App/源社区/源社区_v1.7.2.apk`，35,210,446 字节；SHA-256：`4EFDF1CBAD9FE9A88E6E82FB666F413B5D258AF0E70E6910BD86A59C513710AA`，已同步 `release.sha256`。新包校验完成后按要求删除项目根目录旧版 1.7.1 APK；根目录仅保留当前正式包。构建与检查日志保存在 `build/logs`。
- 未连接 Android 真机；真实登录、启动后关注内容与系统 WebView 会话行为仍需设备验收。

## 1.7.3+18 帖子卡片内容与密度（2026-10-27）

- 对照用户给出的客户端图：卡片保留 M3 外观，等级徽章放回作者名旁，依据站点提供的颜色展示；支持站点给出的性别和同源认证图标。置顶使用状态标记，摘要和统计使用次要文字颜色，关注按钮及版块标签采用紧凑样式。
- 从移动信息流提取等级颜色、性别、认证图标与名称，字段通过 Topic 缓存和版块摘要合并保存；缺失字段不虚构。已有的旧快照仍按缓存优先恢复，新增标识需刷新列表后取得，不为每条帖子额外请求详情。
- 修复默认 SVG 头像未圆形裁剪；压缩卡片内容间距及正文与统计栏距离。统计项在宽度不足或放大字号时换行，头像、关注和点赞触控区域保留至少 48dp。
- 所有 TopicTile 调用点（首页/关注、导读、版块、搜索和个人列表）共享改动；原有图片图库和帖子点击路径保持原样。站点返回的计数和摘要仍以真实响应为准。
### 1.7.3 最终发布校验

- Dart 静态分析无 error/warning；Flutter 全量回归 67/67 通过。新增检查覆盖移动网页的等级颜色、性别、认证标识及缓存往返，同源限制，以及深色/浅色、正常/两倍字号的卡片布局与正文到标签间距。
- 离线 `assembleRelease` 成功；AAPT 确认包名 `ycoo.net.php`、版本 `1.7.3` / code `18`、minSdk 24。APK 中原生库仅 `arm64-v8a`；签名证书匹配指定 BKS，16 KiB zipalign 校验通过。
- 正式包：`D:/App/源社区/源社区_v1.7.3.apk`，35,341,754 字节；SHA-256：`5E5FA13972795624BB0C95C3340368853349E28860235EA433767BB47D7FE286`。新包与构建产物哈希一致，检查通过后删除根目录旧版 1.7.2 APK；日志保存在 `build/logs`。
- 没有进行真机视觉或真实账号验收；旧缓存中新增加的作者标识在刷新对应列表后显示。
## 1.7.4+19 关注按钮和等级颜色（2026-10-27）

- 只读核对站点移动信息流和 `https://ycoo.net/source/plugin/comiis_app/cache/comiis_0_style.css?c2h`：`bg_a` 默认背景是 `#FF9900`，管理员示例 Lv.16 的行内背景是 `#FF0000`。现有移动版块夹具中同为 Lv.7 的用户分别有 `#333333` 和 `#4B3E2A`，说明颜色来自站点用户组样式，不能仅按等级号猜测。
- 移动帖子的等级颜色优先读取站点行内背景；无行内背景的 `.top_lev` 使用站点 `bg_a` 默认橙色。对缺少颜色的旧缓存先显示中性色并后台只读取首屏，按帖子 ID、作者 UID 和等级匹配后仅补颜色，不替换列表内容或滚动位置；会话和页面变更丢弃旧响应。旧缓存中首屏以外未匹配的帖子保持中性色，刷新对应列表后获取原色，避免后台无界拉取历史页。
- “关注”移除加号并使用 32dp 高的 M3 胶囊表面，保留 48dp 点击区域；大字号时按钮按内容增长。已关注状态及既有操作不变。
### 1.7.4 最终发布校验

- Dart 静态分析无 error/warning。完整回归 69/69 通过；最后增加对未知等级样式不猜测颜色的边界处理后，帖子卡片相关 9 项回归再次通过，包括站点默认色、同等级不同用户组颜色、旧缓存补色、过期会话响应和胶囊可点击区域。
- 最终源码离线 `assembleRelease` 成功。AAPT 确认包名 `ycoo.net.php`、版本 `1.7.4` / code `19`、minSdk 24；APK 原生库仅 `arm64-v8a`。签名证书匹配指定 BKS，16 KiB zipalign 校验通过。
- 正式包：`D:/App/源社区/源社区_v1.7.4.apk`，35,341,754 字节；SHA-256：`80A97D6C519B2889B5B61993CF60F0B52491DBE980F3552813A05B97422C0024`。新包与构建产物哈希一致，检查通过后删除根目录旧版 1.7.3 APK；日志保存在 `build/logs`。
- 未进行真机视觉或真实账号验收。旧缓存中首屏以外尚未补到颜色的帖子保持中性色，刷新列表后按站点响应显示颜色。
## 1.7.5+20 旧等级颜色与个人统计稳定显示（2026-10-27）

- 用户指出 1.7.4 的旧缓存普通等级显示灰色。原因是旧快照没有 `levelColor`，界面把缺失值渲染成中性色，而站点 `.top_lev.bg_a` 的默认背景实际为 `#FF9900`。现在缺少颜色时先使用该站点默认橙色；有真实行内用户组颜色时优先使用原色，同等级可有不同用户组颜色。
- 旧快照补色不再仅处理首屏：按已缓存页数顺序逐页读取，最多对应现有快照上限 200 页，最多同时一个请求；按帖子 ID、作者 UID、等级核对后仅更新颜色，保留帖子、顺序及滚动位置。全部匹配、没有更多页、切换会话/列表或请求失败时停止；旧会话响应不写入新账户。
- “我的”原本先显示无统计栏的卡片，profile 请求返回后再插入统计栏造成跳变。现按已确认 UID 缓存主题/帖子/积分，首次无缓存时显示占位符并预留同一布局；成功响应必须 UID 一致且三个计数有效才更新和缓存。账户切换/会话变更丢弃过期响应，失败保留已验证缓存；清除内容缓存及退出登录沿用 `cache.` 清理规则。
- 只读核对站点 profile API 的公开 UID 1，响应包含 UID、threads、posts 和 credits；未使用真实用户账号。旧缓存若无可靠 UID 或站点不可用，暂用站点默认橙色，不能推断特殊用户组色。
### 1.7.5 最终发布校验

- Dart 静态分析无 error/warning；Flutter 全量回归 75/75 通过，覆盖普通等级默认色、多个缓存页的不同用户组原色、过期会话拒绝、个人统计缓存及无缓存布局、网络失败与 UID 不匹配。
- 离线 `assembleRelease` 成功。AAPT 确认包名 `ycoo.net.php`、版本 `1.7.5` / code `20`、minSdk 24，APK 原生库仅 `arm64-v8a`。签名证书与指定 BKS 匹配，16 KiB zipalign 校验通过。
- 正式包：`D:/App/源社区/源社区_v1.7.5.apk`，35,341,754 字节；SHA-256：`129BA6B16526B262D38D426878B3702F336C0CE03B4EBA9A05B4974DB292CCF4`。复制后的哈希与构建产物一致，检查通过后删除根目录旧版 1.7.4 APK；日志保存在 `build/logs`。
- 未连接真机或使用真实账号验收。首次没有统计缓存时先显示占位符；成功取得本人资料后才缓存数字。旧帖子若缺失 UID 或站点离线，特殊组颜色无法确认时暂用默认橙色。
## 1.8.0+21 个人页图标与站点分栏（2026-10-27）

- 我的页面六个重复图标分别改为访客、推广、邀请、资料、头像、空间背景对应的 Material 图标；原入口、账户检查和动作保持不变。
- 通用 NativeSitePage 提取同源站点 `.comiis_topnv` 导航，及好友、心情、圈子、日志、相册等已识别的导航列表，放到 ReviewFrostedAppBar.bottom。使用页面真实 URL 原位切换，游客登录链接保留登录入口；未知脚本或跨域导航不擅自猜测，仍保留原内容。站点原导航从正文中移除，隐藏的对话框不再误显示。
- 社区的版区、新帖、精选、热门改为同页面顶部分栏；导读及版块分类、签到排行与日历从正文标签改为顶部分栏。磨砂层边界随 AppBar.bottom 高度变化；大字号或较多分栏支持横向滚动，内容顶部只计算一次工具栏和分栏高度。
- 本机游客心情页已核对 `.comiis_topnv` 与三个真实链接结构；好友、圈子等需要认证的实际内容未在开发账号上取得，不能以合成夹具断言全部站点脚本行为。仅常规同源链接可原生切换，复杂脚本动作仍有适配边界。
### 1.8.0 最终发布校验

- Dart 静态分析无 error/warning；完整 Flutter 回归 79/79 通过，覆盖原生导航同页切换、未识别脚本不误转换、圈子导航结构、普通和两倍字号下磨砂边界、社区分栏与内容间距，以及既有签到、购买和登录回归。
- 离线 `assembleRelease` 成功。AAPT 确认包名 `ycoo.net.php`、版本 `1.8.0` / code `21`、minSdk 24，APK 原生库仅 `arm64-v8a`；签名证书与指定 BKS 匹配，16 KiB zipalign 校验通过。
- 正式包：`D:/App/源社区/源社区_v1.8.0.apk`，35,342,130 字节；SHA-256：`262D00B35E735FB6BF3D4806F98447D46F44090CE23636CD4A9ECF18C1811289`。复制后哈希与构建产物一致，检查通过后删除根目录旧版 1.7.5 APK；日志保存在 `build/logs`。
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
- 对照 D:/App/Review/lib/features/detail/presentation/widgets/image_gallery_page.dart，迁移普通图片连廊的 PageController(viewportFraction=0.16)、64dp 高度、底部安全区+32dp、选中白框与未选中遮罩。
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
- 正式包：`D:/App/源社区/源社区_v1.0.0.apk`，35,409,206 字节，SHA-256 `DD0D7B3CA74215BECA0717964CF77191C751DBCDE397D8B327A7C465291DA3D1`；新包验证通过后已替换根目录旧包。Gradle 日志位于 `build/logs`。
- 未安装到设备；玻璃效果的实际观感与 GPU 表现仍待真机确认。

## 1.0.0+28 浅色液态玻璃悬浮底栏阴影（2026-10-28）

- 仅将浅色液态玻璃悬浮底栏外壳 `shadowElevation` 设为 0.55；深色仍为 0，其他玻璃胶囊与图片播放器均未修改。
- 定向浅色/深色底栏测试 2/2 通过，目标 Dart 分析通过。
- 离线 ARM64 正式构建成功。AAPT 确认包名 `ycoo.net.php`、versionName `1.0.0` / versionCode `28`、仅 `arm64-v8a`；APK v2 签名匹配指定 BKS 证书 SHA-256 `3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975`，16 KiB zipalign 校验通过。
- 正式包 `D:/App/源社区/源社区_v1.0.0.apk`，35,409,206 字节，SHA-256 `9C3F8B3C6279E13C6FCDA7A5F5D0DFE46A303F49FEBF4F34BB3F12088FBDE587`；校验成功后替换了旧 APK，根目录仅保留最新版。Gradle 日志位于 `build/logs`。
- 未安装到设备；真机阴影观感与 GPU 表现待设备确认。

## 1.0.1+29 Lurk 悬浮底栏行为与尺寸（2026-10-28）

- 对照 `D:/App/Lurk/lib/features/home/presentation/main_scaffold.dart`：悬浮栏宽度采用 `min(440, 屏幕宽度 - 40) × 8/9`；点击切换禁用 indicatorPinchStrength 和 indicatorExpansion，只滑动选中镜片。未迁移 Lurk 的长按/拖动果冻手势。
- 只调整 ReviewNavigationBar 的悬浮导航和相应设置/测试；图库、图片播放器及其他玻璃胶囊保持原样。
- 定向测试覆盖点击镜片参数、浅/深色回归及 Lurk 尺寸，2/2 通过；目标 Dart 分析通过。
- 离线 ARM64 正式构建成功。AAPT 确认包名 `ycoo.net.php`、versionName `1.0.1` / versionCode `29`、仅 `arm64-v8a`；APK v2 签名匹配指定 BKS 证书 SHA-256 `3eb0f6708904f8ef916c6a2572e394ba981ee25d64861344cf1921ca7ea17975`，16 KiB zipalign 校验通过。
- 正式包 `D:/App/源社区/源社区_v1.0.1.apk`，35,409,210 字节，SHA-256 `1E72E74260B85A4C6B162B12E428FE4004ACB1A5BCCC9A0EBA836F6014BC6DC0`；新包验证成功后删除根目录旧 APK，当前仅留此包。Gradle 日志位于 `build/logs`。
- 未安装到设备；底栏触感/液态效果的真机表现仍待确认。

## 1.0.2+30 主底栏平移切页（2026-10-28）

- 参考 `D:/App/Lurk/lib/features/home/presentation/main_scaffold.dart`：主底栏不同页面间使用 260ms `easeOutCubic` 双向平移；按页签顺序及 RTL 调整方向，中途再次切页从当前偏移连续开始。
- 保留访问后懒加载和页面状态；仅当前页接收指针，转场期间维持前后页 ticker。尊重系统减少动态效果设置，关闭动画时直接切换。内部分栏与图库转场不变。
- 定向 `following_tabs_test.dart` 8/8 通过，目标 Dart 分析无错误；转场断言覆盖新旧页面移动与返回首页不重复加载信息流。
- 发布脚本创建临时 subst 路径时被 Windows 拒绝；改用本机指向同一工作区的 ASCII `V:` 路径，执行离线 Gradle `assembleRelease` 成功。日志：`build/logs/release-20261028-home-tab-slide.log`。
- APK：`D:/App/源社区/源社区_v1.0.2.apk`，35,409,210 字节，SHA-256 `9F4CFDC8F945BDA6BFC0BBBAF73EFB9E8CB6B99AE4CABB7C2CE02D809C515534`，`release.sha256` 已同步。
- AAPT 确认包名 `ycoo.net.php`、应用名“源社区”、versionName `1.0.2` / versionCode `30`、minSdk 24；APK 原生库仅 `arm64-v8a`。签名 v2 通过且证书 SHA-256 与指定 BKS 一致；16 KiB zipalign 校验通过。校验完成后根目录及 `previous-releases` 中旧 APK 已清理，只保留当前正式包。
- 未安装到设备；尚未进行真机页面切换视觉验收。
