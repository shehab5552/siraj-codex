# SIRAJ P0 — B-03 / Step 2: Repositories and atomic database invariants

المرجع: `SIRAJ_P0_FINAL_MASTER_SPECIFICATION_v1.0.1_CORRECTED.md` §7.1–7.3، وخطة Flutter B-03/B-05.

الحالة: **تسليم مصدر برمجي للاختبار المحلي — لا يوجد ادعاء نجاح Flutter/Dart قبل تشغيل الأوامر على جهاز التطوير**.

## المضاف في هذه الخطوة

- `user_repository.dart`: حفظ حساب واحد، Query آمن بمعاملات، Epoch Guard، Hash الـNonce وإبطالها، حذف الحساب مع Cascade. **لا يولّد KDF ولا يخزن Marker**؛ هذه وظيفة B-04.
- `settings_repository.dart`: قراءة وتحديث وحذف إعدادات الحساب، مع التحقق من `user_id/account_epoch`.
- `resource_repository.dart`: تسجيل/قراءة الموارد المشتركة للجهاز، مع منع وضع `READY` دون مرحلة تحقق لاحقة B-07/B-12. `RAG_EMBEDDING` مكوّن من Dataset وليس تنزيلًا مستقلاً.
- `conversation_repository.dart`: معاملات Atomic First Message والحد 10 وحذف الأقدم وإعادة المحاولة ذات Message ID، وقراءة الرسائل المقيدة بالحساب وإضافة إجابة بعد تحقق مراجعها شكليًا.
- `database_repository_test.dart`: 8 اختبارات إضافية؛ تُثبت هذه القواعد بالتوازي مع الاختبارات الـ11 السابقة.

**تحديد النطاق:** استخدام Repository للمحادثات في B-05 سيحتاج `AuthSessionGuard` وربط Draft في RAM وUI وتنسيق AI، لذلك إنشاء الدوال هنا **لا يعني أن B-05 منجزة**. التحقق العلمي من `SourceRefs` والمصادر المرجعية مسؤولية مسار AI/RAG ولا يتم بمجرد صحة JSON.

## الاستخدام

افتح Terminal من جذر المشروع `D:\SIRAJ\App Flutter`.

1. تأكد أن ملفات التسليم الجديدة **غير موجودة** قبل فك الضغط. الملف لا يتضمن استبدال `app_database.dart` أو `schema.drift` أو اختبارات الخطوة السابقة أو أي ملفات UI.
2. استخرج ZIP الجديد في جذر المشروع.
3. نفّذ:

```powershell
dart format lib/data/user_repository.dart lib/data/settings_repository.dart lib/data/resource_repository.dart lib/data/conversation_repository.dart test/database_repository_test.dart
flutter analyze
flutter test
git status --short
```

النتيجة المستهدفة: `No issues found`, واجتياز **19 اختبارًا** إن بقيت الاختبارات الـ11 السابقة سليمة.

**مهم:** لا تتجاوز فشلًا، ولا تنفذ Commit/Push قبل مراجعة السجل. عدم نجاح الاختبار يُوثّق ضمن تقرير B-03، وتُصحح الملفات الجديدة قبل المتابعة.

## مهام B-03 المتبقية قبل الإغلاق

- تثبيت فتح قاعدة البيانات كنسخة مشتركة واحدة في التطبيق (والإغلاق عند نهاية عمرها) دون تجاوز Startup/Auth Gate.
- مراجعة الـMigrations/Schema v1 وتوثيق سياسة Upgrade الآمنة؛ لا تنشئ Upgrade صوريًا أو تختبر ترحيلات لم تصدر.
- مراجعة نموذج SourceRefs ومؤشر `active_dataset_revision` مع A/C قبل أي وضع READY أو تفعيل Dataset إنتاجية؛ واجهة Registry الحالية لا تعلن READY.
- تكرار الاختبارات على الجهاز حيث ينطبق ذلك، وتوثيق التقرير الفني والـCommits.
