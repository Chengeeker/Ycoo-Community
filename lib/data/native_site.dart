import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import 'site.dart';
import 'portal.dart';

class NativeForm {
  NativeForm(this.element, this.action, this.method);
  final Element element;
  final Uri action;
  final String method;
  List<Element> get controls => element
      .querySelectorAll('input,textarea,select')
      .where(
        (e) =>
            e.attributes['name']?.isNotEmpty == true &&
            !e.attributes.containsKey('disabled'),
      )
      .toList();
  Map<String, dynamic> values() {
    final result = <String, dynamic>{};
    for (final field in controls) {
      final type = field.attributes['type'];
      if (['submit', 'button', 'file', 'reset'].contains(type)) continue;
      if (['checkbox', 'radio'].contains(type) &&
          !field.attributes.containsKey('checked')) {
        continue;
      }
      final name = field.attributes['name']!;
      final option =
          field.querySelector('option[selected]') ??
          field.querySelector('option');
      final value = field.localName == 'textarea'
          ? field.text
          : field.localName == 'select'
          ? option?.attributes['value'] ?? option?.text ?? ''
          : field.attributes['value'] ?? (type == 'checkbox' ? 'on' : '');
      if (type == 'checkbox' &&
          (name.endsWith('[]') ||
              controls.where((e) => e.attributes['name'] == name).length > 1)) {
        (result.putIfAbsent(name, () => <String>[]) as List<String>).add(value);
      } else {
        result[name] = value;
      }
    }
    return result;
  }
}

class NativePageTab {
  const NativePageTab(this.label, this.uri, {this.selected = false});
  final String label;
  final Uri? uri;
  final bool selected;
}

class NativePageData {
  NativePageData(
    this.parts,
    this.loginRequired,
    this.message, {
    this.adaptationInfo = '',
    this.hasScriptActions = false,
    this.tabs = const [],
  });
  final List<Object> parts;
  final bool loginRequired;
  final String message;
  final String adaptationInfo;
  final bool hasScriptActions;
  final List<NativePageTab> tabs;
  factory NativePageData.parse(String source, Uri base) {
    final doc = html.parse(unwrapPortalHtml(source));
    final root =
        doc.querySelector('.comiis_bodybox, #ct, #messagetext') ?? doc.body!;
    final login = root.querySelector('#loginform') != null;
    final tabs = <NativePageTab>[];
    const knownTabs = [
      {'我的好友', '我的关注', '我的粉丝', '最近来访', '我看过谁', '好友请求', '黑名单'},
      {'圈子话题', '我的话题', '我参与的', '我管理的'},
      {'我的心情', '好友心情', '随便看看'},
      {'我的日志', '好友日志', '随便看看'},
      {'我的相册', '好友相册', '随便看看'},
    ];
    for (final nav in root.querySelectorAll('.comiis_topnv, ul')) {
      final links = nav.querySelectorAll('li a[href]');
      if (links.length < 2) continue;
      if (!nav.classes.contains('comiis_topnv')) {
        final labels = links.map((link) => link.text.trim()).toSet();
        if (!knownTabs.any(
          (group) => labels.length >= 2 && labels.every(group.contains),
        ))
          continue;
      }
      final candidates = <NativePageTab>[];
      for (final link in links) {
        final label = link.text.trim();
        final href = link.attributes['href']?.trim() ?? '';
        if (label.isEmpty) break;
        final selected = const {'f_0', 'active', 'current', 'on', 'a'}.any(
          (name) =>
              link.classes.contains(name) ||
              link.parent?.classes.contains(name) == true,
        );
        Uri? target;
        if (href.startsWith('javascript:') &&
            href.contains('member.php?mod=logging')) {
          target = null;
        } else if ((href.isEmpty || href == '#' || href == 'javascript:;') &&
            selected) {
          target = base;
        } else {
          final parsed = Uri.tryParse(href);
          if (parsed == null ||
              href.isEmpty ||
              href == '#' ||
              href.startsWith('javascript:'))
            break;
          target = normalizeSiteLink(base.resolveUri(parsed).toString());
          if (!isSite(target)) break;
        }
        candidates.add(NativePageTab(label, target, selected: selected));
      }
      if (candidates.length == links.length) {
        tabs.addAll(candidates);
        nav.remove();
        break;
      }
    }
    final scriptActions = root
        .querySelectorAll('[onclick],a[href^="javascript:"]')
        .where(
          (node) =>
              node.localName != 'button' &&
              (node.attributes['onclick']?.trim().isNotEmpty == true ||
                  (node.attributes['href'] ?? '').length > 13),
        )
        .toList();
    final scriptPaths = doc
        .querySelectorAll('script[src]')
        .map((node) => base.resolve(node.attributes['src']!))
        .where((uri) => isSite(uri) && uri.path.startsWith('/source/plugin/'))
        .map((uri) => uri.replace(query: '', fragment: '').toString())
        .toSet()
        .toList();
    final info = jsonEncode({
      'page': base
          .replace(
            queryParameters: {
              for (final entry in base.queryParameters.entries)
                if (const {
                  'id',
                  'mod',
                  'do',
                  'op',
                  'action',
                  'operation',
                  'ac',
                }.contains(entry.key))
                  entry.key: entry.value,
            },
            fragment: '',
          )
          .toString(),
      'scripts': scriptPaths,
      'forms': [
        for (final form in root.querySelectorAll('form'))
          {
            'method': form.attributes['method'] ?? 'get',
            'fields': form
                .querySelectorAll('[name]')
                .map((field) => field.attributes['name'])
                .toSet()
                .toList(),
          },
      ],
      'scriptActions': scriptActions
          .map(
            (node) => RegExp(r'^\s*(?:javascript:)?([a-zA-Z_$][\w.$]*)\s*\(')
                .firstMatch(
                  node.attributes['onclick'] ?? node.attributes['href'] ?? '',
                )
                ?.group(1),
          )
          .whereType<String>()
          .toSet()
          .toList(),
    });
    for (final node in root.querySelectorAll(
      '[hidden],[aria-hidden="true"],[style]',
    )) {
      if (const {'input', 'textarea', 'select'}.contains(node.localName))
        continue;
      final style = node.attributes['style'] ?? '';
      if (node.attributes.containsKey('hidden') ||
          node.attributes['aria-hidden'] == 'true' ||
          RegExp(
            r'(?:^|;)\s*display\s*:\s*none\b',
            caseSensitive: false,
          ).hasMatch(style)) {
        node.remove();
      }
    }
    for (final node in root.querySelectorAll(
      'script,style,link,.comiis_sidenv_box,#comiis_foot_box,#comiis_post_btn,#mask,#comiis_menu_bg,#comiis_alert,.comiis_head,iframe,object,embed',
    )) {
      node.remove();
    }
    final parts = <Object>[];
    final buffer = StringBuffer();
    void flush() {
      if (buffer.isNotEmpty) {
        parts.add(buffer.toString());
        buffer.clear();
      }
    }

    void walk(Node node) {
      if (node is Element && node.localName == 'form') {
        flush();
        final target = base.resolve(
          node.attributes['action']?.isNotEmpty == true
              ? node.attributes['action']!
              : base.toString(),
        );
        if (isSite(target)) {
          parts.add(
            NativeForm(
              node,
              target,
              (node.attributes['method'] ?? 'get').toLowerCase(),
            ),
          );
        }
      } else if (node is Element && node.querySelector('form') != null) {
        for (final child in node.nodes) {
          walk(child);
        }
      } else if (node is Element) {
        buffer.write(node.outerHtml);
      } else if (node is Text) {
        buffer.write(const HtmlEscape().convert(node.text));
      }
    }

    if (!login) {
      for (final node in root.nodes) {
        walk(node);
      }
    }
    flush();
    return NativePageData(
      parts,
      login,
      root.querySelector('#messagetext,.comiis_password_top')?.text.trim() ??
          '',
      adaptationInfo: info,
      hasScriptActions: scriptActions.isNotEmpty,
      tabs: tabs,
    );
  }
}

class SignData {
  SignData(this.stats, this.label, this.formhash);
  final List<String> stats;
  final String label, formhash;
  bool get signed => label.contains('已签到') || label.contains('已签');
  factory SignData.parse(String source) {
    final doc = html.parse(source);
    return SignData(
      doc
          .querySelectorAll('.comiis_qdinfo li')
          .map((e) => e.text.trim())
          .toList(),
      doc.querySelector('#signresult')?.text.trim() ?? '签到',
      RegExp(r'operation=qiandao[^"\s]*formhash=([a-zA-Z0-9]{8})')
              .firstMatch(source)
              ?.group(1) ??
          Site.parseWebSession(source)?['formhash'] as String? ??
          '',
    );
  }
}

class SignRank {
  SignRank(this.uid, this.name, this.detail, this.avatar);
  final String uid, name, detail, avatar;
  static List<SignRank> parse(String source) => html
      .parse(unwrapPortalHtml(source))
      .querySelectorAll('tbody[id^="autolist_"]')
      .map(
        (row) => SignRank(
          row.id.replaceFirst('autolist_', ''),
          row.querySelector('h4 a')?.text.trim() ?? '',
          row.querySelector('.k_misign_lc')?.text.trim() ?? '',
          row.querySelector('img')?.attributes['src'] ?? '',
        ),
      )
      .where((entry) => entry.name.isNotEmpty)
      .toList();
}

extension NativeSiteActions on Site {
  Future<String> signNow(String hash) async {
    if (!loggedIn) throw SiteException('请先登录');
    if (!RegExp(r'^[a-zA-Z0-9]{8}$').hasMatch(hash)) {
      throw SiteException('未能确认签到凭据，请刷新后重试');
    }
    final response = await request(
      '/plugin.php',
      query: {
        'id': 'k_misign:sign',
        'operation': 'qiandao',
        'format': 'text',
        'formhash': hash,
        '_session': DateTime.now().microsecondsSinceEpoch,
        'mobile': 2,
      },
    );
    return plain(unwrapPortalHtml('${response.data}')).trim();
  }
}
