# SIRAJ P0 — B-04 Auth Core (الخطوة التالية)

الحالة: **جاهز للاختبارات المحلية، غير معتمد إنتاجيًا**.

## ملفات الحزمة
- `lib/features/auth/auth_models.dart`: نموذج الجلسة وعلامتها وأخطاء المصادقة.
- `lib/features/auth/session_marker_store.dart`: عقد التخزين المشفر والتطبيق باستخدام `flutter_secure_storage` (Android Keystore-backed).
- `lib/features/auth/session_guard.dart`: التحقق من user_id/account_epoch وSHA-256 لبصمة session_nonce المخزنة في SQLite.
- `lib/features/auth/auth_service.dart`: إنشاء حساب محلي واحد، Login، Restore، Logout، وحذف مؤكد.
- `test/auth_service_test.dart`: اختبارات منطقية على SQLite مؤقت وFake marker.

## احترام المواصفة
1. SQLite يفرض `singleton_slot=1`؛ التحقق في الخدمة مبدئي، وليس البديل عن قيد القاعدة.
2. PBKDF2-HMAC-SHA256/Salts وKDF params من `PasswordHasher` الموجود؛ **عدد التكرارات الإنتاجي غير مثبت**. لا تنشئ `AuthService` إنتاجيًا باستخدام `PasswordHasher(iterations: 1000)`؛ الرقم مستخدم في الاختبارات **فقط** لتقليل زمنها.
3. رمز الجلسة الأولي عشوائي من `Random.secure()`، ولا يُخزن في SQLite. SQLite يخزن SHA-256 فقط؛ والرمز الخام داخل SecureStorage أو ذاكرة الجلسة.
4. `restoreSession()` يتأكد من تطابق الحساب والعصر وبصمة الرمز، ولا يعتبر وجود marker وحده جلسة صالحة.
5. `logout()` يُبطل الرمز في قاعدة البيانات أولًا. حذف الحساب يتم عبر معاملة DB ويحافظ على Resource Registry.
6. **لا يوصل B-04 إلى الواجهات الحالية** في هذا التسليم، ولا يتجاوز AuthGate. تلك مسؤولية ربط الواجهات في B-06 بعد اختبار Android.

## فجوات قبل اعتماد B-04
- حسم إعداد PBKDF2 الإنتاجي ومراجعة سرعة Native عند القيمة الأمنية المقررة، مع توثيق مشكلة إغلاق اختبار `tearDownAll`.
- اختبار `KeystoreSessionMarkerStore` على Samsung الفعلي بعد ربط UI أو عبر integration test مستقل للتحقق من استمرارية الرمز بعد restart وتحمل فشل Keystore.
- تأكيد Android Backup/restore policy: لا تُستعاد بيانات secure-storage مشفرة بمفتاح قديم وغير متاح.
- تنفيذ/اختبار سياسة تزامن طلبات المصادقة (عدم تعارض Login/Logout/Delete). `SessionGuard` يجب إعادة التحقق به داخل حدود معاملات الرسائل B-05، لا الاكتفاء بفحص سابق خارج Transaction.
- تدقيق أمن التوقيت، حدود المدخلات، تطبيع username Unicode، وسياسة كلمات المرور قبل الإنتاج.
- هذه الوحدة لا تستخدم `cryptography_flutter` لأغراض التشفير حتى اختيار المزوّد الإنتاجي المناسب؛ `PasswordHasher` الحالي هو Dart.

## اختبار هذه الخطوة
```
dart format lib/features/auth/auth_models.dart lib/features/auth/auth_service.dart lib/features/auth/session_guard.dart lib/features/auth/session_marker_store.dart test/auth_service_test.dart
flutter analyze
flutter test
flutter test test/auth_service_test.dart --reporter expanded
git status --short
```

لا تنفذ Git Commit أو Push قبل مراجعة المخرجات؛ ولا ترفع `b04-native-logcat.txt`، لأنه قد يحتوي بيانات خاصة من الهاتف.
