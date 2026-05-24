import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  SharedPreferences? _prefs;

  // Connection
  bool autoConnect = false;

  // Display
  bool useDarkTheme = true;
  bool useImperial = false;
  int dashboardRefreshHz = 5;
  bool keepScreenOn = true;

  // CoPilot
  String? openAiApiKey;

  // CSV
  bool autoLogTrips = false;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    autoConnect = _prefs?.getBool('autoConnect') ?? false;
    useDarkTheme = _prefs?.getBool('useDarkTheme') ?? true;
    useImperial = _prefs?.getBool('useImperial') ?? false;
    dashboardRefreshHz = _prefs?.getInt('dashboardRefreshHz') ?? 5;
    keepScreenOn = _prefs?.getBool('keepScreenOn') ?? true;
    openAiApiKey = _prefs?.getString('openAiApiKey');
    autoLogTrips = _prefs?.getBool('autoLogTrips') ?? false;
    notifyListeners();
  }

  Future<void> setAutoConnect(bool v) async {
    autoConnect = v;
    await _prefs?.setBool('autoConnect', v);
    notifyListeners();
  }

  Future<void> setDarkTheme(bool v) async {
    useDarkTheme = v;
    await _prefs?.setBool('useDarkTheme', v);
    notifyListeners();
  }

  Future<void> setImperial(bool v) async {
    useImperial = v;
    await _prefs?.setBool('useImperial', v);
    notifyListeners();
  }

  Future<void> setRefreshHz(int v) async {
    dashboardRefreshHz = v;
    await _prefs?.setInt('dashboardRefreshHz', v);
    notifyListeners();
  }

  Future<void> setKeepScreenOn(bool v) async {
    keepScreenOn = v;
    await _prefs?.setBool('keepScreenOn', v);
    notifyListeners();
  }

  Future<void> setOpenAiKey(String? v) async {
    openAiApiKey = v;
    if (v == null || v.isEmpty) {
      await _prefs?.remove('openAiApiKey');
    } else {
      await _prefs?.setString('openAiApiKey', v);
    }
    notifyListeners();
  }

  Future<void> setAutoLogTrips(bool v) async {
    autoLogTrips = v;
    await _prefs?.setBool('autoLogTrips', v);
    notifyListeners();
  }
}
