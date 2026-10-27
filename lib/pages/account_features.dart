import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html;
import 'package:qr_flutter/qr_flutter.dart';

import '../core/design_system/components/review_frosted_app_bar.dart';
import '../core/design_system/components/review_preference_tile.dart';
import '../core/widgets/app_section_card.dart';
import '../data/site.dart';
import 'common.dart';
import 'login.dart';
import 'native_site.dart';
import 'thread.dart';

class MessagesMenuPage extends StatelessWidget {
  const MessagesMenuPage(this.site, {super.key});
  final Site site;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = <(String, IconData, VoidCallback)>[
      (
        '我的消息',
        Icons.forum_outlined,
        () => push(context, MyContentPage(site, 'mypm', '我的消息')),
      ),
      (
        '我的粉丝',
        Icons.people_outline,
        () => openWeb(
          context,
          '/home.php?mod=space&do=follow&view=follower',
          title: '我的粉丝',
        ),
      ),
      (
        '我的帖子',
        Icons.article_outlined,
        () => openWeb(
          context,
          '/home.php?mod=space&do=notice&view=mypost',
          title: '帖子提醒',
        ),
      ),
      (
        '坛友互动',
        Icons.diversity_3_outlined,
        () => openWeb(
          context,
          '/home.php?mod=space&do=notice&view=interactive',
          title: '坛友互动',
        ),
      ),
      (
        '系统提醒',
        Icons.notifications_outlined,
        () => openWeb(
          context,
          '/home.php?mod=space&do=notice&view=system',
          title: '系统提醒',
        ),
      ),
      (
        '应用提醒',
        Icons.apps_outlined,
        () => openWeb(
          context,
          '/home.php?mod=space&do=notice&view=userapp',
          title: '应用提醒',
        ),
      ),
    ];
    return Scaffold(
      appBar: const ReviewFrostedAppBar(title: Text('消息提醒')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppSectionCard(
            child: Column(
              children: [
                for (final (title, icon, action) in entries)
                  ReviewPreferenceTile(
                    title: title,
                    leading: Icon(icon, color: scheme.primary),
                    onTap: action,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage(this.site, {super.key});
  final Site site;
  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final bindings = <String, Uri>{};
  bool loading = true;
  bool failed = false;
  @override
  void initState() {
    super.initState();
    loadBindings();
  }

  Future<void> loadBindings() async {
    if (mounted)
      setState(() {
        loading = true;
        failed = false;
      });
    final uid = widget.site.uid;
    final session = widget.site.sessionEpoch;
    try {
      final response = await widget.site.request(
        '/home.php',
        query: {'mod': 'spacecp', 'ac': 'profile', 'mobile': 2},
      );
      final doc = html.parse('${response.data}');
      final found = <String, Uri>{};
      for (final link in doc.querySelectorAll('a[href]')) {
        final label = link.text.trim();
        final uri = Uri.tryParse(link.attributes['href'] ?? '');
        if (uri == null) continue;
        final target = normalizeSiteLink(
          response.realUri.resolveUri(uri).toString(),
        );
        if (!['https', 'http'].contains(target.scheme) ||
            target.host.isEmpty ||
            target.userInfo.isNotEmpty)
          continue;
        if (label.contains('微信') && label.contains('绑定'))
          found['微信绑定'] = target;
        if (label.toUpperCase().contains('QQ') && label.contains('绑定'))
          found['QQ绑定'] = target;
      }
      if (mounted &&
          widget.site.uid == uid &&
          widget.site.sessionEpoch == session) {
        setState(() {
          bindings
            ..clear()
            ..addAll(found);
          loading = false;
        });
      }
    } catch (_) {
      if (mounted &&
          widget.site.uid == uid &&
          widget.site.sessionEpoch == session) {
        setState(() {
          failed = true;
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = <(String, IconData, String)>[
      ('修改头像', Icons.add_a_photo_outlined, '/home.php?mod=spacecp&ac=avatar'),
      ('资料修改', Icons.badge_outlined, '/home.php?mod=spacecp&ac=profile'),
      (
        '密码安全',
        Icons.security_outlined,
        '/home.php?mod=spacecp&ac=profile&op=password',
      ),
      (
        '认证信息',
        Icons.verified_user_outlined,
        '/home.php?mod=spacecp&ac=profile&op=verify',
      ),
    ];
    return Scaffold(
      appBar: const ReviewFrostedAppBar(title: Text('资料设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppSectionCard(
            child: Column(
              children: [
                for (final (title, icon, url) in entries)
                  ReviewPreferenceTile(
                    title: title,
                    leading: Icon(icon),
                    onTap: () => openWeb(context, url, title: title),
                  ),
                for (final label in ['微信绑定', 'QQ绑定'])
                  ReviewPreferenceTile(
                    title: label,
                    subtitle: bindings[label] != null
                        ? null
                        : loading
                        ? '正在读取站点入口'
                        : failed
                        ? '读取失败，点击重试'
                        : '站点未返回可识别的入口',
                    leading: const Icon(Icons.link_rounded),
                    onTap: bindings[label] == null
                        ? (failed ? loadBindings : null)
                        : () => openWeb(
                            context,
                            bindings[label].toString(),
                            title: label,
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CreditsPage extends StatefulWidget {
  const CreditsPage(this.site, {super.key});
  final Site site;
  @override
  State<CreditsPage> createState() => _CreditsPageState();
}

class _CreditsPageState extends State<CreditsPage> {
  late Future<Map<String, dynamic>> profile;
  late String uid;
  late int session;
  int index = 0;
  @override
  void initState() {
    super.initState();
    uid = widget.site.uid;
    session = widget.site.sessionEpoch;
    widget.site.addListener(accountChanged);
    profile = load();
  }

  void accountChanged() {
    if (mounted &&
        (widget.site.uid != uid || widget.site.sessionEpoch != session)) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.site.removeListener(accountChanged);
    super.dispose();
  }

  Future<Map<String, dynamic>> load() async {
    final data = await widget.site.api('profile', query: {'uid': uid});
    final space = data['space'];
    if (widget.site.uid != uid ||
        widget.site.sessionEpoch != session ||
        space is! Map ||
        '${space['uid']}' != uid) {
      throw SiteException('账户已变化，请重新打开积分页面');
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.site.uid != uid || widget.site.sessionEpoch != session) {
      return const Scaffold(
        appBar: ReviewFrostedAppBar(title: Text('我的积分')),
        body: Center(child: Text('账户已变化，请重新打开积分页面')),
      );
    }
    final height = (MediaQuery.textScalerOf(context).scale(14) + 28).clamp(
      48.0,
      double.infinity,
    );
    const tabs = ['我的', '转账', '充值', '记录'];
    const operations = ['', 'transfer', 'buy', 'log'];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: ReviewFrostedAppBar(
          title: const Text('我的积分'),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(height),
            child: TabBar(
              isScrollable: MediaQuery.textScalerOf(context).scale(1) > 1.2,
              tabAlignment: MediaQuery.textScalerOf(context).scale(1) > 1.2
                  ? TabAlignment.start
                  : null,
              onTap: (value) => setState(() => index = value),
              tabs: [for (final tab in tabs) Tab(height: height, text: tab)],
            ),
          ),
        ),
        body: index == 0
            ? FutureBuilder<Map<String, dynamic>>(
                future: profile,
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return Failure(
                      snapshot.error!,
                      () => setState(() => profile = load()),
                    );
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final space = snapshot.data!['space'] as Map;
                  final currencies = snapshot.data!['extcredits'] as Map? ?? {};
                  final ids = currencies.keys
                      .map((id) => '$id')
                      .where(
                        (id) =>
                            RegExp(r'^\d+$').hasMatch(id) &&
                            (currencies[id] ?? currencies[int.tryParse(id)])
                                is Map,
                      )
                      .toList();
                  ids.sort((a, b) => int.parse(b).compareTo(int.parse(a)));
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      AppSectionCard(
                        child: ListTile(
                          title: const Text('积分'),
                          subtitle: Text(
                            '${space['credits'] ?? '—'}',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppSectionCard(
                        child: Column(
                          children: [
                            for (final id in ids)
                              ListTile(
                                title: Text(
                                  textOf(
                                    (currencies[id] ??
                                            currencies[int.tryParse(id)])
                                        as Map,
                                    'title',
                                  ),
                                ),
                                trailing: Text(
                                  '${space['extcredits$id'] ?? '—'}',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              )
            : NativeSitePage(
                widget.site,
                '/home.php?mod=spacecp&ac=credit&op=${operations[index]}',
                key: ValueKey('credit-${widget.site.uid}-$index'),
                title: tabs[index],
                embedded: true,
              ),
      ),
    );
  }
}

class PromotionPage extends StatelessWidget {
  const PromotionPage(this.site, {super.key});
  final Site site;
  @override
  Widget build(BuildContext context) {
    final url = Uri.parse('$siteOrigin/')
        .replace(queryParameters: {'fromuid': site.uid})
        .toString();
    return Scaffold(
      appBar: const ReviewFrostedAppBar(title: Text('访问推广')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppSectionCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SiteAvatar(
                    uid: site.uid,
                    name: site.username,
                    url: site.avatar,
                    radius: 36,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    site.username,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('UID ${site.uid}'),
                  const SizedBox(height: 24),
                  Semantics(
                    label: '推广链接二维码',
                    child: LayoutBuilder(
                      builder: (context, constraints) => QrImageView(
                        data: url,
                        size: constraints.maxWidth.clamp(0.0, 220.0),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('邀请好友扫码访问源社区'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SelectableText(url),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (context.mounted) feedback(context, '推广链接已复制');
                },
                icon: const Icon(Icons.copy),
                label: const Text('复制链接'),
              ),
              OutlinedButton.icon(
                onPressed: () => shareText(context, url),
                icon: const Icon(Icons.share_outlined),
                label: const Text('分享'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DarkroomPage extends StatefulWidget {
  const DarkroomPage(this.site, {super.key});
  final Site site;
  @override
  State<DarkroomPage> createState() => _DarkroomPageState();
}

class _DarkroomPageState extends State<DarkroomPage> {
  final rows = <Map>[];
  bool loading = false, more = true;
  String? cursor;
  Object? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool refresh = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await widget.site.request(
        '/forum.php',
        query: {
          'mod': 'misc',
          'action': 'showdarkroom',
          'ajaxdata': 'json',
          if (!refresh && cursor != null) 'cid': cursor,
        },
      );
      final body = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      if (body is! Map || body['data'] is! Map)
        throw SiteException('无法读取小黑屋记录');
      final batch = (body['data'] as Map).values.whereType<Map>().toList();
      final next = RegExp(r'^1\|(\d+)$')
          .firstMatch('${body['message'] ?? ''}')
          ?.group(1);
      if (!mounted) return;
      setState(() {
        if (refresh) rows.clear();
        final ids = rows.map((row) => '${row['cid']}').toSet();
        rows.addAll(batch.where((row) => ids.add('${row['cid']}')));
        more =
            batch.isNotEmpty &&
            next != null &&
            next != (refresh ? null : cursor);
        cursor = next;
        loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          error = e;
          loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: ReviewFrostedAppBar(
      title: const Text('小黑屋'),
      actions: [
        IconButton(
          onPressed: loading ? null : () => load(refresh: true),
          icon: const Icon(Icons.refresh),
          tooltip: '刷新',
        ),
      ],
    ),
    body: rows.isEmpty && loading
        ? const Center(child: CircularProgressIndicator())
        : rows.isEmpty && error != null
        ? Failure(error!, () => load(refresh: true))
        : ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (rows.isEmpty) const Center(child: Text('暂无记录')),
              for (final row in rows)
                AppSectionCard(
                  child: ListTile(
                    leading: SiteAvatar(
                      uid: '${row['uid'] ?? ''}',
                      name: textOf(row, 'username'),
                    ),
                    title: Text(textOf(row, 'username')),
                    subtitle: Text(
                      [
                        textOf(row, 'action'),
                        textOf(row, 'reason'),
                        plain(row['dateline'] ?? ''),
                        '到期：${plain(row['groupexpiry'] ?? '')}',
                      ].where((v) => v.isNotEmpty).join(' · '),
                    ),
                    onTap: RegExp(r'^\d+$').hasMatch('${row['uid'] ?? ''}')
                        ? () => push(
                            context,
                            ProfilePage(widget.site, '${row['uid']}'),
                          )
                        : null,
                  ),
                ),
              if (error != null)
                TextButton(onPressed: load, child: Text('$error · 重试'))
              else if (more)
                TextButton(
                  onPressed: loading ? null : load,
                  child: Text(loading ? '加载中…' : '加载更多'),
                ),
            ],
          ),
  );
}
