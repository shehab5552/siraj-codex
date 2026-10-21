# SIRAJ P0 — B-07 Step 2: التنقل الآمن إلى حالات الموارد

**المرجع:** SIRAJ_P0_FINAL_MASTER_SPECIFICATION_v1.0.1_CORRECTED.md، DD-01/02/03، §§6 و10.1–10.6.

## التغيير
- إضافة زر «حالة الموارد» للصفحة الرئيسية عند توافر استدعاءات الحساب الموثق فقط.
- إعادة التحقق من marker المشفر والحساب وnonce لدى SQLite قبل التنقل، مع منع الفتح وفشل آمن عند خطأ التحقق.
- واجهة B-07 Step 1 تستقبل `ResourceStatusReader(ResourceRepository(runtime.database))` وتقرأ من نفس قاعدة التطبيق.
- لا زر في معاينة Debug ولا في حالات `accountRequired/loginRequired`.
- لا تعديل Schema/DDL ولا تفعيل `READY/ACTIVE` ولا تنزيلات أو HTTP.

## حدود القبول
- اختبار Widget لا يساوي اختبار جلسة Android فعلية. الدخول الصحيح يحتاج حسابًا موثقًا؛ لن نستخدم KDF الاختباري لإنتاج حساب.
- اختبار العرض على Samsung ممكن لاحقًا ضمن جلسة شرعية أو اختبار تكامل معزول، دون تجاوز Auth Gate.
- `RAG_READY` يتطلب Active Revision كاملًا متوافقًا بخمس حزم + Embedding مشترك واختبار Android؛ لا تستنتجه واجهة الحالة.

## تحقق المنفذ
`dart format lib/app/app_bootstrap.dart lib/features/home/home_page.dart test/b07_resource_navigation_test.dart`
ثم `flutter analyze` و`flutter test`. المتوقع 71 اختبارًا (68 + 3). تقرير **PENDING** إلى أن تظهر النتائج من جهاز B.
