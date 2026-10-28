import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

import '../core/design_system/components/review_card.dart';
import '../core/design_system/components/review_frosted_app_bar.dart';
import '../core/widgets/app_section_card.dart';
import '../data/site.dart';
import 'common.dart';
import 'login.dart';
import 'media.dart';
import 'editor_tools.dart';
import 'home.dart' show TopicsPage;
import 'native_site.dart';
import '../core/utils/haptic_feedback_util.dart';

class ThreadPage extends StatefulWidget {
  const ThreadPage(this.site, this.topic, {super.key});
  final Site site;
  final Topic topic;
  @override
  State<ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> {
  final scroll = ScrollController();
  final posts = <Map>[];
  Map thread = {};
  String fid = '';
  int page = 0;
  bool loading = false, more = true;
  bool payRequired = false;
  Object? error;
  String imageCookie = "";
  @override
  void initState() {
    super.initState();
    widget.site.remember(widget.topic);
    scroll.addListener(() {
      if ((widget.site.prefs.getBool('autoReplies') ?? true) &&
          scroll.hasClients &&
          scroll.position.extentAfter < 350 &&
          posts.isNotEmpty &&
          more &&
          !loading &&
          error == null) {
        load();
      }
    });
    load();
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> load({bool refresh = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final sessionEpoch = widget.site.sessionEpoch;
      final requestedPage = refresh ? 1 : page + 1;
      final supplementalHtml = _loadSupplementalPage(requestedPage);
      final v = await widget.site.api(
        'viewthread',
        query: {'tid': widget.topic.id, 'page': requestedPage},
      );
      try {
        final source = await supplementalHtml.timeout(
          const Duration(milliseconds: 800),
          onTimeout: () => null,
        );
        if (source != null) {
          enrichThreadPosts(
            v['postlist'],
            source,
            allowBody: '${v['forum_threadpay'] ?? '0'}' != '1',
          );
        }
      } catch (_) {
        // Keep the API response when optional presentation markup is unavailable.
      }
      try {
        imageCookie =
            await Site.cookies.invokeMethod<String>('getCookies') ?? '';
      } on MissingPluginException {
        imageCookie = '';
      }
      if (!mounted) return;
      if (sessionEpoch != widget.site.sessionEpoch) {
        throw SiteException('登录状态已变化，请刷新重试');
      }
      setState(() {
        if (refresh) {
          posts.clear();
          page = 0;
        }
        thread = v['thread'] as Map? ?? {};
        payRequired = '${v['forum_threadpay'] ?? '0'}' == '1';
        fid = '${v['fid'] ?? thread['fid'] ?? ''}';
        final seen = posts.map((e) => '${e['pid']}').toSet();
        posts.addAll(
          (v['postlist'] as List? ?? []).whereType<Map>().where(
            (e) => seen.add('${e['pid']}'),
          ),
        );
        page++;
        more = page * number(v['ppp']) < number(thread['replies']) + 1;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  Future<String?> _loadSupplementalPage(int pageNumber) async {
    try {
      final response = await widget.site.request(
        '/forum.php',
        query: {
          'mod': 'viewthread',
          'tid': widget.topic.id,
          'page': pageNumber,
          'mobile': '2',
        },
      );
      return '${response.data}';
    } catch (_) {
      return null;
    }
  }

  Future<void> compose({Map? quote}) async {
    if (!widget.site.loggedIn) {
      await push(context, LoginPage(widget.site));
    }
    if (!mounted || !widget.site.loggedIn) return;
    final sent = await push<bool>(
      context,
      ComposePage(widget.site, fid: fid, tid: widget.topic.id, quote: quote),
    );
    if (sent == true) load(refresh: true);
  }

  Future<void> purchase() async {
    if (!widget.site.loggedIn) await push(context, LoginPage(widget.site));
    if (!mounted || !widget.site.loggedIn) return;
    final result = await push<bool>(
      context,
      NativeSitePage(
        widget.site,
        '/forum.php?mod=misc&action=pay&tid=${widget.topic.id}&mobile=2',
        title: '购买主题',
        purchaseTid: widget.topic.id,
        purchasePrice: '${thread['price']}',
      ),
    );
    if (mounted && result == true) load(refresh: true);
  }

  Future<void> favorite() async {
    if (!widget.site.loggedIn) await push(context, LoginPage(widget.site));
    if (!mounted || !widget.site.loggedIn) return;
    try {
      await widget.site.syncSession();
      await widget.site.api(
        'favthread',
        query: {'id': widget.topic.id, 'favoritesubmit': 'true'},
        data: {'formhash': widget.site.formhash, 'description': ''},
      );
      if (mounted) feedback(context, '已收藏到源社区');
    } catch (e) {
      if (mounted) feedback(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: ReviewFrostedAppBar(
      title: const Text('帖子详情'),
      actions: [
        IconButton(
          tooltip: '收藏',
          icon: const Icon(Icons.bookmark_border_rounded),
          onPressed: favorite,
        ),
        PopupMenuButton<String>(
          onSelected: (v) async {
            final path = '/thread-${widget.topic.id}-1-1.html';
            if (v == 'web') {
              openWeb(context, path, title: widget.topic.title, forceWeb: true);
            } else if (v == 'share') {
              await shareText(context, '$siteOrigin$path');
            } else if (v == 'find') {
              push(
                context,
                BrowserPage(path, title: widget.topic.title, findOnLoad: true),
              );
            } else if (v == 'desktop') {
              openWeb(context, '$path?mobile=no', title: '电脑版', forceWeb: true);
            } else {
              Clipboard.setData(ClipboardData(text: '$siteOrigin$path'));
              feedback(context, '链接已复制');
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'copy', child: Text('复制链接')),
            const PopupMenuItem(value: 'web', child: Text('原站 / 购买 / 附件')),
            const PopupMenuItem(value: 'share', child: Text('分享帖子')),
            const PopupMenuItem(value: 'find', child: Text('网页查找')),
            const PopupMenuItem(value: 'desktop', child: Text('电脑版')),
          ],
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: FilledButton.tonalIcon(
          onPressed: loading || fid.isEmpty ? null : () => compose(),
          icon: const Icon(Icons.reply_rounded),
          label: const Text('回复帖子'),
        ),
      ),
    ),
    body: posts.isEmpty && loading
        ? const Center(child: CircularProgressIndicator())
        : posts.isEmpty && error != null
        ? Failure(error!, () => load(refresh: true))
        : RefreshIndicator(
            edgeOffset: MediaQuery.paddingOf(context).top + kToolbarHeight,
            onRefresh: () =>
                HapticFeedbackUtil.refresh(() => load(refresh: true)),
            child: ListView.builder(
              controller: scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                12,
                MediaQuery.paddingOf(context).top + kToolbarHeight + 16,
                12,
                24,
              ),
              itemCount: posts.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          textOf(thread, 'subject').isEmpty
                              ? widget.topic.title
                              : textOf(thread, 'subject'),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${thread['views'] ?? widget.topic.views} 阅读 · ${thread['replies'] ?? widget.topic.replies} 回复',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (number(thread['price']) > 0)
                          TextButton.icon(
                            onPressed: payRequired ? purchase : null,
                            icon: const Icon(Icons.lock_outline),
                            label: Text(
                              payRequired
                                  ? '购买主题 · ${thread['price']} 星币'
                                  : '付费主题 · ${thread['price']} 星币 · 已解锁',
                            ),
                          ),
                      ],
                    ),
                  );
                }
                if (index == posts.length + 1) {
                  return Center(
                    child: error != null
                        ? TextButton(
                            onPressed: () => load(),
                            child: Text('$error · 重试'),
                          )
                        : loading
                        ? const CircularProgressIndicator()
                        : more
                        ? TextButton(
                            onPressed: () => load(),
                            child: const Text('加载更多回复'),
                          )
                        : const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('已显示全部可见内容'),
                          ),
                  );
                }
                final post = posts[index - 1];
                return ReviewCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: SiteAvatar(
                            uid: '${post['authorid'] ?? ''}',
                            name: textOf(post, 'author'),
                          ),
                          title: Text(textOf(post, 'author')),
                          subtitle: Text(
                            '${textOf(post, 'dateline')} · ${post['number'] ?? post['position'] ?? index} 楼${post['displayLevel'] == null ? '' : ' · ${post['displayLevel']}'}${post['displayCategory'] == null ? '' : ' · ${post['displayCategory']}'}',
                          ),
                          onTap: () => push(
                            context,
                            ProfilePage(widget.site, '${post['authorid']}'),
                          ),
                          trailing: IconButton(
                            tooltip: '引用回复',
                            icon: const Icon(Icons.reply_outlined),
                            onPressed: () => compose(quote: post),
                          ),
                        ),
                        const SizedBox(height: 8),
                        HtmlContent(
                          forumPostHtml(post),
                          cookie: imageCookie,
                          linkify: widget.site.prefs.getBool('linkify') ?? true,
                          onLink: (url) => routeLink(
                            context,
                            widget.site,
                            url,
                            cookie: imageCookie,
                          ),
                        ),
                        if ('${post['displayCopyright'] ?? ''}'.isNotEmpty)
                          HtmlContent(
                            '${post['displayCopyright']}',
                            onLink: (url) =>
                                routeLink(context, widget.site, url),
                          ),
                        if (post['attachments'] is Map &&
                            (post['attachments'] as Map).values
                                .whereType<Map>()
                                .any((a) => '${a['isimage']}' != '1'))
                          TextButton.icon(
                            onPressed: () => openWeb(
                              context,
                              '/thread-${widget.topic.id}-1-1.html',
                              title: '原站附件',
                              forceWeb: true,
                            ),
                            icon: const Icon(Icons.attachment),
                            label: const Text('查看原站附件'),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
  );
}

void enrichThreadPosts(dynamic posts, String source, {bool allowBody = false}) {
  if (posts is! List) return;
  final doc = html.parse(source);
  for (final post in posts.whereType<Map>()) {
    final pid = '${post['pid']}';
    if (!RegExp(r'^\d+$').hasMatch(pid)) {
      continue;
    }
    final node = doc.querySelector('#pid$pid');
    if (node == null) continue;
    final body = node.querySelector('.comiis_messages');
    String compact(String value) => value.replaceAll(RegExp(r'\s+|\u00a0'), '');
    final apiText = compact(plain(post['message'] ?? ''));
    // Only restore layout when the same server-visible content is present.
    if (allowBody &&
        body != null &&
        apiText.isNotEmpty &&
        compact(body.text).contains(apiText)) {
      post['displayMessage'] = body.innerHtml;
    }
    final level = node.querySelector('.top_lev')?.text.trim();
    final category = node.querySelector('.comiis_postli_time a')?.text.trim();
    if (level != null && level.isNotEmpty) post['displayLevel'] = level;
    if (category != null && category.isNotEmpty) {
      post['displayCategory'] = category;
    }
    final copyright = node.querySelector('#copyright');
    if (copyright != null && '${post['first']}' == '1') {
      post['displayCopyright'] = copyright.outerHtml;
    }
  }
}

void routeLink(
  BuildContext context,
  Site site,
  String path, {
  String cookie = '',
}) {
  final videoUrl = forumMediaUrl(path);
  if (videoUrl != null &&
      RegExp(
        r'\.(png|jpe?g|gif|webp|avif|bmp)$',
        caseSensitive: false,
      ).hasMatch(Uri.parse(videoUrl).path)) {
    openGallery(context, [videoUrl], 0, cookie: cookie);
    return;
  }
  if (videoUrl != null && isDirectForumVideo(videoUrl)) {
    push(context, ForumVideoPage(videoUrl, cookie: cookie));
    return;
  }
  final uri = normalizeSiteLink(path);
  if (isSite(uri)) {
    final fid =
        RegExp(r'forum-(\d+)').firstMatch(uri.path)?.group(1) ??
        (uri.queryParameters['mod'] == 'forumdisplay'
            ? uri.queryParameters['fid']
            : null);
    if (fid != null) {
      push(context, TopicsPage(site, fid: fid, title: '社区板块'));
      return;
    }
    final tid = nativeThreadId(uri);
    if (tid != null) {
      push(context, ThreadPage(site, Topic(id: tid, title: '帖子详情')));
      return;
    }
    final uid =
        RegExp(r'space-uid-(\d+)').firstMatch(uri.path)?.group(1) ??
        uri.queryParameters['uid'];
    if (uid != null) {
      push(context, ProfilePage(site, uid));
      return;
    }
  }
  openWeb(context, uri.toString());
}

String forumPostHtml(Map post) {
  final fragment = html.parseFragment(
    '${post['displayMessage'] ?? post['message'] ?? ''}',
  );
  final attachments = post['attachments'];
  if (attachments is Map) {
    for (final entry in attachments.entries) {
      final item = entry.value;
      if (item is! Map ||
          '${item['isimage']}' != '1' ||
          (number(item['price']) > 0 && '${item['payed']}' != '1')) {
        continue;
      }
      final url = forumMediaUrl(
        '${item['url'] ?? ''}${item['attachment'] ?? ''}',
      );
      if (url == null || '${item['attachment'] ?? ''}'.isEmpty) continue;
      final existing = fragment
          .querySelectorAll('img')
          .where(
            (img) =>
                img.attributes['aid'] == '${entry.key}' ||
                img.attributes.values.any(
                  (value) =>
                      forumMediaUrl(value) == url ||
                      value == '${item['attachment']}',
                ),
          );
      if (existing.isNotEmpty) {
        existing.first.attributes['file'] = url;
        continue;
      }
      final image = dom.Element.tag('img')..attributes['src'] = url;
      final encoded = '${item['aidencode'] ?? ''}';
      final attachmentLink = fragment
          .querySelectorAll('a')
          .where(
            (a) =>
                encoded.isNotEmpty &&
                a.attributes['href']?.contains(encoded) == true,
          )
          .firstOrNull;
      if (attachmentLink != null) {
        attachmentLink.replaceWith(image);
      } else {
        fragment.append(image);
      }
    }
  }
  return fragment.outerHtml;
}

class HtmlContent extends StatefulWidget {
  const HtmlContent(
    this.source, {
    required this.onLink,
    this.cookie = '',
    this.linkify = true,
    this.followImageLinks = false,
    super.key,
  });
  final String source;
  final String cookie;
  final bool linkify;
  final bool followImageLinks;
  final ValueChanged<String> onLink;
  @override
  State<HtmlContent> createState() => _HtmlContentState();
}

class _HtmlContentState extends State<HtmlContent> {
  final recognizers = <TapGestureRecognizer>[];
  final galleryScope = Object();
  late dom.DocumentFragment fragment = html.parseFragment(widget.source);
  @override
  void didUpdateWidget(covariant HtmlContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      fragment = html.parseFragment(widget.source);
    }
  }

  void clear() {
    for (final r in recognizers) {
      r.dispose();
    }
    recognizers.clear();
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    clear();
    final theme = Theme.of(context);
    final blocks = <Widget>[], images = <String>[], previews = <String>[];
    final buffer = <InlineSpan>[];
    void flush() {
      if (buffer.isEmpty) return;
      final text = buffer.map((span) => span.toPlainText()).join();
      if (text.trim().isEmpty && !text.contains('\n')) {
        buffer.clear();
        return;
      }
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SelectableText.rich(
            TextSpan(
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
              children: List.of(buffer),
            ),
          ),
        ),
      );
      buffer.clear();
    }

    void walk(
      dom.Node node, {
      TextStyle? style,
      String? link,
      bool preformatted = false,
    }) {
      if (node is dom.Text) {
        final text = preformatted
            ? node.text
            : node.text.replaceAll(RegExp(r'[\t\r\n\f ]+'), ' ');
        if (link == null && widget.linkify) {
          final matches = RegExp(r'https?://[^\s<>，。；！？]+')
              .allMatches(text)
              .toList();
          if (matches.isNotEmpty) {
            var end = 0;
            for (final match in matches) {
              buffer.add(
                TextSpan(text: text.substring(end, match.start), style: style),
              );
              final url = match.group(0)!;
              final recognizer = TapGestureRecognizer()
                ..onTap = () {
                  HapticFeedbackUtil.light();
                  widget.onLink(url);
                };
              recognizers.add(recognizer);
              buffer.add(
                TextSpan(
                  text: url,
                  recognizer: recognizer,
                  style: (style ?? const TextStyle()).copyWith(
                    color: theme.colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              );
              end = match.end;
            }
            buffer.add(TextSpan(text: text.substring(end), style: style));
            return;
          }
        }
        if (text.isNotEmpty) {
          TapGestureRecognizer? recognizer;
          if (link != null) {
            recognizer = TapGestureRecognizer()
              ..onTap = () {
                HapticFeedbackUtil.light();
                widget.onLink(link);
              };
            recognizers.add(recognizer);
          }
          buffer.add(
            TextSpan(text: text, style: style, recognizer: recognizer),
          );
        }
        return;
      }
      if (node is! dom.Element) return;
      final tag = node.localName;
      if ([
        'script',
        'style',
        'iframe',
        'object',
        'embed',
        'source',
      ].contains(tag)) {
        return;
      }
      if (tag == 'br') {
        buffer.add(const TextSpan(text: '\n'));
        return;
      }
      final framed =
          node.id == 'copyright' ||
          tag == 'blockquote' ||
          node.classes.any(
            (c) => ['locked', 'showhide', 'quote', 'comiis_quote'].contains(c),
          );
      if (framed) {
        flush();
        final start = blocks.length;
        for (final child in node.nodes) {
          walk(child, style: style, link: link, preformatted: preformatted);
        }
        flush();
        final children = blocks.sublist(start);
        blocks.removeRange(start, blocks.length);
        blocks.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        );
        return;
      }
      if (tag == 'video') {
        final path =
            [
                  node.attributes['src'],
                  node.attributes['data-src'],
                  node.querySelector('source[src]')?.attributes['src'],
                ]
                .whereType<String>()
                .map((value) => value.trim())
                .firstWhere((value) => value.isNotEmpty, orElse: () => '');
        final url = forumMediaUrl(path);
        if (url == null) return;
        final posterPath = node.attributes['poster']?.trim() ?? '';
        final poster = posterPath.isEmpty ? null : forumMediaUrl(posterPath);
        flush();
        blocks.add(
          ForumVideoPreview(url: url, cookie: widget.cookie, poster: poster),
        );
        return;
      }
      if (tag == 'img') {
        final path =
            [
                  node.attributes['file'],
                  node.attributes['zoomfile'],
                  node.attributes['data-src'],
                  node.attributes['src'],
                ]
                .whereType<String>()
                .map((value) => value.trim())
                .firstWhere((value) => value.isNotEmpty, orElse: () => '');
        if (path.isEmpty) return;
        final previewPath =
            [
                  node.attributes['data-src'],
                  node.attributes['src'],
                  node.attributes['zoomfile'],
                  node.attributes['file'],
                ]
                .whereType<String>()
                .map((value) => value.trim())
                .firstWhere((value) => value.isNotEmpty, orElse: () => '');
        var uri = siteUri(path);
        if (uri.scheme == 'http' &&
            uri.host == 'ycoo.net' &&
            uri.userInfo.isEmpty) {
          uri = uri.replace(scheme: 'https');
        }
        if (!['https', 'http'].contains(uri.scheme) ||
            uri.userInfo.isNotEmpty) {
          return;
        }
        flush();
        final url = uri.toString();
        final previewUrl = forumMediaUrl(previewPath) ?? url;
        images.add(url);
        previews.add(previewUrl);
        final imageIndex = images.length - 1;
        blocks.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Semantics(
              button: true,
              label: node.attributes['alt']?.isNotEmpty == true
                  ? node.attributes['alt']
                  : '查看图片',
              child: InkWell(
                onTap: () => widget.followImageLinks && link != null
                    ? widget.onLink(link)
                    : openGallery(
                        context,
                        List.of(images),
                        imageIndex,
                        cookie: widget.cookie,
                        heroScope: galleryScope,
                        previews: List.of(previews),
                      ),
                child: Hero(
                  tag: forumGalleryHeroTag(galleryScope, imageIndex, url),
                  flightShuttleBuilder: forumGalleryFlight,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 440),
                      child: Image.network(
                        previewUrl,
                        headers: siteImageHeaders(
                          previewUrl,
                          cookie: widget.cookie,
                        ),
                        fit: BoxFit.contain,
                        cacheWidth: 1200,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                            ? child
                            : const SizedBox(
                                height: 100,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                        errorBuilder: (_, e, s) => const SizedBox(
                          height: 80,
                          child: Center(child: Text('图片加载失败 · 点击重试查看')),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        return;
      }
      final block = [
        'p',
        'div',
        'blockquote',
        'pre',
        'ul',
        'ol',
        'li',
        'h1',
        'h2',
        'h3',
        'table',
        'tr',
      ].contains(tag);
      if (block) flush();
      var nextStyle = style;
      var nextLink = link;
      if (tag == 'a') {
        nextLink = node.attributes['href'];
        nextStyle = (style ?? const TextStyle()).copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        );
      }
      if (tag == 'b' || tag == 'strong') {
        nextStyle = (style ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w600,
        );
      }
      if (node.classes.contains('pstatus') || tag == 'em') {
        nextStyle = (nextStyle ?? const TextStyle()).copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: theme.textTheme.bodySmall?.fontSize,
        );
      }
      if (['h1', 'h2', 'h3'].contains(tag)) {
        nextStyle = theme.textTheme.titleMedium;
      }
      if (tag == 'code' || tag == 'pre') {
        nextStyle = (style ?? const TextStyle()).copyWith(
          fontFamily: 'monospace',
        );
      }
      if (tag == 'li') buffer.add(const TextSpan(text: '• '));
      for (final child in node.nodes) {
        walk(
          child,
          style: nextStyle,
          link: nextLink,
          preformatted: preformatted || tag == 'pre',
        );
      }
      if (block) flush();
    }

    for (final node in fragment.nodes) {
      walk(node);
    }
    flush();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage(this.site, this.uid, {super.key});
  final Site site;
  final String uid;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<Map<String, dynamic>> future;
  @override
  void initState() {
    super.initState();
    future = widget.site.api('profile', query: {'uid': widget.uid});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: ReviewFrostedAppBar(
      title: const Text('用户主页'),
      actions: [
        IconButton(
          tooltip: '原站主页',
          icon: const Icon(Icons.open_in_browser),
          onPressed: () =>
              openWeb(context, '/space-uid-${widget.uid}.html', title: '用户空间'),
        ),
      ],
    ),
    body: FutureBuilder(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Failure(
            snapshot.error!,
            () => setState(
              () => future = widget.site.api(
                'profile',
                query: {'uid': widget.uid},
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final space = snapshot.data!['space'] as Map? ?? {};
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: SiteAvatar(
                uid: widget.uid,
                name: textOf(space, 'username'),
                radius: 36,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                textOf(space, 'username'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Center(child: Text('UID ${widget.uid}')),
            const SizedBox(height: 24),
            AppSectionCard(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('主题'),
                    trailing: Text('${space['threads'] ?? '—'}'),
                  ),
                  ListTile(
                    title: const Text('帖子'),
                    trailing: Text('${space['posts'] ?? '—'}'),
                  ),
                  ListTile(
                    title: const Text('积分'),
                    trailing: Text('${space['credits'] ?? '—'}'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () => openWeb(
                context,
                '/home.php?mod=space&uid=${widget.uid}&do=thread&view=me',
                title: '用户帖子',
              ),
              child: const Text('查看 TA 的帖子'),
            ),
            OutlinedButton(
              onPressed: () => openWeb(
                context,
                '/home.php?mod=spacecp&ac=pm&op=showmsg&handlekey=showmsg_${widget.uid}&touid=${widget.uid}&pmid=0&daterange=2',
                title: '发送私信',
              ),
              child: const Text('私信'),
            ),
          ],
        );
      },
    ),
  );
}

class ComposePage extends StatefulWidget {
  const ComposePage(
    this.site, {
    required this.fid,
    this.tid,
    this.quote,
    this.types = const {},
    super.key,
  });
  final Site site;
  final String fid;
  final String? tid;
  final Map? quote;
  final Map<String, String> types;
  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  final subject = TextEditingController(), message = TextEditingController();
  bool busy = false;
  bool sent = false;
  Object? error;
  String? type;
  String get draftKey => 'draft.${widget.site.uid}.${widget.tid ?? widget.fid}';
  @override
  void initState() {
    super.initState();
    type = widget.types.keys.firstOrNull;
    subject.text = widget.site.prefs.getString('$draftKey.subject') ?? '';
    message.text = widget.site.prefs.getString('$draftKey.message') ?? '';
  }

  Future<void> save() async {
    if (sent) return;
    final title = subject.text, body = message.text, key = draftKey;
    await widget.site.prefs.setString('$key.subject', title);
    await widget.site.prefs.setString('$key.message', body);
  }

  @override
  void dispose() {
    subject.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (busy) return;
    if (message.text.trim().isEmpty ||
        (widget.tid == null && subject.text.trim().isEmpty)) {
      feedback(context, '请填写${widget.tid == null ? '标题和' : ''}正文');
      return;
    }
    if (!widget.site.loggedIn) await push(context, LoginPage(widget.site));
    if (!mounted || !widget.site.loggedIn) return;
    await save();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.site.api('checkpost', query: {'fid': widget.fid});
      await widget.site.api(
        widget.tid == null ? 'newthread' : 'sendreply',
        query: {
          'fid': widget.fid,
          if (widget.tid != null) 'tid': widget.tid,
          if (widget.tid == null)
            'topicsubmit': 'yes'
          else
            'replysubmit': 'yes',
          if (widget.quote != null) 'repquote': '${widget.quote!['pid']}',
        },
        data: {
          'formhash': widget.site.formhash,
          'message': message.text,
          'subject': subject.text,
          if (type != null) 'typeid': type,
        },
      );
      sent = true;
      await widget.site.prefs.remove('$draftKey.subject');
      await widget.site.prefs.remove('$draftKey.message');
      if (mounted) {
        feedback(context, '服务器已确认发布成功');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = '$e\n如果提交后连接中断，请先查看原帖确认，避免重复发布。草稿已保留。');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    onPopInvokedWithResult: (didPop, result) {
      if (didPop) save();
    },
    child: Scaffold(
      appBar: ReviewFrostedAppBar(
        title: Text(widget.tid == null ? '发布帖子' : '回复帖子'),
        actions: [
          TextButton(
            onPressed: busy ? null : send,
            child: Text(busy ? '提交中…' : '发布'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.quote != null)
            AppSectionCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '引用 ${textOf(widget.quote!, 'author')} · ${widget.quote!['number'] ?? widget.quote!['position']} 楼',
                ),
              ),
            ),
          if (widget.tid == null) ...[
            TextField(
              controller: subject,
              enabled: !busy,
              maxLength: 80,
              decoration: const InputDecoration(labelText: '帖子标题'),
            ),
            if (widget.types.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: type,
                items: [
                  for (final e in widget.types.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: busy
                    ? null
                    : (v) {
                        HapticFeedbackUtil.selection();
                        setState(() => type = v);
                      },
                decoration: const InputDecoration(labelText: '主题分类'),
              ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: message,
            enabled: !busy,
            minLines: 10,
            maxLines: null,
            decoration: const InputDecoration(
              labelText: '正文',
              alignLabelWithHint: true,
              hintText: '输入内容，支持论坛 BBCode',
            ),
            onChanged: (_) => save(),
          ),
          ComposerTools(
            prefs: widget.site.prefs,
            controller: message,
            onApplied: save,
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                '$error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    await save();
                    if (context.mounted) {
                      await openWeb(
                        context,
                        widget.tid == null
                            ? '/forum.php?mod=post&action=newthread&fid=${widget.fid}'
                            : '/forum.php?mod=post&action=reply&fid=${widget.fid}&tid=${widget.tid}',
                        title: '原站编辑器',
                      );
                    }
                  },
            icon: const Icon(Icons.attachment),
            label: const Text('图片、附件、投票与高级编辑'),
          ),
        ],
      ),
    ),
  );
}
