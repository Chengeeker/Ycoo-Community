import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuan_community/core/widgets/app_scope.dart';
import 'package:yuan_community/data/site.dart';
import 'package:yuan_community/pages/account_features.dart';
import 'package:yuan_community/pages/native_site.dart';
import 'package:yuan_community/pages/login.dart';
import 'package:yuan_community/pages/common.dart';
import 'package:yuan_community/settings.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'helpers/fake_webview.dart';

class AccountFixtureSite extends Site {
  AccountFixtureSite(super.prefs) {
    uid = '23706';
    username = '测试用户';
  }
  final calls = <Uri>[];
  int writes = 0;
  bool emptyDarkroom = false;
  @override
  Future<Map<String, dynamic>> api(
    String module, {
    Map<String, dynamic> query = const {},
    Map<String, dynamic>? data,
  }) async => module == 'mypm'
      ? {
          'list': [
            {
              'touid': '23706',
              'tousername': '自己',
              'msgfromid': '7',
              'msgfrom': '好友甲',
              'message': '你好',
              'vdateline': '今天',
            },
          ],
          'count': 1,
          'perpage': 20,
        }
      : {
          'space': {
            'uid': uid,
            'credits': '4648',
            'extcredits2': '4690',
            'extcredits3': '727',
            'extcredits4': '519',
          },
          'extcredits': {
            '2': {'title': '经验'},
            '3': {'title': '贡献'},
            '4': {'title': '星币'},
          },
        };
  @override
  Future<Response<dynamic>> request(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? data,
    int redirects = 0,
  }) async {
    if (data != null) writes++;
    final uri = normalizeSiteLink(path).replace(
      queryParameters: {
        for (final entry
            in (query ?? normalizeSiteLink(path).queryParameters).entries)
          entry.key: '${entry.value}',
      },
    );
    calls.add(uri);
    dynamic response = '<div class="comiis_bodybox"><p>站点内容</p></div>';
    if (uri.queryParameters['action'] == 'showdarkroom') {
      response = {
        'message': emptyDarkroom
            ? '0|1'
            : query?['cid'] == null
            ? '1|5'
            : '0|0',
        'data': emptyDarkroom
            ? []
            : {
                '1': {
                  'cid': query?['cid'] == null ? '8' : '5',
                  'uid': '7',
                  'username': '测试成员',
                  'action': '禁止发言',
                  'reason': '违规',
                  'dateline': '今天',
                  'groupexpiry': '永不过期',
                },
              },
      };
    } else if (uri.queryParameters['ac'] == 'profile') {
      response = '<div class="comiis_bodybox"><a href="/plugin.php?id=wxbind">微信绑定</a><a href="https://example.com/connect">QQ绑定</a></div>';
    } else if (uri.queryParameters['op'] == 'transfer') {
      response = '<div class="comiis_bodybox"><form action="/home.php?mod=spacecp&ac=credit&op=transfer" method="post"><input type="hidden" name="formhash" value="secret"><input name="recipient" value=""><button type="submit">提交</button></form></div>';
    }
    return Response<dynamic>(
      data: response,
      requestOptions: RequestOptions(path: uri.toString()),
    );
  }
}

Future<(SharedPreferences, AccountFixtureSite)> setup() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return (prefs, AccountFixtureSite(prefs));
}

void main() {
  late FakeWebViewPlatform web;
  setUp(() {
    final previous = WebViewPlatform.instance;
    web = FakeWebViewPlatform();
    WebViewPlatform.instance = web;
    if (previous != null) {
      addTearDown(() => WebViewPlatform.instance = previous);
    }
  });
  testWidgets('promotion QR encodes the actual account referral URL', (
    tester,
  ) async {
    final (_, site) = await setup();
    await tester.pumpWidget(MaterialApp(home: PromotionPage(site)));
    expect(find.byType(QrImageView), findsOneWidget);
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      'https://ycoo.net/?fromuid=23706',
    );
    expect(find.text('测试用户'), findsOneWidget);
    expect(site.writes, 0);
  });

  testWidgets(
    'credits keep native balances and open transfer on the official site',
    (tester) async {
      final (prefs, site) = await setup();
      await tester.pumpWidget(
        AppScope(
          site: site,
          settings: Settings(prefs),
          child: MaterialApp(home: CreditsPage(site)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('4648'), findsOneWidget);
      expect(find.text('星币'), findsOneWidget);
      expect(find.text('519'), findsOneWidget);
      await tester.tap(find.text('转账'));
      await tester.pumpAndSettle();
      expect(find.byType(BrowserPage), findsOneWidget);
      expect(web.controller.loads.single.queryParameters['op'], 'transfer');
      expect(find.byType(AppBar), findsOneWidget);
      await tester.tap(find.text('充值'));
      await tester.pumpAndSettle();
      expect(web.controller.loads.single.queryParameters['op'], 'buy');
      await tester.tap(find.text('记录'));
      await tester.pumpAndSettle();
      expect(find.byType(NativeSitePage), findsOneWidget);
      expect(site.calls.last.queryParameters['op'], 'log');
      expect(site.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('messages menu offers distinct source categories', (
    tester,
  ) async {
    final (prefs, site) = await setup();
    await tester.pumpWidget(
      AppScope(
        site: site,
        settings: Settings(prefs),
        child: MaterialApp(home: MessagesMenuPage(site)),
      ),
    );
    for (final title in ['我的消息', '我的粉丝', '我的帖子', '坛友互动', '系统提醒', '应用提醒']) {
      expect(find.text(title), findsOneWidget);
    }
    await tester.tap(find.text('坛友互动'));
    await tester.pumpAndSettle();
    expect(site.calls.last.queryParameters['view'], 'interactive');
    expect(site.writes, 0);
  });

  testWidgets('a private message opens its own conversation', (tester) async {
    final (prefs, site) = await setup();
    await tester.pumpWidget(
      AppScope(
        site: site,
        settings: Settings(prefs),
        child: MaterialApp(home: MyContentPage(site, 'mypm', '我的消息')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('好友甲'), findsOneWidget);
    await tester.tap(find.text('好友甲'));
    await tester.pumpAndSettle();
    expect(web.controller.loads.single.queryParameters['subop'], 'view');
    expect(web.controller.loads.single.queryParameters['touid'], '7');
    expect(site.writes, 0);
  });

  testWidgets('profile binding links come only from the server page', (
    tester,
  ) async {
    final (prefs, site) = await setup();
    await tester.pumpWidget(
      AppScope(
        site: site,
        settings: Settings(prefs),
        child: MaterialApp(home: ProfileSettingsPage(site)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('微信绑定'), findsOneWidget);
    expect(find.text('QQ绑定'), findsOneWidget);
    expect(find.text('站点未返回可识别的入口'), findsNothing);
    expect(find.text('修改头像'), findsNothing);
    final bindingTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, '微信绑定'),
    );
    expect(bindingTile.subtitle, isNull, reason: '${site.calls}');
    expect(bindingTile.onTap, isNotNull);
    await tester.tap(find.text('微信绑定'));
    await tester.pumpAndSettle();
    expect(find.byType(BrowserPage), findsOneWidget);
    expect(web.controller.loads.single.queryParameters['id'], 'wxbind');
    await tester.tap(find.byTooltip('关闭页面'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('QQ绑定'));
    await tester.pumpAndSettle();
    expect(find.text('即将离开源社区'), findsOneWidget);
    expect(site.writes, 0);
  });

  testWidgets('darkroom loads and pages real server-shaped records', (
    tester,
  ) async {
    final (_, site) = await setup();
    await tester.pumpWidget(MaterialApp(home: DarkroomPage(site)));
    await tester.pumpAndSettle();
    expect(find.text('测试成员'), findsOneWidget);
    await tester.tap(find.text('加载更多'));
    await tester.pumpAndSettle();
    expect(site.calls.last.queryParameters['cid'], '5');
    expect(find.text('测试成员'), findsNWidgets(2));
    final rows = find.byType(ListTile);
    expect(
      tester.getTopLeft(rows.at(1)).dy - tester.getBottomLeft(rows.first).dy,
      closeTo(8, .1),
    );
    expect(site.writes, 0);
  });

  testWidgets(
    'empty darkroom is a completed empty state, not a connection error',
    (tester) async {
      final (_, site) = await setup();
      site.emptyDarkroom = true;
      await tester.pumpWidget(MaterialApp(home: DarkroomPage(site)));
      await tester.pumpAndSettle();
      expect(find.text('暂无记录'), findsOneWidget);
      expect(find.byType(Failure), findsNothing);
      expect(find.text('加载更多'), findsNothing);
      expect(site.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
