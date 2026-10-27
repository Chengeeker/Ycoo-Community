import 'package:flutter/widgets.dart';

import '../../data/site.dart';
import '../../settings.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    required this.site,
    required this.settings,
    required super.child,
    super.key,
  });
  final Site site;
  final Settings settings;
  static AppScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>();
  @override
  bool updateShouldNotify(AppScope oldWidget) => true;
}
