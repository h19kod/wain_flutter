import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api.dart';
import 'widgets.dart';

/// Settings that outlive a screen: which server, light or dark, and the shop sign-in.
class AppState extends ChangeNotifier {
  AppState(this._api, {this.themeMode = ThemeMode.system}) {
    _api.onSignedOut = _forgetToken;
  }

  static Future<AppState> load({http.Client? client}) async {
    final server = await LocalStore.read(LocalStore.server);
    final token = await LocalStore.read(LocalStore.shopToken);
    final theme = await LocalStore.read(LocalStore.themeMode);
    return AppState(
      WainApi(baseUrl: server ?? defaultBaseUrl, token: token, client: client),
      themeMode: ThemeMode.values.firstWhere((m) => m.name == theme, orElse: () => ThemeMode.system),
    );
  }

  WainApi _api;
  WainApi get api => _api;
  ThemeMode themeMode;

  bool get signedIn => _api.token != null;

  Future<void> setServer(String url) async {
    final clean = url.trim();
    final changed = clean.isEmpty ? defaultBaseUrl : clean;
    _api = WainApi(baseUrl: changed, token: _api.token)..onSignedOut = _forgetToken;
    await LocalStore.write(LocalStore.server, clean.isEmpty ? null : clean);
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    themeMode = mode;
    await LocalStore.write(LocalStore.themeMode, mode.name);
    notifyListeners();
  }

  /// Saves the token the API just received from login or register.
  Future<void> signedInNow() async {
    await LocalStore.write(LocalStore.shopToken, _api.token);
    notifyListeners();
  }

  Future<void> signOut() async {
    _api.token = null;
    await _forgetToken();
  }

  Future<void> _forgetToken() async {
    await LocalStore.write(LocalStore.shopToken, null);
    notifyListeners();
  }
}
