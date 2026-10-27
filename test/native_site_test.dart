import 'dart:io';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuan_community/data/site.dart';
import 'package:yuan_community/data/native_site.dart';
import 'package:yuan_community/pages/native_site.dart';
import 'package:yuan_community/pages/native_cloud.dart';
import 'package:yuan_community/pages/common.dart';
import 'package:yuan_community/core/design_system/components/review_frosted_app_bar.dart';

const purchaseForm =
    '<div class="comiis_bodybox"><form method="post" action="forum.php?mod=misc&action=pay&tid=31"><input type="hidden" name="formhash" value="abcd1234"><button name="paysubmit" value="yes">确认购买</button></form></div>';

class TabFixtureSite extends Site {
  TabFixtureSite(super.prefs);
  final requests = <String>[];
  @override
  Future<Response<dynamic>> request(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? data,
    int redirects = 0,
  }) async {
    requests.add(path);
    final uri = Uri.parse(path);
    final view = uri.queryParameters['view'] ?? 'me';
    final source =
        '<div class="comiis_bodybox"><div class="comiis_topnv"><ul>'
        '<li class="${view == 'me' ? 'f_0' : ''}"><a href="/home.php?mod=space&do=friend&view=me">我的好友</a></li>'
        '<li class="${view == 'follow' ? 'f_0' : ''}"><a href="/home.php?mod=space&do=friend&view=follow">我的关注</a></li>'
        '<li><a href="/home.php?mod=space&do=friend&view=follower">我的粉丝</a></li>'
        '<li><a href="/home.php?mod=space&do=friend&view=visitor">最近来访</a></li>'
        '</ul></div><p>内容 $view</p><div style="display:none">隐藏确认框</div></div>';
    return Response<dynamic>(
      data: source,
      requestOptions: RequestOptions(path: path),
    );
  }
}

class NativeFixtureSite extends Site {
  NativeFixtureSite(super.prefs) {
    uid = '12';
    username = '测试用户';
  }
  bool unlocked = false, signed = false, failPurchase = false;
  String price = '4';
  int purchases = 0, signs = 0;
  final cloudActions = <String>[];
  @override
  Future<Map<String, dynamic>> api(
    String module, {
    Map<String, dynamic> query = const {},
    Map<String, dynamic>? data,
  }) async => {
    'forum_threadpay': unlocked ? '0' : '1',
    'thread': {'tid': '31', 'price': price},
  };
  @override
  Future<Response<dynamic>> request(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? data,
    int redirects = 0,
  }) async {
    dynamic response = purchaseForm;
    if (path.contains('k_misign-sign')) {
      response = File('test/fixtures/signin.html')
          .readAsStringSync()
          .replaceFirst('>签到</a>', signed ? '>已签到</a>' : '>签到</a>');
    } else if (query?['operation'] == 'qiandao') {
      signs++;
      signed = true;
      response = '签到成功';
    } else if (query?['operation'] == 'list')
      response = File('test/fixtures/sign-rank.html').readAsStringSync();
    else if (query?['id'] == 'bphp_clouds:index')
      response = "BPHP={'formhash':'abcd1234'}";
    else if (query?['id'] == 'bphp_clouds:api') {
      final action = '${data?['ac']}';
      cloudActions.add(action);
      response = switch (action) {
        'config' => {
          'sta': 1,
          'data': {'storageType': 'local'},
        },
        'getUserInfo' => {
          'sta': 1,
          'data': {'capacity': '1', 'spaceSize': '100'},
        },
        'fileDisplay' => {
          'sta': 1,
          'pid': 0,
          'maxPage': 1,
          'fList': [
            {
              'id': '1',
              'name': '原文件.txt',
              'link': 'https://ycoo.net/data/file.txt',
            },
          ],
          'cList': [],
        },
        _ => {'sta': 1, 'msg': '操作成功'},
      };
    } else if (data != null) {
      purchases++;
      expectSync(data['formhash'], 'abcd1234');
      expectSync(data['paysubmit'], 'yes');
      unlocked = !failPurchase;
      response = failPurchase ? '<div id="messagetext">余额不足</div>' : '购买成功';
    }
    return Response<dynamic>(
      data: response,
      requestOptions: RequestOptions(path: normalizeSiteLink(path).toString()),
    );
  }
}

void main() {
  testWidgets('native tabs keep their frosted boundary at large text size', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final site = TabFixtureSite(await SharedPreferences.getInstance());
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(2),
          ),
          child: NativeSitePage(
            site,
            '/home.php?mod=space&do=friend&view=me',
            title: '我的好友',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(find.byType(TabBar)).dy,
      tester.getBottomLeft(find.byType(ReviewFrostedAppBar)).dy,
    );
    expect(
      tester.getTopLeft(find.text('内容 me')).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byType(TabBar)).dy),
    );
    expect(tester.takeException(), isNull);
  });

  test('unknown scripted or external navigation is not silently converted', () {
    final data = NativePageData.parse(
      '<div class="comiis_bodybox"><div class="comiis_topnv"><ul><li><a href="/home.php">正常</a></li><li><a href="javascript:custom()">操作</a></li></ul></div></div>',
      Uri.parse(siteOrigin),
    );
    expect(data.tabs, isEmpty);
    expect(data.parts.whereType<String>().join(), contains('custom()'));
  });
  test('recognizes circle tabs even without the site navigation class', () {
    final data = NativePageData.parse(
      '<div class="comiis_bodybox"><ul><li class="on"><a href="/group.php?mod=my">圈子话题</a></li><li><a href="/group.php?mod=my&view=joined">我参与的</a></li></ul><p>圈子内容</p></div>',
      Uri.parse(siteOrigin),
    );
    expect(data.tabs.map((tab) => tab.label), ['圈子话题', '我参与的']);
    expect(data.tabs.first.selected, isTrue);
    expect(data.parts.whereType<String>().join(), isNot(contains('圈子话题')));
  });
  testWidgets(
    'native navigation tabs keep content below the frosted bar and switch in place',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final site = TabFixtureSite(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        MaterialApp(
          home: NativeSitePage(
            site,
            '/home.php?mod=space&do=friend&view=me',
            title: '我的好友',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('内容 me'), findsOneWidget);
      expect(find.text('隐藏确认框'), findsNothing);
      expect(
        tester.getTopLeft(find.text('内容 me')).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.byType(ReviewFrostedAppBar)).dy,
        ),
      );
      await tester.tap(find.text('我的关注'));
      await tester.pumpAndSettle();
      expect(find.text('内容 follow'), findsOneWidget);
      expect(site.requests.last, contains('view=follow'));
      expect(find.byType(NativeSitePage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('adaptation feedback contains structure without credentials or field values', () {
    final page = NativePageData.parse(
      '<div class="comiis_bodybox"><script src="source/plugin/jnfarm/main.js?token=secret"></script><a href="javascript:plant(3)">种植</a><form action="/plugin.php"><input name="formhash" value="private-hash"><input name="password" value="private-password"></form></div>',
      Uri.parse(
        '$siteOrigin/plugin.php?id=jnfarm&formhash=private-hash&uid=12',
      ),
    );
    expect(page.hasScriptActions, isTrue);
    final decoded = jsonDecode(page.adaptationInfo) as Map;
    expect(decoded['scriptActions'], contains('plant'));
    expect(page.adaptationInfo, isNot(contains('private-')));
    expect(page.adaptationInfo, isNot(contains('token=secret')));
  });
  test(
    'native forms preserve selected values and reject cross-site submissions',
    () {
      final data = NativePageData.parse(
        '<div class="comiis_bodybox">说明<script>evil()</script><form method="post" action="/home.php"><input name="formhash" type="hidden" value="abcd1234"><select name="gender"><option value="0">保密</option><option selected value="2">女</option></select><input type="checkbox" checked name="interest[]" value="read"><input type="checkbox" checked name="interest[]" value="code"><textarea name="bio">A &amp; B</textarea><input disabled name="ignored" value="no"></form><form action="https://example.com/steal"><input name="secret"></form></div>',
        Uri.parse(siteOrigin),
      );
      final forms = data.parts.whereType<NativeForm>().toList();
      expect(forms, hasLength(1));
      expect(forms.single.values(), {
        'formhash': 'abcd1234',
        'gender': '2',
        'interest[]': ['read', 'code'],
        'bio': 'A & B',
      });
      expect(data.parts.whereType<String>().join(), isNot(contains('evil()')));
    },
  );
  test(
    'actual sign response has native stats, a CSRF token and ranking entries',
    () {
      final source = File('test/fixtures/signin.html').readAsStringSync();
      final data = SignData.parse(source);
      expect(data.stats, hasLength(3));
      expect(data.formhash, matches(r'^[a-zA-Z0-9]{8}$'));
      expect(
        SignRank.parse(File('test/fixtures/sign-rank.html').readAsStringSync()),
        isNotEmpty,
      );
    },
  );
  for (final scenario in [
    'success',
    'cancel',
    'failure',
    'priceChanged',
    'doubleTap',
  ]) {
    testWidgets(
      'native theme purchase $scenario has no browser and no unconfirmed charge',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final site = NativeFixtureSite(await SharedPreferences.getInstance());
        bool? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await push<bool>(
                      context,
                      NativeSitePage(
                        site,
                        '/forum.php?mod=misc&action=pay&tid=31',
                        title: '购买主题',
                        purchaseTid: '31',
                        purchasePrice: '4',
                      ),
                    );
                  },
                  child: const Text('打开购买'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开购买'));
        await tester.pumpAndSettle();
        expect(find.byType(BrowserPage), findsNothing);
        expect(site.purchases, 0);
        site.failPurchase = scenario == 'failure';
        if (scenario == 'priceChanged') site.price = '5';
        if (scenario == 'doubleTap') {
          final form = tester.widget<NativeFormView>(
            find.byType(NativeFormView),
          );
          form.onSubmit({...form.form.values(), 'paysubmit': 'yes'});
          form.onSubmit({...form.form.values(), 'paysubmit': 'yes'});
        } else {
          await tester.tap(find.text('确认购买'));
        }
        await tester.pumpAndSettle();
        expect(site.purchases, 0);
        await tester.tap(find.text(scenario == 'cancel' ? '取消' : '确认'));
        await tester.pumpAndSettle();
        expect(
          site.purchases,
          scenario == 'cancel' || scenario == 'priceChanged' ? 0 : 1,
        );
        if (scenario == 'success' || scenario == 'doubleTap') {
          expect(
            result,
            isTrue,
            reason: tester.allWidgets
                .whereType<Text>()
                .map((text) => text.data ?? '')
                .join(' | '),
          );
        } else {
          expect(result, isNull);
        }
        if (scenario == 'failure') {
          expect(find.textContaining('余额不足'), findsWidgets);
        }
        if (scenario == 'priceChanged') {
          expect(find.textContaining('价格已变化'), findsWidgets);
        }
      },
    );
  }
  testWidgets(
    'daily sign uses a native page, guards duplicate taps and reloads status',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final site = NativeFixtureSite(await SharedPreferences.getInstance());
      await tester.pumpWidget(MaterialApp(home: SignPage(site)));
      await tester.pumpAndSettle();
      expect(find.byType(BrowserPage), findsNothing);
      await tester.tap(find.text('立即签到'));
      await tester.pumpAndSettle();
      expect(site.signs, 1);
      expect(find.text('今日已签到'), findsOneWidget);
    },
  );
  testWidgets('cloud uses the actual plugin API and native rename controls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final site = NativeFixtureSite(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(home: NativeCloudPage(site)));
    await tester.pumpAndSettle();
    expect(find.text('原文件.txt'), findsOneWidget);
    expect(find.byType(BrowserPage), findsNothing);
    expect(site.cloudActions, ['config', 'getUserInfo', 'fileDisplay']);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '新文件.txt');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(site.cloudActions, contains('reName'));
  });
}
