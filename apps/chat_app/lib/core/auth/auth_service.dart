import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env.dart';
import '../network/api_client.dart';
import '../../shared/models/user_profile.dart';
import 'auth_state.dart';

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthState> {
  static const _tokenKey = 'chat_app_jwt_token';
  static const _refreshTokenKey = 'chat_app_refresh_token';

  AuthNotifier() : super(AuthState.initial()) {
    restoreSession();
  }

  Future<void> restoreSession() async {
    state = AuthState.loading();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);

      if (token == null || token.isEmpty) {
        state = AuthState.unauthenticated();
        return;
      }

      await _fetchProfileAndSetState(token, isRestore: true);
    } catch (_) {
      state = AuthState.unauthenticated();
    }
  }

  Future<void> signIn(String email, String password) async {
    state = AuthState.loading();
    try {
      // Direct call to Supabase Auth token endpoint
      final uri =
          Uri.parse('${Env.supabaseUrl}/auth/v1/token?grant_type=password');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'apikey': Env.supabaseAnonKey,
        },
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
        }),
      );

      if (response.statusCode != 200) {
        String message = 'Invalid email or password';
        try {
          final body = jsonDecode(response.body);
          if (body['error_description'] != null) {
            message = body['error_description'];
          } else if (body['msg'] != null) {
            message = body['msg'];
          }
        } catch (_) {}
        state = AuthState.error(message);
        return;
      }

      final data = jsonDecode(response.body);
      final accessToken = data['access_token'] as String;
      final refreshToken = data['refresh_token'] as String?;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, accessToken);
      if (refreshToken != null) {
        await prefs.setString(_refreshTokenKey, refreshToken);
      }

      await _fetchProfileAndSetState(accessToken, isRestore: false);
    } catch (e) {
      state = AuthState.error('Network error during login: $e');
    }
  }

  Future<void> _fetchProfileAndSetState(String token,
      {bool isRestore = false}) async {
    try {
      final apiClient = ApiClient(
        baseUrl: Env.apiBaseUrl,
        getToken: () async => token,
      );

      final statusJson = await apiClient.get('/users/me');
      final profile = UserProfile.fromJson(statusJson);

      if (!profile.isApproved) {
        state = AuthState.unapproved(profile, token);
      } else {
        state = AuthState.authenticated(profile, token);
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401 || isRestore) {
        await signOut();
      } else {
        state = AuthState.error(e.message);
      }
    } catch (e) {
      if (isRestore) {
        await signOut();
      } else {
        state = AuthState.error('Failed to retrieve user status: $e');
      }
    }
  }

  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_refreshTokenKey);
    } catch (_) {}
    state = AuthState.unauthenticated();
  }

  Future<String?> getCurrentToken() async {
    if (state.token != null) return state.token;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }
}
