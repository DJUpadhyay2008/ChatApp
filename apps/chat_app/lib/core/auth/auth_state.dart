import '../../shared/models/user_profile.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unapproved,
  unauthenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final UserProfile? user;
  final String? token;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.user,
    this.token,
    this.errorMessage,
  });

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);

  factory AuthState.loading() => const AuthState(status: AuthStatus.loading);

  factory AuthState.unauthenticated([String? error]) => AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: error,
      );

  factory AuthState.unapproved(UserProfile user, String token) => AuthState(
        status: AuthStatus.unapproved,
        user: user,
        token: token,
      );

  factory AuthState.authenticated(UserProfile user, String token) => AuthState(
        status: AuthStatus.authenticated,
        user: user,
        token: token,
      );

  factory AuthState.error(String message) => AuthState(
        status: AuthStatus.error,
        errorMessage: message,
      );
}
