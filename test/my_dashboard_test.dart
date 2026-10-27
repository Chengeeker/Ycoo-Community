import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuan_community/data/site.dart';
import 'package:yuan_community/pages/home.dart';
import 'package:yuan_community/settings.dart';

class ProfileSite extends Site {
  ProfileSite(super.prefs) {
    uid = '23706';
    username = '有你便是晴天';
  }
  final profile = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> api(
    String module, {
    Map<String, dynamic> query = const {},
    Map<String, dynamic>? data,
  }) => profile.future;
}

void main() {
  for (final cached in [false, true]) {
    testWidgets(
      'dashboard reserves stats and restores account cache: $cached',
      (tester) async {
        SharedPreferences.setMockInitialValues(
          cached
              ? {
                  'cache.profile.23706':
                      '{"uid":"23706","threads":2,"posts":401,"credits":4648}',
                }
              : {},
        );
        final prefs = await SharedPreferences.getInstance();
        final site = ProfileSite(prefs);
        await tester.pumpWidget(
          MaterialApp(home: MyDashboardPage(site, Settings(prefs))),
        );
        await tester.pump();
        expect(find.text('主题'), findsOneWidget);
        expect(
          find.text(cached ? '4648' : '—'),
          cached ? findsOneWidget : findsNWidgets(3),
        );
        final topBefore = tester.getTopLeft(find.text('我的内容')).dy;
        site.profile.complete({
          'space': {
            'uid': '23706',
            'threads': '2',
            'posts': '401',
            'credits': '4650',
          },
        });
        await tester.pumpAndSettle();
        expect(find.text('4650'), findsOneWidget);
        expect(tester.getTopLeft(find.text('我的内容')).dy, topBefore);
        expect(prefs.getString('cache.profile.23706'), contains('4650'));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'profile response from an old session cannot update or cache stats',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final site = ProfileSite(prefs);
      await tester.pumpWidget(
        MaterialApp(home: MyDashboardPage(site, Settings(prefs))),
      );
      await tester.pump();
      site.sessionEpoch++;
      site.profile.complete({
        'space': {
          'uid': '23706',
          'threads': '2',
          'posts': '401',
          'credits': '4648',
        },
      });
      await tester.pumpAndSettle();
      expect(find.text('4648'), findsNothing);
      expect(prefs.getString('cache.profile.23706'), isNull);
    },
  );

  testWidgets('profile failure keeps cached counts', (tester) async {
    SharedPreferences.setMockInitialValues({
      'cache.profile.23706':
          '{"uid":"23706","threads":2,"posts":401,"credits":4648}',
    });
    final prefs = await SharedPreferences.getInstance();
    final site = ProfileSite(prefs);
    await tester.pumpWidget(
      MaterialApp(home: MyDashboardPage(site, Settings(prefs))),
    );
    await tester.pump();
    site.profile.completeError(SiteException('网络不可用'));
    await tester.pumpAndSettle();
    expect(find.text('4648'), findsOneWidget);
    expect(prefs.getString('cache.profile.23706'), contains('4648'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile counts belonging to another uid are rejected', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final site = ProfileSite(prefs);
    await tester.pumpWidget(
      MaterialApp(home: MyDashboardPage(site, Settings(prefs))),
    );
    await tester.pump();
    site.profile.complete({
      'space': {'uid': '99', 'threads': '1', 'posts': '10', 'credits': '1234'},
    });
    await tester.pumpAndSettle();
    expect(find.text('1234'), findsNothing);
    expect(prefs.getString('cache.profile.23706'), isNull);
  });
}
