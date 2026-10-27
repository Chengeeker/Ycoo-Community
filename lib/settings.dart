import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/utils/haptic_feedback_util.dart';

class Settings extends ChangeNotifier {
  Settings(this.prefs);
  final SharedPreferences prefs;
  ThemeMode get mode =>
      ThemeMode.values[(prefs.getInt('themeMode') ?? 0).clamp(0, 2)];
  bool get dynamicColor => prefs.getBool('dynamicColor') ?? false;
  bool get pureBlack => prefs.getBool('pureBlack') ?? false;
  bool get floating => prefs.getBool('floating') ?? true;
  bool get liquidGlass => prefs.getBool('liquidGlass') ?? false;
  bool get haptics => prefs.getBool('haptics') ?? true;
  int get color => (prefs.getInt('color') ?? 0).clamp(0, 7);
  double get textScale => prefs.getDouble('textScale') ?? 1;
  Future<void> set(String key, Object value) async {
    if (key == 'haptics') {
      HapticFeedbackUtil.isEnabled = value as bool;
      if (value) HapticFeedbackUtil.light();
    }
    if (value is bool) await prefs.setBool(key, value);
    if (value is int) await prefs.setInt(key, value);
    if (value is double) await prefs.setDouble(key, value);
    HapticFeedbackUtil.isEnabled = haptics;
    notifyListeners();
  }
}
