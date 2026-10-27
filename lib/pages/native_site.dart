import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:html/dom.dart' as dom;

import '../data/site.dart';
import '../data/native_site.dart';
import '../core/design_system/components/review_frosted_app_bar.dart';
import '../core/widgets/app_section_card.dart';
import '../core/utils/haptic_feedback_util.dart';
import 'common.dart';
import 'login.dart';
import 'thread.dart';

class NativeSitePage extends StatefulWidget {
  const NativeSitePage(
    this.site,
    this.url, {
    required this.title,
    this.purchaseTid,
    this.purchasePrice,
    this.embedded = false,
    super.key,
  });
  final Site site;
  final String url, title;
  final String? purchaseTid, purchasePrice;
  final bool embedded;
  @override
  State<NativeSitePage> createState() => _NativeSitePageState();
}

class _NativeSitePageState extends State<NativeSitePage>
    with TickerProviderStateMixin {
  NativePageData? page;
  Object? error;
  bool busy = false;
  bool confirming = false;
  late Uri current = normalizeSiteLink(widget.url);
  int generation = 0;
  String? quotedPrice;
  TabController? tabs;
  bool switchingTab = false;

  void setPage(NativePageData next) {
    final selected = next.tabs.indexWhere((tab) => tab.selected);
    if (next.tabs.isEmpty) {
      tabs?.dispose();
      tabs = null;
    } else if (tabs == null || tabs!.length != next.tabs.length) {
      tabs?.dispose();
      tabs = TabController(
        length: next.tabs.length,
        vsync: this,
        initialIndex: selected < 0 ? 0 : selected,
      );
    } else if (selected >= 0) {
      tabs!.index = selected;
    }
    page = next;
  }

  Future<void> selectTab(int index) async {
    HapticFeedbackUtil.selection();
    final oldPage = page;
    if (oldPage == null || index >= oldPage.tabs.length) return;
    final oldIndex = oldPage.tabs.indexWhere((tab) => tab.selected);
    final target = oldPage.tabs[index].uri;
    if (busy || target == null) {
      tabs?.index = oldIndex < 0 ? 0 : oldIndex;
      if (!busy && target == null) {
        await push(context, LoginPage(widget.site));
        if (mounted && widget.site.loggedIn) await load();
      }
      return;
    }
    final previous = current;
    setState(() {
      current = target;
      switchingTab = true;
    });
    await load();
    if (!mounted) return;
    setState(() {
      switchingTab = false;
      if (error != null) {
        current = previous;
        tabs?.index = oldIndex < 0 ? 0 : oldIndex;
      }
    });
  }

  @override
  void dispose() {
    generation++;
    tabs?.dispose();
    super.dispose();
  }

  Future<void> followLink(String url) async {
    if (RegExp(r'^javascript:(?:window\.)?history\.(?:back\(\)|go\(-1\))')
        .hasMatch(url)) {
      Navigator.maybePop(context);
      return;
    }
    if (url.contains('member.php?mod=logging') &&
        url.contains('action=login')) {
      await push(context, LoginPage(widget.site));
      if (mounted && widget.site.loggedIn) load();
      return;
    }
    routeLink(context, widget.site, url);
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final ticket = ++generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final uri = current.replace(
        queryParameters: {
          ...current.queryParameters,
          'mobile': '2',
          '_session': '${DateTime.now().microsecondsSinceEpoch}',
        },
      );
      final result = await widget.site.request(uri.toString());
      if (widget.purchaseTid != null && widget.site.loggedIn) {
        final view = await widget.site.api(
          'viewthread',
          query: {
            'tid': widget.purchaseTid,
            '_session': DateTime.now().microsecondsSinceEpoch,
          },
        );
        quotedPrice = '${(view['thread'] as Map?)?['price'] ?? ''}';
        if (num.tryParse(quotedPrice!) == null ||
            num.parse(quotedPrice!) <= 0) {
          throw SiteException('站点未返回可确认的主题价格');
        }
      }
      if (!mounted || ticket != generation) return;
      setState(() {
        setPage(NativePageData.parse('${result.data}', result.realUri));
        busy = false;
      });
    } catch (e) {
      if (mounted && ticket == generation) {
        setState(() {
          error = e;
          busy = false;
        });
      }
    }
  }

  Future<void> submit(NativeForm form, Map<String, dynamic> values) async {
    if (busy || confirming) return;
    final account = widget.site.uid;
    final epoch = widget.site.sessionEpoch;
    if (widget.purchaseTid != null &&
        (form.action.path != '/forum.php' ||
            form.action.queryParameters['action'] != 'pay' ||
            '${values['tid'] ?? form.action.queryParameters['tid'] ?? ''}' !=
                widget.purchaseTid ||
            (form.action.queryParameters['tid'] != null &&
                form.action.queryParameters['tid'] != widget.purchaseTid))) {
      feedback(context, '购买表单与当前主题不匹配，请刷新后重试');
      return;
    }
    final message = widget.purchaseTid != null
        ? '购买该主题将由站点扣除 ${quotedPrice ?? widget.purchasePrice ?? '页面所示数量的'} 星币。确认购买？'
        : '确认提交“${widget.title}”中的这项操作？';
    confirming = true;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.purchaseTid != null ? '确认购买主题' : '确认提交'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    confirming = false;
    if (yes != true ||
        !mounted ||
        busy ||
        widget.site.uid != account ||
        widget.site.sessionEpoch != epoch) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.purchaseTid != null) {
        final before = await widget.site.api(
          'viewthread',
          query: {
            'tid': widget.purchaseTid,
            '_session': DateTime.now().microsecondsSinceEpoch,
          },
        );
        final price = '${(before['thread'] as Map?)?['price'] ?? ''}';
        if ('${before['forum_threadpay']}' != '1' &&
            before['forum_threadpay'] != null &&
            '${(before['thread'] as Map?)?['tid']}' == widget.purchaseTid) {
          if (mounted) Navigator.pop(context, true);
          return;
        }
        if (quotedPrice == null || price != quotedPrice) {
          throw SiteException('主题价格已变化，请刷新并重新核对价格');
        }
      }
      final result = await widget.site.request(
        form.action
            .replace(
              queryParameters: {...form.action.queryParameters, 'mobile': '2'},
            )
            .toString(),
        query: form.method == 'get'
            ? {...form.action.queryParameters, 'mobile': '2', ...values}
            : null,
        data: form.method == 'post' ? values : null,
      );
      if (!mounted || account != widget.site.uid) return;
      if (widget.purchaseTid != null) {
        final checked = await widget.site.api(
          'viewthread',
          query: {
            'tid': widget.purchaseTid,
            '_session': DateTime.now().microsecondsSinceEpoch,
          },
        );
        if (checked['forum_threadpay'] != null &&
            '${checked['forum_threadpay']}' != '1' &&
            '${(checked['thread'] as Map?)?['tid']}' == widget.purchaseTid) {
          if (mounted) Navigator.pop(context, true);
          return;
        }
      }
      if (mounted) {
        setState(() {
          setPage(NativePageData.parse('${result.data}', result.realUri));
          busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabHeight = (MediaQuery.textScalerOf(context).scale(14) + 28).clamp(
      48.0,
      double.infinity,
    );
    final tabData = page?.tabs ?? const <NativePageTab>[];
    final scrollTabs =
        tabData.length > 3 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.2 ||
        tabData.any((tab) => tab.label.runes.length > 4);
    return Scaffold(
      appBar: widget.embedded
          ? null
          : ReviewFrostedAppBar(
              title: Text(widget.title),
              bottom: tabs == null
                  ? null
                  : PreferredSize(
                      preferredSize: Size.fromHeight(tabHeight),
                      child: TabBar(
                        controller: tabs,
                        isScrollable: scrollTabs,
                        tabAlignment: scrollTabs ? TabAlignment.start : null,
                        onTap: selectTab,
                        tabs: [
                          for (final tab in tabData)
                            Tab(height: tabHeight, text: tab.label),
                        ],
                      ),
                    ),
              actions: [
                if (page != null)
                  IconButton(
                    tooltip: '复制页面适配信息',
                    icon: const Icon(Icons.bug_report_outlined),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: page!.adaptationInfo),
                      );
                      if (context.mounted) {
                        feedback(context, '已复制页面结构信息，不包含 Cookie、密码或表单值');
                      }
                    },
                  ),
                IconButton(
                  tooltip: '刷新',
                  onPressed: busy ? null : load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
      body: busy && (page == null || switchingTab)
          ? const Center(child: CircularProgressIndicator())
          : error != null && page == null
          ? Failure(error!, load)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (busy) const LinearProgressIndicator(),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '$error',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (page?.hasScriptActions == true)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('此插件仍可能包含未适配的脚本操作，可复制页面适配信息反馈。'),
                  ),
                if (page?.loginRequired == true)
                  FilledButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('登录后继续'),
                    onPressed: () async {
                      await push(context, LoginPage(widget.site));
                      if (mounted && widget.site.loggedIn) load();
                    },
                  ),
                if (widget.purchaseTid != null)
                  AppSectionCard(
                    child: ListTile(
                      leading: const Icon(Icons.payments_outlined),
                      title: Text(
                        '购买主题 · ${quotedPrice ?? widget.purchasePrice ?? '以站点确认为准'} 星币',
                      ),
                      subtitle: const Text('费用与权限由站点核对，成功后自动刷新帖子'),
                    ),
                  ),
                for (final part in page?.parts ?? <Object>[])
                  if (part is String)
                    HtmlContent(
                      part,
                      followImageLinks: true,
                      onLink: followLink,
                    )
                  else if (part is NativeForm)
                    NativeFormView(
                      key: ObjectKey(part),
                      form: part,
                      busy: busy,
                      onSubmit: (values) => submit(part, values),
                    ),
                if (page != null && page!.parts.isEmpty && !page!.loginRequired)
                  Text(
                    page!.message.isNotEmpty ? page!.message : '站点暂未返回可显示的内容',
                  ),
              ],
            ),
    );
  }
}

class NativeFormView extends StatefulWidget {
  const NativeFormView({
    required this.form,
    required this.onSubmit,
    required this.busy,
    super.key,
  });
  final NativeForm form;
  final bool busy;
  final ValueChanged<Map<String, dynamic>> onSubmit;
  @override
  State<NativeFormView> createState() => _NativeFormViewState();
}

class _NativeFormViewState extends State<NativeFormView> {
  late final values = widget.form.values();
  String? parentLabel(dom.Element element) {
    for (var parent = element.parent; parent != null; parent = parent.parent) {
      if (parent.localName == 'label') return parent.text.trim();
    }
    return null;
  }

  bool checked(dom.Element e) {
    final value = values[e.attributes['name']];
    return value is List
        ? value.contains(e.attributes['value'] ?? 'on')
        : value != null;
  }

  void toggle(dom.Element e, bool selected) {
    final name = e.attributes['name']!;
    final value = e.attributes['value'] ?? 'on';
    if (name.endsWith('[]') ||
        widget.form.controls
                .where((field) => field.attributes['name'] == name)
                .length >
            1) {
      final list = List<String>.from(values[name] as List? ?? []);
      list.remove(value);
      if (selected) list.add(value);
      if (list.isEmpty) {
        values.remove(name);
      } else {
        values[name] = list;
      }
    } else if (selected) {
      values[name] = value;
    } else {
      values.remove(name);
    }
  }

  String label(dom.Element e) =>
      e.attributes['placeholder'] ??
      e.attributes['title'] ??
      widget.form.element
          .querySelectorAll('label')
          .where((label) => label.attributes['for'] == e.id && e.id.isNotEmpty)
          .firstOrNull
          ?.text
          .trim() ??
      parentLabel(e) ??
      const {
        'username': '用户名',
        'password': '密码',
        'message': '内容',
        'subject': '标题',
        'name': '名称',
        'signature': '签名',
        'bio': '简介',
      }[e.attributes['name']] ??
      '填写内容';
  @override
  Widget build(BuildContext context) {
    final form = widget.form;
    final summary = form.element.clone(true);
    for (final control in summary.querySelectorAll(
      'input,button,select,textarea,label',
    )) {
      control.remove();
    }
    final fields = form.controls
        .where(
          (e) => ![
            'hidden',
            'submit',
            'button',
            'reset',
          ].contains(e.attributes['type']),
        )
        .toList();
    final submits = form.element.querySelectorAll(
      'button:not([type="button"]):not([type="reset"]),input[type="submit"]',
    );
    return AppSectionCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (summary.text.trim().isNotEmpty ||
                summary.querySelector('img') != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: HtmlContent(
                  summary.outerHtml,
                  onLink: (url) => openWeb(context, url),
                ),
              ),

            for (final field in fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: field.localName == 'select'
                    ? DropdownButtonFormField<String>(
                        initialValue:
                            '${values[field.attributes['name']] ?? ''}',
                        decoration: InputDecoration(labelText: label(field)),
                        items: [
                          for (final option in field.querySelectorAll('option'))
                            DropdownMenuItem(
                              value: option.attributes['value'] ?? option.text,
                              child: Text(option.text),
                            ),
                        ],
                        onChanged: widget.busy
                            ? null
                            : (value) => values[field.attributes['name']!] =
                                  value ?? '',
                      )
                    : field.attributes['type'] == 'radio'
                    ? RadioGroup<String>(
                        groupValue: values[field.attributes['name']] as String?,
                        onChanged: widget.busy
                            ? (_) {}
                            : (value) => setState(
                                () => values[field.attributes['name']!] = value,
                              ),
                        child: RadioListTile<String>(
                          value: field.attributes['value'] ?? '',
                          title: Text(label(field)),
                        ),
                      )
                    : field.attributes['type'] == 'checkbox'
                    ? CheckboxListTile(
                        title: Text(label(field)),
                        value: checked(field),
                        onChanged: widget.busy
                            ? null
                            : (checked) => setState(
                                () => toggle(field, checked == true),
                              ),
                      )
                    : field.attributes['type'] == 'file'
                    ? OutlinedButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: Text(
                          values[field.attributes['name']] is MultipartFile
                              ? (values[field.attributes['name']]
                                            as MultipartFile)
                                        .filename ??
                                    '已选择文件'
                              : '选择文件',
                        ),
                        onPressed: widget.busy
                            ? null
                            : () async {
                                try {
                                  final file = await chooseUploadFile(
                                    types: (field.attributes['accept'] ?? '')
                                        .split(','),
                                  );
                                  if (mounted && file != null) {
                                    setState(
                                      () => values[field.attributes['name']!] =
                                          file,
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) feedback(context, e);
                                }
                              },
                      )
                    : TextFormField(
                        initialValue:
                            '${values[field.attributes['name']] ?? ''}',
                        enabled: !widget.busy,
                        readOnly: field.attributes.containsKey('readonly'),
                        obscureText: field.attributes['type'] == 'password',
                        maxLines: field.localName == 'textarea' ? 4 : 1,
                        decoration: InputDecoration(labelText: label(field)),
                        onChanged: (value) =>
                            values[field.attributes['name']!] = value,
                      ),
              ),
            for (final button in submits)
              FilledButton(
                onPressed:
                    widget.busy || button.attributes.containsKey('disabled')
                    ? null
                    : () {
                        HapticFeedbackUtil.light();
                        widget.onSubmit({
                          ...values,
                          if (button.attributes['name'] != null)
                            button.attributes['name']!:
                                button.attributes['value'] ?? 'true',
                        });
                      },
                child: Text(
                  button.localName == 'input'
                      ? button.attributes['value'] ?? '提交'
                      : button.text.trim().isEmpty
                      ? '提交'
                      : button.text.trim(),
                ),
              ),
            if (submits.isEmpty)
              FilledButton(
                onPressed: widget.busy
                    ? null
                    : () => widget.onSubmit(Map.of(values)),
                child: const Text('查询'),
              ),
          ],
        ),
      ),
    );
  }
}

class SignPage extends StatefulWidget {
  const SignPage(this.site, {super.key});
  final Site site;
  @override
  State<SignPage> createState() => _SignPageState();
}

class _SignPageState extends State<SignPage> {
  SignData? data;
  NativePageData? ranking;
  List<SignRank> ranks = [];
  String tab = 'today';
  bool busy = false;
  Object? error;
  int page = 1;
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
      final results = await Future.wait([
        widget.site.request(
          '/k_misign-sign.html',
          query: {
            'mobile': 2,
            '_session': DateTime.now().microsecondsSinceEpoch,
          },
        ),
        widget.site.request(
          '/plugin.php',
          query: {
            'id': 'k_misign:sign',
            'operation': tab == 'calendar' ? 'calendar' : 'list',
            'op': tab,
            'page': page,
            'mobile': 2,
          },
        ),
      ]);
      if (mounted) {
        setState(() {
          data = SignData.parse('${results[0].data}');
          ranking = NativePageData.parse(
            '${results[1].data}',
            results[1].realUri,
          );
          ranks = SignRank.parse('${results[1].data}');
          busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          busy = false;
        });
      }
    }
  }

  Future<void> sign() async {
    if (!widget.site.loggedIn) {
      await push(context, LoginPage(widget.site));
      if (mounted && widget.site.loggedIn) load();
      return;
    }
    if (busy || data == null) return;
    setState(() => busy = true);
    try {
      final result = await widget.site.signNow(data!.formhash);
      if (mounted) feedback(context, result);
    } catch (e) {
      if (mounted) feedback(context, e);
    }
    if (mounted) {
      setState(() => busy = false);
      load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabHeight = (MediaQuery.textScalerOf(context).scale(14) + 28).clamp(
      48.0,
      double.infinity,
    );
    const tabs = [
      ('today', '今日榜'),
      ('month', '月榜'),
      ('zong', '总榜'),
      ('calendar', '签到日历'),
    ];
    return DefaultTabController(
      length: tabs.length,
      initialIndex: tabs
          .indexWhere((entry) => entry.$1 == tab)
          .clamp(0, tabs.length - 1),
      child: Scaffold(
        appBar: ReviewFrostedAppBar(
          title: const Text('每日签到'),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(tabHeight),
            child: IgnorePointer(
              ignoring: busy,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                onTap: (index) {
                  HapticFeedbackUtil.selection();
                  setState(() {
                    tab = tabs[index].$1;
                    page = 1;
                  });
                  load();
                },
                tabs: [
                  for (final entry in tabs)
                    Tab(height: tabHeight, text: entry.$2),
                ],
              ),
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (busy) const LinearProgressIndicator(),
              if (error != null) Failure(error!, load),
              AppSectionCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (final stat in data?.stats ?? <String>[])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(stat),
                        ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: busy || data?.signed == true ? null : sign,
                        icon: const Icon(Icons.event_available),
                        label: Text(
                          data?.signed == true
                              ? '今日已签到'
                              : widget.site.loggedIn
                              ? '立即签到'
                              : '登录后签到',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (final rank in ranks)
                ListTile(
                  leading: SiteAvatar(
                    uid: rank.uid,
                    name: rank.name,
                    url: rank.avatar.isEmpty
                        ? null
                        : normalizeSiteLink(rank.avatar).toString(),
                  ),
                  title: Text(rank.name),
                  subtitle: Text(rank.detail.replaceFirst(rank.name, '')),
                  onTap: () =>
                      push(context, ProfilePage(widget.site, rank.uid)),
                ),
              if (ranks.isEmpty)
                for (final part in ranking?.parts ?? <Object>[])
                  if (part is String)
                    HtmlContent(
                      part,
                      onLink: (url) => routeLink(context, widget.site, url),
                    ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: busy || page == 1
                        ? null
                        : () {
                            page--;
                            load();
                          },
                    child: const Text('上一页'),
                  ),
                  Text('$page'),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            page++;
                            load();
                          },
                    child: const Text('下一页'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
