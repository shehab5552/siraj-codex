# SIRAJ P0 — B-03 / Step 3: Android Smoke & Database Runtime

المرجع: المواصفة v1.0.1 CORRECTED §7، وخطة Flutter: B-03 (TK-06).

## ما أُضيف

- `lib/data/database_runtime.dart`: مالك كسول لاتصال واحد بـSQLite، يُمرَّر إلى Repositories، مع إغلاق واضح وعدم السماح بإعادة الفتح بعد الإغلاق. لا يغير الواجهات أو المصادقة. سيُوصل بـStartup في B-04.
- `test/database_runtime_test.dart`: اختباران للتشارك الصحيح للنسخة، عدم الفتح المبكر، إغلاق مكرر آمن، وتفعيل FK.
- `integration_test/b03_android_database_test.dart`: اختبار على هاتف Android الحقيقي؛ يفتح ملف SQLite مؤقتًا منفصلًا تمامًا عن قاعدة بيانات سراج الفعلية، يفحص Version 1 وFK، ويحفظ مستخدمًا ومحادثة ورسالة وموردًا، ويتحقق من Cascade وبقاء المورد ثم يحذف ملف الاختبار.

## لماذا لا توجد Migration إلى V2؟

النسخة الحالية هي Schema v1 في مشروع جديد. `app_database.dart` تحتوي سياسة `onUpgrade` ترفض الانتقال غير المعروف، ولا تُسقط الجداول أو بيانات الطالب. لا نختلق ترحيلًا إلى إصدار لم يصدر بعد. عند تحديث المخطط مستقبلًا يجب اعتماد ترحيل ومقارنته مع Schema Snapshot واختبارات Upgrade قبل رفع schemaVersion.

## خطوات التشغيل في PowerShell من جذر المشروع

```powershell
flutter pub add 'dev:integration_test:{sdk: flutter}'
flutter pub get
dart format lib/data/database_runtime.dart test/database_runtime_test.dart integration_test/b03_android_database_test.dart
flutter analyze
flutter test
flutter devices
flutter test integration_test/b03_android_database_test.dart -d R3CR40J3XRZ
git status --short
```

**توقف عند أول خطأ وشارك سجل المشكلة.** توقع 21 اختبارًا في `flutter test` العادي (19 سابقًا + 2 جديدة) واختبارًا واحدًا إضافيًا على الهاتف. تشغيل الاختبار على الهاتف قد يتطلب إعادة بناء APK واستخدام بعض الوقت.

**ملاحظة:** لا يعد إنشاء DatabaseRuntime توصيله الفعلي بـBootstrap/Auth. ذلك جزء من عمل B-04؛ يجب أن تُنشأ نسخة Runtime واحدة عند بدء التطبيق وأن تستخدمها جميع Repositories، وألا تُنشأ AppDatabase منفصلة لكل شاشة.

## سياسة Git والتوثيق

- لا Commit أو Push قبل نجاح تشغيل الملفات الجديدة ومراجعة نتائج الاختبارات.
- لا تخزن DB أو ملفات SQLite أو مفاتيح حقيقية في GitHub. يوجد ملف SQLite مؤقت ينشأ أثناء اختبار الهاتف ويُحذف بعده.
- في تقرير B-03 النهائي سجّل إصدارات `drift 2.33.0`, `drift_dev 2.33.0`, `drift_flutter 0.3.1`, `build_runner 2.15.1` وأسباب `--force-jit` ونتائج 19 ثم 21 اختبارًا ونتيجة جهاز Android، ورقم Commit النهائي عند اعتماده.
