import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuan_community/core/design_system/components/review_navigation_bar.dart';
import 'package:yuan_community/data/site.dart';
import 'package:yuan_community/pages/home.dart';
import 'package:yuan_community/settings.dart';

class ReadingSite extends Site {
  ReadingSite(super.prefs, {this.more = false}) {
    uid = '7';
  }
  final requests = <String>[];
  int forumRequests = 0;
  final bool more;

  @override
  Future<void> syncSession() async {}

  @override
  Future<List<Map<String, dynamic>>> forums() async {
    forumRequests++;
    return [
      {'fid': '2', 'name': '版块'},
    ];
  }

  @override
  Future<TopicBatch> topics({
    String? fid,
    String view = 'portal',
    int page = 1,
    String? type,
  }) async {
    requests.add('$uid/$view/$page');
    return TopicBatch(
      List.generate(
        60,
        (i) => Topic(id: '$view-$i', title: '$view 文章 $i', author: '作者'),
      ),
      more,
    );
  }
}

void main() {
  testWidgets(
    'restoring near the bottom stays cached and the next user scroll appends',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = ReadingSite(prefs, more: true);
      await tester.pumpWidget(
        MaterialApp(home: HomePage(first, Settings(prefs))),
      );
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(CustomScrollView).first,
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      position.jumpTo(position.maxScrollExtent - 100);
      await tester.pumpAndSettle();
      expect(first.requests, ['7/portal/1']);
      final offset = position.pixels;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final cold = ReadingSite(prefs);
      await tester.pumpWidget(
        MaterialApp(home: HomePage(cold, Settings(prefs))),
      );
      await tester.pumpAndSettle();
      expect(cold.requests, isEmpty);
      final restored = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(CustomScrollView).first,
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      expect(restored.pixels, closeTo(offset, 1));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(cold.requests, ['7/portal/2']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'cold restart restores the selected feed, offset and cached data',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = ReadingSite(prefs);
      Future<void> mount(Site site) =>
          tester.pumpWidget(MaterialApp(home: HomePage(site, Settings(prefs))));
      await mount(first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('圈子').first);
      await tester.pumpAndSettle();
      // TabBars have their own Scrollables; use the vertical feed explicitly.
      final position = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(CustomScrollView).first,
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      position.jumpTo(1500);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final restored = ReadingSite(prefs);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await mount(restored);
      await tester.pumpAndSettle();
      expect(restored.requests, isEmpty);
      expect(restored.forumRequests, 0);
      final restoredPosition = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(CustomScrollView).first,
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      expect(restoredPosition.pixels, closeTo(1500, 1));
      expect(find.textContaining('circles 文章'), findsWidgets);
      restored.sessionEpoch++;
      restored.username = '昵称已更新';
      restored.notifyListeners();
      await tester.pumpAndSettle();
      expect(restoredPosition.pixels, closeTo(1500, 1));
      expect(restored.requests, isEmpty);
      final nav = tester.widget<ReviewNavigationBar>(
        find.byType(ReviewNavigationBar),
      );
      nav.onSelected(2);
      await tester.pumpAndSettle();
      await tester.tap(find.text('热门').first);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final last = ReadingSite(prefs);
      await mount(last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ReviewNavigationBar>(find.byType(ReviewNavigationBar))
            .selectedIndex,
        2,
      );
      expect(find.textContaining('hot 文章'), findsWidgets);
      expect(last.requests, isEmpty);
      last.uid = '8';
      last.sessionEpoch++;
      last.notifyListeners();
      await tester.pumpAndSettle();
      expect(last.requests, ['8/portal/1']);
      expect(
        tester
            .widget<ReviewNavigationBar>(find.byType(ReviewNavigationBar))
            .selectedIndex,
        0,
      );
      expect(prefs.getString('cache.v2.7.hot.all'), isNotNull);
      expect(prefs.getString('cache.v2.8.portal.all'), isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
