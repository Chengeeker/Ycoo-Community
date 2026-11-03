import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuan_community/core/theme/app_theme.dart';
import 'package:yuan_community/core/widgets/app_section_card.dart';
import 'package:yuan_community/data/site.dart';
import 'package:yuan_community/pages/home.dart';
import 'package:yuan_community/pages/reading_settings.dart';
import 'package:yuan_community/settings.dart';

void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      for (final appearance in [false, true]) {
        testWidgets(
          'section titles align with leading icons: appearance=$appearance dark=$dark scale=$scale',
          (tester) async {
            tester.view.physicalSize = const Size(320, 6000);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            SharedPreferences.setMockInitialValues({});
            final prefs = await SharedPreferences.getInstance();
            final settings = Settings(prefs);
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? AppTheme.darkTheme() : AppTheme.lightTheme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: appearance
                    ? AppearancePage(settings)
                    : SettingsPage(Site(prefs), settings),
              ),
            );
            await tester.pumpAndSettle();
            final pairs = appearance
                ? {
                    '明暗模式': null,
                    '色彩方案': Icons.auto_awesome_outlined,
                    '底部导航': Icons.dock_rounded,
                    '显示效果': Icons.blur_on_rounded,
                    '触感与震动': Icons.vibration_rounded,
                  }
                : {
                    '账号设置': Icons.account_circle_outlined,
                    '偏好与功能': Icons.history_rounded,
                    '内容与服务': Icons.cleaning_services_outlined,
                    '关于与支持': Icons.info_outline,
                  };
            for (final pair in pairs.entries) {
              final leading = pair.value == null
                  ? find.byType(Radio<ThemeMode>).first
                  : find.byIcon(pair.value!);
              expect(
                tester.getTopLeft(find.text(pair.key)).dx,
                closeTo(tester.getTopLeft(leading).dx, 0.1),
                reason: pair.key,
              );
              final card = find.ancestor(
                of: leading,
                matching: find.byType(AppSectionCard),
              );
              expect(
                tester.getTopLeft(find.text(pair.key)).dx -
                    tester.getTopLeft(card).dx,
                16,
                reason: 'The heading starts inside the card edge: ${pair.key}',
              );
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets(
    'reading settings share the card UI and preserve sign-in preference',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'autoSignIn': true});
      final prefs = await SharedPreferences.getInstance();
      final settings = Settings(prefs);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: SettingsPage(Site(prefs), settings),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('自动签到'), findsNothing);
      await tester.scrollUntilVisible(find.text('阅读与社区功能'), 200);
      await tester.tap(find.text('阅读与社区功能'));
      await tester.pumpAndSettle();
      expect(find.byType(ReadingSettingsPage), findsOneWidget);
      for (final label in ['自动加载回复', 'URL 自动链接', '显示 FPS', '自动签到']) {
        final tile = find.ancestor(
          of: find.text(label),
          matching: find.byType(SwitchListTile),
        );
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.text(label)).dx, 72);
        expect(
          find.ancestor(of: tile, matching: find.byType(AppSectionCard)),
          findsOneWidget,
        );
        if (label == '自动签到') {
          expect(tester.widget<SwitchListTile>(tile).value, isTrue);
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(prefs.getBool('autoSignIn'), isFalse);
          expect(tester.widget<SwitchListTile>(tile).value, isFalse);
        }
      }
      expect(prefs.getBool('autoReplies'), isNull);
      expect(prefs.getBool('linkify'), isNull);
      expect(prefs.getBool('showFps'), isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('rounded centered about dialog: dark=$dark scale=$scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.darkTheme() : AppTheme.lightTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: SettingsPage(Site(prefs), Settings(prefs)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('关于源社区'), 250);
        await tester.pumpAndSettle();
        expect(find.textContaining('复用自'), findsNothing);
        await tester.tap(find.text('关于源社区'));
        await tester.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        final image = find.descendant(of: dialog, matching: find.byType(Image));
        final icon = tester.widget<Image>(image);
        final clip = tester.widget<ClipRRect>(
          find.ancestor(of: image, matching: find.byType(ClipRRect)).first,
        );
        expect(clip.borderRadius, BorderRadius.circular(18));
        expect(icon.width, 72);
        expect(icon.height, 72);
        expect(icon.fit, BoxFit.cover);
        final provider =
            (icon.image as ResizeImage).imageProvider as AssetImage;
        expect(provider.assetName, 'assets/site-icon.png');
        expect(
          tester.getCenter(image).dx,
          closeTo(tester.getCenter(dialog).dx, 0.1),
        );
        expect(find.text('v1.2.12'), findsOneWidget);
        expect(find.textContaining('复用自'), findsNothing);
        expect(find.textContaining('Review'), findsNothing);
        expect(
          find.text('github.com/Chengeeker/Ycoo-Community'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('开源仓库'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('开源仓库'));
        await tester.pumpAndSettle();
        expect(find.text('即将离开源社区'), findsOneWidget);
        expect(
          find.text('https://github.com/Chengeeker/Ycoo-Community'),
          findsOneWidget,
        );
        Navigator.of(tester.element(find.text('即将离开源社区'))).pop();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (!dark && scale == 1) {
          await tester.tap(find.text('开源许可'));
          await tester.pumpAndSettle();
          expect(find.byType(LicensePage), findsOneWidget);
          Navigator.of(tester.element(find.byType(LicensePage))).pop();
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('我知道了'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
