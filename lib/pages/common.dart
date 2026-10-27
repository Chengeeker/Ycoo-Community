import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../core/utils/haptic_feedback_util.dart';

import '../core/design_system/components/review_frosted_app_bar.dart';
import '../data/site.dart';
import '../core/widgets/app_scope.dart';
import 'thread.dart' show routeLink;
import 'media.dart' show openGallery;
import 'native_site.dart';
import 'native_cloud.dart';

Future<T?> push<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
const appActions = MethodChannel('ycoo.net.php/actions');
bool _choosingUploadFile = false;

Future<MultipartFile?> chooseUploadFile({List<String> types = const []}) async {
  if (_choosingUploadFile) throw SiteException('正在选择或读取文件，请稍候');
  _choosingUploadFile = true;
  try {
    final files = await appActions.invokeListMethod<String>('chooseFiles', {
      'types': types,
      'multiple': false,
    });
    if (files == null || files.isEmpty) return null;
    final info = await appActions.invokeMapMethod<String, dynamic>(
      'readSelectedFile',
      {'uri': files.first},
    );
    if (info == null || info['bytes'] is! Uint8List) {
      throw SiteException('无法读取选择的文件');
    }
    return MultipartFile.fromBytes(
      info['bytes'] as Uint8List,
      filename: '${info['name'] ?? 'upload.bin'}',
      contentType: DioMediaType.parse(
        RegExp(r'^[a-zA-Z0-9.+-]+/[a-zA-Z0-9.+-]+$')
                .hasMatch('${info['mimeType']}')
            ? '${info['mimeType']}'
            : 'application/octet-stream',
      ),
    );
  } finally {
    _choosingUploadFile = false;
  }
}

Future<void> shareText(BuildContext context, String text) async {
  try {
    await appActions.invokeMethod<void>('shareText', {'text': text});
  } on MissingPluginException {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) feedback(context, '链接已复制');
  } on PlatformException {
    if (context.mounted) feedback(context, '无法打开系统分享');
  }
}

bool isDownloadUri(Uri uri) =>
    ['http', 'https'].contains(uri.scheme) &&
    uri.userInfo.isEmpty &&
    (uri.queryParameters['mod'] == 'attachment' ||
        RegExp(
          r'\.(apk|zip|7z|rar|epub|mobi|azw3|pdf)$',
          caseSensitive: false,
        ).hasMatch(uri.path));

Future<void> showDownloadDialog(BuildContext context, String url) async {
  final action = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('下载文件'),
      content: const Text('选择系统下载或浏览器下载。需要登录权限的附件可在浏览器中完成验证。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'copy'),
          child: const Text('复制链接'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'browser'),
          child: const Text('浏览器'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, 'download'),
          child: const Text('系统下载'),
        ),
      ],
    ),
  );
  if (action == null || !context.mounted) return;
  if (action == 'copy') {
    await Clipboard.setData(ClipboardData(text: url));
  } else if (action == 'browser') {
    await push(context, BrowserPage(url, previewFile: true));
  } else {
    try {
      await appActions.invokeMethod<int>('download', {'url': url});
      if (context.mounted) feedback(context, '已加入系统下载队列，请在通知栏查看进度');
    } on PlatformException catch (e) {
      if (context.mounted) feedback(context, e.message ?? '无法启动下载');
    } on MissingPluginException {
      if (context.mounted) feedback(context, '当前平台未提供系统下载');
    }
  }
}

void feedback(BuildContext context, Object error) {
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$error')));
  }
}

class SiteAvatar extends StatelessWidget {
  const SiteAvatar({
    required this.uid,
    required this.name,
    this.url,
    this.radius = 16,
    super.key,
  });

  final String uid, name;
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = SvgPicture.asset(
      'assets/default-avatar.svg',
      width: radius * 2,
      height: radius * 2,
      semanticsLabel: '$name 的默认头像',
    );
    final image = url?.isNotEmpty == true ? url! : discuzAvatarUrl(uid);
    if (image.isEmpty || Uri.tryParse(image)?.path.endsWith('.svg') == true) {
      return ClipOval(child: fallback);
    }
    return ClipOval(
      child: Image.network(
        image,
        width: radius * 2,
        height: radius * 2,
        cacheWidth: (radius * 3).round(),
        fit: BoxFit.cover,
        headers: siteImageHeaders(image),
        semanticLabel: '$name 的头像',
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : fallback,
      ),
    );
  }
}

class Failure extends StatelessWidget {
  const Failure(this.error, this.retry, {super.key});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    ),
  );
}

class BrowserPage extends StatefulWidget {
  const BrowserPage(
    this.url, {
    this.title = '原站页面',
    this.findOnLoad = false,
    this.previewFile = false,
    super.key,
  });
  final String url, title;
  final bool findOnLoad;
  final bool previewFile;
  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  late final WebViewController controller;
  int progress = 0;
  String? error;
  bool initialFindShown = false;
  late String currentUrl = siteUri(widget.url).toString();
  late String currentTitle = widget.title;
  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        siteUri(widget.url).queryParameters['mobile'] == 'no'
            ? siteUserAgent
            : siteMobileUserAgent,
      )
      ..setOnJavaScriptAlertDialog((request) async {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(request.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      })
      ..setOnJavaScriptConfirmDialog((request) async {
        if (!mounted) return false;
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                content: Text(request.message),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('确定'),
                  ),
                ],
              ),
            ) ??
            false;
      })
      ..setOnJavaScriptTextInputDialog((request) async {
        if (!mounted) return '';
        final input = TextEditingController(text: request.defaultText);
        final answer = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(request.message),
            content: TextField(controller: input, autofocus: true),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, input.text),
                child: const Text('确定'),
              ),
            ],
          ),
        );
        input.dispose();
        return answer ?? '';
      })
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            final title = await controller.getTitle();
            if (mounted && title?.isNotEmpty == true) {
              setState(() => currentTitle = title!);
            }
            if (widget.findOnLoad && !initialFindShown && mounted) {
              initialFindShown = true;
              findInPage();
            }
          },
          onProgress: (v) {
            if (mounted) setState(() => progress = v);
          },
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                error = null;
                currentUrl = url;
              });
            }
          },
          onWebResourceError: (e) {
            if (e.isForMainFrame == true && mounted) {
              setState(() => error = e.description);
            }
          },
          onNavigationRequest: (request) async {
            final uri = Uri.tryParse(request.url);
            if (uri == null ||
                !['https', 'http'].contains(uri.scheme) ||
                uri.userInfo.isNotEmpty ||
                uri.host.isEmpty) {
              return NavigationDecision.prevent;
            }
            if (request.isMainFrame && mounted) {
              final target = normalizeSiteLink(request.url);
              final site = AppScope.maybeOf(context)?.site;
              if (isDirectForumImage(target)) {
                await openGallery(context, [target.toString()], 0);
                return NavigationDecision.prevent;
              }
              if (site != null &&
                  nativeThreadId(target) != null &&
                  target.toString() != siteUri(widget.url).toString()) {
                routeLink(context, site, target.toString());
                return NavigationDecision.prevent;
              }
            }
            if (request.isMainFrame &&
                isDownloadUri(uri) &&
                mounted &&
                !(widget.previewFile && uri == siteUri(widget.url))) {
              await showDownloadDialog(context, uri.toString());
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(siteUri(widget.url));
    if (controller.platform case final AndroidWebViewController android) {
      android.setOnShowFileSelector((params) async {
        HapticFeedbackUtil.light();
        try {
          return await appActions.invokeListMethod<String>('chooseFiles', {
                'types': params.acceptTypes,
                'multiple': params.mode == FileSelectorMode.openMultiple,
              }) ??
              [];
        } on PlatformException {
          if (mounted) feedback(context, '无法打开文件选择器');
          return [];
        } on MissingPluginException {
          return [];
        }
      });
    }
  }

  Future<void> findInPage() async {
    final input = TextEditingController();
    Future<void> find({bool backwards = false}) async {
      if (input.text.isEmpty) return;
      HapticFeedbackUtil.selection();
      final found = await controller.runJavaScriptReturningResult(
        'window.find(${jsonEncode(input.text)}, false, $backwards, true)',
      );
      if (found == false && mounted) feedback(context, '没有找到匹配内容');
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('网页查找'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(labelText: '查找文字'),
          onSubmitted: (_) => find(),
        ),
        actions: [
          TextButton(
            onPressed: () => find(backwards: true),
            child: const Text('上一处'),
          ),
          TextButton(onPressed: () => find(), child: const Text('下一处')),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('完成'),
          ),
        ],
      ),
    );
    input.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop) return;
      if (await controller.canGoBack()) {
        await controller.goBack();
      } else if (context.mounted) {
        Navigator.of(context).pop();
      }
    },
    child: Scaffold(
      appBar: ReviewFrostedAppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              Uri.tryParse(currentUrl)?.host ?? currentUrl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        leading: IconButton(
          tooltip: '关闭页面',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.reload(),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              final url =
                  await controller.currentUrl() ??
                  siteUri(widget.url).toString();
              if (v == 'copy') {
                await Clipboard.setData(ClipboardData(text: url));
              } else if (v == 'share') {
                if (context.mounted) await shareText(context, url);
              } else if (v == 'find') {
                await findInPage();
              } else if (v == 'top') {
                await controller.runJavaScript(
                  'window.scrollTo({top:0,behavior:"smooth"})',
                );
              } else if (v == 'desktop') {
                final uri = Uri.parse(url);
                await controller.setUserAgent(siteUserAgent);
                await controller.loadRequest(
                  uri.replace(
                    queryParameters: {...uri.queryParameters, 'mobile': 'no'},
                  ),
                );
              } else if (v == 'download') {
                if (context.mounted) await showDownloadDialog(context, url);
              } else {
                await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'copy', child: Text('复制链接')),
              const PopupMenuItem(value: 'external', child: Text('在浏览器打开')),
              const PopupMenuItem(value: 'share', child: Text('分享网页')),
              const PopupMenuItem(value: 'find', child: Text('网页查找')),
              const PopupMenuItem(value: 'top', child: Text('回到顶部')),
              const PopupMenuItem(value: 'desktop', child: Text('电脑版')),
              const PopupMenuItem(value: 'download', child: Text('下载当前链接')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (progress < 100) LinearProgressIndicator(value: progress / 100),
          Expanded(
            child: error == null
                ? WebViewWidget(controller: controller)
                : Failure(error!, () => controller.reload()),
          ),
        ],
      ),
    ),
  );
}

Future<void> openWeb(
  BuildContext context,
  String url, {
  String title = '原站页面',
  bool forceWeb = false,
}) async {
  final uri = normalizeSiteLink(url);
  if (!['https', 'http'].contains(uri.scheme) ||
      uri.userInfo.isNotEmpty ||
      uri.host.isEmpty) {
    feedback(context, '暂不支持此链接，可长按复制原文');
    return;
  }
  if (isDirectForumImage(uri)) {
    await openGallery(context, [uri.toString()], 0);
    return;
  }
  final site = AppScope.maybeOf(context)?.site;
  if (!forceWeb && site != null && nativeThreadId(uri) != null) {
    routeLink(context, site, uri.toString());
    return;
  }
  if (!forceWeb && !isSite(uri)) {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('即将离开源社区', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              const Text('此链接指向外部网站，请确认访问地址。'),
              const SizedBox(height: 12),
              SelectableText(uri.toString()),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context, 'continue'),
                child: const Text('继续访问'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, 'copy'),
                      child: const Text('复制链接'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, 'browser'),
                      child: const Text('浏览器打开'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: uri.toString()));
      if (context.mounted) feedback(context, '链接已复制');
      return;
    }
    if (action == 'browser') {
      await push(
        context,
        BrowserPage(uri.toString(), title: title, previewFile: true),
      );
      return;
    }
  }
  if (isDownloadUri(uri)) {
    await showDownloadDialog(context, uri.toString());
    return;
  }
  final isAuthentication =
      uri.path == '/member.php' &&
      ['logging', 'register'].contains(uri.queryParameters['mod']);
  if (!forceWeb && site != null && isSite(uri) && !isAuthentication) {
    if (uri.queryParameters['id'] == 'bphp_clouds:index') {
      await push(context, NativeCloudPage(site));
      return;
    }
    final sign =
        uri.path == '/k_misign-sign.html' ||
        uri.queryParameters['id'] == 'k_misign:sign';
    await push(
      context,
      sign
          ? SignPage(site)
          : NativeSitePage(site, uri.toString(), title: title),
    );
    return;
  }
  await push(context, BrowserPage(uri.toString(), title: title));
}
