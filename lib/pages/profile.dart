import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html;
import 'package:qr_flutter/qr_flutter.dart';

import '../core/design_system/components/review_frosted_app_bar.dart';
import '../core/utils/haptic_feedback_util.dart';
import '../data/profile.dart';
import '../data/site.dart';
import '../data/portal.dart';
import 'common.dart';
import 'home.dart' show TopicTile;
import 'login.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage(this.site, this.uid, {super.key});
  final Site site;
  final String uid;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserProfile? profile;
  Object? error;
  bool loading = false, acting = false;
  final loadingKeys = <String>{};
  final loginKeys = <String>{};
  bool get contentBusy => loadingKeys.contains(contentKey);
  bool get contentLogin => loginKeys.contains(contentKey);
  int generation = 0, contentGeneration = 0, tab = 0;
  String threadType = 'thread';
  final contents = <String, List<Object>>{};
  final pages = <String, int>{};
  final more = <String, bool>{};
  Object? contentError;
  String get kind => const ['profile', 'thread', 'blog', 'album'][tab];
  String get contentKey => kind == 'thread' ? '$kind-$threadType' : kind;
  String path(String section, {String? type}) => Uri(
    path: '/home.php',
    queryParameters: {
      'mod': 'space',
      'uid': widget.uid,
      'do': section,
      'view': 'me',
      'from': 'space',
      'mobile': '2',
      if (type != null) 'type': type,
    },
  ).toString();

  @override
  void initState() {
    super.initState();
    widget.site.addListener(sessionChanged);
    load();
  }

  void sessionChanged() {
    contentGeneration++;
    loadingKeys.clear();
    contents.clear();
    pages.clear();
    more.clear();
    loginKeys.clear();
    load();
    if (kind != 'profile') loadContent(refresh: true);
  }

  @override
  void dispose() {
    generation++;
    widget.site.removeListener(sessionChanged);
    super.dispose();
  }

  Future<void> load() async {
    final ticket = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final next = await widget.site.userProfile(widget.uid);
      if (!mounted || ticket != generation) return;
      setState(() {
        profile = next;
        loading = false;
      });
    } catch (e) {
      if (mounted && ticket == generation) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  Future<void> loadContent({bool refresh = false}) async {
    if (contentBusy || kind == 'profile') return;
    final key = contentKey, section = kind;
    final replies = threadType == 'reply';
    final ticket = contentGeneration;
    final epoch = widget.site.sessionEpoch;
    final nextPage = refresh ? 1 : (pages[key] ?? 0) + 1;
    setState(() {
      loadingKeys.add(key);
      contentError = null;
      loginKeys.remove(key);
    });
    try {
      final uri = Uri.parse(
        path(section, type: section == 'thread' ? threadType : null),
      );
      final response = await widget.site.request(
        uri.path,
        query: {
          ...uri.queryParameters,
          'page': nextPage,
          '_session': DateTime.now().microsecondsSinceEpoch,
        },
      );
      final source = unwrapPortalHtml('${response.data}');
      final doc = html.parse(source);
      if (!mounted || epoch != widget.site.sessionEpoch) return;
      final login = doc.querySelector('#loginform') != null;
      final entries = <Object>[];
      bool hasMore = false;
      if (!login) {
        if (section == 'thread') {
          final topics = profileTopics(source, profile!, replies: replies);
          entries.addAll(topics);
          hasMore =
              doc.querySelector(
                    '.pg a.nxt, a[rel="next"], .comiis_page a.nxt',
                  ) !=
                  null ||
              topics.length >= 20;
        } else {
          entries.addAll(ProfileContentEntry.parse(source, section));
          hasMore =
              doc.querySelector(
                '.pg a.nxt, a[rel="next"], .comiis_page a.nxt',
              ) !=
              null;
        }
        final message = doc.querySelector('#messagetext')?.text.trim();
        if (entries.isEmpty && message != null && message.isNotEmpty) {
          throw SiteException(message);
        }
      }
      setState(() {
        contents[key] = [if (!refresh) ...?contents[key], ...entries];
        pages[key] = nextPage;
        more[key] = hasMore;
        if (login) loginKeys.add(key);
      });
    } catch (e) {
      if (mounted && key == contentKey) setState(() => contentError = e);
    } finally {
      if (mounted && ticket == contentGeneration) {
        setState(() => loadingKeys.remove(key));
      }
    }
  }

  Future<void> select(int value) async {
    HapticFeedbackUtil.selection();
    setState(() {
      tab = value;
      contentError = null;
    });
    if (kind != 'profile' && !contents.containsKey(contentKey)) {
      await loadContent();
    }
  }

  Future<void> interaction(String action, String title) async {
    if (acting) return;
    if (!widget.site.loggedIn) {
      await push(context, LoginPage(widget.site));
      if (!mounted || !widget.site.loggedIn) return;
    }
    final epoch = widget.site.sessionEpoch;
    setState(() => acting = true);
    try {
      // Resolve authenticated links afresh; never reuse a guest hash or invent a write URL.
      final mobile = await widget.site.request(path('profile'));
      var uri = UserProfile.action('${mobile.data}', widget.uid, action);
      if (uri == null) {
        final desktop = await widget.site.request(
          '/home.php',
          query: {
            'mod': 'space',
            'uid': widget.uid,
            'do': 'profile',
            'mobile': 'no',
            '_session': DateTime.now().microsecondsSinceEpoch,
          },
        );
        uri = UserProfile.action('${desktop.data}', widget.uid, action);
      }
      if (!mounted || epoch != widget.site.sessionEpoch) return;
      if (uri == null) throw SiteException('站点未提供当前账号可用的$title入口，请刷新资料后重试');
      if (action != 'pm') {
        final yes = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text('确认对 ${profile?.name ?? widget.uid} 执行“$title”？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('继续'),
              ),
            ],
          ),
        );
        if (yes != true || !mounted || epoch != widget.site.sessionEpoch) {
          return;
        }
      }
      await openWeb(context, uri.toString(), title: title);
      if (mounted && epoch == widget.site.sessionEpoch) await load();
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  void qr() {
    final user = profile!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(user.name, style: Theme.of(context).textTheme.titleLarge),
              Text('UID ${user.uid}'),
              const SizedBox(height: 16),
              Semantics(
                label: '个人主页二维码',
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(
                    data: user.url,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('扫码查看个人主页'),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: user.url));
                  feedback(context, '主页链接已复制');
                },
                icon: const Icon(Icons.copy),
                label: const Text('复制主页链接'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget image(String url, {BoxFit fit = BoxFit.cover}) => Image.network(
    normalizeSiteLink(url).toString(),
    fit: fit,
    headers: siteImageHeaders(normalizeSiteLink(url).toString()),
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );

  Widget header(UserProfile user) {
    final theme = Theme.of(context);
    final rawColor = RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(user.levelColor)
        ? int.tryParse(user.levelColor.substring(1), radix: 16)
        : null;
    final levelColor = rawColor == null
        ? theme.colorScheme.primaryContainer
        : Color(0xff000000 | rawColor);
    Widget statistic(
      String key,
      String label,
      String count,
      VoidCallback? onTap,
    ) => Expanded(
      child: InkWell(
        key: ValueKey('profile-header-$key'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            alignment: Alignment.centerLeft,
            heightFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: MediaQuery.textScalerOf(context).scale(13) > 18
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          count,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.2,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      '$count $label',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 224),
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: theme.colorScheme.primaryContainer,
              child: user.cover.isEmpty ? null : image(user.cover),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black26, Colors.black.withValues(alpha: .85)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SiteAvatar(
                  key: const ValueKey('profile-avatar'),
                  uid: user.uid,
                  name: user.name,
                  url: user.avatar,
                  radius: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  key: const ValueKey('profile-name'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    statistic('views', '人气', user.count('views'), null),
                    statistic(
                      'following',
                      '关注',
                      user.count('following'),
                      () => openWeb(
                        context,
                        '/home.php?mod=follow&do=following&uid=${user.uid}',
                        title: 'TA 的关注',
                      ),
                    ),
                    statistic(
                      'followers',
                      '粉丝',
                      user.count('follower'),
                      () => openWeb(
                        context,
                        '/home.php?mod=follow&do=follower&uid=${user.uid}',
                        title: 'TA 的粉丝',
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (user.level.isNotEmpty)
                      Chip(
                        label: Text(user.level),
                        backgroundColor: levelColor,
                        side: BorderSide.none,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          color: levelColor.computeLuminance() > .179
                              ? Colors.black
                              : Colors.white,
                        ),
                      ),
                    if (user.group.isNotEmpty)
                      Chip(
                        label: Text(user.group),
                        labelStyle: const TextStyle(fontSize: 12, height: 1.2),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    if (widget.uid != widget.site.uid)
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(64, 32),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        onPressed: acting
                            ? null
                            : () => interaction(
                                'follow',
                                user.followed ? '取消关注' : '关注',
                              ),
                        child: Text(user.followed ? '已关注' : '关注'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> details(UserProfile user) {
    final theme = Theme.of(context);
    Widget row(
      String label,
      String value, {
      VoidCallback? onTap,
      Widget? trailing,
    }) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
      final content = value.isEmpty ? '暂无' : value;
      return ListTile(
        title: largeText
            ? Text(label)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: Text(label)),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: Text(
                      content,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
        subtitle: largeText ? Text(content) : null,
        trailing:
            trailing ??
            (onTap == null ? null : const Icon(Icons.chevron_right)),
        onTap: onTap,
      );
    }

    final metrics = <(String, String, IconData, VoidCallback?)>[
      ('帖子', user.count('threads'), Icons.article_outlined, () => select(1)),
      (
        '回复',
        user.count('replies'),
        Icons.forum_outlined,
        () {
          threadType = 'reply';
          contents.remove('thread-reply');
          select(1);
        },
      ),
      (
        '好友',
        user.count('friends'),
        Icons.people_outline,
        () => openWeb(context, path('friend'), title: 'TA 的好友'),
      ),
      (
        '粉丝',
        user.count('follower'),
        Icons.person_outline,
        () => openWeb(
          context,
          '/home.php?mod=follow&do=follower&uid=${user.uid}',
          title: 'TA 的粉丝',
        ),
      ),
      ('日志', user.count('blogs'), Icons.book_outlined, () => select(2)),
      (
        '相册',
        user.count('albums'),
        Icons.photo_library_outlined,
        () => select(3),
      ),
      (
        '心情',
        user.count('doings'),
        Icons.mood_outlined,
        () => openWeb(context, path('doing'), title: 'TA 的心情'),
      ),
      (
        '人气',
        user.count('views'),
        Icons.visibility_outlined,
        () => openWeb(context, '${path('friend')}&view=visitor', title: '最近访客'),
      ),
    ];
    return [
      row('认证信息', user.verification.isEmpty ? '暂无认证' : user.verification),
      ListTile(
        title: const Text('勋章荣誉'),
        trailing: TextButton(
          onPressed: () =>
              openWeb(context, '/home.php?mod=medal', title: '勋章中心'),
          child: const Text('勋章中心'),
        ),
      ),
      if (user.medals.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('暂无勋章'),
        )
      else
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final medal in user.medals)
              Tooltip(
                message: textOf(medal, 'name'),
                child: InkWell(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(textOf(medal, 'name')),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 72,
                            height: 72,
                            child: image(
                              textOf(medal, 'image'),
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            textOf(medal, 'description').isEmpty
                                ? '站点授予的荣誉勋章'
                                : textOf(medal, 'description'),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('关闭'),
                        ),
                      ],
                    ),
                  ),
                  child: SizedBox(
                    width: 48,
                    height: 56,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: image(textOf(medal, 'image'), fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
          ],
        ),
      row('个人签名', user.signature.isEmpty ? '这家伙很懒，什么也没留下…' : user.signature),
      row(
        '二维码',
        '分享 TA 的个人主页',
        onTap: qr,
        trailing: const Icon(Icons.qr_code_2),
      ),
      const Divider(),
      Column(
        key: const ValueKey('profile-metrics'),
        children: [
          for (var row = 0; row < 2; row++)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var column = 0; column < 4; column++)
                  Expanded(
                    child: InkWell(
                      key: ValueKey('profile-metric-${row * 4 + column}'),
                      onTap: metrics[row * 4 + column].$4,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 2,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              metrics[row * 4 + column].$3,
                              color: [
                                theme.colorScheme.primary,
                                theme.colorScheme.secondary,
                                theme.colorScheme.tertiary,
                              ][(row * 4 + column) % 3],
                              size: 22,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              metrics[row * 4 + column].$1,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, height: 1.2),
                            ),
                            Text(
                              metrics[row * 4 + column].$2,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, height: 1.2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
      const Divider(),
      Wrap(
        children: [
          for (final item in [
            ('积分', user.count('credits')),
            ...user.credits.entries
                .where((e) => e.value is Map)
                .map(
                  (e) => (
                    textOf(e.value as Map, 'title'),
                    user.count('extcredits${e.key}'),
                  ),
                ),
          ])
            SizedBox(
              width: (MediaQuery.sizeOf(context).width - 32) / 2,
              child: ListTile(
                title: Text(item.$1),
                subtitle: Text(
                  item.$2,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
      const Divider(),
      row('用户ID', user.uid),
      row(
        '在线时间',
        user.value('oltime').isEmpty ? '' : '${user.value('oltime')} 小时',
      ),
      row('注册时间', user.value('regdate')),
      row('最后访问', user.value('lastvisit')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = profile;
    final theme = Theme.of(context);
    final tabHeight = (MediaQuery.textScalerOf(context).scale(12) * 1.2 + 24)
        .clamp(52.0, double.infinity);
    final entries = contents[contentKey] ?? [];
    final widgets = user == null
        ? <Widget>[]
        : kind == 'profile'
        ? details(user)
        : <Widget>[
            if (kind == 'thread')
              Row(
                children: [
                  for (final type in ['thread', 'reply'])
                    TextButton(
                      onPressed: contentBusy
                          ? null
                          : () {
                              setState(() => threadType = type);
                              if (!contents.containsKey(contentKey)) {
                                loadContent();
                              }
                            },
                      child: Text(
                        type == 'thread' ? '主题' : '回复',
                        style: TextStyle(
                          fontWeight: threadType == type
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                ],
              ),
            if (contentLogin)
              FilledButton.icon(
                onPressed: () async {
                  await push(context, LoginPage(widget.site));
                  if (mounted && widget.site.loggedIn) {
                    loadContent(refresh: true);
                  }
                },
                icon: const Icon(Icons.login),
                label: const Text('登录后查看'),
              ),
            if (entries.isEmpty &&
                !contentBusy &&
                !contentLogin &&
                contentError == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('暂无可见内容')),
              ),
            for (final entry in entries)
              if (entry is Topic)
                TopicTile(widget.site, entry)
              else if (entry is ProfileContentEntry)
                ListTile(
                  leading: entry.image.isEmpty
                      ? Icon(
                          kind == 'album'
                              ? Icons.photo_library_outlined
                              : Icons.book_outlined,
                        )
                      : SizedBox(
                          width: 56,
                          height: 56,
                          child: image(entry.image),
                        ),
                  title: Text(entry.title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openWeb(context, entry.url, title: entry.title),
                ),
            if (contentError != null)
              TextButton(
                onPressed: () => loadContent(refresh: entries.isEmpty),
                child: Text('$contentError · 重试'),
              ),
            if (contentBusy)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (more[contentKey] == true)
              TextButton(onPressed: loadContent, child: const Text('加载更多')),
          ];
    return Scaffold(
      appBar: ReviewFrostedAppBar(
        title: Text(
          '个人主页',
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 18,
            height: 1.2,
          ),
        ),
        toolbarHeight: (MediaQuery.textScalerOf(context).scale(18) * 1.2 + 8)
            .clamp(48.0, double.infinity),
        titleSpacing: 8,
        iconTheme: const IconThemeData(size: 20),
        actionsIconTheme: const IconThemeData(size: 20),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: loading
                ? null
                : () {
                    load();
                    if (kind != 'profile') loadContent(refresh: true);
                  },
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'copy') {
                Clipboard.setData(
                  ClipboardData(
                    text: '$siteOrigin/space-uid-${widget.uid}.html',
                  ),
                );
                feedback(context, '主页链接已复制');
              } else {
                openWeb(
                  context,
                  path('profile'),
                  title: '用户空间',
                  forceWeb: true,
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'copy', child: Text('复制主页链接')),
              const PopupMenuItem(value: 'web', child: Text('原站主页')),
            ],
          ),
        ],
      ),
      bottomNavigationBar: user == null || widget.uid == widget.site.uid
          ? null
          : SafeArea(
              top: false,
              child: Material(
                color: theme.colorScheme.surfaceContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    key: const ValueKey('profile-actions'),
                    children: [
                      for (final action in [
                        ('friend', '加好友', Icons.person_add_outlined),
                        ('poke', '打招呼', Icons.waving_hand_outlined),
                        ('pm', '聊聊天', Icons.chat_outlined),
                        ('block', '拉黑', Icons.block),
                      ])
                        Expanded(
                          child: TextButton(
                            key: ValueKey('profile-action-${action.$1}'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 6,
                              ),
                            ),
                            onPressed: acting
                                ? null
                                : () => interaction(action.$1, action.$2),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(action.$3, size: 18),
                                const SizedBox(height: 4),
                                Text(
                                  action.$2,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
      body: user == null
          ? loading
                ? const Center(child: CircularProgressIndicator())
                : Failure(error ?? '无法读取用户资料', load)
          : RefreshIndicator(
              onRefresh: () async {
                await load();
                if (kind != 'profile') await loadContent(refresh: true);
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: header(user)),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _ProfileTabs(
                      height: tabHeight,
                      color: theme.colorScheme.surface,
                      border: theme.colorScheme.outlineVariant,
                      child: DefaultTabController(
                        length: 4,
                        initialIndex: tab,
                        key: ValueKey(tab),
                        child: TabBar.secondary(
                          onTap: select,
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          labelStyle: const TextStyle(
                            fontSize: 12,
                            height: 1.2,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontSize: 12,
                            height: 1.2,
                          ),
                          tabs: [
                            for (final item in [
                              ('资料', Icons.badge_outlined),
                              ('帖子', Icons.article_outlined),
                              ('日志', Icons.book_outlined),
                              ('相册', Icons.photo_library_outlined),
                            ])
                              Tab(
                                height: tabHeight,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(item.$2, size: 18),
                                    const SizedBox(height: 2),
                                    Text(item.$1),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (loading)
                    const SliverToBoxAdapter(child: LinearProgressIndicator()),
                  if (error != null)
                    SliverToBoxAdapter(
                      child: TextButton(
                        onPressed: load,
                        child: Text('$error · 重试'),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: SliverList.builder(
                      itemCount: widgets.length,
                      itemBuilder: (_, index) => widgets[index],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProfileTabs extends SliverPersistentHeaderDelegate {
  _ProfileTabs({
    required this.height,
    required this.color,
    required this.border,
    required this.child,
  });
  final double height;
  final Color color, border;
  final Widget child;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Stack(
    fit: StackFit.expand,
    children: [
      ReviewFrostedBackdrop(color: color, borderColor: border),
      Material(color: color.withValues(alpha: .8), child: child),
    ],
  );
  @override
  bool shouldRebuild(covariant _ProfileTabs oldDelegate) =>
      oldDelegate.height != height ||
      oldDelegate.color != color ||
      oldDelegate.border != border ||
      oldDelegate.child != child;
}
