import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
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
    expect(bar.settings?.glassColor, const Color(0xF0FFFFFF));
    expect(bar.settings?.rimLight, 1);
    expect(bar.settings?.shadowElevation, 0.55);
    expect(bar.indicatorSettings?.glassColor, const Color(0x18000000));
    expect(bar.indicatorSettings?.bodyMode, GlassBodyMode.clear);
    expect(bar.indicatorSettings?.rimShade, 0.12);
    expect(bar.indicatorSettings?.rimLight, 0.35);
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

  testWidgets('dark liquid glass navigation keeps its original appearance', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme(),
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
    expect(bar.settings?.glassColor, const Color(0x66000000));
    expect(bar.settings?.shadowElevation, 0);
    expect(bar.indicatorSettings?.glassColor, const Color(0x00FFFFFF));
    expect(bar.indicatorSettings?.bodyMode, GlassBodyMode.adaptive);
    expect(bar.indicatorSettings?.rimShade, 0);
    expect(bar.indicatorSettings?.rimLight, 0);
    expect(bar.indicatorColor, const Color(0x66000000));
    expect(bar.selectedIconColor, Colors.white);
    expect(bar.unselectedIconColor, Colors.white);
    expect(find.byKey(const ValueKey('liquid-glass-light-rim')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
