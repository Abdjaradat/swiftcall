import 'package:flutter/foundation.dart';

class AppSettingsNotifier extends ChangeNotifier {
  static final AppSettingsNotifier instance = AppSettingsNotifier._();
  AppSettingsNotifier._();

  bool _isDark = true;
  String _locale = 'ar';

  bool get isDark => _isDark;
  String get locale => _locale;

  /// Seeds initial values without notifying listeners (called at startup).
  void init(bool isDark, String locale) {
    _isDark = isDark;
    _locale = locale;
  }

  void setDark(bool v) {
    _isDark = v;
    notifyListeners();
  }

  void setLocale(String v) {
    _locale = v;
    notifyListeners();
  }
}
