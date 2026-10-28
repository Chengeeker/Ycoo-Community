import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../theme/app_theme.dart';
import '../../utils/haptic_feedback_util.dart';

double reviewFloatingNavigationClearance(
  BuildContext context, {
  required bool useFloating,
  required bool useLiquidGlass,
}) {
  if (!useFloating) return 16;
  final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
  final hasBottomInset = bottomInset > 0;
  return 56 +
      (hasBottomInset ? 6 : 14) +
      (hasBottomInset && !useLiquidGlass ? bottomInset : 0) +
      8;
}

/// Material 3 navigation shared by the app shell.
class ReviewNavigationBar extends StatelessWidget {
  const ReviewNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.hasBottomInset,
    this.isTransitioning = false,
    this.useFloating = true,
    this.useLiquidGlass = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool hasBottomInset;
  final bool isTransitioning;
  final bool useFloating;
  final bool useLiquidGlass;

  void _select(int index) {
    HapticFeedbackUtil.selection();
    onSelected(index);
  }

  static const _destinations = <_NavigationDestination>[
    _NavigationDestination(
      icon: Icons.dynamic_feed_outlined,
      selectedIcon: Icons.dynamic_feed_rounded,
      label: '首页',
    ),
    _NavigationDestination(
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
      label: '社区',
    ),
    _NavigationDestination(
      icon: Icons.auto_stories_outlined,
      selectedIcon: Icons.auto_stories_rounded,
      label: '导读',
    ),
    _NavigationDestination(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: '我的',
    ),
  ];

  static double _floatingBarWidth(BuildContext context) =>
      math.min(440.0, MediaQuery.sizeOf(context).width - 32.0).toDouble();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!useFloating) {
      return NavigationBar(
        selectedIndex: selectedIndex,
        elevation: 0,
        height: 68,
        onDestinationSelected: _select,
        destinations: [
          for (final destination in _destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
            ),
        ],
      );
    }

    if (useLiquidGlass) {
      final isLightMode = Theme.of(context).brightness == Brightness.light;
      return SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: hasBottomInset ? 6 : 14),
            child: RepaintBoundary(
              child: SizedBox(
                width: _floatingBarWidth(context),
                height: 56,
                child: Stack(
                  children: [
                    GlassTabBar.bottom(
                      tabs: [
                        for (final destination in _destinations)
                          GlassTab(
                            icon: Icon(destination.icon),
                            activeIcon: Icon(destination.selectedIcon),
                            label: destination.label,
                          ),
                      ],
                      selectedIndex: selectedIndex,
                      onTabSelected: _select,
                      barHeight: 56,
                      horizontalPadding: 0,
                      verticalPadding: 0,
                      barBorderRadius: 9999,
                      indicatorBorderRadius: 9999,
                      settings: LiquidGlassSettings(
                        glassColor: isLightMode
                            ? const Color(0xF0FFFFFF)
                            : const Color(0x66000000),
                        bodyMode: GlassBodyMode.clear,
                        thickness: 10,
                        blur: 2,
                        lightIntensity: 0.25,
                        ambientStrength: 0,
                        refractiveIndex: 1.19,
                        chromaticAberration: 0.008,
                        rimLight: isLightMode ? 1 : 0,
                        shadowElevation: isLightMode ? 0.55 : 0,
                      ),
                      indicatorSettings: LiquidGlassSettings(
                        glassColor: isLightMode
                            ? const Color(0x18000000)
                            : const Color(0x00FFFFFF),
                        bodyMode: isLightMode
                            ? GlassBodyMode.clear
                            : GlassBodyMode.adaptive,
                        refractiveIndex: 1.18,
                        chromaticAberration: 0.025,
                        rimShade: isLightMode ? 0.12 : 0,
                        rimLight: isLightMode ? 0.35 : 0,
                      ),
                      quality: GlassQuality.premium,
                      backgroundQuality: GlassQuality.premium,
                      maskingQuality: MaskingQuality.high,
                      enableBlend: true,
                      indicatorColor: isLightMode
                          ? const Color(0x26000000)
                          : const Color(0x66000000),
                      interactionGlowColor: const Color(0x20FFFFFF),
                      innerBlur: 6,
                      pressScale: 1.06,
                      selectedIconColor: isLightMode
                          ? colorScheme.primary
                          : Colors.white,
                      selectedLabelColor: isLightMode
                          ? colorScheme.primary
                          : Colors.white,
                      unselectedIconColor: isLightMode
                          ? colorScheme.onSurfaceVariant
                          : Colors.white,
                      unselectedLabelColor: isLightMode
                          ? colorScheme.onSurfaceVariant
                          : Colors.white,
                    ),
                    if (isLightMode)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            key: const ValueKey('liquid-glass-light-rim'),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9999),
                              border: Border.all(
                                color: const Color(0xF5FFFFFF),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(bottom: hasBottomInset ? 6 : 14),
          child: Container(
            width: _floatingBarWidth(context),
            height: 56,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.35
                        : 0.12,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / _destinations.length;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: itemWidth,
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          offset: Offset(selectedIndex.toDouble(), 0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: List.generate(
                          _destinations.length,
                          (index) => Expanded(
                            child: _buildFloatingItem(
                              context,
                              index,
                              colorScheme,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingItem(
    BuildContext context,
    int index,
    ColorScheme colorScheme,
  ) {
    final selected = selectedIndex == index;
    final destination = _destinations[index];
    final activeContent = colorScheme.onSecondaryContainer;
    final inactiveContent = colorScheme.onSurfaceVariant;

    return Semantics(
      label: destination.label,
      button: true,
      selected: selected,
      excludeSemantics: true,
      onTap: () => _select(index),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          onTap: () => _select(index),
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: Icon(
                      selected ? destination.selectedIcon : destination.icon,
                      key: ValueKey(selected),
                      size: 22,
                      color: selected ? activeContent : inactiveContent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: context.adjustWeight(
                        selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      color: selected ? activeContent : inactiveContent,
                    ),
                    child: Text(destination.label),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationDestination {
  const _NavigationDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
