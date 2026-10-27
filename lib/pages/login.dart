import 'package:flutter/material.dart';

import '../core/utils/haptic_feedback_util.dart';

import '../core/design_system/components/review_frosted_app_bar.dart';
import '../core/design_system/components/review_preference_tile.dart';
import '../core/widgets/app_section_card.dart';
import '../data/site.dart';
import 'common.dart';
import 'home.dart';
import 'thread.dart';

class LoginPage extends StatefulWidget {
  const LoginPage(this.site, {super.key});
  final Site site;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final user = TextEditingController(),
      password = TextEditingController(),
      answer = TextEditingController();
  bool busy = false, hide = true;
  String question = '0';
  Object? error;
  @override
  void dispose() {
    user.dispose();
    password.dispose();
    answer.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (!form.currentState!.validate() || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.site.login(
        user.text.trim(),
        password.text,
        question: question,
        answer: answer.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on LoginWebRequired {
      if (mounted) await webLogin();
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> webLogin() async {
    widget.site.sessionEpoch++;
    await openWeb(
      context,
      '/member.php?mod=logging&action=login&mobile=2',
      title: '网页登录',
    );
    widget.site.sessionEpoch++;
    try {
      await widget.site.syncSessionFromWeb();
      if (mounted && widget.site.loggedIn) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) feedback(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ReviewFrostedAppBar(title: Text('登录源社区')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(
                Icons.forum_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text('欢迎回到源社区', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              TextFormField(
                controller: user,
                enabled: !busy,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'UID / 用户名 / Email',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? '请输入账户' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: password,
                enabled: !busy,
                obscureText: hide,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: '密码',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: hide ? '显示密码' : '隐藏密码',
                    icon: Icon(
                      hide
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => hide = !hide),
                  ),
                ),
                validator: (v) => v == null || v.isEmpty ? '请输入密码' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: question,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '安全提问'),
                items: [
                  for (final entry in const {
                    '0': '未设置安全提问',
                    '1': '母亲的名字',
                    '2': '爷爷的名字',
                    '3': '父亲出生的城市',
                    '4': '您其中一位老师的名字',
                    '5': '您个人计算机的型号',
                    '6': '您最喜欢的餐馆名称',
                    '7': '驾驶执照最后四位数字',
                  }.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (v) {
                        HapticFeedbackUtil.selection();
                        setState(() => question = v ?? '0');
                      },
              ),
              if (question != '0')
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextFormField(
                    controller: answer,
                    decoration: const InputDecoration(labelText: '安全问题答案'),
                    validator: (v) => v == null || v.isEmpty ? '请输入答案' : null,
                  ),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    '$error',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: busy ? null : login,
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('登录'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: busy ? null : webLogin,
                child: const Text('网页登录 / 验证码验证'),
              ),
              TextButton(
                onPressed: () => openWeb(
                  context,
                  '/member.php?mod=register',
                  title: '注册与邀请',
                ),
                child: const Text('注册账户'),
              ),
              const SizedBox(height: 16),
              const Text('登录凭据只发送到源社区。密码不会保存在应用设置中；会话由系统 WebView Cookie 存储。'),
            ],
          ),
        ),
      ),
    ),
  );
}

class AccountPage extends StatefulWidget {
  const AccountPage(this.site, {super.key});
  final Site site;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool loading = true;
  Object? error;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.site.syncSession();
    } catch (e) {
      error = e;
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    return Scaffold(
      appBar: const ReviewFrostedAppBar(title: Text('我的账户')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Failure(error!, refresh)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppSectionCard(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(20),
                    leading: site.loggedIn
                        ? SiteAvatar(
                            uid: site.uid,
                            name: site.username,
                            url: site.avatar,
                            radius: 20,
                          )
                        : const CircleAvatar(child: Icon(Icons.person_outline)),
                    title: Text(site.loggedIn ? site.username : '尚未登录'),
                    subtitle: Text(
                      site.loggedIn ? 'UID ${site.uid}' : '登录后查看收藏、消息和帖子',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      if (site.loggedIn) {
                        await push(context, ProfilePage(site, site.uid));
                      } else {
                        await push(context, LoginPage(site));
                        await refresh();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 24),
                AppSectionCard(
                  child: Column(
                    children: [
                      for (final entry in const {
                        'myfavthread': '我的收藏',
                        'mythread': '我的帖子',
                        'mypm': '私信',
                        'mynotelist': '通知',
                      }.entries)
                        ReviewPreferenceTile(
                          title: entry.value,
                          leading: Icon(switch (entry.key) {
                            'myfavthread' => Icons.bookmark_outline,
                            'mythread' => Icons.article_outlined,
                            'mypm' => Icons.mail_outline,
                            _ => Icons.notifications_none,
                          }),
                          onTap: () async {
                            if (!site.loggedIn) {
                              await push(context, LoginPage(site));
                              await refresh();
                            }
                            if (context.mounted && site.loggedIn) {
                              await push(
                                context,
                                MyContentPage(site, entry.key, entry.value),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),
                if (site.loggedIn) ...[
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () async {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('退出当前账户？'),
                          content: const Text('将清除此应用的登录会话、账户缓存和本机阅读历史。'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('退出'),
                            ),
                          ],
                        ),
                      );
                      if (yes == true) {
                        await site.logout();
                        await site.prefs.remove('history');
                        await refresh();
                      }
                    },
                    child: const Text('退出登录'),
                  ),
                ],
              ],
            ),
    );
  }
}

class MyContentPage extends StatefulWidget {
  const MyContentPage(this.site, this.module, this.title, {super.key});
  final Site site;
  final String module, title;
  @override
  State<MyContentPage> createState() => _MyContentPageState();
}

class _MyContentPageState extends State<MyContentPage> {
  final rows = <Map>[];
  bool busy = false, more = true;
  Object? error;
  int page = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final v = await widget.site.api(widget.module, query: {'page': page + 1});
      dynamic list = v['list'] ?? v['data'];
      if (list is Map) list = list['list'] ?? list.values.toList();
      final batch = (list is List ? list : const []).whereType<Map>().toList();
      if (!mounted) return;
      setState(() {
        rows.addAll(batch);
        page++;
        more =
            batch.isNotEmpty &&
            (number(v['count']) == 0
                ? batch.length >= number(v['perpage'])
                : rows.length < number(v['count']));
        busy = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          busy = false;
        });
      }
    }
  }

  String get webPath => switch (widget.module) {
    'myfavthread' => '/home.php?mod=space&do=favorite&type=thread',
    'mythread' => '/home.php?mod=space&do=thread&view=me',
    'mypm' => '/home.php?mod=space&do=pm',
    _ => '/home.php?mod=space&do=notice',
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: ReviewFrostedAppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          tooltip: '原站管理',
          icon: const Icon(Icons.open_in_browser),
          onPressed: () => openWeb(context, webPath, title: widget.title),
        ),
      ],
    ),
    body: rows.isEmpty && busy
        ? const Center(child: CircularProgressIndicator())
        : rows.isEmpty && error != null
        ? Failure(error!, load)
        : ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('暂无内容')),
                ),
              for (final row in rows)
                if (widget.module == 'myfavthread' ||
                    widget.module == 'mythread')
                  TopicTile(
                    widget.site,
                    Topic.fromJson({
                      ...row,
                      'tid': row['tid'] ?? row['id'],
                      'subject': row['subject'] ?? row['title'],
                    }),
                  )
                else
                  Builder(
                    builder: (context) {
                      final uid = [row['touid'], row['msgfromid']]
                          .map((value) => '${value ?? ''}')
                          .where(
                            (value) =>
                                RegExp(r'^\d+$').hasMatch(value) &&
                                value != '0' &&
                                value != widget.site.uid,
                          )
                          .firstOrNull;
                      final recipient = textOf(row, 'tousername');
                      final sender = textOf(row, 'msgfrom');
                      final name =
                          uid == '${row['touid'] ?? ''}' && recipient.isNotEmpty
                          ? recipient
                          : sender.isNotEmpty
                          ? sender
                          : textOf(row, 'author');
                      final message = plain(
                        row['message'] ??
                            row['note'] ??
                            row['lastsummary'] ??
                            row['subject'] ??
                            '',
                      );
                      final time = textOf(row, 'vdateline');
                      return ListTile(
                        leading: uid == null
                            ? null
                            : SiteAvatar(uid: uid, name: name),
                        title: Text(name.isEmpty ? '站点消息' : name),
                        subtitle: Text(
                          [
                            message,
                            time,
                          ].where((value) => value.isNotEmpty).join('\n'),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => openWeb(
                          context,
                          widget.module == 'mypm' && uid != null
                              ? '/home.php?mod=space&do=pm&subop=view&touid=$uid&viewall=1'
                              : webPath,
                          title: name.isEmpty ? widget.title : name,
                        ),
                      );
                    },
                  ),
              if (error != null)
                TextButton(onPressed: load, child: Text('$error · 重试'))
              else if (more)
                TextButton(
                  onPressed: busy ? null : load,
                  child: Text(busy ? '加载中…' : '加载更多'),
                ),
            ],
          ),
  );
}
