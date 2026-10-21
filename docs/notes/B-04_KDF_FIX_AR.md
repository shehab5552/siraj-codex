# SIRAJ P0 — B-04: إصلاح PasswordHasher

**الحالة:** تصحيح برمجي يحتاج التأكيد من اختبارات جهاز التطوير والهاتف. لا يمثل اعتماد B-04.

## المشكلة
- `Unsupported operation: The bytes have been destroyed` أثناء `_derive`.
- السبب: تنفيذ `secretKey.destroy()` قبل نسخ بيانات `extractBytes()`؛ قد يرجع `extractBytes()` مخزنًا حساسًا مرتبطًا بالمفتاح.
- ملاحظة analyzer: `prefer_initializing_formals`.

## الإصلاح
1. ننسخ البايتات إلى `Uint8List` **قبل** إتلاف `secretKey`.
2. نستعمل `try/finally` لضمان استدعاء `destroy()` حتى في حال فشل الاستخراج أو النسخ.
3. نستبدل `required int iterations` مع الإسناد اليدوي بـ `required this.iterations`.
4. لا تغيير لخوارزمية PBKDF2 أو قيم الاختبار أو مخطط قاعدة البيانات أو الواجهات.

## معايير التحقق
```powershell
dart format lib/features/auth/password_hasher.dart
flutter analyze
flutter test
flutter test integration_test/b04_kdf_benchmark_test.dart -d R3CR40J3XRZ
git status --short
```

**ملاحظة:** لا تعتمد عدد Iterations الإنتاجي حتى مراجعة زمن القياس على Android والمتطلبات الأمنية.
