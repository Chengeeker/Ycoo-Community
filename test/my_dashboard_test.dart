import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuan_community/core/theme/app_theme.dart';
import 'package:yuan_community/core/widgets/app_section_card.dart';
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
  testWidgets(
    'settings icon aligns with card edge and keeps its touch target',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      for (final width in [320.0, 393.0]) {
        for (final scale in [1.0, 2.0]) {
          tester.view.physicalSize = Size(width, 900);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: MyDashboardPage(Site(prefs), Settings(prefs)),
            ),
          );
          await tester.pumpAndSettle();
          final button = find.widgetWithIcon(
            IconButton,
            Icons.settings_outlined,
          );
          final icon = find.byIcon(Icons.settings_outlined);
          final card = find.byType(AppSectionCard).first;
          expect(
            tester.getTopRight(icon).dx,
            closeTo(tester.getTopRight(card).dx, 0.1),
            reason:
                'width=$width scale=$scale; target=${tester.getRect(button)}',
          );
          expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(find.byType(SettingsPage), findsOneWidget);
          Navigator.of(tester.element(find.byType(SettingsPage))).pop();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

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
