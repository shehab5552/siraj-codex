# B-04 — التدقيق الأمني والإصلاح والتحقق الفعلي

تاريخ التسليم: 23 أكتوبر 2026 بتوقيت عدن. آخر تشغيل شامل بدأ في
22 أكتوبر 2026، الساعة 22:29:55 UTC، الموافق 23 أكتوبر 01:29:55 في عدن.

## نتيجة التسليم وحدودها

نُفذت إصلاحات حقيقية في نسخة Codex، مع 37 اختبارًا جديدًا ونجاح المجموعة
الكاملة: **167 ناجحًا، صفر فشل، صفر تخطٍّ**. اختبارات Auth المركزة:
**67 ناجحًا، صفر فشل، صفر تخطٍّ**؛ هي مجموعة فرعية من الاختبارات الكاملة.
نجح `flutter analyze` و`flutter pub get --enforce-lockfile`.

لم ينجح بناء Android لغياب SDK، ولا يوجد جهاز Android أو Emulator متصل.
لم يُنتج APK ولم يُترجم Kotlin في هذه البيئة. لذلك لم تُفتح بوابة المصادقة
الإنتاجية، ولم يُعلن نجاح Keystore أو عدم وجود ANR على Android.

## Git والنطاق

| البند | القيمة المثبتة |
|---|---|
| المستودع | `shehab5552/siraj-codex` |
| الفرع الافتراضي | `main` |
| Git Base | `651af0d62d05761c80d9a8cbc9d1f51b836929eb`، دمج PR #2 |
| الفرع المستقل | `codex/b04-security-repair-01` |
| Commit الكود والاختبارات وأدلة QA | `80b4f0fe1a228731ff6ae57ccdeb5598d201f681` |
| Pull Request | [PR #5](https://github.com/shehab5552/siraj-codex/pull/5) إلى `main` |
| الملفات في التسليم | 35 ملفًا: 32 كود/اختبارات/أداة و3 وثائق |

يضيف Commit توثيق لاحق هذا التقرير وروابط التسليم إلى JSON؛ الكود لم يتغير
بعد تشغيل التحقق النهائي. يمكن الحصول على SHA رأس التسليم من PR أو
`git rev-parse origin/codex/b04-security-repair-01` دون افتراض SHA لوثيقة تدرج نفسها.

عند التحقق السابق للتسليم: PR #1 مفتوح؛ PR #3 للتنزيل مفتوح عند
`27ff8e5265e03092ccf84fedeae39d5bb4d008a7`؛ PR #4 لـB-08 مفتوح كمسودة عند
`306b3a69bb855a49b3bf01bbb1b6bd30a1c087f5`؛ PR #2 وحده مدمج سابقًا.
لم تنفذ هذه المهمة أي Merge. الفرع من `origin/main`، ولا يضم Commits PR #1/#3/#4.

لم تتغير التبعيات أو `pubspec.lock` أو schema أو الملفات المولدة أو
AppBootstrap أو تكاملات AI/الموارد. تعديل مسار المحادثة الموجود محصور
في منع كتابة USER متأخرة بعد إبطال الجلسة؛ لا ميزات B-08 في هذا PR.
يتقاطع PR #4 مع بعض ملفات Auth/Conversation، ويجب تسوية التداخل عند دمجه
لاحقًا؛ لا يُطبق الفرعان معًا دون مراجعة.

## المرجعية والقرارات المحفوظة

قرئت نسخة حزمة التسليم المرفوعة، دون الوصول إلى المستودع الأصلي أو الكمبيوتر المحلي:

- `SIRAJ_P0_FINAL_MASTER_SPECIFICATION_v1.0.1_CORRECTED.md`؛ SHA-256:
  `084d2f3ece9373dacc3795fb35bed99ee36ebbdbb9ba139d5cca9d0daa5727d8`.
- `DOCUMENT_02_TEAM_B_REVISED_IMPLEMENTATION_PLAN.md`؛ SHA-256:
  `715eca6033eeeec8657df72571bbaf4cdf4ed1bd7dc2eba695d39aa24b6a5f0e`.
- عقود Flutter ووثيقة Workflow/QA في الحزمة، مع B-04/TK-16 وFR-19
  وDD-05/06/07/18 وNFR-03 وحالات TC-21/24/29/30، وحماية الكتابة المتعلقة بـTC-15/25.

حُفظت PBKDF2-HMAC-SHA256، والحساب المحلي الواحد، وSQLite، وOffline-first،
وربط الجلسة الآمنة بـnonce، وحذف بيانات الحساب دون حذف الموارد المشتركة.
بقي الفصل بين UI/Domain/Data/Platform، ولم يتغير فصل LLM/Embedding/RAG/PDF.

DD-05 يتطلب قياس جهاز Android المستهدف ومراجعة أمنية قبل اعتماد work factor.
600000 مرشح موثق بمرجع
[OWASP Password Storage](https://github.com/OWASP/CheatSheetSeries/blob/master/cheatsheets/Password_Storage_Cheat_Sheet.md)
الذي جرى فحص نصه؛ ليس اعتمادًا تلقائيًا لإعداد إنتاجي على الجهاز.

## الحالة قبل الإصلاح والسبب الجذري

كانت AuthService وSalt/hash والمقارنة الثابتة العمل وSQLite وKeystore AES-GCM
موجودة بالفعل. لم يُعد بناؤها من الصفر. AppBootstrap كان يتعمد إظهار
Signup/Login دون handlers إنتاجية لأن إعداد KDF لم يعتمد على الجهاز.
اختبارات الأساس نجحت فعلًا: 130/0/0، لكن لم تغطِّ السباقات المكتشفة.

| العيب المثبت في Codex | السبب الجذري | الإصلاح والدليل |
|---|---|---|
| طلبا Login متداخلان قد يفصلان Marker عن nonce المخزنة | عدم وجود تسلسل موحد لكتابات المخزنين | AuthOperationLane لكل AppDatabase؛ اختبارات تزامن فعلية |
| Logout أثناء إعادة المصادقة قد يفقد صلاحية إبطال الجلسة | استبدال/تفريغ الحالة الخاصة مبكرًا، ثم فحص جلسة قديمة | تصريف الطلب السابق والاحتفاظ بسلطة الإبطال الخاصة حتى نجاح الاستبدال/الإبطال |
| كتابة Marker مع ACK مفقود وفشل rollback قد تترك جلسة قابلة للاستعادة بعد فشل الطلب | نشر nonce قبل نجاح الكتابة الآمنة، واعتماد rollback قابل للفشل | Marker أولًا ثم CAS للـnonce داخل SQLite؛ لا rollback بعد COMMIT |
| إلغاء بعد CAS قد ينقض نجاحًا دائمًا أو يفشل تراجعه | عدم تعريف نقطة حسم العملية | COMMIT الناجح هو نقطة الحسم؛ Logout/Delete التالي يبطلان الناتج الجديد |
| Signup محفوظ ثم فشل الجلسة يترك الواجهة في مسار إنشاء حساب غير ممكن | عدم تمييز نجاح إنشاء الحساب عن نجاح الجلسة | `AuthFailure.accountCreated` وانتقال إلى Login؛ فحص إلغاء داخل معاملة إنشاء الحساب |
| فشل DB أثناء Logout قد يسمح بمواصلة عمليات حساسة أو يمنع Retry | إسقاط الحالة الخاصة دون إبطال DB، وعدم وجود حجب محلي مشترك | حجب الجلسة فور الطلب، إخفاؤها عن getter/guards، مع إبقاء سلطة Retry خاصة |
| طلب Logout مصفوف خلف إصدار جلسة قد يتعثر قبل حجب الجلسة الجديدة | await تحقق DB يسبق الحجب عند بدء الإجراء المصفوف | حجب الحالة الخاصة الحالية تزامنيًا قبل أول await |
| أول USER قد تكتب بعد Logout | SessionGuard مبكر خارج المعاملة: فجوة TOCTOU | nonce وهوية الحساب وفحص الحجب داخل المعاملة قبل الكتابة وعند نهايتها |
| Startup قد يمسح Marker حديثة أثناء تنظيف قديمة | التنظيف خارج ترتيب عمليات المصادقة | القراءة والتنظيف داخل نفس Lane مع مهلة تنظيف محدودة |
| Manifest لا يحتوي `allowBackup=false` فعليًا | ملاحظة سابقة لا تطابق الملف الحالي | إضافة المنع وقواعد backup/transfer واختبار السياسة |

أعيد إنتاج عيوب السلوك باختبارات RED ثم نجحت بعد الإصلاح، بما فيها فشل
التخزين وإعادة المحاولة والإلغاء وحدود المعاملة. hashes سجلاتها موجودة في
ملف أدلة QA؛ لا ترفع سجلات الفشل الخام التي قد تعرض قيم matcher اصطناعية.

لم يثبت deadlock أو ANR في Codex على Linux. اشتقاق الأساس عند 600000 اكتمل
في 2506ms مع استمرار heartbeat؛ لذلك لا يصح نقل تشخيص المشروع الأصلي إلى هذه
النسخة، ولا إعلان أن مشكلة Android التاريخية أُغلقت.

## التنفيذ الأمني النهائي

### KDF وكلمات المرور

- نقل العمل المكلف إلى `IsolatePbkdf2` باستخدام DartPbkdf2/HMAC-SHA256 صريح،
  دون تنفيذ Kotlin KDF جديد أو تبديل أمني في plugin.
- Salt جديد من `Random.secure` بطول 16 bytes، hash بطول 256 bits، ومعلمات
  محفوظة؛ Login يتحقق بالمعلمات المخزنة، والمقارنة لا تتوقف عند أول بايت مختلف.
- عامل واحد فعّال لكل worker؛ تداخل العمل يفشل typed busy، وإلغاء يوقف
  العامل، ومهلة 60 ثانية. لا إنشاء غير محدود لـIsolates.
- كلمات المرور محدودة بـ1024 UTF-8 bytes دون truncation، والمعلمات بـ4096
  محرفًا، والتكرارات بحد أعلى 5000000 لمنع عمل غير محدود من metadata تالفة.
- نُسخت البايتات الناتجة قبل تدمير SecretKey ومسحت buffers المملوكة القابلة
  للتعديل. لا ادعاء بمحو Strings المدارة أو جميع نسخ الذاكرة.
- `candidateIterations=600000` للاختبار والمراجعة فقط؛ لا production default.
  القيم 10/1000 للاختبارات المعزولة، ولم توصل إلى التطبيق الإنتاجي.

### معاملات المصادقة والجلسة

`AuthOperationLane` مشترك داخل العملية لكل AppDatabase مفتوحة. يمنع ازدواج
عمليات credentials، وLogout/Delete يلغيان ويصرفان الطلب السابق قبل إبطال
الجلسة. هذا ضمان ضمن runtime قاعدة البيانات الواحدة، وليس قفلًا بين عمليات OS متعددة.

كتابة SQLite وKeystore ليست معاملة ذرية واحدة. لذلك يُكتب Marker ويؤكد أولًا،
ثم ينشر CAS داخل معاملة SQLite nonce المطابقة للمالك وaccount epoch والحالة
السابقة. Marker يتيم لا يمنح جلسة ما لم يطابق DB، وينظفه Startup لاحقًا.

نجاح COMMIT هو نقطة حسم إصدار الجلسة. إلغاء لاحق لا يتظاهر بإلغاء حفظ دائم؛
ينشر الحالة في الذاكرة دون await قابل للفشل. الإبطال المصفوف بعده يستهدف
nonce التي صدرت بالفعل. أما الإلغاء قبل COMMIT فيمنع الكتابة عبر فحص المعاملة.
إن حُفظ الحساب قبل تعطل إصدار الجلسة، يُبلغ `accountCreated=true` وينتقل
المستخدم إلى Login بدل محاولة إنشاء حساب ثانٍ.

يُحجب الوصول الحساس عند طلب الإبطال، وحتى عند فشل DB. يحتفظ AuthService
بحالة خاصة لإعادة الإبطال؛ public `activeSession` وSessionGuard لا يمنحانها.
فحص سلطة Retry يتطلب مطابقة المالك/epoch/nonce المخزنة، ولا يستخدم لإتاحة
البيانات. الحجب يحتفظ ببصمة SHA-256 لهوية الجلسة دون raw nonce؛ جلسة جديدة
بـnonce عشوائية لا تعيد صلاحية الجلسة القديمة.

SQLite مصدر إبطال الجلسة أولًا. فشل الكتابة ليس Logout ناجحًا، ولا يؤدي لحذف
الحساب أو فقد البيانات. Delete المؤكد يحذف صفوف الحساب المرتبطة، ويحتفظ
بالموارد المشتركة؛ الصفوف القديمة تفشل بالمالك/epoch/nonce بعد الحذف أو الخروج.

### Keystore وUI

حُفظ AndroidKeyStore/AES-256-GCM الموجود، وأضيفت حدود ciphertext/Marker
وUTF-8 صارم، ومهلة Dart للقناة 15 ثانية. منفذ native تسلسلي مشترك بين Engines
بطابور محدود 8 يحاصر تراكم العمل، وdisposed callbacks لا تعاد إلى Engine قديم.
MainActivity يتخلص من القناة السابقة عند الاستبدال. نطاق الاختبار native
لا يسمح به في build غير debuggable. لا تخزين plaintext أو fallback أضعف.

Manifest أصبح يرفض backup مع قواعد استثناء DB/Prefs/files وdevice transfer.
اختبار XML والسياسة يثبت محتوى الملفات، ولا يثبت merged manifest أو سلوك OEM
دون بناء واختبار Android.

Signup/Login يقبلان callbacks للإلغاء، وdispose يلغي الطلب المشغول، وتمسح
حقول كلمة المرور بعد النجاح أو المصالحة. اختبارات Widget استخدمت AuthService
وKDF الحقيقيين عند 600000 وSQLite؛ البديل المعزول هو Marker. هذا يثبت عمل
طبقات Flutter تحت الاختبار، ولا يعني أن التطبيق المنشور يملك Signup/Login
إنتاجيين: ربط AppBootstrap باقٍ خلف البوابة وفق DD-05.

## نتائج الأوامر والاختبارات

البيئة الفعلية: Flutter 3.38.5، Dart 3.10.4، Linux x86_64 / Debian 13.

| التحقق | Exit | النتيجة | الزمن |
|---|---|---|---|
| `dart format --output=none --set-exit-if-changed` للملفات المتغيرة | 0 | منسق | 0.135s |
| `flutter pub get --enforce-lockfile` | 0 | نجح، لا تغيير lockfile | 0.577s |
| `flutter analyze` | 0 | دون issues | 1.756s |
| `flutter test --machine` | 0 | 167 pass / 0 fail / 0 skip | 24.056s |
| Auth focused، 13 ملفًا | 0 | 67 pass / 0 fail / 0 skip؛ ضمن 167 | 17.088s |
| `git diff --check` | 0 | نظيف | فحص Git |
| `flutter build apk --debug --no-pub` | 1 | `No Android SDK found`؛ لا APK | متعذر عند شرط SDK |
| Android Integration/Force-stop/Logcat | لم ينفذ | `PENDING_DEVICE_TEST` | لا SDK/adb/emulator/device |

استُخدم SQLite native فعلًا، مع ملف مؤقت وإعادة فتحه، بعد التحقق من hash
لـlibsqlite3.so في cache المعزول:
`b17729184e5a2818055ecbddd5ed6642521bfe6e56aafa472330e483c0e2e0d2`.
لا تُعد إعادة فتح الملف إعادة تشغيل للتطبيق أو للهاتف.

| الاختبارات الجديدة | العدد | ما تثبته |
|---|---|---|
| `b04_kdf_worker_test.dart` | 13 | 7 متجهات مستقلة، 600000، Unicode/NUL/long key، الإلغاء/busy/deadline/heartbeat/حدود المدخل |
| `b04_auth_race_test.dart` | 8 | تداخل Login/Logout/Delete، حد COMMIT، عدم كتابة نتيجة ملغاة |
| `b04_security_recovery_test.dart` | 5 | accountCreated، فشل DB أثناء الإبطال، حجب الجلسة وRetry، تنظيف Marker |
| `b04_keystore_channel_test.dart` | 4 | عقد MethodChannel، أخطاء ومقاسات ومهلة؛ native غير منفذ |
| `b04_auth_real_widget_test.dart` | 2 | Signup/Login بعمل KDF حقيقي مع رسم UI والإلغاء |
| `b04_cross_store_recovery_test.dart` | 2 | فشل reauth مع سلطة إبطال سابقة، وترتيب Startup مع Marker جديدة |
| `b04_full_flow_test.dart` | 1 | إنشاء/SQLite reopen/استعادة/خاطئة/صحيحة/Logout/Login/Delete وبقاء الموارد |
| `b04_late_message_test.dart` | 1 | رفض أول USER المتأخرة بعد الإبطال داخل المعاملة |
| `b04_backup_policy_test.dart` | 1 | Manifest وقواعد استبعاد النسخ والنقل |
| الإجمالي الجديد | 37 | يضاف إلى baseline 130 ليصبح 167 |

المتجهات ولدت خارج مكتبة التطبيق باستخدام Python `hashlib.pbkdf2_hmac`
مع OpenSSL 3.5.8، وبمدخلات اختبار اصطناعية لا تخص حساب مستخدم.
الاختبارات القائمة للمخطط والمستودعات وAuth وB-05/B-06 وResource Validation
استمرت بالنجاح. نتائج كل ملف والتوقيت وhashes السجلات في
[`B04_SECURITY_VERIFICATION_2026-10-23.json`](../qa/B04_SECURITY_VERIFICATION_2026-10-23.json).

أُجريت مراجعتان مستقلتان: standards/security ومطابقة مواصفة P0. عولجت الملاحظات
باختبارات regression. لا موانع متبقية ضمن نطاق الكود الذي راجعتاه؛ هذا لا
يعني اعتمادًا أمنيًا إنتاجيًا أو تحقق Android. شجرة المراجعة
`721ef1369a4341505876efa50eb8b150d672b117`، وشجرة التحقق النهائي
`e739b41cf0ca4e19a2bc479a4a880e1ddcde1d11`؛ الفرق اللاحق للمراجعة قوسان
لـlint في UserRepository دون تغيير السلوك. ثم أضيفت وثائق التسليم فقط.

## قياسات KDF والذاكرة

قياسات CLI على Linux JIT عند 600000، بكلمات اختبار اصطناعية دون إخراجها:

| القياس | الاشتقاق ms | heartbeat ticks | أكبر فجوة ms | RSS قبل/بعد bytes |
|---|---|---|---|---|
| Baseline، عينة واحدة | 2506 | 247 | 33.415 | 209248256 / 210280448 |
| Isolate، العينة 1 | 1900 | 188 | 23.577 | 210563072 / 211898368 |
| Isolate، العينة 2 | 1894 | 189 | 11.077 | 211959808 / 212029440 |
| Isolate، العينة 3 | 1918 | 191 | 10.337 | 212029440 / 212090880 |

تسوية إلغاء عمل 5000000 بعد بدءه: **2.092ms**؛ النتيجة cancelled.
أقصى RSS للعملية بعد الإصلاح 233443328 bytes. RSS للعملية الكاملة وDart VM،
وليس heap العامل وحده. المقارنة عينة واحدة مقابل ثلاث وليست تجربة إحصائية
مضبوطة؛ لا نسبة تحسن مضمونة ولا إثبات leak-free أو قياس Android.
التكرار المحدود يثبت اكتمال هذه العينات والإلغاء، ولا يغني عن stress/ذاكرة
وframe timings على الهاتف. الأداة: `tool/b04_kdf_benchmark.dart`.

## الشبكة والعوائق الدقيقة

| URL / hostname | الحالة المرصودة | الطبقة والسبب |
|---|---|---|
| `https://dl.google.com/android/repository/repository2-1.xml` — `dl.google.com` | 403 Forbidden؛ curl exit 56 | proxy CONNECT tunnel failed؛ حالة origin غير متاحة |
| `https://maven.google.com/` — `maven.google.com` | 403 Forbidden | `flutter doctor`: Proxy failed to establish tunnel |
| `https://cocoapods.org/` — `cocoapods.org` | 403 Forbidden | فحص doctor العام؛ ليس متطلبًا لمسار Android Auth |

غياب SDK هو سبب فشل أمر APK الفعلي. رفض proxy يمنع مسار جلب مستودع SDK
المجرب؛ لا دليل على رفض صادر من خوادم Google أو على تعطل كل الإنترنت.
نجح GitHub وpub get في العمليات المسجلة. لم تُعطل TLS أو Keystore أو سياسة
الشبكة، ولم تُكشف credentials. لا جهاز Android أو Emulator لاختبار Logcat/ANR.

## تصنيف المكونات

| المكون | التصنيف المطلوب | حد الإثبات |
|---|---|---|
| PBKDF2/Salt/verification/Isolate/cancel | `IMPLEMENTED_AND_TESTED_NOT_DEVICE_VERIFIED` | متجهات مستقلة وأداء/heartbeat سحابي؛ الجهاز مطلوب |
| AuthService، SQLite، Logout/Delete، الحجب وRetry | `IMPLEMENTED_AND_TESTED_NOT_DEVICE_VERIFIED` | DB فعلية وسباقات وفشل محقون؛ Marker بديل اختباري |
| حراسة USER والمعاملات | `IMPLEMENTED_AND_TESTED_NOT_DEVICE_VERIFIED` | regression على مسار B-05 الموجود |
| Keystore/MethodChannel/Lifecycle native | `PARTIALLY_RESOLVED` | إصلاح ومراجعة static وعقد Dart؛ Kotlin غير مبني وnative غير مجرب |
| Backup/device transfer | `PARTIALLY_RESOLVED` | XML/Manifest والسياسة مختبرة؛ merged manifest/OEM معلّق |
| Startup persistence/recovery | `PARTIALLY_RESOLVED` | SQLite reopen وMarker اختباري؛ Force-stop/reboot/فقد مفتاح حقيقي غير منفذة |
| ربط Signup/Login الإنتاجي وKDF profile المعتمد | `BLOCKED` | DD-05 benchmark جهاز 6GB ومراجعة قبل فتح البوابة |
| Android Build والقبول على الجهاز | `BLOCKED` | SDK غير موجود وشبكته المجربة محجوبة، ولا جهاز متصل |

لا مكون يصنف `RESOLVED_AND_DEVICE_VERIFIED` في هذه البيئة. أصل مشكلة Android
التاريخية ونجاح المسار المنشور غير محسومين بهذه الاختبارات. عدم وجود عيب
متبقٍ مثبت في اختبارات السحابة ليس إثبات خلو النظام من جميع العيوب.

## الملفات المتأثرة

القائمة الكاملة 35 ملفًا، بما فيها هذا التقرير:

```text
android/app/src/main/AndroidManifest.xml
android/app/src/main/kotlin/com/example/siraj/MainActivity.kt
android/app/src/main/kotlin/com/example/siraj/SirajSecureSessionChannel.kt
android/app/src/main/res/xml/backup_rules.xml
android/app/src/main/res/xml/data_extraction_rules.xml
docs/qa/B04_ANDROID_ACCEPTANCE_AR.md
docs/qa/B04_SECURITY_VERIFICATION_2026-10-23.json
docs/reports/B-04_SECURITY_AUDIT_REPAIR_01_AR.md
integration_test/b04_android_secure_session_test.dart
lib/data/conversation_repository.dart
lib/data/user_repository.dart
lib/features/auth/auth_models.dart
lib/features/auth/auth_operation_lane.dart
lib/features/auth/auth_service.dart
lib/features/auth/kdf_worker.dart
lib/features/auth/login_page.dart
lib/features/auth/password_hasher.dart
lib/features/auth/session_guard.dart
lib/features/auth/session_marker_store.dart
lib/features/auth/signup_page.dart
lib/features/auth/startup_session_resolver.dart
lib/features/chat/conversation_draft_controller.dart
test/b04_auth_race_test.dart
test/b04_auth_real_widget_test.dart
test/b04_backup_policy_test.dart
test/b04_cross_store_recovery_test.dart
test/b04_full_flow_test.dart
test/b04_kdf_worker_test.dart
test/b04_keystore_channel_test.dart
test/b04_late_message_test.dart
test/b04_security_recovery_test.dart
test/fixtures/b04_pbkdf2_sha256_vectors.json
test/support/auth_test_marker.dart
test/support/auth_test_repository.dart
tool/b04_kdf_benchmark.dart
```

## أول خطوة صحيحة والقبول الإنتاجي

1. تجهيز Android SDK عبر مسار شبكة مصرح به، وجهاز فعلي 6GB، وبناء اختبار
   معزول بمعرّف حزمة مختلف عن أي تثبيت مستخدم. لا تثبيت فوق بيانات حقيقية.
2. تنفيذ [`B04_ANDROID_ACCEPTANCE_AR.md`](../qa/B04_ANDROID_ACCEPTANCE_AR.md):
   القناة وKeystore الفعليان، Signup/Login خاطئة وصحيحة، Force-stop/reboot،
   Logout/Delete وموارد مشتركة، إلغاء وتداخل وفشل DB/Keystore، Activity/Engine
   lifecycle وbackup/transfer، وتوثيق ANR/frame timings/RAM/أزمنة cold/warm.
3. مراجعة القياسات والأمان واعتماد profile إنتاجي مبرر دون خفض تجريبي للتكرارات،
   ثم ربط AuthService في AppBootstrap ضمن تغيير مستقل قابل للمراجعة. لا bypass
   أو test credentials أو فتح بوابة قبل الدليل.
4. مراجعة دمج PR #5 بقرار المستخدم فقط، وتسوية تقاطعه مع B-08 عند استئناف
   ذلك المسار. يبقى تكامل Biology G2/G3 المبكر أولوية؛ PDF/Quiz والحزم الخمس
   ليست شرطًا لبدء التكامل الهندسي. لا ادعاء G2/G3 دون موارد متوافقة وجهاز فعلي.

لم تبدأ هذه المهمة مرحلة جديدة ولم تُدخل موارد AI وهمية إلى الإنتاج.
إن لزم التراجع، تُعكس Commits هذه المرحلة بمراجعة واضحة دون حذف DB/المفاتيح
أو تغيير schema؛ إعادة الكود القديم تعيد عيوبًا أمنية ولا تبرر إطلاقه إنتاجيًا.
