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
  ThemeMode themeMode = ThemeMode.system;

  Future<void> init() async {
    status = AuthStatus.loading;
    bootError = null;
    notifyListeners();
    
    final tm = await tokens.theme;
    themeMode = tm == 'dark' ? ThemeMode.dark : (tm == 'light' ? ThemeMode.light : ThemeMode.system);
    
    try {
      await loadMe();
    } catch (e) {
      // Backend mavjud bo'lmaganda yoki oflayn holatda ham ilova to'g'ridan-to'g'ri ochiladi
      me = Me.defaultUser();
      status = AuthStatus.ready;
      notifyListeners();
    }
  }

  Future<void> loadMe() async {
    try {
      final res = await api.get('/me');
      me = Me.fromJson(Map<String, dynamic>.from(res));
    } catch (_) {
      me ??= Me.defaultUser();
    }
    status = AuthStatus.ready;
    notifyListeners();
  }

  void _expired() async {
    await loadMe();
  }

  Future<void> finishOnboarding() async {
    await tokens.setOnboarded();
    status = AuthStatus.ready;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    await loadMe();
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    await tokens.setTheme(m.name);
    notifyListeners();
  }

  Future<void> register(String email, String password, {String? fullName}) async {
    await loadMe();
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
  }

  Future<void> logout() async {
    // Login qismi olib tashlangan, ma'lumotlarni qayta yuklaydi
    await loadMe();
  }

  Future<void> updateMe(Map<String, dynamic> patch) async {
    try {
      final res = await api.patch('/me', body: patch);
      me = Me.fromJson(Map<String, dynamic>.from(res));
    } catch (_) {
      // Mahalliy xotirada yangilash
      if (me != null) {
        final newProfile = Map<String, dynamic>.from(me!.profile);
        patch.forEach((k, v) {
          if (k == 'full_name') {
            // me fullName
          } else {
            newProfile[k] = v;
          }
        });
        me = Me.fromJson({
          'id': me!.id,
          'email': me!.email,
          'full_name': patch['full_name'] ?? me!.fullName,
          'role': me!.role,
          'profile': newProfile,
          'settings': me!.settings,
          'profile_completed': true,
        });
      }
    }
    status = AuthStatus.ready;
    notifyListeners();
  }
}
