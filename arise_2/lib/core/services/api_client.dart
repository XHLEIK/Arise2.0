import '../config/app_config.dart';

/// Centralized HTTP client utilities for A.R.I.S.E. 2.0
/// Provides shared headers and timeout constants for all services.
class ApiClient {
  ApiClient._();

  /// Headers for JSON requests with API key authentication.
  static Map<String, String> get jsonHeaders => {
        'Content-Type': 'application/json',
        'X-API-KEY': AppConfig.apiKey,
      };

  /// Headers with only API key (no Content-Type).
  static Map<String, String> get baseHeaders => {
        'X-API-KEY': AppConfig.apiKey,
      };

  /// Default timeout for standard HTTP calls.
  static const Duration defaultTimeout = Duration(seconds: 30);

  /// Extended timeout for long operations (model pulls, large responses).
  static const Duration longTimeout = Duration(seconds: 120);

  /// Timeout for streaming connections (SSE, chat streams).
  static const Duration streamTimeout = Duration(minutes: 5);
}
