import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:liquid_glass_widgets/widgets/shared/glass_effect.dart';
import 'package:yuan_community/core/design_system/components/review_navigation_bar.dart';
import 'package:yuan_community/core/theme/app_theme.dart';

void main() {
  testWidgets('light liquid glass navigation matches GreenNote material', (
    tester,
  ) async {
    final colorScheme = AppTheme.lightTheme().colorScheme;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          bottomNavigationBar: ReviewNavigationBar(
            selectedIndex: 0,
            hasBottomInset: false,
            onSelected: (_) {},
            useLiquidGlass: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
    final screenWidth = MediaQuery.sizeOf(
      tester.element(find.byType(GlassTabBar)),
    ).width;
    expect(
      tester.getSize(find.byType(GlassTabBar)).width,
      closeTo(math.min(440.0, screenWidth - 40.0) * 8 / 9, 0.01),
    );
    expect(bar.settings?.glassColor, const Color(0xF0FFFFFF));
    expect(bar.settings?.rimLight, 1);
    expect(bar.settings?.shadowElevation, 0.55);
    expect(bar.indicatorSettings?.glassColor, const Color(0x18000000));
    expect(bar.indicatorSettings?.bodyMode, GlassBodyMode.clear);
    expect(bar.indicatorSettings?.rimShade, 0.12);
    expect(bar.indicatorSettings?.rimLight, 0.35);
    expect(bar.indicatorPinchStrength, 0);
    expect(bar.indicatorExpansion, EdgeInsets.zero);
    expect(bar.indicatorColor, const Color(0x26000000));
    expect(bar.selectedIconColor, colorScheme.primary);
    expect(bar.selectedLabelColor, colorScheme.primary);
    expect(bar.unselectedIconColor, colorScheme.onSurfaceVariant);
    expect(bar.unselectedLabelColor, colorScheme.onSurfaceVariant);
    expect(
      find.byKey(const ValueKey('liquid-glass-light-rim')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dark liquid glass selection matches GreenNote and theme changes',
    (tester) async {
      final theme = AppTheme.darkTheme();
      var selected = 0;
      Future<void> show(ThemeData theme) => tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            bottomNavigationBar: ReviewNavigationBar(
              selectedIndex: 0,
              hasBottomInset: false,
              onSelected: (value) => selected = value,
              useLiquidGlass: true,
            ),
          ),
        ),
      );
      for (final theme in [
        theme,
        theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(primary: Colors.greenAccent),
        ),
      ]) {
        await show(theme);
        await tester.pumpAndSettle();

        final bar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
        expect(bar.settings?.glassColor, const Color(0x66000000));
        expect(bar.settings?.shadowElevation, 0);
        expect(bar.indicatorSettings?.glassColor, const Color(0x26FFFFFF));
        expect(bar.indicatorSettings?.bodyMode, GlassBodyMode.clear);
        expect(bar.indicatorSettings?.rimShade, 0);
        expect(bar.indicatorSettings?.rimLight, 0);
        expect(bar.indicatorPinchStrength, 0);
        expect(bar.indicatorExpansion, EdgeInsets.zero);
        expect(bar.indicatorColor, const Color(0x26FFFFFF));
        expect(bar.selectedIconColor, theme.colorScheme.primary);
        expect(bar.selectedLabelColor, theme.colorScheme.primary);
        expect(bar.unselectedIconColor, Colors.white);
        expect(bar.unselectedLabelColor, Colors.white);
        expect(
          find.byKey(const ValueKey('liquid-glass-light-rim')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
      final rect = tester.getRect(find.byType(GlassTabBar));
      await tester.tapAt(
        Offset(rect.left + rect.width * 3 / 8, rect.center.dy),
      );
      await tester.pumpAndSettle();
      expect(selected, 1);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'tap stays flat; hold and drag restore the full lens in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var selected = 0;
        var useGlass = true;
        late StateSetter update;
        final selections = <int>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.dark
                ? AppTheme.darkTheme()
                : AppTheme.lightTheme(),
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Scaffold(
                  bottomNavigationBar: ReviewNavigationBar(
                    selectedIndex: selected,
                    hasBottomInset: false,
                    useLiquidGlass: useGlass,
                    onSelected: (index) {
                      selections.add(index);
                      setState(() => selected = index);
                    },
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        GlassTabBar bar() =>
            tester.widget<GlassTabBar>(find.byType(GlassTabBar));
        final bounds = tester.getRect(find.byType(GlassTabBar));
        Offset slot(int index) => Offset(
          bounds.left + bounds.width * (index + .5) / 4,
          bounds.center.dy,
        );
        final tap = await tester.startGesture(slot(1));
        await tester.pump(const Duration(milliseconds: 80));
        expect(bar().indicatorPinchStrength, 0);
        expect(bar().indicatorExpansion, EdgeInsets.zero);
        expect(
          tester
              .widgetList<AnimatedGlassIndicator>(
                find.byType(AnimatedGlassIndicator),
              )
              .every((lens) => lens.thickness == 0),
          isTrue,
        );
        await tap.up();
        await tester.pumpAndSettle();
        expect(selections, [1]);
        selections.clear();

        final hold = await tester.startGesture(slot(1));
        await tester.pump(const Duration(milliseconds: 230));
        await tester.pump(const Duration(milliseconds: 350));
        expect(bar().indicatorPinchStrength, .7);
        expect(selections, isEmpty);
        final lens = find.byType(GlassEffect).last;
        final effect = tester.widget<GlassEffect>(lens);
        expect(effect.settings.pinchStrength, closeTo(.7, .01));
        expect(effect.settings.refractiveIndex, 1.18);
        expect(effect.settings.chromaticAberration, .025);
        expect(tester.getSize(lens).height, closeTo(64, 1));
        expect(
          tester.getSize(lens).width,
          closeTo((bounds.width - 8) / 4 + 24, 1),
        );
        await hold.moveTo(slot(2));
        await tester.pump(const Duration(milliseconds: 100));
        final before = tester
            .widgetList<AnimatedGlassIndicator>(
              find.byType(AnimatedGlassIndicator),
            )
            .first
            .alignment;
        await hold.moveBy(const Offset(8, 0));
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          tester
              .widgetList<AnimatedGlassIndicator>(
                find.byType(AnimatedGlassIndicator),
              )
              .first
              .alignment,
          isNot(before),
        );
        expect(selections, isEmpty);
        await hold.up();
        await tester.pumpAndSettle();
        expect(selections, [2]);
        expect(bar().indicatorPinchStrength, 0);
        expect(bar().indicatorExpansion, EdgeInsets.zero);

        selections.clear();
        final drag = await tester.startGesture(slot(2));
        await drag.moveBy(const Offset(25, 0));
        await tester.pump(const Duration(milliseconds: 40));
        expect(bar().indicatorPinchStrength, .7);
        await drag.cancel();
        await tester.pumpAndSettle();
        expect(selections, isEmpty);
        expect(bar().indicatorPinchStrength, 0);
        expect(tester.takeException(), isNull);

        final disabled = await tester.startGesture(slot(0));
        await tester.pump(const Duration(milliseconds: 230));
        update(() => useGlass = false);
        await tester.pumpAndSettle();
        expect(find.byType(GlassTabBar), findsNothing);
        await disabled.cancel();
        update(() => useGlass = true);
        await tester.pumpAndSettle();
        await tester.startGesture(slot(0));
        await tester.pump(const Duration(milliseconds: 230));
        expect(bar().indicatorPinchStrength, .7);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
