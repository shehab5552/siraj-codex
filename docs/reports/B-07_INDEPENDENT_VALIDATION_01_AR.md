# SIRAJ P0 — تقرير B-07/INDEPENDENT-VALIDATION-01

## 1. تعريف المهمة والحالة

- **Task ID:** `B-07/INDEPENDENT-VALIDATION-01`.
- **Step:** تحقق سلامة ملف فعلي وHeader Preflight، تطوير مستقل من قاعدة Codex؛ ليس نقلًا لكود المشروع الأصلي.
- **Date:** 2026-10-22.
- **Status:** اكتملت الشريحة البرمجية المختبرة وهي معروضة للمراجعة. لا يعني ذلك اكتمال B-07 أو Resource Integration أو P0 Production Acceptance.
- **Requirement References:** المواصفة الرسمية P0 v1.0.1 المصححة، DD-03، §6.5 و§10.1–10.5؛ خطة B المعدّلة. تدعم جزءًا من فحوص سلامة الموارد المرتبطة بـTC-12/13/26/27، ولا تشهد باجتياز تلك الحالات كاملة أو أي Gate.
- **Authorization:** التكليف التنفيذي الأخير أذن بالتطوير المستقل وCommit/Push/PR وألغى انتظار مصدر المشروع الأصلي. لم يُفتح `siraj-p0` أو كمبيوتر المالك. الدمج غير منفذ.

## 2. Git والتسليم

| الحقل | القيمة المثبتة |
|---|---|
| Repository | `shehab5552/siraj-codex` |
| Default/Base Branch | `main` |
| Base Commit | `de84bcfaa6ee885eccd906f933e589d876a4cdac` |
| Feature Branch | `codex/b07-resource-validation` |
| Implementation Commit | `18ce8488c34a67381dc0ea69c0c829990782dde0` |
| Readiness classification/configuration documentation commit | `8eb0b7e5d90d66793a116f9b1f096f11002f2c11` |
| Pull Request | https://github.com/shehab5552/siraj-codex/pull/2 |
| Target / State عند الإنشاء | `main` / OPEN، غير مدمج |
| Connected account | `Eng-Osama-Ali-Al-qudsi`؛ أثبت GitHub API صلاحية Push ونجح رفع الفرع |

التقرير نفسه ضمن Commit توثيق لاحق على PR ذاته؛ تسجل صفحة Commits وبيانات PR قيمة HEAD النهائية. PR #1 السابق للتحقق من الكتابة منفصل، وملفه ليس ضمن هذا التغيير.

## 3. الهدف ومعايير القبول

قاعدة `main` تضمنت عقود المتطلبات وتصريح المرشح، دون فاحص فعلي للبايتات. الهدف إضافة تحقق قابل للاستدعاء والاختبار، قبل بناء DownloadService والتفعيل، مع إبقاء الفصل بين LLM وDataset وPDF.

معايير هذه الشريحة: مطابقة Hash معلوم وحجم معلن؛ رفض التلف حتى مع تساوي الحجم؛ رفض Hash الإلزامي الغائب/المعطوب والمسارات والروابط غير الآمنة؛ قراءة على دفعات لا تحمل النموذج كله إلى الذاكرة؛ نتائج أخطاء محددة؛ التعرف المحدود على الترويسة دون إسقاط فحوص Runtime/Device/Load/PDF Readability أو منح READY. تحققها الاختبارات الآلية أدناه.

## 4. التنفيذ الفعلي والملفات

| الملف | التغيير والغرض |
|---|---|
| `lib/features/resources/artifact_integrity_validator.dart` | API محلي ونتائج Typed لفحص الحجم وSHA-256 والمسار، مع Evidence ثابتة غير قابلة للتعديل |
| `lib/features/resources/resource_format_preflight.dart` | فحص محدود للـprefix الملتقط أثناء حساب البصمة، مع إبقاء الفحوص المتخصصة معلقة |
| `test/b07_artifact_integrity_test.dart` | 23 اختبارًا بملفات ومجلدات وروابط مؤقتة فعلية |
| `test/b07_resource_format_preflight_test.dart` | 18 اختبارًا للترويسات ولعدم إثبات الجاهزية |
| `docs/architecture/RESOURCE_INTEGRATION_READINESS.md` | تصنيف الموارد وConfiguration والتخزين والتحقق والتفعيل والاختبارات والعمل الممكن الآن وما يحتاج المورد/الجهاز |
| `docs/reports/B-07_INDEPENDENT_VALIDATION_01_AR.md` | هذا التقرير الموحد ونتائج التسليم |

### السلوك والقرارات

- Hash مطلوب لـLLM وRAG_PACK وRAG_EMBEDDING. PDF يفرض Hash إن قدمه Catalog؛ إذا غاب، تحسب بصمة ملاحظة ويظل `sha256Matched=false`. الحجم يفحص عندما يعلنه المصدر؛ السالب مرفوض.
- SHA-256 من `cryptography` الموجودة، عبر pure-Dart streaming sink، وقراءات 64 KiB. يحتفظ الفاحص بأول 24 بايت فقط؛ لا يحمل ملفًا متعدد الجيجابايت كاملًا.
- Relative Path واضح؛ يمنع Traversal والأجزاء الملتبسة والروابط الرمزية في الجذر المقدم ومكونات المسار والملف. يقارن الحجم وStat بعد القراءة ويرصد التغييرات العادية. إغلاق Handle في `finally`، وFileSystemException يتحول إلى خطأ I/O محدد.
- أخطاء السلامة: `invalidExpectation`، `missingRequiredHash`، `unsafePath`، `missingFile`، `sizeMismatch`، `hashMismatch`، `fileChanged`، `ioFailure`. لا تقدم الأخطاء نجاحًا بديلًا.
- GGUF Little Endian v2/v3: تعرف على Magic/Version ورأس ثابت أدنى 24 بايت فقط. PDF: ترويسة إصدارات 1.0–1.7 أو 2.0 متبوعة بـCR/LF في البداية. RAG Pack/Embedder يحتاجان Validator متخصصًا ولا يفترض الفاحص صيغتهما.
- `recognizedHeader` يمكن أن ينطبق على ملف غير قابل للاستخدام. `remainingChecks` لا يزيل إلا SHA المطابق؛ اكتمال النقل وصحة الصيغة وRuntime/Device/Load/Readability تظل مطلوبة.
- لا Network/Extraction/SQLite/Promotion/Activation في الفاحصين. لا تعديل لجدول أو Schema أو Repository أو UI أو KDF أو ملف تطبيق قائم. لم تربط شاشة الحالة بالفاحصين بعد؛ سيتولى منسق الموارد المقبل استدعاءهما دون تعريض نتائج جزئية كجاهزية.
- **Dependencies:** لا إضافة أو ترقية؛ `pubspec.yaml` و`pubspec.lock` محفوظان. لا اختيار Model/Runtime/Tokenizer/ABI إنتاجي ولا Threshold افتراضي.
- **Compatibility:** واجهة إضافية داخل ميزة الموارد، دون تغيير السلوك العام القائم. مصطلحات Evidence محدودة لتجنب تجاوز عقود B-07 السابقة.

## 5. الاختبارات والأدلة الفعلية

البيئة: Flutter **3.38.5**، Dart **3.10.4**، Linux x64. الاختبارات الجديدة تستخدم Temp Directories فقط. لم تستخدم ملفات موارد طالب أو قاعدة بيانات إنتاجية.

| الأمر/التحقق | المتوقع | النتيجة الفعلية |
|---|---|---|
| `flutter pub get --enforce-lockfile` | اعتماد Lockfile دون تغيير | exit 0؛ نجح، لا تغيير للحزم المقفلة |
| `flutter analyze` قبل التغيير | خط أساس معروف | exit 0؛ No issues found |
| `flutter test --machine` قبل التغيير | خط أساس مثبت | exit 0؛ **89 passed / 0 failed / 0 skipped** |
| Integrity focused tests | نجاح حالات السلامة والرفض | 23 اختبارًا ناجحًا بعد إضافة حالتي Empty/Missing Root |
| Header focused tests | فحص محدود وإبقاء المتطلبات | 18 اختبارًا ناجحًا ضمن التشغيل النهائي |
| `dart format --output=none --set-exit-if-changed lib/features/resources/artifact_integrity_validator.dart lib/features/resources/resource_format_preflight.dart test/b07_artifact_integrity_test.dart test/b07_resource_format_preflight_test.dart` | لا تغيير مطلوب | exit 0؛ أربعة ملفات، صفر تغييرات |
| `flutter analyze` بعد التنفيذ | لا ملاحظات | exit 0؛ No issues found، 1.4 ثانية |
| `flutter test --machine` بعد التنفيذ | السابق + الجديد دون Regression | exit 0؛ **130 passed / 0 failed / 0 skipped**، نجاح المشغّل، نحو 10.3 ثانية |
| `git diff --check` | لا أخطاء whitespace | نجح |
| `flutter devices --machine` | تحديد الدليل المتاح | Linux فقط؛ لا جهاز Android في القائمة |
| SQLite native على Linux | اختبارات DB القائمة تعمل | نجحت ضمن الحزمة؛ ELF x86-64 موجود و`ldd` دون تبعيات مفقودة |
| Android / G2 / G3 / Real Runtime / PDF Reader | إثبات مستقل على الجهاز | **NOT RUN**؛ لا نتائج جهاز أو قبول إنتاجي |

عد الاختبارات من أحداث `testDone` غير المخفية؛ أحداث تحميل Suites لا تعد اختبارات، والتخطي منفصل عن النجاح. لا أخطاء أو stderr في التشغيل النهائي.

### Test-first والمراجعة

شُغلت الاختبارات ضد API Scaffold قبل تنفيذ السلوك: فشل اختبار SHA المعلوم بسبب الحصول على Failure بدل Match؛ وفشل Header Recognition بسبب نتيجة Specialized Validator بدل التعرف المتوقع. ثم نفذ السلوك ونجحت الاختبارات. فشل مرحلي في موضع Imports وملاحظتا Braces عولجت قبل التحقق النهائي؛ لا تعرض كإخفاقات باقية.

مراجعة المعمارية/Standards ومراجعة المواصفة نفذتا مستقلتين على التغيير المثبت. لا Findings برمجية باقية؛ ملاحظة واحدة عن تصنيف الموارد في الوثيقة صُححت بالمصطلحات المطلوبة وأعيد التحقق منها. المراجعتان ساكنتان، ونتائج Flutter مستقلة عنهما.

### فشل تنزيل أداة المراجعة

Qodo CLI غير مثبت، وكذلك المسار الاحتياطي. تعذر تنزيل المثبت الموثق:

`https://get.qodo.ai/installers/bd546a0fc51ac4bb32486c9f766870ba0dedef27bf0472bb1e15ffdede52acf8/install.sh`

- **Hostname:** `get.qodo.ai`.
- **Proxy CONNECT HTTP status:** **403 Forbidden**، مع `server: envoy`.
- **Origin HTTP status:** لم يصل الطلب إلى المصدر؛ Curl يعرض `000`، وليس HTTP Response من Qodo.
- **Exact error:** `curl: (56) CONNECT tunnel failed, response 403`؛ محاولة التنزيل الأولى أبلغت أيضًا `(22) The requested URL returned error: 403`.
- **Cause identifiable:** رفض وكيل الخروج CONNECT؛ المضيف غير مدرج في allowlist المعروضة للبيئة. لم ينفذ المثبت، ولم تُضعف السياسة أو يُجر تجاوز. **لم تنفذ مراجعة Qodo**، وليست هذه مشكلة مصادقة مثبتة.

لم يفشل جلب اعتمادات Flutter في هذا التحقق. نجاح `pub get` باستخدام Cache المتاح لا يثبت السماح بجميع المضيفين أو تنزيل جميع الموارد المستقبلية.

## 6. الأمن والقيود والمخاطر المتبقية

Staging خاص بالتطبيق ومنسق يمنع الكتابات المتزامنة شرط استخدام، لا ميزة Locking منفذة. Dart path/stat checks ليست `openat/O_NOFOLLOW` ولا تقاوم وحدها كاتبًا خصمًا يبدل المسارات بين الفحوص. لا تنقل Evidence إلى ملف آخر ولا تستخدمها بعد تبديل الملف؛ يلزم في المراحل التالية ضبط الملكية والنشر غير القابل للتعديل وإعادة التحقق عند Startup.

Hash متوقع من مصدر موثوق شرط أصالة؛ Hash مشتق من الملف نفسه ليس دليلًا. الاختبار المولد يولد مرجعه لتجربة السيناريو فقط، مع SHA ثابت معلوم لـ`abc` واختبار البصمة الفارغة أيضًا.

الترويسة ليست Parse كاملًا. يلزم لاحقًا Safe Extraction وArchive/Internal Checksums وUTF-8/Schema/References/Index وShared Embedding Config/Android Query. يلزم Runtime Load للنموذج وReader Open/Parse للـPDF. لا توجد ضمانات RAM/Latency أو توافق جهاز من اختبارات هذه الشريحة.

لا تعديل لمؤشر Active أو إصدار سابق. Immutable Promotion وAtomic Pointer وPinned Handles وCrash Recovery مطلوبة في مراحل لاحقة، وليست منفذة هنا. لا Fake Tutor أو بيانات تعليمية وهمية في مسار المنتج.

**Rollback:** Revert لتغييرات PR بعد الاعتماد إذا لزم؛ لا Migration أو بيانات تحتاج إصلاحًا. **Technical debt:** APIs الجديدة غير موصولة بـDownload/Resource Coordinator بعد؛ هذا عمل مخطط، وليس جاهزية مخفية.

## 7. Handoff والخطوة التالية

**Completion:** شريحة سلامة البايتات وHeader Preflight مكتملة ومختبرة؛ PR للمراجعة، دون Merge. توثق [جاهزية دمج الموارد](../architecture/RESOURCE_INTEGRATION_READINESS.md) المورد والعقد وConfiguration والتخزين والتحقق والتفعيل والاختبارات وما يمكن بناؤه وما يتطلب الموارد/الجهاز.

**Next recommended task:** `B-07/INDEPENDENT-DOWNLOAD-01`: بناء DownloadService إلى Staging وفق §6.5/§10.5، مع HTTPS وTyped Errors وDisk Space وPause/Cancel وArtifact Identity وResume/Restart آمنين؛ اختبارات الانقطاع وتغير الهوية وفشل الحجم/Hash وعدم التفعيل. استخدام Catalog/DownloadSpec المعتمدين كعقد، دون اختراع روابط إنتاج أو تغيير قرارات Runtime. لا يحتاج هذا العمل إلى كود المشروع الأصلي أو اكتمال موارد AI.

**Parallel preparation:** استقبال Catalog/Artifacts وRuntime/Embedding Config وBiology Fixture مراجعة؛ تشغيل G2/G3 على Android مبكرًا عند توفر المدخلات، دون انتظار UI كامل أو خمس Packs إنتاجية. تبقى Fixture معزولة عن مؤشر الإنتاج و`RAG_READY`. تثبت Cloud Tests سلوكها المختبر فقط.
