import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuan_community/core/design_system/components/review_card.dart';
import 'package:yuan_community/core/design_system/components/review_navigation_bar.dart';
import 'package:yuan_community/data/portal.dart';
import 'package:yuan_community/data/site.dart';
import 'package:yuan_community/pages/home.dart';
import 'package:yuan_community/pages/login.dart';
import 'package:yuan_community/settings.dart';

import 'widget_test.dart' show PreviewSite;

class StartupSessionSite extends PreviewSite {
  StartupSessionSite(
    super.prefs, {
    this.restoreLoggedIn = true,
    this.retryFails = false,
  });
  final bool restoreLoggedIn;
  final bool retryFails;
  final startup = Completer<void>();
  int checks = 0;

  @override
  Future<void> syncSession() async {
    checks++;
    if (checks == 1) await startup.future;
    if (checks == 2 && retryFails) throw SiteException('连接失败');
    if (!restoreLoggedIn) return;
    uid = '7';
    username = '已登录用户';
    sessionEpoch++;
    notifyListeners();
  }

  @override
  Future<TopicBatch> topics({
    String? fid,
    String view = 'newthread',
    int page = 1,
    String? type,
  }) async =>
      TopicBatch([Topic(id: view, title: '$uid-$view', author: '作者')], false);
}

class FollowingSite extends Site {
  FollowingSite(super.prefs) {
    uid = '1';
  }
  final queries = <Map<String, dynamic>>[];

  @override
  Future<Response<dynamic>> request(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? data,
    int redirects = 0,
  }) async {
    queries.add(Map.of(query!));
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: File('test/fixtures/mobile-feed.xml').readAsStringSync(),
    );
  }
}

class FollowingPageSite extends Site {
  FollowingPageSite(super.prefs) {
    uid = '1';
  }
  final calls = <String>[];

  @override
  Future<TopicBatch> topics({
    String? fid,
    String view = 'newthread',
    int page = 1,
    String? type,
  }) async {
    calls.add(view);
    return TopicBatch(
      [Topic(id: view, title: '内容 $view', author: '作者', uid: '2')],
      false,
      portal: view == 'following' ? const PortalData() : null,
    );
  }
}

void main() {
  testWidgets('primary navigation slides pages and preserves feed state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final site = PreviewSite(prefs);
    await tester.pumpWidget(MaterialApp(home: HomePage(site, Settings(prefs))));
    await tester.pumpAndSettle();
    final requests = site.topicRequests;

    await tester.tap(
      find.descendant(
        of: find.byType(ReviewNavigationBar),
        matching: find.text('社区'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    final incoming = tester.widget<SlideTransition>(
      find.byKey(const ValueKey('home-tab-slide-1')),
    );
    final outgoing = tester.widget<SlideTransition>(
      find.byKey(const ValueKey('home-tab-slide-0')),
    );
    expect(incoming.position.value.dx, inInclusiveRange(0, 1));
    expect(incoming.position.value.dx, greaterThan(0));
    expect(outgoing.position.value.dx, lessThan(0));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(ReviewNavigationBar),
        matching: find.text('首页'),
      ),
    );
    await tester.pumpAndSettle();
    expect(site.topicRequests, requests);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in ['success', 'retry', 'cancel', 'guest', 'network']) {
    testWidgets('startup session $scenario preserves the selected page', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final site = StartupSessionSite(
        prefs,
        restoreLoggedIn: scenario != 'guest',
        retryFails: scenario == 'network',
      );
      await tester.pumpWidget(
        MaterialApp(home: HomePage(site, Settings(prefs))),
      );
      await tester.pumpAndSettle();
      expect(find.text('0-portal'), findsOneWidget);
      await tester.tap(
        find.descendant(of: find.byType(TabBar), matching: find.text('关注')),
      );
      await tester.pump();
      expect(find.byType(LoginPage), findsNothing);
      expect(find.text('正在确认登录状态'), findsOneWidget);
      if (scenario == 'cancel') {
        await tester.tap(find.text('圈子'));
        await tester.pump();
      }
      if (scenario == 'retry' || scenario == 'network') {
        site.startup.completeError(SiteException('连接失败'));
      } else {
        site.startup.complete();
      }
      await tester.pumpAndSettle();
      if (scenario == 'network') {
        expect(find.byType(LoginPage), findsNothing);
        expect(find.text('正在确认登录状态'), findsNothing);
        await tester.tap(
          find.descendant(of: find.byType(TabBar), matching: find.text('关注')),
        );
        await tester.pumpAndSettle();
      }
      expect(
        find.byType(LoginPage),
        scenario == 'guest' ? findsOneWidget : findsNothing,
      );
      if (scenario != 'guest') {
        expect(
          find.text(scenario == 'cancel' ? '7-circles' : '7-following'),
          findsOneWidget,
        );
        expect(find.text('0-portal'), findsNothing);
      }
      expect(
        site.checks,
        scenario == 'retry'
            ? 2
            : scenario == 'network'
            ? 3
            : 1,
      );
      expect(tester.takeException(), isNull);
    });
  }
  test('following feeds use the site page and pagination parameters', () async {
    SharedPreferences.setMockInitialValues({});
    final site = FollowingSite(await SharedPreferences.getInstance());
    for (final entry in {
      'following': (45, 'user'),
      'following_forums': (46, 'bbs'),
      'following_friends': (47, 'friend'),
    }.entries) {
      final first = await site.topics(view: entry.key);
      expect(first.topics, isNotEmpty);
      expect(site.queries.last['pid'], entry.value.$1);
      expect(site.queries.last['comiis_list'], 'yes');
      await site.topics(view: entry.key, page: 2);
      expect(site.queries.last['pid'], entry.value.$1);
      expect(site.queries.last['op'], entry.value.$2);
      expect(site.queries.last.containsKey('comiis_list'), isFalse);
    }
    site.uid = '0';
    await expectLater(
      site.topics(view: 'following'),
      throwsA(isA<SiteException>()),
    );
  });

  testWidgets(
    'following tabs have separate content and extend the frosted bar',
    (tester) async {
      tester.view.physicalSize = const Size(393, 873);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 28, bottom: 24);
      tester.view.viewPadding = const FakeViewPadding(top: 28, bottom: 24);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final site = FollowingPageSite(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        MaterialApp(home: TopicsPage(site, home: true, root: true)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsOneWidget);
      expect(tester.getTopLeft(find.byType(TabBar)).dy, 28 + 64);
      await tester.tap(
        find.descendant(of: find.byType(TabBar), matching: find.text('关注')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsNWidgets(2));
      expect(
        tester.widget<TabBar>(find.byType(TabBar).first).dividerColor,
        Colors.transparent,
      );
      expect(
        tester.getBottomLeft(find.byType(TabBar).first).dy,
        tester.getTopLeft(find.byType(TabBar).last).dy,
      );
      expect(find.text('内容 following'), findsOneWidget);
      expect(find.text('社区动态'), findsNothing);
      final card = find
          .ancestor(
            of: find.text('内容 following'),
            matching: find.byType(ReviewCard),
          )
          .first;
      expect(
        tester.getTopLeft(card).dy -
            tester.getBottomLeft(find.byType(AppBar)).dy,
        12,
      );
      expect(find.text('已关注'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.byType(TabBar).last).dy,
        tester.getBottomLeft(find.byType(AppBar)).dy,
      );
      expect(
        tester.getTopLeft(find.text('作者')).dy,
        greaterThan(tester.getBottomLeft(find.byType(AppBar)).dy),
      );
      await tester.tap(find.text('关注版块'));
      await tester.pumpAndSettle();
      expect(find.text('内容 following_forums'), findsOneWidget);
      await tester.tap(find.text('好友动态'));
      await tester.pumpAndSettle();
      expect(find.text('内容 following_friends'), findsOneWidget);
      await tester.tap(find.text('我的关注'));
      await tester.pumpAndSettle();
      expect(find.text('内容 following'), findsOneWidget);
      expect(site.calls.where((view) => view == 'following'), hasLength(1));
      await tester.tap(find.text('推荐'));
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: TopicsPage(site, home: true, root: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(TabBar)).dy, 28 + 104);
      expect(tester.takeException(), isNull);
    },
  );
}
