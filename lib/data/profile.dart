import 'package:html/parser.dart' as html;

import 'site.dart';
import 'portal.dart';

String? nativeUserProfileId(Uri uri) {
  if (!isSite(uri) ||
      (uri.queryParameters['do'] != null &&
          uri.queryParameters['do'] != 'profile')) {
    return null;
  }
  final uid =
      RegExp(r'^/space-uid-(\d+)').firstMatch(uri.path)?.group(1) ??
      (uri.path == '/home.php' && uri.queryParameters['mod'] == 'space'
          ? uri.queryParameters['uid']
          : null);
  return uid != null && RegExp(r'^[1-9]\d*$').hasMatch(uid) ? uid : null;
}

class UserProfile {
  UserProfile(this.uid, this.space, this.credits, this.source);
  final String uid, source;
  final Map space, credits;
  late final document = html.parse(unwrapPortalHtml(source));
  String value(String key) => textOf(space, key);
  late final header =
      document
          .querySelectorAll('.comiis_space_profile li')
          .any(
            (row) =>
                row.children.any(
                  (child) =>
                      child.localName == 'span' && child.text.trim() == '用户ID',
                ) &&
                row.querySelector('.profile_rs')?.text.trim() == uid,
          )
      ? document.querySelector('.comiis_space_tx')
      : null;
  String get name {
    final visible = header?.querySelector('h2')?.text.trim() ?? '';
    return visible.isEmpty ? value('username') : visible;
  }

  String get url => '$siteOrigin/home.php?mod=space&uid=$uid&do=profile';
  String get avatar {
    final raw =
        header?.querySelector('.user_img img')?.attributes['src'] ??
        discuzAvatarUrl(uid, size: 'middle');
    final uri = normalizeSiteLink(raw);
    return ['http', 'https'].contains(uri.scheme) &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri.toString()
        : discuzAvatarUrl(uid, size: 'middle');
  }

  String get cover {
    final styles = document
        .querySelectorAll('style')
        .map((e) => e.text)
        .join('\n');
    final match = RegExp(
      r'''\.comiis_space_box\s*\{[^}]*background\s*:\s*url\(['"]?([^)'"\s]+)''',
    ).firstMatch(styles);
    return match?.group(1) ?? '';
  }

  String get level {
    final text = header?.querySelector('.kmlv')?.text ?? '';
    final match = RegExp(
      r'\bLv\.\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(text);
    return match == null ? '' : 'Lv.${match.group(1)}';
  }

  Map get _group => space['group'] is Map ? space['group'] as Map : const {};
  String get levelColor => plain(_group['color'] ?? '');
  String get group {
    final visible = header?.querySelector('.kmlev')?.text.trim() ?? '';
    return visible.isEmpty ? plain(_group['grouptitle'] ?? '') : visible;
  }

  String get signature =>
      document
          .querySelector('.profile_face')
          ?.text
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ') ??
      plain(space['sightml'] ?? '');
  String get verification {
    final node = document.querySelector('.comiis_space_profile .comiis_verify');
    final text = node?.text.trim() ?? '';
    if (text.isNotEmpty) return text;
    return node
            ?.querySelectorAll('img')
            .map(
              (image) =>
                  image.attributes['title'] ?? image.attributes['alt'] ?? '',
            )
            .where((s) => s.isNotEmpty)
            .join(' · ') ??
        '';
  }

  List<Map> get medals {
    final value = space['medals'];
    final items = value is List
        ? value
        : value is Map
        ? value.values
        : const [];
    return items.whereType<Map>().toList(growable: false);
  }

  String count(String key) {
    if (key == 'replies') {
      final posts = int.tryParse(value('posts'));
      final threads = int.tryParse(value('threads'));
      return posts == null || threads == null || posts < 0 || threads < 0
          ? '—'
          : '${(posts - threads).clamp(0, posts)}';
    }
    return value(key).isEmpty ? '—' : value(key);
  }

  bool get followed =>
      document.querySelector('#followmod')?.text.contains('取消') == true ||
      document.querySelector('#followmod')?.text.contains('已关注') == true;

  static Uri? action(String source, String uid, String kind) {
    final doc = html.parse(unwrapPortalHtml(source));
    for (final link in doc.querySelectorAll(
      '#followmod, .comiis_space_foot a, a[id^="a_friend_"], a[id^="a_sendpm_"]',
    )) {
      final href = link.attributes['href'] ?? '';
      final candidates = <String>[
        if (!href.startsWith('javascript:')) href,
        for (final match in RegExp(
          r"""['"]((?:https://ycoo\.net/|/)?home\.php\?[^'"\s<>]+)['"]""",
        ).allMatches('$href ${link.attributes['onclick'] ?? ''}'))
          match.group(1)!,
      ];
      for (final candidate in candidates) {
        final uri = normalizeSiteLink(candidate);
        final q = uri.queryParameters;
        if (!isSite(uri) || uri.path != '/home.php' || q['mod'] != 'spacecp') {
          continue;
        }
        final target = q['fuid'] ?? q['touid'] ?? q['uid'];
        if (target != uid ||
            [
              'uid',
              'fuid',
              'touid',
            ].any((key) => q[key] != null && q[key] != uid)) {
          continue;
        }
        final matches = switch (kind) {
          'follow' => q['ac'] == 'follow',
          'friend' => q['ac'] == 'friend' && q['op'] != 'ignore',
          'block' => q['ac'] == 'friend' && q['op'] == 'ignore',
          'poke' => q['ac'] == 'poke',
          'pm' => q['ac'] == 'pm',
          _ => false,
        };
        if (matches) return uri;
      }
    }
    return null;
  }
}

extension UserProfileRequests on Site {
  Future<UserProfile> userProfile(String id) async {
    if (!RegExp(r'^[1-9]\d*$').hasMatch(id)) throw SiteException('无效的用户 ID');
    final epoch = sessionEpoch;
    final results = await Future.wait([
      api('profile', query: {'uid': id}),
      request(
        '/home.php',
        query: {
          'mod': 'space',
          'uid': id,
          'do': 'profile',
          'mobile': 2,
          '_session': DateTime.now().microsecondsSinceEpoch,
        },
      ).then((r) => '${r.data}').catchError((_) => ''),
    ]);
    if (epoch != sessionEpoch) throw SiteException('账户已切换，请重新加载');
    final variables = results[0] as Map;
    final space = variables['space'];
    if (space is! Map ||
        '${space['uid']}' != id ||
        textOf(space, 'username').isEmpty) {
      throw SiteException('站点未返回对应用户的资料');
    }
    return UserProfile(
      id,
      space,
      variables['extcredits'] is Map
          ? variables['extcredits'] as Map
          : const {},
      results[1] as String,
    );
  }
}

class ProfileContentEntry {
  ProfileContentEntry(this.title, this.url, this.image);
  final String title, url, image;
  static List<ProfileContentEntry> parse(String source, String kind) {
    final doc = html.parse(unwrapPortalHtml(source));
    final root = doc.querySelector('.comiis_bodybox, #ct') ?? doc.body!;
    for (final node in root.querySelectorAll(
      '.comiis_sidenv_box, .comiis_leftnv, .comiis_space_box, .comiis_space_foot, script, style',
    )) {
      node.remove();
    }
    final entries = <String, ProfileContentEntry>{};
    final parameter = kind == 'blog' ? 'blogid' : 'albumid';
    for (final link in root.querySelectorAll('a[href]')) {
      final uri = normalizeSiteLink(link.attributes['href']!);
      if (!isSite(uri) ||
          !RegExp(r'^[1-9]\d*$')
              .hasMatch(uri.queryParameters[parameter] ?? '')) {
        continue;
      }
      final image = link.querySelector('img');
      final id = uri.queryParameters[parameter]!;
      final previous = entries[id];
      final title =
          [
            previous?.title ?? '',
            link.text.trim(),
            link.attributes['title'] ?? '',
            image?.attributes['alt'] ?? '',
          ].where((s) => s.isNotEmpty).firstOrNull ??
          '';
      final preview =
          [
            previous?.image ?? '',
            image?.attributes['data-src'] ?? image?.attributes['src'] ?? '',
          ].where((s) => s.isNotEmpty).firstOrNull ??
          '';
      entries[id] = ProfileContentEntry(title, uri.toString(), preview);
    }
    return entries.values
        .map(
          (entry) => entry.title.isNotEmpty
              ? entry
              : ProfileContentEntry(
                  '${kind == 'blog' ? '日志' : '相册'} ${Uri.parse(entry.url).queryParameters[parameter]}',
                  entry.url,
                  entry.image,
                ),
        )
        .toList();
  }
}

List<Topic> profileTopics(
  String source,
  UserProfile user, {
  bool replies = false,
}) {
  try {
    final primary = Site.parseMobileTopics(source).topics;
    if (primary.isNotEmpty) return primary;
  } on SiteException {
    // User spaces may use the standard table layout instead of the feed template.
  }
  final doc = html.parse(unwrapPortalHtml(source));
  final root = doc.querySelector('.comiis_bodybox, #ct') ?? doc.body!;
  for (final node in root.querySelectorAll(
    '.comiis_sidenv_box, .comiis_leftnv, .comiis_space_box, .comiis_space_foot, .comiis_topnv, script, style',
  )) {
    node.remove();
  }
  final result = <Topic>[];
  final seen = <String>{};
  for (final link in root.querySelectorAll('a[href]')) {
    final id = nativeThreadId(normalizeSiteLink(link.attributes['href']!));
    final title = link.attributes['title']?.trim() ?? link.text.trim();
    if (id == null || title.isEmpty || !seen.add(id)) continue;
    var row = link.parent;
    while (row != null && !{'li', 'tr', 'tbody'}.contains(row.localName)) {
      row = row.parent;
    }
    row ??= link.parent;
    final author = row?.querySelector('a[href*="uid"]');
    result.add(
      Topic(
        id: id,
        title: title,
        author: author?.text.trim() ?? (replies ? '' : user.name),
        uid: author == null
            ? (replies ? '' : user.uid)
            : nativeUserProfileId(
                    normalizeSiteLink(author.attributes['href'] ?? ''),
                  ) ??
                  '',
        preview:
            row
                ?.querySelector('.list_body, .list-content, .comiis_pyqtxt')
                ?.text
                .trim() ??
            '',
      ),
    );
  }
  return result;
}
