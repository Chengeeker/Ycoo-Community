import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuan_community/main.dart';
import 'package:yuan_community/settings.dart';
import 'package:yuan_community/core/design_system/components/review_card.dart';
import 'package:yuan_community/core/design_system/components/review_navigation_bar.dart';
import 'package:yuan_community/core/design_system/components/review_preference_tile.dart';
import 'package:yuan_community/core/design_system/components/review_switch_tile.dart';
import 'package:yuan_community/core/theme/app_theme.dart';
import 'package:yuan_community/core/utils/haptic_feedback_util.dart';

import 'widget_test.dart' show PreviewSite;

import 'package:yuan_community/data/portal.dart';
import 'package:yuan_community/pages/portal.dart';

void main() {
  for (final floating in [true, false]) {
    testWidgets('safe areas are counted once with floating=$floating', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 873);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 28, bottom: 24);
      tester.view.viewPadding = const FakeViewPadding(top: 28, bottom: 24);
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        final font = FontLoader('Roboto')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                File('C:/Windows/Fonts/msyh.ttc').readAsBytesSync(),
              ),
            ),
          );
        await font.load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      SharedPreferences.setMockInitialValues({
        'floating': floating,
        'themeMode': 2,
      });
      final prefs = await SharedPreferences.getInstance();
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: YuanApp(settings: Settings(prefs), site: PreviewSite(prefs)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(
        tester.getBottomLeft(find.byType(TabBar)).dy,
        tester.getBottomLeft(find.byType(AppBar)).dy,
      );
      await tester.tap(find.text('社区').last);
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNothing);
      expect(
        tester.getBottomLeft(find.byType(TabBar)).dy,
        tester.getBottomLeft(find.byType(AppBar)).dy,
      );
      final stats = find
          .ancestor(of: find.text('今日新帖'), matching: find.byType(ReviewCard))
          .first;
      final gap =
          tester.getTopLeft(stats).dy -
          tester.getBottomLeft(find.byType(AppBar)).dy;
      expect(
        gap,
        inInclusiveRange(8, 20),
        reason: 'content begins just below the tab bar, without a second inset',
      );
      await tester.tap(find.text('新帖'));
      await tester.pumpAndSettle();
      expect(find.text('分享与阅读，发现更多好内容'), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      await tester.tap(find.text('版区'));
      await tester.pumpAndSettle();
      if (floating) await _capture(tester, key, 'community-fixed');
      await tester.tap(find.text('我的').last);
      await tester.pumpAndSettle();
      final grid = find.byKey(const ValueKey('my-content-grid'));
      expect(tester.getSize(grid).height, 172);
      final headingBottom = tester.getBottomLeft(find.text('我的内容')).dy;
      expect(tester.getTopLeft(grid).dy - headingBottom, lessThanOrEqualTo(12));
      expect(find.byType(NavigationDrawer), findsNothing);
      expect(find.byIcon(Icons.menu_rounded), findsNothing);
      expect(tester.takeException(), isNull);
      if (floating) await _capture(tester, key, 'my-fixed');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('ranking and pinned modules retain compact reference density', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PortalSections(
              data: PortalData(
                rankings: List.generate(
                  15,
                  (i) => PortalEntry(
                    title: '排行$i',
                    url: 'https://ycoo.net/thread-${i + 1}-1-1.html',
                    detail: '123人在看',
                  ),
                ),
                pinned: List.generate(
                  8,
                  (i) => PortalEntry(
                    title: '置顶$i',
                    url: 'https://ycoo.net/thread-${i + 1}-1-1.html',
                    detail: '#公告#',
                  ),
                ),
              ),
              onOpen: (_) {},
              active: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.ancestor(
      of: find.text('排行0'),
      matching: find.byType(ListTile),
    );
    expect(tester.getSize(row).height, lessThanOrEqualTo(48));
    expect(
      tester.getSize(find.byType(GridView)).height,
      lessThanOrEqualTo(280),
    );
    expect(find.text('置顶7'), findsOneWidget);
    final pinned = find.ancestor(
      of: find.text('置顶0'),
      matching: find.byType(ReviewCard),
    );
    final card = tester.widget<ReviewCard>(pinned);
    expect(
      (card.shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(16),
    );
    final thumbnail = find
        .descendant(of: pinned, matching: find.byType(ClipRRect))
        .first;
    expect(
      tester.getTopLeft(thumbnail) - tester.getTopLeft(pinned),
      const Offset(8, 8),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'enabled actions emit one haptic; disabled and cancelled gestures emit none',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') calls.add(call);
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
        HapticFeedbackUtil.isEnabled = true;
        HapticFeedbackUtil.resetForTesting();
      });
      var value = false;
      var index = 0;
      var selected = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Column(
                children: [
                  ReviewCard(
                    onTap: () {},
                    child: const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('卡片'),
                    ),
                  ),
                  ReviewPreferenceTile(title: '设置行', onTap: () {}),
                  ReviewSwitchTile(
                    title: '开关',
                    value: value,
                    onChanged: (next) => setState(() => value = next),
                  ),
                  ChoiceChip(
                    label: const Text('分类'),
                    selected: selected,
                    onSelected: (next) => setState(() => selected = next),
                  ),
                  FilledButton(onPressed: () {}, child: const Text('按钮')),
                  const FilledButton(onPressed: null, child: Text('禁用按钮')),
                  SizedBox(
                    height: 90,
                    child: ReviewNavigationBar(
                      selectedIndex: index,
                      hasBottomInset: false,
                      onSelected: (next) => setState(() => index = next),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> check(Finder finder, int count) async {
        calls.clear();
        HapticFeedbackUtil.resetForTesting();
        await tester.tap(finder);
        await tester.pump();
        expect(calls, hasLength(count));
        await tester.pumpAndSettle();
      }

      HapticFeedbackUtil.isEnabled = true;
      for (final finder in [
        find.text('卡片'),
        find.text('设置行'),
        find.byType(Switch),
        find.byType(ChoiceChip),
        find.text('按钮'),
        find.text('社区'),
      ]) {
        await check(finder, 1);
      }
      await check(find.text('禁用按钮'), 0);
      HapticFeedbackUtil.isEnabled = false;
      for (final finder in [
        find.text('卡片'),
        find.text('设置行'),
        find.byType(Switch),
        find.byType(ChoiceChip),
        find.text('按钮'),
        find.text('首页'),
      ]) {
        await check(finder, 0);
      }
      HapticFeedbackUtil.isEnabled = true;
      calls.clear();
      HapticFeedbackUtil.resetForTesting();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(
            body: ListView(
              children: [
                for (var i = 0; i < 30; i++)
                  ListTile(title: Text('行$i'), onTap: () {}),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('行2')),
      );
      await tester.pump();
      expect(calls, isEmpty, reason: 'pointer down is not a confirmed action');
      await gesture.moveBy(const Offset(0, -120));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(calls, isEmpty, reason: 'scroll cancellation must not vibrate');
    },
  );

  test(
    'turning haptics back on immediately previews and persists feedback',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({'haptics': false});
      final prefs = await SharedPreferences.getInstance();
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            calls.add(call);
            return null;
          });
      HapticFeedbackUtil.isEnabled = false;
      HapticFeedbackUtil.resetForTesting();
      await Settings(prefs).set('haptics', true);
      expect(prefs.getBool('haptics'), isTrue);
      expect(
        calls.where((e) => e.method == 'HapticFeedback.vibrate'),
        hasLength(1),
      );
      await Settings(prefs).set('haptics', false);
      HapticFeedbackUtil.light();
      expect(
        calls.where((e) => e.method == 'HapticFeedback.vibrate'),
        hasLength(1),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      HapticFeedbackUtil.isEnabled = true;
      HapticFeedbackUtil.resetForTesting();
    },
  );
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/previews').createSync(recursive: true);
    File('build/previews/$name.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
