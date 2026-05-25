/// Centralized configuration for A.R.I.S.E. 2.0
/// All base URLs and authentication keys are defined here.
/// Override at build time: flutter run --dart-define=SPRING_BASE_URL=http://...
class AppConfig {
  AppConfig._();

  static const String springBaseUrl = String.fromEnvironment(
    'SPRING_BASE_URL',
    defaultValue: 'http://localhost:8081',
  );

  static const String pythonBaseUrl = String.fromEnvironment(
    'PYTHON_BASE_URL',
    defaultValue: 'http://localhost:8002',
  );

  static const String apiKey = String.fromEnvironment(
    'ARISE_API_KEY',
    defaultValue: 'arise-local-dev-key',
  );
}
