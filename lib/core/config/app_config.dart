/// Build-time defaults for Supabase and the Python FastAPI ML server.
///
/// Both values are safe client-side identifiers (the publishable key only
/// grants access permitted by PostgreSQL Row-Level Security policies).
/// Override at build/run time with `--dart-define=SUPABASE_URL=...`,
/// `--dart-define=SUPABASE_PUBLISHABLE_KEY=...`, or `--dart-define=ML_SERVER_URL=...`.
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wxdacmoxlvblmakrwkog.supabase.co',
  );

  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_4RgXahz2RGB2O6LWNa-YvQ_pwhTrWCo',
  );

  static const defaultMlServerUrl = String.fromEnvironment(
    'ML_SERVER_URL',
    defaultValue: 'http://127.0.0.1:7860',
  );

  /// True once `Supabase.initialize(...)` has completed in `main()`.
  /// Remains `false` inside widget tests that pump `KheryneApp` directly.
  static bool supabaseReady = false;
}
