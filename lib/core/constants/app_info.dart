/// Application identity. Version mirrors pubspec.yaml `version:`
/// (kept in sync by test/app_info_test.dart — no package_info dependency).
abstract final class AppInfo {
  static const String name = 'Companion';
  static const String version = '1.0.0+1';
  static const String tagline = 'Local-only companion. No AI, no accounts, no network.';
}
