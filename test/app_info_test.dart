import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_companion/core/constants/app_info.dart';

/// Guards the no-dependency version strategy: AppInfo.version must equal
/// pubspec.yaml `version:` (avoids package_info_plus entirely).
void main() {
  test('AppInfo.version matches pubspec.yaml', () {
    final text = File('pubspec.yaml').readAsStringSync();
    final match =
        RegExp(r'^version:\s*(\S+)\s*$', multiLine: true).firstMatch(text);
    expect(match, isNotNull, reason: 'pubspec has no version line');
    expect(AppInfo.version, match!.group(1));
  });
}
