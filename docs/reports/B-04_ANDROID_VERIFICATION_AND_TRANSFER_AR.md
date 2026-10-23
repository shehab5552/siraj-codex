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

PR المتابعة: [#6](https://github.com/shehab5552/siraj-codex/pull/6)، قاعدة الفرع
`17ac3cd1d27acd0ae32a24cc09a5aa99b363c126`. Commit أدوات Flutter الاختبارية
`f2c4dbb20d1fcfe825bdf4edba09ef388a0eae98`؛ Commit الدليل والـPatches
`b0b2144`؛ أضيف اختبار Android UI في
`9ff1c7c9f0392c0567070b5dd7c919b61a71872f`، وأصلح مسار أداة مراقبة ANR في
`693968d2540d20fdbfff8aac7d56ec4dcd8a0924`. لم يتغير كود PR #5 الإنتاجي.

لا يُعتمد600000 إنتاجيًا ولا تفتح Gate. نجحت حتى الآن اختبارات Linux
الكاملة170/0/0، ومنها3جديدة للمسبار، بعد167/0/0 في التسليم السابق.
ملف الأدلة الآلية النهائي يسجل توقيت وأوامر آخر تحقق.

| الأمر الفعلي في آخر تحقق | النتيجة | الزمن |
|---|---|---|
| `flutter pub get --enforce-lockfile` | exit0؛ lockfile دون تغيير |0.543s|
| `flutter analyze --no-pub` | exit0؛ نظيف |1.312s|
| `flutter test --no-pub --machine` |170pass /0fail /0skip|23.632s|
| Auth/probe focused،14ملفًا |70pass /0fail /0skip؛ ضمن170|20.995s|

بدأ الكامل23أكتوبر03:37:54 بتوقيت عدن. هذه counts لا تشمل ملفات
integration_test غير المنفذة على الجهاز. المصدر/التوقيت/hashes السجلات في
[JSON الأدلة](../qa/B04_ANDROID_TRANSFER_VERIFICATION_2026-10-23.json).

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
   عند `0b2fa8a3e34016fc4ee04ef588812cbda95e55c4`: انتهت FAILURE بـexit124
   من إحدى مهلات انتظار Emulator داخل خطوة إعداد Android؛ لم يُبنَ APK
   ولم ينفذ native test. لم تكن آنذاك رسالة تحدد أي مهلة من الاثنتين.
4. [المحاولة الثالثة39874263701](https://github.com/shehab5552/siraj-codex/actions/runs/39874263701)،
   عند `d6f4c429bfcec91f0810ad39f2881f6cf4c9fd9a`: انتهت FAILURE بـexit1
   في خطوة إعداد Android؛ ظهرت ملاحظة sdkmanager completion، لكنها لا تثبت
   وجود صورة مطلوبة إذا تخطيت packages بسبب license. لا نتيجة native ناجحة.
5. أضيف قبول تراخيص SDK الرسمية على runner المؤقت والتحقق من package.xml
   للصورة المطلوبة، وفُصل بناء APK عن إقلاع Emulator كي لا يمنع فشل المحاكي
   محاولة بناء مستقلة. أضيفت diagnostics محدودة لـAVD/boot وmetrics notices.
6. [المحاولة الرابعة39874613933](https://github.com/shehab5552/siraj-codex/actions/runs/39874613933)،
   عند `a4bdb72efb1c2527bae086a1e6f1c7ff6e30c657`: نجحت خطوة SDK/image
   الرسمية و**نجح بناء APK وKotlin**، وفحص aapt هوية
   `com.example.siraj.b04verification`. فشل boot، exit1، برسالة مثبتة:
   `Unknown AVD name [siraj-b04-api33]` وعدم وجود ini في مسار بحث Emulator.
   اختبارات native لم تنفذ. فصل البناء عن boot أتاح إثبات البناء رغم هذا العطل.
7. [Artifact المحاولة الرابعة](https://github.com/shehab5552/siraj-codex/actions/runs/39874613933/artifacts/12468127122)
   منشور فعلًا، size76358461bytes للـZIP، غير منتهي عند الفحص. يحوي
   `b04-probe-debug.apk` وaapt/حدود الدليل، وليس ترقية للمشروع الأصلي.
   يجب التحقق من ID وعدم وجود تثبيت مجهول بالاسم نفسه قبل تثبيته؛ لا نجاح هاتف
   يستنتج من مجرد وجود APK. لم يُنزّل هذا الملف أو يثبت على جهاز المستخدم هنا.
8. وُحدت ANDROID_USER_HOME/ANDROID_EMULATOR_HOME/ANDROID_AVD_HOME إلى مساحة
   runner مؤقتة، مع path صريح وفحص ini و-list-avds قبل الإقلاع. هذا يصلح
   السبب المثبت لاكتشاف AVD، ولا يغير تطبيق SIRAJ.
9. [المحاولة الخامسة39875411936](https://github.com/shehab5552/siraj-codex/actions/runs/39875411936)،
   عند `e03061adca057d316812ce6a56d41624a424933d`: **SUCCESS** فعلًا، من
   03:00:26 إلى03:09:34 بتوقيت عدن؛9دقائق8ثوانٍ للمهمة كاملة. نجح SDK وAPK
   وإقلاع Emulator، و**اختبارا Android:2ناجح/0فشل/0تخطٍّ**: الجلسة native
   وKDF metrics. أعلنت check annotations نجاح Keystore/SQLite ومقاييس KDF،
   وليست نتيجة مختلقة من tests السحابة. لا تتضمن هاتان الحالتان جولة UI كاملة
   أو child cascade أو Force-stop/reboot؛ كل منها يحتاج اختباره المحدد.
10. [Artifact الخامسة](https://github.com/shehab5552/siraj-codex/actions/runs/39875411936/artifacts/12468985496)
    منشور، ZIP size76358459bytes. المصدر `e03061a` وAPK للـprobe المعزول؛
    لم يُنزّل/يثبت على هاتف المستخدم بواسطة Codex.
11. أضيف اختبار native UI مستقل بعد نجاح الأساس: Signup/loading/كلمة خاطئة
    وصحيحة/Logout/Delete، مع USER ومحادثة حقيقيتين لقياس cascade، وفحص
    event-buffer لغياب سجل ANR خاص بـpackage المعزولة. هذا لا يثبت غياب ANR
    مطلقًا ولا اختبار Samsung.
12. [المحاولة السادسة39876603665](https://github.com/shehab5552/siraj-codex/actions/runs/39876603665)،
    عند `9ff1c7c9f0392c0567070b5dd7c919b61a71872f`: نجحت **اختبارات Android
    الثلاثة، 3/0/0**، بما فيها UI وchild cascade. لكن المهمة كاملة انتهت
    FAILURE بـexit127 **بعد الاختبارات** لأن خطوة جمع ANR استدعت `adb`
    خارج PATH الخاص بها. لم يُجمع سجل ANR في هذه المحاولة؛ نجاح الاختبارات
    لا يساوي نجاح workflow. كود الاختبار الجديد راجعه مستقل، وحُسن cleanup
    لكي لا يخفي فشلًا أصليًا أو يمنع تنظيف Marker/temp عند تعثر DB close.
    قياسات600000:4934/5477/6335ms، وأكبر فجوة heartbeat
    331.589/34.265/70.194ms، والإلغاء35.58ms. هذه بيانات تشغيل مختلف وليست
    تحسنًا أو تراجعًا مثبتًا إحصائيًا؛ RSS الكامل موجود في JSON الأدلة.
13. أُصلح أمر مراقبة ANR إلى المسار الرسمي الصريح
    `"$ANDROID_HOME/platform-tools/adb"`؛ لم يتغير أي كود Auth أو اختبار Dart.
14. [المحاولة السابعة39878012411](https://github.com/shehab5552/siraj-codex/actions/runs/39878012411)،
    عند `693968d2540d20fdbfff8aac7d56ec4dcd8a0924`: **SUCCESS** للمهمة
    كاملة، من03:25:21 إلى03:35:41 بتوقيت عدن،10دقائق20ثانية. نجح تثبيت SDK الرسمي وبناء APK وإقلاع API33 Emulator واختبارات
    Android الثلاثة **3ناجح/0فشل/0تخطٍّ**. نجح جمع event buffer ولم يوجد
    سجل `am_anr` خاص بالحزمة المعزولة في النافذة المتاحة بعد الاختبارات؛
    هذا رصد محدود وليس إثبات غياب ANR/تجمّد مطلقًا أو قبول هاتف Samsung.
15. [APK المحاولة السابعة ضمن Artifact](https://github.com/shehab5552/siraj-codex/actions/runs/39878012411/artifacts/12470060804)
    منشور بالفعل؛ ZIP size76358465bytes، retention7أيام، غير منتهٍ عند
    الفحص. الهوية `com.example.siraj.b04verification`. لم ينزل Codex الملف
    أو يثبت أي شيء على هاتف المستخدم. مفاتيح debug مختلفة بين مصادر البناء
    قد تمنع تحديث تثبيت اختبار سابق؛ لا تعالج ذلك بمسح التطبيق الأصلي.

### قياسات آخر تشغيل ناجح كاملًا

المصدر: JSON من check annotation `B04 Android metrics` للمحاولة السابعة؛
Android API33 Google APIs x86_64 Emulator، Debug، وليس profile/release:

| العينة600000 | زمن الاشتقاق ms | heartbeat ticks | أكبر فجوة ms | RSS قبل/بعد bytes |
|---|---|---|---|---|
|1|4923|405|577.438|302796800 /224870400|
|2|3988|396|23.849|225136640 /211734528|
|3|5746|561|31.585|211734528 /160153600|

الإلغاء34.02ms. **فجوة577.438ms حقيقية**؛ تشغيل CPU خارج UI isolate لا
يلغي أثر تحميل VM/Emulator وجدولة النظام. لا نستنتج سبب الفجوة أو قبول
الاستجابة من هذه العينة وحدها. يلزم قياس frames وتجربة loading/cancel
وفترات تشغيل متكررة على Samsung، مع إبقاء Gate مغلقة. لا تختار أسرع عينة
وتخفي البقية. تحذيرات Node20/setup-java v4 تخص صيانة Actions لاحقًا؛ لم
تفشل التشغيل النهائي، ولم توسع هذه المهمة إلى ترقية مستقلة للأدوات.

### قياسات التشغيل الأساسي السابقة

قياسات الخامسة من JSON المنشور في `B04 Android metrics`، على Android API33
Google APIs x86_64 Emulator، Debug:

| العينة600000 | زمن الاشتقاق ms | heartbeat ticks | أكبر فجوة ms | RSS قبل/بعد bytes |
|---|---|---|---|---|
|1|4700|414|376.143|262885376 /229416960|
|2|4310|428|21.919|229683200 /206761984|
|3|4708|463|32.623|206761984 /189177856|

الإلغاء22.411ms. **فجوة376.143ms في العينة الأولى حقيقية ولا تُحذف**؛
heartbeat ليس قياس إطارات UI، ولا يثبت وجود/غياب ANR. RSS للعملية كلها،
والاختبار Debug على Emulator؛ لا حكم leak-free أو ضمان أداء Samsung أو6GB.
`production_approved=false` كما في الاختبار، والبوابة ما تزال مغلقة.

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
- `integration_test/b04_android_probe_ui_test.dart`: يستخدم API وUI وقاعدة
  native حقيقية مع child rows، دون fake storage؛ الاختبار لا يساوي قبول
  الواجهة والأداء على هاتف فعلي ولا إثبات lifecycle/backup.
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
أضيف class القناة Kotlin كاملًا من Commit الإصلاح إذا لم يوجد أصلًا في
المشروع المحلي، ومثال دمج تسجيلها وتنظيفها داخل Activity الموجودة دون
استبدال بقية القنوات. لا ملفات Auth/SQLite كاملة لأمر استبدال أعمى.

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

إصلاحات Flutter/SQLite: منفذة ومختبرة في Linux؛ Keystore/الجلسة/مسار UI
وchild cascade: **مختبرة فعليًا على Android Emulator API33** ضمن الحالات
الثلاث المذكورة. Samsung `PENDING_DEVICE_TEST`؛ Force-stop/reboot وOEM
backup وفقد مفتاح/lifecycle الحقيقي تبقى غير مثبتة. Gate/KDF production
approval `BLOCKED` حتى القياس والمراجعة وفق DD-05. نجاح Emulator لا يغير
تصنيف الهاتف تلقائيًا ولا يثبت زوال التعليق التاريخي في المشروع الأصلي.

أول خطوة للمستخدم: backup وفرع محلي، ثم تجربة مرجع Codex المعزول على
الهاتف نفسه قبل نقل الدوال المتوافقة إلى النسخة الأصلية. لا Merge أو تفعيل
إنتاجي بمجرد نجاح probe. التقرير النهائي يربط SHA الفرع والـPR وأدلة الأوامر.
