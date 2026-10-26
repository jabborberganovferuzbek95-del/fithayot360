import 'package:flutter/material.dart';

import 'api_client.dart';
import 'models.dart';

enum AuthStatus { loading, onboarding, signedOut, needsProfile, ready }

class AppState extends ChangeNotifier {
  AppState() {
    api = ApiClient(tokens)..onSessionExpired = _expired;
  }

  final tokens = TokenStore();
  late final ApiClient api;
  final navigatorKey = GlobalKey<NavigatorState>();

  AuthStatus status = AuthStatus.loading;
  Me? me;
  String? bootError;
  bool _onboarded = false;
  ThemeMode themeMode = ThemeMode.system;

  Future<void> init() async {
    status = AuthStatus.loading;
    bootError = null;
    notifyListeners();
    _onboarded = await tokens.onboarded;
    final tm = await tokens.theme;
    themeMode = tm == 'dark' ? ThemeMode.dark : (tm == 'light' ? ThemeMode.light : ThemeMode.system);
    if (await tokens.access == null && await tokens.refresh == null) return _signedOut();
    try {
      await loadMe();
    } on ApiException catch (e) {
      if (e.status == 0 || e.status >= 500) {
        bootError = e.message; // oflayn: sessiyani saqlab qolamiz, qayta urinish tugmasi ko'rsatiladi
        notifyListeners();
      } else {
        await tokens.clear();
        _signedOut();
      }
    }
  }

  Future<void> loadMe() async {
    me = Me.fromJson(Map<String, dynamic>.from(await api.get('/me')));
    status = me!.profileCompleted ? AuthStatus.ready : AuthStatus.needsProfile;
    notifyListeners();
  }

  void _signedOut() {
    me = null;
    status = _onboarded ? AuthStatus.signedOut : AuthStatus.onboarding;
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
    notifyListeners();
  }

  void _expired() async {
    await tokens.clear();
    _signedOut();
  }

  Future<void> finishOnboarding() async {
    await tokens.setOnboarded();
    _onboarded = true;
    if (status == AuthStatus.onboarding) {
      status = AuthStatus.signedOut;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    final j = await api.post('/auth/login', body: {'email': email, 'password': password}, auth: false);
    await tokens.save(j['access_token'], j['refresh_token']);
    await loadMe();
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    await tokens.setTheme(m.name);
    notifyListeners();
  }

  Future<void> register(String email, String password, {String? fullName}) async {
    final j = await api.post('/auth/register',
        body: {
          'email': email, 'password': password, 'is_adult_confirmed': true, 'accept_terms': true,
          if (fullName != null && fullName.trim().isNotEmpty) 'full_name': fullName.trim(),
        },
        auth: false);
    await tokens.save(j['access_token'], j['refresh_token']);
    await loadMe();
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
  }

  Future<void> logout() async {
    await tokens.clear();
    _signedOut();
  }

  Future<void> updateMe(Map<String, dynamic> patch) async {
    me = Me.fromJson(Map<String, dynamic>.from(await api.patch('/me', body: patch)));
    status = me!.profileCompleted ? AuthStatus.ready : AuthStatus.needsProfile;
    notifyListeners();
  }
}
