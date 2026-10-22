# B-04 — تحقق Android ونقل الإصلاحات إلى Windows

تاريخ العمل: 23 أكتوبر 2026، Asia/Aden. هذا تسليم تابع لإصلاح PR #5، دون
تغيير كوده الإنتاجي أو دمج أي PR أو الوصول إلى `siraj-p0` أو الكمبيوتر المحلي.

## A. حالة الحل والتحقق

إصلاحات KDF/الجلسة/SQLite موجودة في PR #5 عند
`17ac3cd1d27acd0ae32a24cc09a5aa99b363c126`، وCommit كودها
`80b4f0fe1a228731ff6ae57ccdeb5598d201f681`، من قاعدة
`651af0d62d05761c80d9a8cbc9d1f51b836929eb`.

أضيفت في هذه المتابعة أدوات اختبار وتوثيق فقط على الفرع
`codex/b04-android-verification-guide`، المبني على PR #5. يجب أن يستهدف PR
الإضافي فرع PR #5 لعرض هذه الإضافات وحدها؛ إعادة استهداف main لاحقًا تحتاج
مراجعة بعد اعتماد/دمج الإصلاح بقرار المستخدم، ولا تنفذ تلقائيًا.

لا يُعتمد600000 إنتاجيًا ولا تفتح Gate. نجحت حتى الآن اختبارات Linux
الكاملة170/0/0، ومنها3جديدة للمسبار، بعد167/0/0 في التسليم السابق.
ملف الأدلة الآلية النهائي يسجل توقيت وأوامر آخر تحقق.

### البيئة السحابية الأصلية

- Flutter3.38.5 / Dart3.10.4، Linux x86_64. لا Android SDK/adb/emulator/device.
- أمر `flutter build apk --debug --no-pub` نُفذ وفشل exit1:
  `No Android SDK found. Try setting the ANDROID_HOME environment variable.`
- محاولة SDK الرسمية إلى
  `https://dl.google.com/android/repository/repository2-1.xml` رُفضت403 عند
  proxy CONNECT، curl56. حالة origin غير متاحة، ولم يتجاوز الاختبار proxy/TLS.
- `flutter doctor` أكد403 CONNECT لـ`https://maven.google.com/` و
  `https://cocoapods.org/`؛ فحص الأخير عام وليس اعتماد Android Auth.
- محاولة مساعدة لكتالوج Flutter
  `https://storage.googleapis.com/flutter_infra_release/flutter/releases/releases_linux.json`
  رجعت404؛ سببها غير محسوم هنا. لم تستخدم SDK/ملفًا غير موثوق بدلًا منها؛
  Workflow استنسخ tag3.38.5 من `flutter/flutter` الرسمي وتحقق من revision.

### GitHub Actions

أمكن إنشاء Workflow ودفعه وتشغيله فعليًا على GitHub-hosted ubuntu-24.04؛
نجاح push ليس افتراضًا بأن SDK/Emulator يعملان.

1. [المحاولة الأولى39872568598](https://github.com/shehab5552/siraj-codex/actions/runs/39872568598)،
   عند `f2c4dbb20d1fcfe825bdf4edba09ef388a0eae98`: انتهت FAILURE، بعد
   نجاح checkout/JDK/Flutter والتحليل والاختبارات، في خطوة إعداد Android،
   exit1 قبل البناء/native tests. لم تعرض annotations السبب التفصيلي.
2. أُصلح إعداد PATH الصريح لأدوات SDK وأضيف تشخيص محدود إلى annotations
   بدل الاعتماد على سجل لا نستطيع جلبه. هذا تحسين إعداد workflow، ولا
   يجزم بسبب المحاولة الأولى دون سجلها.
3. [المحاولة الثانية39873245489](https://github.com/shehab5552/siraj-codex/actions/runs/39873245489)،
   عند `0b2fa8a3e34016fc4ee04ef588812cbda95e55c4`: كانت قيد التنفيذ وقت
   هذه المسودة؛ **لا تُعد PASS**. تُحدث النتيجة قبل تسليم التقرير النهائي.

جلب logs عبر gh تعذر عند hostname
`results-receiver.actions.githubusercontent.com`؛ أعيد قياس HEAD للجذر
`https://results-receiver.actions.githubusercontent.com/` فأعاد403 CONNECT
من proxy، curl56. روابط تنزيل logs موقعة مؤقتًا؛ لا تُدرج signature في
التقرير أو تطلب من المستخدم مشاركتها. توجد بيانات الحالة/الخطوات عبر API
الرسمي `api.github.com`؛ لا تُستبدل بها قياسات لم تُستخرج فعليًا.

فحص `GET /repos/shehab5552/siraj-codex/actions/permissions` أعاد403:
`Resource not accessible by integration`. هذه صلاحية قراءة إعدادات المستودع؛
لم تمنع push وتشغيل workflow فعليًا، ولا يصح وصفها بمنع Actions كله.

## B. شرح الإصلاح وحد الإثبات

الدليل يعرض before/after حقيقيين من Git مع full per-file patches. قبل
الإصلاح كان PasswordHasher يستدعي Pbkdf2 provider من isolate المستدعي.
بعده CPU داخل Dart Isolate مملوك محدود مع cancel/timeout/busy؛ الخوارزمية
Salt16/hash256 محفوظان. لا دليل أن المشكلة التاريخية في الأصل لها السبب نفسه.

Keystore Kotlin/MethodChannel وAES256GCM كانا قائمين. أصلح PR #5 تسلسل
عامل process مشترك محدود وdisposed/lifecycle guards وحدود ciphertext وUTF-8.
AuthService يصدر Marker قبل CAS nonce، ويحسم النجاح عند COMMIT؛ يحجب
الجلسة عند طلب الإبطال وفشله، ويحافظ على سلطة Retry الخاصة. SQLite
يمنع USER المتأخرة داخل transaction؛ Delete يحافظ على الموارد المشتركة.

قياسات Linux السابقة600000:2506ms قبلًا، و1900/1894/1918ms بعدًا؛ إلغاء2.092ms.
ليست مقارنة إحصائية مضبوطة أو دليل أداء Samsung/عدم وجود ANR أو تسرب.
لا production default منخفضًا أو test credentials في lib/main/AppBootstrap.

### أدوات المتابعة

- `integration_test/support/b04_probe_app.dart`: entry point Debug Android
  منفصل، يستخدم AuthService والصفحات والقناة الحقيقية وDB مختلفة مستمرة.
  لا يصلح release entry point؛ يرفض التشغيل خارج Debug Android.
- `integration_test/b04_android_kdf_metrics_test.dart`: ثلاث عينات600000
  على Android وheartbeat/RSS وإلغاء؛ لا يزعم قياس frame times أو absence ANR.
- `test/b04_probe_app_test.dart`: إنشاء/استعادة/Logout/كلمة خاطئة وصحيحة/
  Delete/موارد وفشل تخزين+Retry؛ SQLite/Auth حقيقيان، Marker fake اختبار فقط.
- `.github/workflows/b04-android-verification.yml`: official pinned actions،
  Flutter fixed tag، SDK Google رسمي، API33 Google APIs x86_64، package
  `com.example.siraj.b04verification`، artifact APK منفصل، لا merge/secrets/DB.

المسبار يضيف سجل PDF بحالة MISSING فقط عند الضغط عليه لاختبار بقاء الموارد؛
لا PDF فعلية ولا READY/ACTIVE ولا إجابات AI وهمية. لا تغييرات lib/android/
schema/dependencies في متابعة التوثيق والاختبار هذه.

## C. حزمة النقل ودليل Windows

[B04_LOCAL_WINDOWS_REPRODUCTION_GUIDE_AR.md](../guides/B04_LOCAL_WINDOWS_REPRODUCTION_GUIDE_AR.md)
هو الدليل التنفيذي، ويضم:

- backup للملفات وGit bundle وpatches للـstaged/unstaged، وفرع مستقل دون
  reset/clean أو رفع أسرار.
- جدول لكل واحد من32 ملفًا، وظيفة/سبب التغيير وطريقة النقل وتبعياته،
  وتسلسل افتح/ابحث/ادمج/احفظ/اختبر للمجموعات المتصلة.
- كود before/after وشرح worker/Lane/COMMIT/Kotlin/backup، والتعامل مع اختلاف
  package/schema/APIs دون استبدال Auth/SQLite كاملين.
- أوامر PowerShell5.1 وSDK والتحقق من الهاتف وlockfile والتحليل/tests وAPK.
- debug applicationIdSuffix، وفحص APK بـaapt **قبل أي تثبيت**، ونسخة probe
  مستقلة لا تستبدل تثبيت المستخدم؛ Gate تبقى مغلقة.
- Native integration وmetrics، وتجربة Samsung اليدوية وForce-stop/reboot
  وLogcat/frames/memory، ومصفوفة قبول وتشخيص ومعلومات مسموح إرسالها بعد التنقيح.

حزمة [b04_reference](../qa/b04_reference/README_AR.md) تحتوي32 Patch حقيقية،
ومحتوى الملفات الجديدة كاملًا بامتدادtxt وبصمات قبل/بعد. تحققت round-trip
على قاعدة Codex المعزولة ومطابقة bytes لCommit الإصلاح. `.gitattributes`
يحافظ على bytes عند clone على Windows؛ لا توجد مقارنة فعلية مع الأصل.

## D. الهاتف والتوافق مع B-08

Samsung SM-N986U/Android13 غير متصل بهذه البيئة. لا نتائج لهذا الهاتف.
قبوله يتطلب كل صف في دليل التجربة، وتوثيق RAM/ABI الفعليين؛ لا يفترض6GB
من اسم الجهاز، ولا يكفي Emulator لاعتماد أداء6GB أو Keystore hardware.
فقد مفتاح/تلف ciphertext وOEM backup/transfer يحتاج fixture/device أدلة
إضافية؛ لا يثبتها اختبار mock أو زر في المسبار.

أجري `git merge-tree --write-tree` على رأسي PR #5 و#4 دون checkout لدمج،
ودون تعديل index/worktree/فرعي PR أو Commit دمج. الناتج تعارض نصي في:

1. `lib/data/user_repository.dart`
2. `lib/data/conversation_repository.dart`
3. `lib/features/chat/conversation_draft_controller.dart`

الوظائف ليست تكرارًا بسيطًا: يجب إبقاء outcome/eviction/idempotent IDs/
follow-up/reply-id/watchSession من B-08، وCAS/الإلغاء/حجب SessionGuard في
المعاملات من B-04. لا تسوية أو suite مشتركة في هذه المهمة؛ لا ادعاء توافق
جاهز. PR #3/#4/#5 لم تدمج. Biology G2/G3 أولوية لاحقة؛ هذه المهمة لا تغير
عقود AI أو تدعي نجاح موارد/Android لم تنفذ.

## الحكم وخطوة الاستئناف

إصلاحات Flutter/SQLite: `IMPLEMENTED_AND_TESTED_NOT_DEVICE_VERIFIED` بالنسبة
إلى الهاتف الحقيقي. native/backup/lifecycle: لا يتجاوز الدليل الفعلي لكل
بيئة، وSamsung `PENDING_DEVICE_TEST`. Gate/KDF production approval `BLOCKED`
حتى القياس والمراجعة وفق DD-05. نتائج Emulator، إن نجحت، تسجل مستقلًا ولا
تغير تصنيف Samsung تلقائيًا.

أول خطوة للمستخدم: backup وفرع محلي، ثم تجربة مرجع Codex المعزول على
الهاتف نفسه قبل نقل الدوال المتوافقة إلى النسخة الأصلية. لا Merge أو تفعيل
إنتاجي بمجرد نجاح probe. التقرير النهائي يربط SHA الفرع والـPR وأدلة الأوامر.
