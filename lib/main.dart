import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/haptic_feedback_util.dart';
import 'data/site.dart';
import 'pages/home.dart';
import 'settings.dart';
import 'core/widgets/fps_indicator.dart';
import 'core/widgets/app_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
  final prefs = await SharedPreferences.getInstance();
  runApp(
    LiquidGlassWidgets.wrap(
      child: YuanApp(settings: Settings(prefs), site: Site(prefs)),
      brightnessResolver: Theme.maybeBrightnessOf,
    ),
  );
}

class YuanApp extends StatelessWidget {
  const YuanApp({required this.settings, required this.site, super.key});
  final Settings settings;
  final Site site;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) {
      HapticFeedbackUtil.isEnabled = settings.haptics;
      return DynamicColorBuilder(
        builder: (light, dark) => MaterialApp(
          title: '源社区',
          debugShowCheckedModeBanner: false,
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          themeMode: settings.mode,
          theme: AppTheme.lightTheme(
            colorIndex: settings.color,
            dynamicColorScheme: settings.dynamicColor ? light : null,
          ),
          darkTheme: AppTheme.darkTheme(
            colorIndex: settings.color,
            isPureBlack: settings.pureBlack,
            dynamicColorScheme: settings.dynamicColor ? dark : null,
          ),
          builder: (context, child) => AppScope(
            site: site,
            settings: settings,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: _AppTextScaler(
                  MediaQuery.textScalerOf(context),
                  settings.textScale,
                ),
              ),
              child: settings.prefs.getBool('showFps') == true
                  ? Stack(
                      children: [
                        child!,
                        Positioned(
                          top: MediaQuery.viewPaddingOf(context).top,
                          left: 4,
                          child: const FpsIndicator(),
                        ),
                      ],
                    )
                  : child!,
            ),
          ),
          home: HomePage(site, settings),
        ),
      );
    },
  );
}

class _AppTextScaler extends TextScaler {
  const _AppTextScaler(this.system, this.factor);
  final TextScaler system;
  final double factor;
  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;
  @override
  double get textScaleFactor => system.scale(14) / 14 * factor;
}
