/// Configuration management supporting compile-time `--dart-define` values
/// and local development defaults.
class Env {
  /// Base HTTP API URL (e.g. Render backend or local server)
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// Base WebSocket URL
  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://localhost:8000/ws',
  );

  /// Supabase project URL for direct Auth operations
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://placeholder.supabase.co',
  );

  /// Supabase Anon Key (Safe for public client distribution)
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'placeholder-anon-key',
  );
}
