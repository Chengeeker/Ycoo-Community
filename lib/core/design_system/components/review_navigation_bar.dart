import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kTouchSlop;
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
class ReviewNavigationBar extends StatefulWidget {
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

  @override
  State<ReviewNavigationBar> createState() => _ReviewNavigationBarState();
}

class _ReviewNavigationBarState extends State<ReviewNavigationBar> {
  Timer? _holdTimer, _resetTimer;
  int? _pointer;
  Offset? _origin;
  int? _pendingIndex;
  int _gestureId = 0;
  bool _moved = false, _horizontal = false, _lensActive = false;

  void _pointerDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _holdTimer?.cancel();
    _resetTimer?.cancel();
    if (_lensActive) setState(() => _lensActive = false);
    _pointer = event.pointer;
    _origin = event.position;
    _pendingIndex = null;
    _moved = _horizontal = false;
    _gestureId++;
    _holdTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted || _pointer != event.pointer || _moved) return;
      setState(() => _lensActive = true);
      HapticFeedbackUtil.light();
    });
  }

  void _pointerMove(PointerMoveEvent event) {
    if (_pointer != event.pointer || _origin == null) return;
    final delta = event.position - _origin!;
    if (delta.distance <= kTouchSlop) return;
    _moved = true;
    _holdTimer?.cancel();
    if (delta.dx.abs() > delta.dy.abs()) {
      _horizontal = true;
      if (!_lensActive) setState(() => _lensActive = true);
    }
  }

  void _pointerEnd(PointerEvent event, {bool cancelled = false}) {
    if (_pointer != event.pointer) return;
    _holdTimer?.cancel();
    final gesture = _gestureId;
    // Let the glass bar finish its own release callback before choosing a page.
    scheduleMicrotask(() {
      if (!mounted || gesture != _gestureId) return;
      final target = _pendingIndex;
      final rejected = cancelled || (_moved && !_horizontal);
      final wasLens = _lensActive;
      _pointer = null;
      _origin = null;
      _pendingIndex = null;
      if (wasLens) {
        _resetTimer = Timer(const Duration(milliseconds: 250), () {
          if (mounted && gesture == _gestureId) {
            setState(() => _lensActive = false);
          }
        });
      }
      if (!rejected &&
          target != null &&
          (!wasLens || target != widget.selectedIndex)) {
        _select(target);
      }
    });
  }

  void _glassSelected(int index) {
    if (_pointer != null) {
      _pendingIndex = index;
    } else {
      _select(index);
    }
  }

  @override
  void didUpdateWidget(covariant ReviewNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.useLiquidGlass || !widget.useFloating) {
      _holdTimer?.cancel();
      _resetTimer?.cancel();
      _gestureId++;
      _pointer = null;
      _origin = null;
      _pendingIndex = null;
      _lensActive = false;
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _resetTimer?.cancel();
    super.dispose();
  }

  void _select(int index) {
    HapticFeedbackUtil.selection();
    widget.onSelected(index);
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
      math.min(440.0, MediaQuery.sizeOf(context).width - 40.0).toDouble() *
      8 /
      9;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!widget.useFloating) {
      return NavigationBar(
        selectedIndex: widget.selectedIndex,
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

    if (widget.useLiquidGlass) {
      final isLightMode = Theme.of(context).brightness == Brightness.light;
      return SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.hasBottomInset ? 6 : 14),
            child: RepaintBoundary(
              child: SizedBox(
                width: _floatingBarWidth(context),
                height: 56,
                child: Stack(
                  children: [
                    Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: _pointerDown,
                      onPointerMove: _pointerMove,
                      onPointerUp: _pointerEnd,
                      onPointerCancel: (event) =>
                          _pointerEnd(event, cancelled: true),
                      child: GlassTabBar.bottom(
                        tabs: [
                          for (final destination in _destinations)
                            GlassTab(
                              icon: Icon(destination.icon),
                              activeIcon: Icon(destination.selectedIcon),
                              label: destination.label,
                            ),
                        ],
                        selectedIndex: widget.selectedIndex,
                        onTabSelected: _glassSelected,
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
                              : const Color(0x26FFFFFF),
                          bodyMode: GlassBodyMode.clear,
                          refractiveIndex: 1.18,
                          chromaticAberration: 0.025,
                          rimShade: isLightMode ? 0.12 : 0,
                          rimLight: isLightMode ? 0.35 : 0,
                        ),
                        indicatorPinchStrength: _lensActive ? 0.7 : 0,
                        indicatorExpansion: _lensActive
                            ? const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              )
                            : EdgeInsets.zero,
                        quality: GlassQuality.premium,
                        backgroundQuality: GlassQuality.premium,
                        maskingQuality: MaskingQuality.high,
                        enableBlend: true,
                        indicatorColor: isLightMode
                            ? const Color(0x26000000)
                            : const Color(0x26FFFFFF),
                        interactionGlowColor: const Color(0x20FFFFFF),
                        innerBlur: 6,
                        pressScale: 1.06,
                        selectedIconColor: colorScheme.primary,
                        selectedLabelColor: colorScheme.primary,
                        unselectedIconColor: isLightMode
                            ? colorScheme.onSurfaceVariant
                            : Colors.white,
                        unselectedLabelColor: isLightMode
                            ? colorScheme.onSurfaceVariant
                            : Colors.white,
                      ),
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
          padding: EdgeInsets.only(bottom: widget.hasBottomInset ? 6 : 14),
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
                          offset: Offset(widget.selectedIndex.toDouble(), 0),
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
    final selected = widget.selectedIndex == index;
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
