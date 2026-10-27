import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html;
import 'package:shared_preferences/shared_preferences.dart';

import 'portal.dart';

const siteOrigin = 'https://ycoo.net';
const siteMobileUserAgent =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36';
const siteUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';
String plain(Object? value) => html.parseFragment('$value').text ?? '';
String textOf(Map data, String key) => plain(data[key] ?? '');
int number(Object? value) => int.tryParse('$value') ?? 0;
Uri siteUri(String path) => Uri.parse('$siteOrigin/').resolve(path);
String discuzAvatarUrl(String uid, {String size = 'small'}) {
  if (!RegExp(r'^\d{1,9}$').hasMatch(uid) || int.tryParse(uid) == 0) return '';
  final id = uid.padLeft(9, '0');
  return siteUri(
    'data/avatar/${id.substring(0, 3)}/${id.substring(3, 5)}/${id.substring(5, 7)}/${id.substring(7)}_avatar_$size.jpg',
  ).toString();
}

Map<String, String> siteImageHeaders(String url, {String cookie = ''}) {
  final uri = Uri.tryParse(url);
  final sameSite = uri != null && isSite(uri);
  return {
    'User-Agent': siteUserAgent,
    if (sameSite) 'Referer': '$siteOrigin/',
    if (sameSite && cookie.isNotEmpty) 'Cookie': cookie,
  };
}

bool isSite(Uri uri) =>
    uri.scheme == 'https' &&
    uri.host == 'ycoo.net' &&
    uri.port == 443 &&
    uri.userInfo.isEmpty;

Uri normalizeSiteLink(String value) {
  final parsed = Uri.tryParse(value.trim());
  if (parsed == null) return Uri(scheme: 'invalid');
  final uri = Uri.parse('$siteOrigin/').resolveUri(parsed);
  return uri.scheme == 'http' &&
          uri.host == 'ycoo.net' &&
          uri.userInfo.isEmpty &&
          uri.port == 80
      ? uri.replace(scheme: 'https')
      : uri;
}

String? nativeThreadId(Uri uri) => isSite(uri)
    ? RegExp(r'^/thread-(\d+)-').firstMatch(uri.path)?.group(1) ??
          (uri.path == '/forum.php' &&
                  uri.queryParameters['mod'] == 'viewthread' &&
                  RegExp(r'^\d+$').hasMatch(uri.queryParameters['tid'] ?? '')
              ? uri.queryParameters['tid']
              : null)
    : null;

bool isDirectForumImage(Uri uri) =>
    ['http', 'https'].contains(uri.scheme) &&
    uri.userInfo.isEmpty &&
    uri.host.isNotEmpty &&
    RegExp(
      r'\.(png|jpe?g|gif|webp|avif|bmp)$',
      caseSensitive: false,
    ).hasMatch(uri.path);

class SiteException implements Exception {
  SiteException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LoginWebRequired extends SiteException {
  LoginWebRequired() : super('站点返回了网页登录页面，请在网页中完成登录');
}

class Topic {
  const Topic({
    required this.id,
    required this.title,
    this.author = '',
    this.uid = '',
    this.forum = '',
    this.fid = '',
    this.time = '',
    this.replies = '',
    this.views = '',
    this.preview = '',
    this.avatar = '',
    this.pinned = false,
    this.images = const [],
    this.likes = '',
    this.level = '',
    this.levelColor = '',
    this.gender = '',
    this.verificationIcon = '',
    this.verificationLabel = '',
  });
  final String id,
      title,
      author,
      uid,
      forum,
      fid,
      time,
      replies,
      views,
      preview,
      avatar;
  final bool pinned;
  final List<String> images;
  final String likes,
      level,
      levelColor,
      gender,
      verificationIcon,
      verificationLabel;
  factory Topic.fromJson(Map data) {
    final uid = '${data['authorid'] ?? ''}';
    final avatar = textOf(data, 'avatar');
    return Topic(
      id: '${data['tid'] ?? data['id'] ?? ''}',
      title: textOf(data, 'subject'),
      author: textOf(data, 'author'),
      uid: uid,
      forum: textOf(data, 'forumname'),
      fid: '${data['fid'] ?? ''}',
      time: textOf(data, 'dateline'),
      replies: '${data['replies'] ?? ''}',
      views: '${data['views'] ?? ''}',
      preview: textOf(data, 'message'),
      avatar: avatar.isEmpty
          ? discuzAvatarUrl(uid)
          : siteUri(avatar).toString(),
      pinned: number(data['displayorder']) > 0,
      images: (data['images'] as List? ?? []).whereType<String>().toList(),
      likes: textOf(data, 'likes'),
      level: textOf(data, 'level'),
      levelColor: textOf(data, 'levelColor'),
      gender: textOf(data, 'gender'),
      verificationIcon: textOf(data, 'verificationIcon'),
      verificationLabel: textOf(data, 'verificationLabel'),
    );
  }
  Map<String, dynamic> toJson() => {
    'tid': id,
    'subject': title,
    'author': author,
    'authorid': uid,
    'forumname': forum,
    'fid': fid,
    'dateline': time,
    'replies': replies,
    'views': views,
    'avatar': avatar,
    'message': preview,
    'displayorder': pinned ? 1 : 0,
    'images': images,
    'likes': likes,
    'level': level,
    'levelColor': levelColor,
    'gender': gender,
    'verificationIcon': verificationIcon,
    'verificationLabel': verificationLabel,
  };
}

class TopicBatch {
  TopicBatch(
    this.topics,
    this.hasMore, {
    this.types = const {},
    this.next,
    this.portal,
  });
  final List<Topic> topics;
  final bool hasMore;
  final Map<String, String> types;
  final String? next;
  final PortalData? portal;
}

List<Topic> mergeForumSummaries(List<Topic> mobile, List<Topic> api) {
  final byId = {for (final topic in api) topic.id: topic};
  return mobile.map((topic) {
    final summary = byId[topic.id];
    if (summary == null) return topic;
    return Topic(
      id: topic.id,
      title: topic.title.isNotEmpty ? topic.title : summary.title,
      author: topic.author.isNotEmpty ? topic.author : summary.author,
      uid: topic.uid.isNotEmpty ? topic.uid : summary.uid,
      forum: topic.forum.isNotEmpty ? topic.forum : summary.forum,
      fid: topic.fid.isNotEmpty ? topic.fid : summary.fid,
      time: topic.time.isNotEmpty ? topic.time : summary.time,
      replies: topic.replies.isNotEmpty ? topic.replies : summary.replies,
      views: topic.views.isNotEmpty ? topic.views : summary.views,
      preview: topic.preview.isNotEmpty ? topic.preview : summary.preview,
      avatar: topic.avatar.isNotEmpty ? topic.avatar : summary.avatar,
      pinned: topic.pinned || summary.pinned,
      images: topic.images.isNotEmpty ? topic.images : summary.images,
      likes: topic.likes.isNotEmpty ? topic.likes : summary.likes,
      level: topic.level.isNotEmpty ? topic.level : summary.level,
      levelColor: topic.levelColor.isNotEmpty
          ? topic.levelColor
          : summary.levelColor,
      gender: topic.gender.isNotEmpty ? topic.gender : summary.gender,
      verificationIcon: topic.verificationIcon.isNotEmpty
          ? topic.verificationIcon
          : summary.verificationIcon,
      verificationLabel: topic.verificationLabel.isNotEmpty
          ? topic.verificationLabel
          : summary.verificationLabel,
    );
  }).toList();
}

class Site extends ChangeNotifier {
  Site(this.prefs);
  final SharedPreferences prefs;
  Map<String, String> forumStatistics = {};
  static const cookies = MethodChannel('ycoo.net.php/session');
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: siteOrigin,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      followRedirects: false,
      headers: {
        // The site's Android template lacks the topic markup parsed natively.
        'User-Agent': siteUserAgent,
        'Referer': '$siteOrigin/',
      },
    ),
  );
  String uid = '0', username = '', formhash = '', avatar = '';
  int sessionEpoch = 0;
  bool get loggedIn => uid != '0' && uid.isNotEmpty;
  Future<Response<dynamic>> request(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? data,
    int redirects = 0,
  }) async {
    final generation = sessionEpoch;
    final uri = siteUri(path);
    if (!isSite(uri)) throw SiteException('不支持的站点地址');
    String cookie = '';
    try {
      cookie =
          await cookies.invokeMethod<String>('getCookies', {
            'url': uri.toString(),
          }) ??
          '';
    } on MissingPluginException {
      /* Pure parser tests have no Android cookie store. */
    }
    try {
      final multipart =
          data?.values.any((value) => value is MultipartFile) == true;
      final response = await dio.request<dynamic>(
        uri.toString(),
        queryParameters: query,
        data: multipart
            ? FormData.fromMap(
                data!.map(
                  (key, value) => MapEntry(
                    key,
                    value is MultipartFile ? value.clone() : value,
                  ),
                ),
              )
            : data,
        options: Options(
          method: data == null ? 'GET' : 'POST',
          contentType: data == null
              ? null
              : multipart
              ? Headers.multipartFormDataContentType
              : Headers.formUrlEncodedContentType,
          headers: {
            if (query?.containsKey('_session') == true ||
                uri.queryParameters.containsKey('_session'))
              'Cache-Control': 'no-cache, no-store',
            if ('${query?['mobile'] ?? uri.queryParameters['mobile']}' == '2' ||
                uri.path.startsWith('/api/mobile/'))
              'User-Agent': siteMobileUserAgent,
            if (cookie.isNotEmpty) 'Cookie': cookie,
          },
          validateStatus: (status) =>
              status != null && status >= 200 && status < 400,
        ),
      );
      if (generation != sessionEpoch) throw SiteException('账户已切换，请重新加载');
      final set = response.headers['set-cookie'] ?? [];
      if (set.isNotEmpty) {
        try {
          await cookies.invokeMethod('setCookies', {
            'url': response.realUri.toString(),
            'cookies': set,
          });
        } on MissingPluginException {
          /* See above. */
        }
      }
      if ((response.statusCode ?? 200) >= 300) {
        final location = response.headers.value('location');
        if (location == null || redirects >= 3) throw SiteException('站点跳转失败');
        final target = response.realUri.resolve(location);
        if (!isSite(target)) throw SiteException('站点要求跳转外部页面，请使用原站入口');
        return await request(target.toString(), redirects: redirects + 1);
      }
      return response;
    } on DioException catch (e) {
      throw SiteException(
        e.response?.statusCode == null
            ? '连接源社区失败，请检查网络后重试。部分线路可能无法访问该站。'
            : '服务器返回 ${e.response!.statusCode}，请稍后重试',
      );
    }
  }

  Future<Map<String, dynamic>> api(
    String module, {
    Map<String, dynamic> query = const {},
    Map<String, dynamic>? data,
  }) async {
    final response = await request(
      '/api/mobile/index.php',
      query: {'version': '4', 'module': module, ...query},
      data: data,
    );
    dynamic body = response.data;
    if (body is String) {
      try {
        body = jsonDecode(body.trim().replaceFirst(RegExp(r'^\uFEFF'), ''));
      } catch (_) {
        if (module == 'login') throw LoginWebRequired();
        throw SiteException('站点未返回可识别的数据，请尝试原站页面');
      }
    }
    if (body is! Map || body['Variables'] is! Map) {
      if (module == 'login') {
        final message = body is Map ? body['Message'] : null;
        if (message is Map && message['messagestr'] != null) {
          throw SiteException(plain(message['messagestr']));
        }
        throw LoginWebRequired();
      }
      throw SiteException('站点接口暂不可用');
    }
    final vars = Map<String, dynamic>.from(body['Variables'] as Map);
    if (vars['formhash'] != null) formhash = '${vars['formhash']}';
    final message = body['Message'];
    if (message is Map) {
      final code = '${message['messageval']}';
      if (!code.contains('succeed') && !code.contains('success')) {
        if (code.contains('login') || code.contains('to_login')) {
          throw SiteException('请先登录源社区');
        }
        throw SiteException(plain(message['messagestr'] ?? code));
      }
    }
    if (data != null &&
        const {'newthread', 'sendreply', 'favthread'}.contains(module)) {
      final code = message is Map ? '${message['messageval']}' : '';
      if (!code.contains('succeed') && !code.contains('success')) {
        throw SiteException('服务器尚未确认操作成功，请在原站核对');
      }
    }
    return vars;
  }

  Future<List<Map<String, dynamic>>> forums() async {
    final v = await api('forumindex');
    final categories = <String, String>{};
    final order = <String, int>{};
    for (final category in (v['catlist'] as List? ?? []).whereType<Map>()) {
      for (final id in (category['forums'] as List? ?? [])) {
        categories['$id'] = plain(category['name']);
        order['$id'] = order.length;
      }
    }
    try {
      final response = await request(
        '/forum.php',
        query: {'forumlist': 1, 'mobile': 2},
      );
      final doc = html.parse('${response.data}');
      forumStatistics = {
        for (final item in doc.querySelectorAll('.comiis_forum_tj li'))
          item.querySelector('span')?.text.trim() ?? '':
              item.querySelector('em')?.text.trim() ?? '',
      }..removeWhere((key, value) => key.isEmpty || value.isEmpty);
    } catch (_) {
      forumStatistics = {};
    }
    final result = (v['forumlist'] as List? ?? [])
        .whereType<Map>()
        .map(
          (e) => {
            ...Map<String, dynamic>.from(e),
            'category': categories['${e['fid']}'] ?? '其他版块',
          },
        )
        .toList();
    result.sort(
      (a, b) =>
          (order['${a['fid']}'] ?? 999).compareTo(order['${b['fid']}'] ?? 999),
    );
    return result;
  }

  Future<TopicBatch> topics({
    String? fid,
    String view = 'newthread',
    int page = 1,
    String? type,
  }) async {
    if (fid != null) {
      final v = await api(
        'forumdisplay',
        query: {'fid': fid, 'page': page, if (type != null) 'typeid': type},
      );
      final rows = (v['forum_threadlist'] as List? ?? [])
          .whereType<Map>()
          .toList();
      final types = v['threadtypes'] is Map
          ? (v['threadtypes'] as Map)['types']
          : null;
      final mobile = await request(
        '/forum.php',
        query: {
          'mod': 'forumdisplay',
          'fid': fid,
          'page': page,
          'mobile': 2,
          if (type != null) 'typeid': type,
        },
      );
      final mobileBatch = parseMobileTopics('${mobile.data}', page: page);
      final summaries = rows.map(Topic.fromJson).toList();
      return TopicBatch(
        mobileBatch.topics.isNotEmpty
            ? mergeForumSummaries(mobileBatch.topics, summaries)
            : summaries,
        mobileBatch.topics.isNotEmpty
            ? mobileBatch.hasMore
            : page * number(v['tpp']) <
                  number((v['forum'] as Map?)?['threads']),
        types: types is Map
            ? types.map((k, v) => MapEntry('$k', plain(v)))
            : {},
      );
    }
    const followPages = {
      'following': (45, 'user'),
      'following_forums': (46, 'bbs'),
      'following_friends': (47, 'friend'),
    };
    if (followPages.containsKey(view)) {
      if (!loggedIn) {
        throw SiteException('登录后查看关注动态');
      }
      final (pid, operation) = followPages[view]!;
      final response = await request(
        '/plugin.php',
        query: {
          'id': 'comiis_app_portal',
          'pid': pid,
          'page': page,
          if (page == 1) 'comiis_list': 'yes',
          if (page > 1) 'op': operation,
          'inajax': 1,
          'mobile': 2,
        },
      );
      return parseMobileTopics('${response.data}', page: page);
    }
    if (['portal', 'circles'].contains(view)) {
      final pid = {'portal': 28, 'circles': 72}[view]!;
      final responses = await Future.wait([
        request(
          '/plugin.php',
          query: {
            'id': 'comiis_app_portal',
            'pid': pid,
            'page': page,
            if (page == 1) 'comiis_list': 'yes',
            'inajax': 1,
            'mobile': 2,
          },
        ),
        if (page == 1)
          request(
            '/plugin.php',
            query: {
              'id': 'comiis_app_portal',
              'pid': pid,
              'istab': 'yes',
              'inajax': 1,
              'mobile': 2,
            },
          ),
      ]);
      return parseMobileTopics(
        '${responses.first.data}',
        page: page,
        portal: page == 1 ? PortalData.parse('${responses.last.data}') : null,
      );
    }
    final r = await request(
      '/forum.php',
      query: {
        'mod': 'guide',
        'view': view,
        'page': page,
        'index': 1,
        'mobile': 2,
      },
    );
    return parseMobileTopics('${r.data}', page: page);
  }

  static TopicBatch parseMobileTopics(
    String source, {
    int page = 1,
    PortalData? portal,
  }) {
    final body = unwrapPortalHtml(source);
    final doc = html.parse(body);
    final topics = <Topic>[];
    final seen = <String>{};
    for (final link in doc.querySelectorAll('#comiis_displayorder a[href]')) {
      final uri = siteUri(link.attributes['href']!);
      final id =
          RegExp(r'thread-(\d+)').firstMatch(uri.path)?.group(1) ??
          uri.queryParameters['tid'];
      if (id == null || !seen.add(id)) continue;
      topics.add(
        Topic(
          id: id,
          title: link.text.trim().replaceFirst(RegExp(r'^置顶\s*'), ''),
          pinned: true,
        ),
      );
    }
    for (final row in doc.querySelectorAll('li.forumlist_li')) {
      final link = row.querySelector(
        '.mmlist_li_box h2 a, .forumlist_li_box h2 a',
      );
      final id = RegExp(r'thread-(\d+)')
          .firstMatch(link?.attributes['href'] ?? '')
          ?.group(1);
      if (link == null || id == null || !seen.add(id)) continue;
      final author = row.querySelector('.top_user');
      final authorUri = siteUri(author?.attributes['href'] ?? '');
      final uid =
          authorUri.queryParameters['uid'] ??
          RegExp(r'uid-(\d+)').firstMatch(authorUri.path)?.group(1) ??
          '';
      final forum = row.querySelector('.comiis_xznalist_bk a[href*="forum-"]');
      final level = row.querySelector('.top_lev');
      final gender = row.querySelector('.top_gender');
      final verification = row.querySelector('.comiis_verify img');
      final verificationSource = verification?.attributes['src'] ?? '';
      final verificationPath = Uri.tryParse(verificationSource);
      final verificationUri = verificationPath == null
          ? null
          : Uri.parse('$siteOrigin/').resolveUri(verificationPath);
      final counts = row.querySelectorAll('.comiis_xznalist_bottom > ul > li');
      final images = row
          .querySelectorAll('.mmlist_li_box img, .forumlist_li_box img')
          .map(
            (image) =>
                image.attributes['file'] ??
                image.attributes['data-src'] ??
                image.attributes['src'] ??
                '',
          )
          .where((url) => url.isNotEmpty)
          .map((url) => siteUri(url).toString())
          .toSet()
          .toList();
      topics.add(
        Topic(
          id: id,
          title: link.text.trim().replaceFirst(RegExp(r'^置顶\s*'), ''),
          pinned: link.querySelector('.bg_del')?.text.contains('置顶') == true,
          author: author?.text.trim() ?? '',
          uid: uid,
          avatar: siteUri(
            row.querySelector('.top_tximg')?.attributes['src'] ??
                './data/avatar/noavatar.svg',
          ).toString(),
          level: level?.text.trim() ?? '',
          levelColor:
              RegExp(r'background(?:-color)?\s*:\s*(#[0-9a-fA-F]{6})\b')
                  .firstMatch(level?.attributes['style'] ?? '')
                  ?.group(1) ??
              (level?.classes.contains('bg_a') == true ? '#FF9900' : ''),
          gender: gender?.classes.contains('bg_boy') == true
              ? 'male'
              : gender?.classes.contains('bg_girl') == true
              ? 'female'
              : '',
          verificationIcon:
              verificationSource.isNotEmpty &&
                  verificationUri != null &&
                  isSite(verificationUri)
              ? verificationUri.toString()
              : '',
          verificationLabel:
              verification?.attributes['title'] ??
              verification?.attributes['alt'] ??
              '',
          forum: forum?.text.trim() ?? '',
          fid:
              RegExp(r'forum-(\d+)')
                  .firstMatch(forum?.attributes['href'] ?? '')
                  ?.group(1) ??
              '',
          time: row.querySelector('.forumlist_li_time')?.text.trim() ?? '',
          preview: row.querySelector('.list_body')?.text.trim() ?? '',
          images: images,
          likes: counts.isNotEmpty
              ? counts[0].querySelector('span')?.text.trim() ?? ''
              : '',
          replies: counts.length > 1
              ? counts[1].querySelector('span')?.text.trim() ?? ''
              : '',
          views: counts.length > 2
              ? counts[2].querySelector('span')?.text.trim() ?? ''
              : '',
        ),
      );
    }
    if (topics.isEmpty &&
        !body.contains('comiis_') &&
        !body.contains('没有') &&
        !body.contains('暂无')) {
      throw SiteException(
        doc.querySelector('#messagetext')?.text.trim() ?? '无法读取移动版内容，请重试',
      );
    }
    final maxPage = int.tryParse(
      RegExp(r'comiis_page(?:_list_\d+)?\s*<\s*(\d+)')
              .firstMatch(body)
              ?.group(1) ??
          '',
    );
    return TopicBatch(
      topics,
      topics.isNotEmpty && (maxPage == null ? page < 50 : page < maxPage),
      portal: portal,
    );
  }

  static TopicBatch parseGuide(String source, {bool portal = false}) {
    final doc = html.parse(source);
    final topics = <Topic>[];
    final selector = portal
        ? '#portal_block_677_content .kmlist'
        : '#threadlisttableid .kmlist';
    for (final row in doc.querySelectorAll(selector)) {
      final link = row.querySelector('a.kmtit');
      final id = RegExp(r'thread-(\d+)')
          .firstMatch(link?.attributes['href'] ?? '')
          ?.group(1);
      if (id == null) continue;
      final user = row.querySelector('.kmfoot a[href*="uid"]');
      final forum = row.querySelector('.kmfoot a[href*="forum-"]');
      final uid =
          RegExp(r'uid-(\d+)')
              .firstMatch(user?.attributes['href'] ?? '')
              ?.group(1) ??
          '';
      final avatar = user?.querySelector('img')?.attributes['src'];
      topics.add(
        Topic(
          id: id,
          title:
              row.querySelector('.km_subject')?.text.trim() ??
              (link!.attributes['title']?.isNotEmpty == true
                  ? link.attributes['title']!
                  : link.text.trim()),
          author: user?.text.trim() ?? '',
          uid: uid,
          avatar: avatar == null
              ? discuzAvatarUrl(uid)
              : siteUri(avatar).toString(),
          forum: forum?.text ?? '',
          fid:
              RegExp(r'forum-(\d+)')
                  .firstMatch(forum?.attributes['href'] ?? '')
                  ?.group(1) ??
              '',
          time: row.querySelector('.kmtime')?.text.trim() ?? '',
          replies: row.querySelector('.kmpl')?.text ?? '',
          views: row.querySelector('.kmck')?.text ?? '',
        ),
      );
    }
    if (topics.isEmpty &&
        doc.querySelector(
              portal ? '#portal_block_677_content' : '#threadlisttableid',
            ) ==
            null) {
      throw SiteException(
        doc.querySelector('#messagetext')?.text.trim() ?? '暂时无法读取导读，请重试或打开原站',
      );
    }
    return TopicBatch(topics, !portal && doc.querySelector('.pg .nxt') != null);
  }

  Future<TopicBatch> search(String keyword, {String? next}) async {
    final response = next == null
        ? await request(
            '/plugin.php',
            query: {
              'id': 'twpx_xunsearch',
              'q': keyword,
              's': 'relevance',
              'syn': 'yes',
            },
          )
        : await request(next);
    return parseSearch('${response.data}', response.realUri);
  }

  static TopicBatch parseSearch(String source, Uri base) {
    final doc = html.parse(source);
    final found = <Topic>[];
    for (final heading in doc.querySelectorAll('.result-list dt')) {
      final a = heading.querySelector('a');
      if (a == null) continue;
      final uri = base.resolve(a.attributes['href'] ?? '');
      final id = uri.queryParameters['tid'];
      if (id == null || !isSite(uri)) continue;
      a.querySelector('small')?.remove();
      final detail = heading.nextElementSibling;
      final author = detail?.querySelector('.field-info a[href*="uid="]');
      final forum = detail?.querySelector('.field-info a[href*="fid="]');
      final preview =
          detail
              ?.querySelectorAll('p')
              .where(
                (e) =>
                    !e.classes.contains('field-info') &&
                    e.text.trim().isNotEmpty,
              )
              .firstOrNull
              ?.text
              .trim() ??
          '';
      found.add(
        Topic(
          id: id,
          title: a.text.trim().replaceFirst(RegExp(r'^\d+\s+'), ''),
          author: author?.text ?? '',
          uid:
              siteUri(author?.attributes['href'] ?? '')
                  .queryParameters['uid'] ??
              '',
          forum: forum?.text ?? '',
          preview: preview,
        ),
      );
    }
    if (doc.querySelector('.result-list') == null &&
        !source.contains('没有找到') &&
        !source.contains('没有搜索到')) {
      throw SiteException(
        doc.querySelector('#messagetext')?.text.trim() ?? '搜索页面暂不可用，请打开原站搜索',
      );
    }
    final current = number(base.queryParameters['p']) == 0
        ? 1
        : number(base.queryParameters['p']);
    final next = doc
        .querySelectorAll('.pagination a[href]')
        .map((e) => base.resolve(e.attributes['href']!))
        .where(
          (uri) =>
              isSite(uri) && number(uri.queryParameters['p']) == current + 1,
        )
        .firstOrNull;
    return TopicBatch(found, next != null, next: next?.toString());
  }

  Future<void> syncSession() async {
    final generation = sessionEpoch;
    Map<String, dynamic>? vars;
    LoginWebRequired? verification;
    try {
      vars = await api(
        'login',
        query: {'_session': DateTime.now().microsecondsSinceEpoch},
      );
    } on LoginWebRequired catch (e) {
      verification = e;
    }
    if (vars == null || number(vars['member_uid']) == 0) {
      final response = await request(
        '/home.php',
        query: {
          'mod': 'space',
          'do': 'profile',
          'mycenter': 1,
          'mobile': 2,
          '_session': DateTime.now().microsecondsSinceEpoch,
        },
      );
      final viewer = parseWebSession('${response.data}');
      if (viewer != null) vars = {...?vars, ...viewer};
    }
    if (generation != sessionEpoch) throw SiteException('账户已切换，请重新加载');
    if (vars == null) throw verification ?? LoginWebRequired();
    await _completeSessionName(vars);
    if (generation != sessionEpoch) throw SiteException('账户已切换，请重新加载');
    _applySession(vars);
  }

  Future<void> syncSessionFromWeb() async {
    final generation = sessionEpoch;
    final response = await request(
      '/home.php',
      query: {
        'mod': 'space',
        'do': 'profile',
        'mycenter': 1,
        'mobile': 2,
        '_session': DateTime.now().microsecondsSinceEpoch,
      },
    );
    final viewer = parseWebSession('${response.data}');
    if (generation != sessionEpoch) throw SiteException('账户已切换，请重新加载');
    if (viewer != null && number(viewer['member_uid']) > 0) {
      await _completeSessionName(viewer);
      if (generation != sessionEpoch) throw SiteException('账户已切换，请重新加载');
      _applySession(viewer);
    } else {
      await syncSession();
    }
  }

  Future<void> _completeSessionName(Map<String, dynamic> vars) async {
    final id = '${vars['member_uid'] ?? '0'}';
    if (number(id) == 0 || textOf(vars, 'member_username').isNotEmpty) return;
    if (id == uid && username.isNotEmpty) {
      vars['member_username'] = username;
      return;
    }
    try {
      final profile = await api('profile', query: {'uid': id});
      final space = profile['space'];
      if (space is Map && '${space['uid'] ?? id}' == id) {
        vars['member_username'] = textOf(space, 'username');
      }
    } on SiteException {
      /* Keep the verified identity if profile metadata is unavailable. */
    }
  }

  void _applySession(Map<String, dynamic> vars) {
    final nextUid = '${vars['member_uid'] ?? '0'}';
    final nextName = textOf(vars, 'member_username');
    final changed = uid != nextUid || username != nextName;
    uid = nextUid;
    username = nextName;
    final memberAvatar = textOf(vars, 'member_avatar');
    avatar = memberAvatar.isEmpty
        ? discuzAvatarUrl(uid)
        : siteUri(memberAvatar).toString();
    if (vars['formhash'] != null) formhash = '${vars['formhash']}';
    if (changed) {
      sessionEpoch++;
      notifyListeners();
    }
  }

  static Map<String, dynamic>? parseWebSession(String source) {
    final doc = html.parse(source);
    final scripts = doc
        .querySelectorAll('script')
        .map((s) => s.text)
        .join('\n');
    final id = RegExp(r'''\bdiscuz_uid\s*=\s*['"](\d+)['"]''')
        .firstMatch(scripts)
        ?.group(1);
    if (id == null) return null;
    final name =
        doc
            .querySelector('.comiis_user_name, .comiis_myname, .vwmy')
            ?.text
            .trim() ??
        '';
    final hash =
        doc.querySelector('input[name="formhash"]')?.attributes['value'] ??
        RegExp(r'''\bformhash\s*=\s*['"]([a-zA-Z0-9]{8})['"]''')
            .firstMatch(scripts)
            ?.group(1) ??
        doc
            .querySelectorAll('a[href]')
            .map(
              (a) =>
                  Uri.tryParse(a.attributes['href']!)
                      ?.queryParameters['formhash'],
            )
            .whereType<String>()
            .where((hash) => RegExp(r'^[a-zA-Z0-9]{8}$').hasMatch(hash))
            .firstOrNull;
    return {
      'member_uid': id,
      'member_username': name,
      'member_avatar': discuzAvatarUrl(id),
      if (hash != null) 'formhash': hash,
    };
  }

  Future<String?> maybeAutoSignIn() async {
    if (!loggedIn || prefs.getBool('autoSignIn') != true) return null;
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    final key = 'signIn.$uid.date';
    if (prefs.getString(key) == today) return null;
    if (formhash.isEmpty) await syncSession();
    if (!loggedIn || !RegExp(r'^[a-zA-Z0-9]{8}$').hasMatch(formhash)) {
      return '未能确认签到凭据，请打开每日签到';
    }
    final response = await request(
      '/plugin.php',
      query: {
        'id': 'k_misign:sign',
        'operation': 'qiandao',
        'format': 'text',
        'formhash': formhash,
      },
    );
    final message = plain(unwrapPortalHtml('${response.data}')).trim();
    if (message.contains('签到成功') ||
        message.contains('已经签到') ||
        message.contains('已签到') ||
        message.contains('今日已签')) {
      await prefs.setString(key, today);
      return message;
    }
    return message.isEmpty ? '签到结果未确认，请打开每日签到查看' : message;
  }

  Future<void> login(
    String user,
    String password, {
    String question = '0',
    String answer = '',
  }) async {
    sessionEpoch++;
    await syncSession();
    try {
      await api(
        'login',
        query: {'loginsubmit': 'yes', 'loginfield': 'auto'},
        data: {
          'username': user,
          'password': password,
          'questionid': question,
          'answer': answer,
          'cookietime': '2592000',
          'formhash': formhash,
        },
      );
    } on LoginWebRequired {
      await syncSessionFromWeb();
      if (!loggedIn) rethrow;
    }
    await syncSession();
    if (!loggedIn) throw SiteException('登录未完成，请使用网页登录完成验证码或安全验证');
    await clearContentCache();
  }

  Future<void> logout() async {
    sessionEpoch++;
    final account = uid;
    await cookies.invokeMethod('clearCookies');
    uid = '0';
    username = '';
    formhash = '';
    avatar = '';
    await clearContentCache();
    for (final key
        in prefs
            .getKeys()
            .where((k) => k.startsWith('draft.$account.'))
            .toList()) {
      await prefs.remove(key);
    }
    await prefs.remove('history.$account');
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    notifyListeners();
  }

  Future<void> clearContentCache() async {
    for (final k
        in prefs.getKeys().where((k) => k.startsWith('cache.')).toList()) {
      await prefs.remove(k);
    }
  }

  List<Topic> history() {
    try {
      return (jsonDecode(prefs.getString('history.$uid') ?? '[]') as List)
          .whereType<Map>()
          .map(Topic.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> remember(Topic topic) async {
    final list = history()..removeWhere((e) => e.id == topic.id);
    await prefs.setString(
      'history.$uid',
      jsonEncode([topic, ...list].take(200).map((e) => e.toJson()).toList()),
    );
  }
}
