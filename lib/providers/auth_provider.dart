import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../models/models.dart';

class AuthState {
  final AppUser? user;
  final bool loading; // 초기 부팅 로딩
  const AuthState({this.user, this.loading = true});

  bool get isLoggedIn => user != null;
  AuthState copyWith({AppUser? user, bool? loading, bool clearUser = false}) => AuthState(
        user: clearUser ? null : (user ?? this.user),
        loading: loading ?? this.loading,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._api) : super(const AuthState()) {
    _boot();
  }
  final ApiClient _api;

  Future<void> _boot() async {
    final token = await _api.token;
    if (token == null) {
      state = const AuthState(loading: false);
      return;
    }
    try {
      final res = await _api.get('/auth/me');
      state = AuthState(user: AppUser.fromJson(res['user']), loading: false);
    } catch (_) {
      await _api.clearToken();
      state = const AuthState(loading: false);
    }
  }

  Future<void> login(String email, String password) async {
    final res = await _api.post('/auth/login', data: {
      'email': email,
      'password': password,
      'device': 'mobile',
    });
    await _api.saveToken(res['token']);
    state = AuthState(user: AppUser.fromJson(res['user']), loading: false);
  }

  Future<void> register(Map<String, dynamic> data) async {
    final res = await _api.post('/auth/register', data: data);
    await _api.saveToken(res['token']);
    state = AuthState(user: AppUser.fromJson(res['user']), loading: false);
  }

  Future<void> refresh() async {
    try {
      final res = await _api.get('/auth/me');
      state = state.copyWith(user: AppUser.fromJson(res['user']));
    } catch (_) {}
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {}
    await _api.clearToken();
    state = const AuthState(loading: false, user: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiProvider));
});
