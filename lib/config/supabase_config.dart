import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration class for Supabase initialization
class SupabaseConfig {
  static late final SupabaseClient client;
  static bool _initialized = false;

  /// Initialize Supabase with credentials from .env file
  static Future<void> initialize() async {
    if (_initialized) return;

    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw Exception(
        'Supabase credentials not found in .env file. '
        'Please add SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      debug: false, // Disable debug logging in production
    );

    client = Supabase.instance.client;
    _initialized = true;
  }

  /// Get the current Supabase client instance
  static SupabaseClient get instance {
    if (!_initialized) {
      throw Exception(
        'SupabaseConfig not initialized. Call SupabaseConfig.initialize() first.',
      );
    }
    return client;
  }

  /// Check if Supabase is initialized
  static bool get isInitialized => _initialized;
}
