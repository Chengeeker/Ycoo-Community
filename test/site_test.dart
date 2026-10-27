import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuan_community/data/site.dart';

class Adapter implements HttpClientAdapter {
  Adapter(this.handle);
  final Future<ResponseBody> Function(RequestOptions) handle;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handle(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody body(Map data) => ResponseBody.fromString(
  jsonEncode(data),
  200,
  headers: {
    'content-type': ['application/json'],
  },
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Site site;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    site = Site(await SharedPreferences.getInstance());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          Site.cookies,
          (call) async => call.method == 'getCookies' ? '' : null,
        );
  });
  test('real guide and portal preserve full title and pagination', () {
    final guide = Site.parseGuide(
      File('test/fixtures/guide.html').readAsStringSync(),
    );
    final portal = Site.parseGuide(
      File('test/fixtures/portal.html').readAsStringSync(),
      portal: true,
    );
    expect(guide.topics.length, 1);
    expect(guide.hasMore, true);
    expect(portal.topics.single.id, guide.topics.single.id);
    expect(portal.topics.single.title, guide.topics.single.title);
    expect(portal.topics.single.forum, '游戏专区');
    expect(portal.hasMore, false);
  });
  test(
    'login accepts BOM JSON and routes HTML verification explicitly',
    () async {
      site.dio.httpClientAdapter = Adapter(
        (options) async => ResponseBody.fromString(
          '\uFEFF{"Variables":{"member_uid":"0"}}',
          200,
          headers: {
            'content-type': ['text/plain'],
          },
        ),
      );
      await site.syncSession();
      expect(site.loggedIn, isFalse);
      site.dio.httpClientAdapter = Adapter(
        (options) async => ResponseBody.fromString(
          '<html><form>验证码登录</form></html>',
          200,
          headers: {
            'content-type': ['text/html'],
          },
        ),
      );
      await expectLater(site.syncSession(), throwsA(isA<LoginWebRequired>()));
    },
  );
  test(
    'HTML login success checks session before treating it as a challenge',
    () async {
      var postSeen = false;
      site.dio.httpClientAdapter = Adapter((options) async {
        if (options.method == 'POST') {
          postSeen = true;
          return ResponseBody.fromString(
            '<html>欢迎回来</html>',
            200,
            headers: {
              'content-type': ['text/html'],
            },
          );
        }
        return body({
          'Variables': {
            'member_uid': postSeen ? '12' : '0',
            'formhash': 'abcd1234',
          },
        });
      });
      await site.login('fixture', 'fixture');
      expect(site.uid, '12');
    },
  );
  test('real Xunsearch markup has native results and next page', () {
    final result = Site.parseSearch(
      File('test/fixtures/search.html').readAsStringSync(),
      Uri.parse('$siteOrigin/plugin.php?id=twpx_xunsearch&q=test'),
    );
    expect(result.topics.length, 1);
    expect(result.topics.single.id, isNotEmpty);
    expect(result.topics.single.title, contains('阅读'));
    expect(result.topics.single.title, isNot(contains('[99%]')));
    expect(Uri.parse(result.next!).queryParameters['p'], '2');
  });
  test('web authenticated viewer replaces guest API atomically and uses scoped cookies', () async {
    final cookieUrls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(Site.cookies, (call) async {
          if (call.method == 'getCookies') {
            cookieUrls.add((call.arguments as Map)['url'] as String);
            return 'auth=fixture';
          }
          return null;
        });
    var notifications = 0;
    site.addListener(() => notifications++);
    site.dio.httpClientAdapter = Adapter((r) async {
      expect(r.headers['Cookie'], 'auth=fixture');
      expect(r.headers['User-Agent'], siteMobileUserAgent);
      expect(r.headers['Cache-Control'], 'no-cache, no-store');
      if (r.uri.path == '/api/mobile/index.php') {
        return body({
          'Variables': {'member_uid': '0', 'formhash': 'guest123'},
        });
      }
      return ResponseBody.fromString(
        '<script>var discuz_uid = "12";</script><div class="comiis_user_name">测试用户</div><input name="formhash" value="web12345">',
        200,
        headers: {
          'content-type': ['text/html'],
        },
      );
    });
    await site.syncSession();
    expect(site.uid, '12');
    expect(site.username, '测试用户');
    expect(site.formhash, 'web12345');
    expect(site.loggedIn, isTrue);
    expect(notifications, 1);
    expect(cookieUrls, [
      '$siteOrigin/api/mobile/index.php',
      '$siteOrigin/home.php',
    ]);
    await site.syncSession();
    expect(
      notifications,
      1,
      reason: 'Guest API must not temporarily log out a confirmed web session',
    );
  });
  test(
    'guest API and failed web identity check do not discard the session',
    () async {
      site.uid = '12';
      site.username = '现有用户';
      site.dio.httpClientAdapter = Adapter((r) async {
        if (r.uri.path == '/api/mobile/index.php') {
          return body({
            'Variables': {'member_uid': '0'},
          });
        }
        return ResponseBody.fromString('unavailable', 503);
      });
      await expectLater(site.syncSession(), throwsA(isA<SiteException>()));
      expect(site.uid, '12');
      expect(site.username, '现有用户');
    },
  );
  test('viewer identity comes from the server global, never arbitrary profile links', () {
    expect(Site.parseWebSession('<a href="space-uid-12.html">某用户</a>'), isNull);
    expect(
      Site.parseWebSession(
        '<script>var discuz_uid="0";</script>',
      )!['member_uid'],
      '0',
    );
  });
  test('unknown HTML is an error rather than a fake empty feed', () {
    expect(
      () => Site.parseGuide('<html>blocked</html>'),
      throwsA(isA<SiteException>()),
    );
    expect(
      () => Site.parseSearch('<html>blocked</html>', Uri.parse(siteOrigin)),
      throwsA(isA<SiteException>()),
    );
  });
  test(
    'returning from web login checks the web identity before the API',
    () async {
      var apiRequests = 0;
      site.dio.httpClientAdapter = Adapter((r) async {
        if (r.uri.path == '/api/mobile/index.php' &&
            r.queryParameters['module'] == 'login') {
          apiRequests++;
        }
        return ResponseBody.fromString(
          '<script>var discuz_uid="12";</script><input name="formhash" value="web12345">',
          200,
          headers: {
            'content-type': ['text/html'],
          },
        );
      });
      await site.syncSessionFromWeb();
      expect(site.uid, '12');
      expect(site.formhash, 'web12345');
      expect(apiRequests, 0);
    },
  );
  test('external redirects never receive site cookie or a request', () async {
    var requests = 0;
    site.dio.httpClientAdapter = Adapter((r) async {
      requests++;
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': ['https://outside.invalid/'],
        },
      );
    });
    await expectLater(
      site.request('/search.php'),
      throwsA(isA<SiteException>()),
    );
    expect(requests, 1);
    expect(isSite(Uri.parse('https://ycoo.net.evil.invalid/')), false);
    expect(isSite(Uri.parse('https://user@ycoo.net/')), false);
    expect(isSite(Uri.parse('http://ycoo.net/')), false);
  });
  test('old account response cannot replace cookies after logout', () async {
    final pending = Completer<ResponseBody>();
    final started = Completer<void>();
    site.dio.httpClientAdapter = Adapter((r) {
      started.complete();
      return pending.future;
    });
    final request = site.request('/api/mobile/index.php');
    final check = expectLater(request, throwsA(isA<SiteException>()));
    await started.future;
    site.sessionEpoch++;
    pending.complete(
      ResponseBody.fromString(
        '{}',
        200,
        headers: {
          'set-cookie': ['auth=old'],
        },
      ),
    );
    await check;
  });
  test('mutations need explicit server success', () async {
    site.dio.httpClientAdapter = Adapter(
      (r) async => body({
        'Variables': {'member_uid': '1', 'formhash': 'test'},
      }),
    );
    await expectLater(
      site.api('sendreply', data: {'message': 'test'}),
      throwsA(isA<SiteException>()),
    );
    site.dio.httpClientAdapter = Adapter(
      (r) async => body({
        'Variables': {'pid': '9'},
        'Message': {'messageval': 'post_reply_succeed', 'messagestr': 'ok'},
      }),
    );
    expect(
      (await site.api('sendreply', data: {'message': 'test'}))['pid'],
      '9',
    );
  });
  test(
    'web login without a displayed name fills it from the matching profile',
    () async {
      site.dio.httpClientAdapter = Adapter((r) async {
        if (r.uri.path == '/home.php') {
          return ResponseBody.fromString(
            '<script>var discuz_uid="12";</script><input name="formhash" value="web12345">',
            200,
            headers: {
              'content-type': ['text/html'],
            },
          );
        }
        expect(r.queryParameters['module'], 'profile');
        expect(r.queryParameters['uid'], '12');
        return body({
          'Variables': {
            'space': {'uid': '12', 'username': '真实昵称'},
          },
        });
      });
      await site.syncSessionFromWeb();
      expect(site.uid, '12');
      expect(site.username, '真实昵称');
    },
  );
  test(
    'multipart form submissions preserve reusable file data and its MIME type',
    () async {
      final file = MultipartFile.fromBytes(
        [1, 2, 3],
        filename: 'avatar.png',
        contentType: DioMediaType('image', 'png'),
      );
      var requests = 0;
      site.dio.httpClientAdapter = Adapter((r) async {
        requests++;
        expect(r.data, isA<FormData>());
        final data = r.data as FormData;
        expect(
          Map<String, String>.fromEntries(data.fields)['formhash'],
          'abcd1234',
        );
        expect(data.files.single.value.contentType.toString(), 'image/png');
        return body({'ok': true});
      });
      await site.request(
        '/upload.php',
        data: {'formhash': 'abcd1234', 'file': file},
      );
      await site.request(
        '/upload.php',
        data: {'formhash': 'abcd1234', 'file': file},
      );
      expect(requests, 2);
      expect(file.isFinalized, isFalse);
    },
  );
  test('history is bounded, deduplicated and scoped to account', () async {
    site.uid = '1';
    await site.remember(const Topic(id: '1', title: 'old'));
    await site.remember(const Topic(id: '1', title: 'new'));
    expect(site.history().single.title, 'new');
    site.uid = '2';
    expect(site.history(), isEmpty);
    site.uid = '1';
    for (var i = 2; i < 205; i++) {
      await site.remember(Topic(id: '$i', title: 'topic'));
    }
    expect(site.history().length, 200);
  });
}
