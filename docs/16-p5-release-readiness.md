# 16 — P5 Release Readiness (completed 2026-09-23/24)

Non-AI, offline, network-free. No new dependencies.

## 1. Build environment: DIAGNOSED + REPAIRED

- Symptom: `flutter build apk` failed configuring `:app`; flutter-tool path
  showed `sdkmanager.bat` crashing (0xC0000409).
- Actual cause (direct `gradlew assembleDebug --stacktrace`):
  `[CXX1101] NDK at C:\src\sdk\ndk\28.2.13676358 did not have a
  source.properties file`. The dir held only `.installer/` — an incomplete
  NDK download. AGP validates the pinned NDK (`ndkVersion =
  flutter.ndkVersion`, template default) at configuration time even though
  the app ships no native code. The sdkmanager crash was downstream cascade.
- Repair: standalone reinstall, verified via `source.properties`.
  Note: sdkmanager still exits -1073740791 at teardown AFTER payload lands —
  verify by artifacts, not exit code.
- Second fault (2026-09-24): `cleanMergeDebugAssets` delete failures on
  fresh font assets. Isolated to the OneDrive-synced folder (identical source
  outside OneDrive builds first try). Guidance: pause sync during Gradle
  builds or build from a non-synced copy. No app-code impact.

## 2. Builds

- `flutter build apk --debug` → PASS (148.9MB).
- `flutter build apk --release` → PASS (49MB, debug-signed).
- aapt audit: label `Companion`, version 1.0.0, zero network permissions
  (only Flutter's internal non-exported-receiver permission).

## 3. Release configuration (store publication DEFERRED by decision)

- Label: `Companion`. applicationId `com.example.ai_companion`: kept
  (Android requires one; replacing deferred with store work).
- No keystore, no Play signing — debug-signed local builds only, stated in
  `build.gradle.kts` comment. Icon: Flutter default (deferred).

## 4. Offline pass: PASS

Zero network/media imports in `lib/`; no code path needs connectivity.

## 5. Performance (host-measured, 10k-message thread)

insert 8.9s, page(50) 2ms, LIKE search 6ms, count 0ms, fresh open 12ms —
asserted in `test/db_perf_test.dart`. Device frame timing NOT TESTED.

## 6. Device/emulator: PASS (core path, API-36 emulator)

Install + launch, onboarding → Home, chat send with programmed reply +
caption, force-stop restart persistence (flag, messages, history metadata),
logcat clean. Deeper tap-throughs covered by widget tests, not re-driven.

## 7. Verification matrix

analyze PASS · tests 47/47 PASS · debug/release APKs PASS · device core
path PASS · iOS NOT TESTED (no macOS host).
