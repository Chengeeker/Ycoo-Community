import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class ReviewGalleryGlassIconButton extends StatefulWidget {
  const ReviewGalleryGlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.opacity,
    required this.opacityKey,
    required this.useLiquidGlass,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double opacity;
  final Key opacityKey;
  final bool useLiquidGlass;

  @override
  State<ReviewGalleryGlassIconButton> createState() =>
      ReviewGalleryGlassIconButtonState();
}

class ReviewGalleryGlassIconButtonState
    extends State<ReviewGalleryGlassIconButton> {
  static Future<ui.FragmentProgram>? _programFuture;
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    if (!widget.useLiquidGlass && ui.ImageFilter.isShaderFilterSupported) {
      _loadShader();
    }
  }

  @override
  void didUpdateWidget(covariant ReviewGalleryGlassIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.useLiquidGlass == widget.useLiquidGlass) return;
    if (widget.useLiquidGlass) {
      _shader?.dispose();
      _shader = null;
    } else if (ui.ImageFilter.isShaderFilterSupported) {
      _loadShader();
    }
  }

  Future<void> _loadShader() async {
    try {
      final program = await (_programFuture ??= ui.FragmentProgram.fromAsset(
        'shaders/gallery_glass_button.frag',
      ));
      final shader = program.fragmentShader();
      if (!mounted || widget.useLiquidGlass) {
        shader.dispose();
        return;
      }
      setState(() => _shader = shader);
    } catch (_) {
      // Blur and the highlight surface remain usable if shader loading fails.
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = widget.opacity;
    if (widget.useLiquidGlass) {
      return GestureDetector(
        excludeFromSemantics: true,
        // Long holds are reserved for exploring the liquid effect.
        onLongPress: () {},
        child: GlassButton(
          label: widget.tooltip,
          width: 48,
          height: 48,
          icon: widget.icon,
          iconSize: 22,
          iconColor: Colors.white,
          onTap: () => widget.onPressed?.call(),
          enabled: widget.onPressed != null,
          useOwnLayer: true,
          stretch: 0.8,
          anchorStretchSettings: const AnchorStretchSettings(
            intensity: 0.8,
            squashFactor: 0.3,
            translationDamping: 0.15,
            bounciness: 0.2,
          ),
          glowColor: const Color(0x20FFFFFF),
          glowOpacity: 1,
          quality: GlassQuality.premium,
          settings: LiquidGlassSettings(
            visibility: opacity,
            glassColor: const Color(0x66000000),
            bodyMode: GlassBodyMode.clear,
            thickness: 32,
            blur: 2,
            lightIntensity: 0.25,
            ambientStrength: 0,
            refractiveIndex: 1.24,
            chromaticAberration: 0.025,
            shadowElevation: 0,
          ),
        ),
      );
    }
    final blur = ui.ImageFilter.blur(
      sigmaX: 2.5 * opacity,
      sigmaY: 2.5 * opacity,
    );
    final shader = _shader;
    final filter = shader == null || opacity < 1
        ? blur
        : ui.ImageFilter.compose(
            outer: ui.ImageFilter.shader(shader),
            inner: blur,
          );

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20 * opacity),
                    blurRadius: 7,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.08 * opacity),
                    blurRadius: 5,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: ClipOval(
                clipBehavior: Clip.antiAlias,
                child: BackdropFilter(
                  filter: filter,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.grey.shade200.withValues(
                            alpha: 0.30 * opacity,
                          ),
                          Colors.grey.shade500.withValues(
                            alpha: 0.20 * opacity,
                          ),
                          Colors.grey.shade800.withValues(
                            alpha: 0.36 * opacity,
                          ),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.34 * opacity),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: widget.tooltip,
            style: IconButton.styleFrom(
              fixedSize: const Size.square(48),
              padding: EdgeInsets.zero,
              foregroundColor: Colors.white,
              backgroundColor: Colors.transparent,
              shape: const CircleBorder(),
            ),
            onPressed: widget.onPressed,
            icon: Opacity(
              key: widget.opacityKey,
              opacity: opacity,
              child: widget.icon,
            ),
          ),
        ],
      ),
    );
  }
}
