# SIRAJ P0 — B-03 / Step 1 (SQLite Schema Foundation)

**المواصفة:** SIRAJ_P0_FINAL_MASTER_SPECIFICATION_v1.0.1_CORRECTED.md — §7.1–7.3.

**الحالة:** مصدر برمجي مُعد للفحص المحلي، وليس إثبات نجاح اختبار على هاتف المستخدم.

## ما يحتويه التسليم

- `lib/data/schema.drift`: المخطط المنطقي المعتمد للجداول الخمسة والفهارس وقيود CHECK/UNIQUE/FK.
- `lib/data/app_database.dart`: تعريف Drift، الإصدار الأول من Schema، فتح قاعدة بيانات الجهاز، تفعيل Foreign Keys، ورفض أي Migration مجهولة عوضًا عن حذف البيانات.
- `test/database_schema_test.dart`: اختبارات مخطط SQLite والقيود والعزل وحذف البيانات التابعة والتراجع والتخزين المستمر.

## طريقة الدمج

> تأكد أن جميع الملفات الثلاثة غير موجودة، أو راجع أي اختلاف قبل استخراج ZIP. لا يُعدّل هذا التسليم `main.dart` أو `pubspec.yaml` أو الواجهات الحالية.

من جذر المشروع `D:\SIRAJ\App Flutter` وبعد استخراج ZIP:

```powershell
# توليد كود Drift؛ لا تعدّل الملف المولّد يدويًا
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
git status --short
```

### ملاحظات قبول مهمة

- `flutter test` يجب أن يعرض 10 اختبارات ناجحة إذا كان اختبارا B-02 ما يزالان موجودين وتم تنفيذ 8 اختبارات قواعد البيانات بنجاح.
- هذا التسليم يختبر مخطط DB؛ إنشاء Repositories والتعامل الذري مع أول رسالة (B-05) لم يحدث بعد.
- `AppDatabase()` مع `driftDatabase` يفتح ملف `siraj_p0.sqlite` في Documents للتطبيق عندما يتم استعماله؛ لا يُفتح أو يُربط مع Bootstrap في هذه الخطوة.
- يجب تعريف واعتماد مسار Upgrade عند رفع `schemaVersion` مستقبلًا؛ حاليًا يُرفض أي مسار ترحيل غير مُعرّف عمدًا بدل مسح البيانات.
- مفاتيح Session Marker تحفظ لاحقًا في Keystore-backed secure storage، وليس في SQLite.
- لا ترفع أي DB تشغيلية أو مفاتيح إلى GitHub. `*.sqlite` مستبعدة بالفعل من `.gitignore`.
- لا تُنشئ Commit أو Push قبل ظهور اختبارات فعلية ناجحة وإرسال المخرجات للمراجعة.
