# SIRAJ P0 — B-04: AndroidKeystore direct session storage, corrective patch

## Why this change

Previous integration attempt reached `signup_started` but hit the 60-second test watchdog. This **does not prove** which internal async step stalled. Before that, the same device showed ANRs with `flutter_secure_storage 11.2.0`, and an uncompleted acceptance run with 9.2.4. Do not assert all of these have the same cause.

This patch **removes both versions of flutter_secure_storage from the active session path** and introduces an Android-specific, compact MethodChannel implementation. It encrypts only the session marker with AES-256-GCM using a non-biometric AndroidKeyStore key. Encryption, key generation, reads and writes run on a dedicated background thread, never on Android's UI thread. Flutter calls are bounded (15 seconds), and `AuthService` fails closed on marker failures. The marker and plaintext key are never saved to SQLite; DB stores SHA-256 of the nonce.

## Files

- `android/app/src/main/kotlin/com/example/siraj/MainActivity.kt`: registers native channel with Flutter engine. **Backup and compare existing MainActivity before overwriting.**
- `android/app/src/main/kotlin/com/example/siraj/SirajSecureSessionChannel.kt`: AndroidKeystore AES-256-GCM, two fully separate preference/key namespaces (`production`, `b04_test`), background executor and redacted errors.
- `lib/features/auth/session_marker_store.dart`: MethodChannel adapter and fail-closed 15-second deadline, including a test-only namespace constructor.
- `lib/features/auth/auth_service.dart`: optional stage checkpoint callback (step identifiers only, never password, nonce, account ID or derived hash). Preserves existing auth semantics.
- `integration_test/b04_android_secure_session_test.dart`: trace steps, time-bounded signup, isolated persistent SQLite and encrypted marker, reopen, logout, login, confirmed deletion, resource retention.
- `integration_test/b04_secure_storage_isolation_test.dart`: optional simple native storage smoke test. Do not run it by default.

## Minimal Windows steps

1. Backup project files before overwriting. Stop old stuck Android test if still open.
2. Extract ZIP with `-Force` only after backups and verifying `MainActivity.kt` has no custom logic. The ZIP assumes Flutter's original single-line MainActivity.
3. `flutter pub remove flutter_secure_storage` — only after extraction; no remaining Dart source in this patch imports it. Keep `cryptography` and `cryptography_flutter` unchanged.
4. Ensure `<application android:allowBackup="false" ...>` in `android/app/src/main/AndroidManifest.xml`, preserving other attrs. No biometric permission.
5. `dart format lib/features/auth integration_test/b04_android_secure_session_test.dart integration_test/b04_secure_storage_isolation_test.dart`
6. `flutter analyze` and `flutter test` (37 unit tests expected, existing counts may change as features progress).
7. **One Android acceptance**: `flutter test integration_test/b04_android_secure_session_test.dart -d R3CR40J3XRZ --reporter expanded`.
8. If it fails, collect **last SIRAJ_B04_CORE step** or first explicit error, not full Logcat. No new plugin swaps or repeated runs.

## P0 safety boundary

- The active account still requires credential validation and is bounded to one device-local account.
- Active session only after DB hash and Keystore marker are both valid; logout invalidates DB nonce first.
- Keystore failure or unusable ciphertext causes session restoration to fail closed; no automatic deletion, downgrade, biometric bypass, or plaintext fallback.
- Separate test namespace; no production user profile or resources are deleted by integration test.
- Reopen of isolated SQLite is **not** a real app restart or reboot; those acceptance tests remain outstanding.
- KDF production work factor remains **unapproved**. 1,000 iterations are test-only. Do not ship this as production-complete P0 auth yet.
- Native platform key encryption not verified until actual Samsung Android acceptance passes. Avoid claiming a guaranteed fix beforehand.
- `flutter_secure_storage` migration is intentionally **not** performed because previous B-04 code is not yet released to production. If a real account was ever created with older storage, migration must be planned separately.
- Do not push logcat, bugreport, temp DB or keystore debug data to Git.
