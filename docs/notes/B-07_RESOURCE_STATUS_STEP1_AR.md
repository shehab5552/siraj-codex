# SIRAJ P0 — B-07 Step 1: قراءة وعرض حالات الموارد

## المرجع

SIRAJ_P0_FINAL_MASTER_SPECIFICATION_v1.0.1_CORRECTED.md، الأقسام 10.1–10.6، DD-01/02/03/14، FR-12/21/22 وTC-26/27.

## النطاق

- قراءة الجدول الموجود `installed_resource` دون تعديل Schema أو Migration.
- فصل أربعة أنواع تقنية في العرض: `LLM`, `RAG_PACK`, `RAG_EMBEDDING`, `PDF`.
- `RAG_EMBEDDING` مسجل تقنيًا منفصلًا، لكن تنزيله للمستخدم جزء من تجهيز Dataset الواحد فقط.
- حالات `MISSING/DOWNLOADING/FAILED` معروضة كنصوص؛ أي حالة أخرى—including `READY`/`ACTIVE`—تظهر «يتطلب التحقق»؛ لا ادعاء جاهزية من صف قاعدة بيانات.
- واجهة الموارد **غير مربوطة بالتنقل بعد** حتى نراعي Auth Gate؛ هذه الخطوة لا تضيف زر تنزيل، أو تحقق سلامة، أو ترقية ACTIVE.

## ما لا تفعله هذه الخطوة

- لا تغيّر المؤشر `active_dataset_revision`، ولا تنشئه، ولا تعلن `RAG_READY`.
- لا تتحقق من SHA-256، أو ملف PDF قابل للقراءة، أو Embedding/Index، أو صلاحية تحميل Local LLM.
- لا تتعامل مع `INTEGRATION_FIXTURE_MODE` كحزمة RAG إنتاجية.
- لا تُجري HTTP ولا تطلب بيانات حساب المستخدم.
- لا توسع Scope Biology Pilot إلى تنزيل خمس مواد إنتاجية أثناء تجربة G2/G3.

## اختبارات القبول

1. سجل فارغ لا ينتج جاهزية وهمية.
2. الفصل بين الأنواع الأربعة.
3. عرض MISSING/DOWNLOADING/FAILED.
4. الصف المحفوظ بحالة READY/ACTIVE لا يساوي تحققًا من الملفات.
5. القراءة لا تعدل SQL.
6. الحفاظ على منع `recordUnverified(READY)`.
7. واجهة Flutter لا تعرض إجراء تنزيل وهميًا.
8. عرض صادق عند عدم وجود سجلات.

**حالة الخطوة:** PENDING DEVICE/FLUTTER TEST حتى تظهر نتائج `flutter analyze` و`flutter test` عند المنفذ B. ليست إغلاقًا لـB-07.
