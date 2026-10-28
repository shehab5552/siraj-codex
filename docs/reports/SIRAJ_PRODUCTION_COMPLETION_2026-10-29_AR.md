# SIRAJ P0 — تقرير التنفيذ والتحقق، 29 أكتوبر 2026

**التصنيف الحالي: Integration Testing، وليس Release Candidate أو Production Ready.** استؤنف التطبيق الموحد من `0b911d0a844488bb262cef88d7a708fd9dd1916f`؛ أضيف قارئ PDF وتثبيت محلي حقيقيان، وتحسينات V2 وحماية الإلغاء وأدلة مقارنة. لا تزال مطابقة V2 النهائية ومدخلات الإنتاج/الجهاز غير مكتملة.

## Git والنطاق

- المستودع الوحيد: `shehab5552/siraj-codex`، default branch `main`؛ Git Base/main عند التحقق `651af0d62d05761c80d9a8cbc9d1f51b836929eb`.
- فرع العمل: `codex/unified-siraj-v2-integration-20261024`، [PR12](https://github.com/shehab5552/siraj-codex/pull/12) OPEN/DRAFT إلى main. لا Merge في هذه الدفعة، ولا تعديل main.
- PR2 مدمج سابقًا عند `2026-10-22T06:40:21Z`؛ PR1 وPR3–PR11 لم تُدمج. لا نسخ جديد لتنفيذاتها المتراكبة؛ التطبيق الموحد الموجود يُستكمل.
- نقاط الكود: [V2 ca2c0fc](https://github.com/shehab5552/siraj-codex/commit/ca2c0fc2c61efdf9169efbf6a857b41bffb0781f)، [PDF1194527](https://github.com/shehab5552/siraj-codex/commit/119452767894b469e4819c4108b50a8d0d211a78)، [إصلاح الجلسة/Lifecycle2014171](https://github.com/shehab5552/siraj-codex/commit/201417183b4388bf89e9cd0683d0fc6dd48e129f).
- مراجع التنفيذ: المواصفة P0 v1.0.1 المصححة كاملة وخطة B المعدلة في `docs/spec/`، التكليف الأحدث محفوظ في `PRODUCTION_COMPLETION_USER_REQUEST_2026-10-28_AR.md`، وحزمة V2 الأصلية محفوظة مع Hashes في `docs/design/reference_v2/`.
- لم يُفتح siraj-p0 أو جهاز المستخدم، ولم تُكشف بيانات اعتماد. لا تغييرات Schema أو Auth production profile أو سياسات علمية.

## المنفذ فعليًا والملفات

| المسار | الملفات الأساسية | التغيير/الحد |
|---|---|---|
| Design/V2 | `lib/core/design/siraj_design.dart`، `siraj_components.dart`، `siraj_v2_components.dart` | Tokens/typography/AppBar68/Navigation66، حقول وبطاقات وحوارات موحدة؛ تفاصيل المقارنة والفروق في تقرير التصميم |
| Navigation/session | `lib/core/design/siraj_navigation.dart`، `lib/app/authenticated_navigation.dart`، `app_bootstrap.dart`، `authenticated_workspace.dart` | Navigator خاص واحد وشريط بعمر الجلسة، Authorization قبل التنقل؛ إزالة الصفحات/الحوارات عند الإلغاء، منع النقر عبر الحوار وإصلاح popup سريع |
| واجهات فعلية | Home/Onboarding/AuthFormFrame/Chat/History/Quiz/Resources/Settings/Library | إعادة استعمال الخدمات والعقود؛ لا Demo science/catalog في الإنتاج؛ خانة التبويب المختار كاملة54dp وتثبيت نماذج الحساب أعلى الشاشة؛ بعض الفروق البصرية باقية ومصرّح بها |
| PDF contracts/controller | `lib/features/library/pdf_reader_contracts.dart`، `pdf_reader_controller.dart` | أخطاء مصنفة، طلب render واحد ووجهة تالية مجمعة، إخفاء الصورة القديمة، إلغاء/إغلاق بلا إحياء استجابة قديمة |
| PDF storage | `pdf_install_store.dart`، `verified_library_actions.dart` | B07 HTTPS/provenance/lease مع حجم وSHA إلزاميين للكتاب، نسخة مرشحة وفحص header/hash ثم Native parse/render/close ثم rename نهائي |
| Native reader/UI | `native_pdf_reader.dart`، `pdf_reader_page.dart`، `SirajPdfChannel.kt`، `MainActivity.kt` | Android PdfRenderer فعلي، صفحات PNG وتنقل/تكبير، worker خلفي تسلسلي، open no-follow ومسارات خاصة، حدود ذاكرة، close/reopen حقيقيان |
| Cleanup | `lib/core/runtime/resource_cleanup_owner.dart`، `quiz_cleanup_owner.dart` | استخراج السلوك المشترك دون تغيير سياسة Quiz؛ فشل إغلاق PDF يحتفظ بالقفل حتى نجاح إعادة المحاولة |
| Android/CI | Manifest، `.github/workflows/siraj-unified-verification.yml`، `integration_test/unified_pdf_reader_test.dart` وrestart setup/restore | الاسم SIRAJ، نفس هوية الاختبار المعزولة وسياسة التوقيع، اختبار محرك PDF وإعادة تشغيل فعلية مع حفظ البيانات؛ لا تخفيف Auth |
| Evidence | `test/goldens/reference_v2/`، `v2_all_screens_golden_test.dart`، `tool/compare_v2_reference.py` | لقطات التطبيق الحقيقي بالحجم المرجعي ومقارنات RGB/مصفوفة فروق؛ لا استنتاج نجاح التصميم من Golden وحده |

لا مكتبة Flutter أو ABI binary جديدة؛ `pubspec.yaml` وLockfile بلا تحديث تبعيات لهذه الدفعة. PdfRenderer من Android framework (API21+، حد التطبيق26). روجع مصدر AOSP Android13 لعقد descriptor/one-page/ARGB_8888/عدم thread-safety؛ المحرك ليس اختيار LLM، ولا يضيف صيغة نموذج/Index. يحتاج اختبار parser على الكتب المعتمدة والأجهزة المستهدفة، ويستفيد من تحديثات أمان OS.

## ضمانات PDF

- التنزيل يظل عبر DownloadService الموجود؛ لا ناقل ثانٍ ولا تعطيل TLS. شهادة HTTPS ومفتاح الاختبار يظلان حصريين في `test/support/download_tls/` ولا تُحمّل production assets منهما.
- المجلد النهائي `files/pdf-books-v1/<SHA256 كامل لهوية النقل>/book.pdf`، والمرشح `candidate.pdf` داخل الهوية نفسها. الهوية تشمل Resource/Revision/URL/Size/Hash/Destination؛ تغيير المورد لا يستكمل كتابًا آخر.
- `.part` لا يُقدّم للقارئ في الإنتاج؛ `withCompletedArtifact` يمسك provenance/writer lease حتى اكتمال copy والتحقق وقراءة أول صفحة وإغلاق Native ثم promotion داخل filesystem. تكفي نسخة bytes ثانية ومساحة احتياطية؛ التخزين المجهول يفشل مغلقًا.
- native open محصور في book/candidate داخل app files، ويرفض traversal/canonical alias/symlink عبر الفحص وO_NOFOLLOW. لا external intent ولا صلاحية قراءة ملفات المستخدم.
- قفل OS/static يمنع installer/reader متزامنين؛ نسخة سليمة لا تُستبدل، وتلف النسخة يمكن إصلاحه فقط بعد إثبات النسخة المرشحة تحت القفل. لا حذف متكرر/شامل أو مساس بمورد نشط/إصدار آخر.
- حد العرض2048، الارتفاع4096، البكسلات4Mi والخرج PNG20MiB؛ يعيد resourceLimit دون إسقاط التطبيق. Parser/render تسلسليان خارج UI مع close barrier.
- `readable` يتطلب byte proof وnative parse/render، وليس `%PDF` أو صف SQLite. لا كتابة READY/ACTIVE/RAG_READY في مسار المكتبة.
- القارئ مستقل عن LLM وEmbedding وDataset؛ مع غياب كتالوج رسمي تبقى المكتبة بلا كتب مخترعة. عند حذف الحساب تبقى ملفات الموارد المشتركة وفق P0، وتُغلق مقابض القراءة الخاصة بالجلسة.

## الاختبارات والمراجعة

Flutter3.38.5/Dart3.10.4. Lockfile enforced بلا تحديث؛ analyze بلا ملاحظات. فحص كامل بعد إصلاحات الكود: **591 ناجحًا،0 فاشل،0 متخطى** (85.390ث؛ بعد إصلاح الإلغاء وتحسين الخلية المختارة وتجديد الصور). خط الأساس566، checkpointV2=569، PDF=585؛ لا يُعاد استعمال عدد قديم بوصفه نتيجة تشغيل جديد. التحقق النهائي والأثر المصنّع مربوطان بـCommit/CI في سجل التسليم.

اختبارات جديدة: مؤقتات وملفات معزولة وHTTPS test server فعلي، تثبيت كامل وإعادة فتح محلية، رفض parser/Hash/Size، تلف/Links/نقص مساحة، إلغاء أثناء الفحص وإعادة محاولة دون تنزيل زائد، close failure يحتفظ بالقفل، render coalescing/stale protection، typed channel replies، 200% reader RTL/LTR، وتدمير Navigator الخاص الحقيقي أثناء فتح PDF.

المراجعتان المستقلتان: محور المواصفة ومحور المعمارية، نطاق مثبت `0b911d0..1194527`. كلاهما وجد مشكلة واحدة مهمة: `Navigator.dispose` لا يكمل `push.popped`، فكان انتظار العرض يمنع تحرير قفل الكتاب بعد Logout. أُثبت RED في اختبار pending presenter وفي Navigator موثّق فعلي، وأُصلح بإنهاء انتظار العملية عند الإلغاء مع انتظار close قبل release؛ GREEN للحالتين close-success/close-failure/retry. لا توصيات صغيرة مؤجلة من هذين التقريرين. ليست مراجعة ذاتية أو اعتماد إنتاج.

فشل CI أولي `40769379925` بعد نجاح build/native: ضغط Delete قبل اكتمال التخطيط وصل إلى مكان يغطيه الشريط؛ لم يظهر الحوار. صُحح انتظار ensureVisible/layout وassert hitTestable، دون إخفاء تحذير أو تجاوز تأكيد الحذف. تشغيل CI التالي نجح.

[CI40771453346](https://github.com/shehab5552/siraj-codex/actions/runs/40771453346) عند1194527 **SUCCESS**:585 host،10 Native،1 PDF فعلي،1 تطبيق فعلي؛ جميعها0 فشل. Debug وRelease evaluation غير موقع بُنيا بنجاح. PDF استعمل وثيقة اصطناعية ذات صفحتين فقط، وليس كتاب أحياء معتمدًا. القياس المسجل لمرشح PBKDF2=600000:7210ms/708heartbeat على المحاكي؛ ليس قياس Samsung ولا اعتماد iteration إنتاجي.

تشغيل [CI40780034725](https://github.com/shehab5552/siraj-codex/actions/runs/40780034725) يضيف حفظ حساب/USER/EN-dark ثم تعطيل WiFi/mobile data وadb force-stop والتحقق من انعدام PID ثم استعادة جلسة Keystore وSQLite وإعادة الدخول/الحذف. **فشل setup:0 ناجح/1 فاشل، restore لم يُنفذ. السبب موثق من Flutter SDK: flutter test يحذف تثبيت التطبيق بعد كل هدف، فاختفى onboarding المحفوظ. صُحح المشغل إلى flutter drive --keep-app-running الرسمي، وصارت الصور تُجمع على المضيف والعدادات من binding.results الفعلية. التشغيل المصحح في سجل التسليم؛ لا ندعي نجاح force-stop قبل نتيجته.**

## بوابات القبول

| Gate | الحكم الكلي لهذه الدفعة | الدليل/المانع |
|---|---|---|
|1 Code Quality|PASS للكود المختبر؛ آخر CI موضح في سجل التسليم|591 host/analyze/pub enforced، format للملفات المتغيرة وdiff check؛ لا فشل مستتر|
|2 Visual Fidelity|FAIL|Golden ومقارنة380×737 وResponsive/RTL/EN/200% موجودة، لكن فروق V2 الجوهرية وأصل الهوية لم تُغلق؛ انظر المصفوفة|
|3 Native Android|BLOCKED للإصدار الإنتاجي؛ الاختبارات المتاحة PASS|Debug/unsigned Release،12 اختبار Native+PDF+App مثبتة في CI1194527؛ Lifecycle الجديد حسب سجل CI، توقيع الإنتاج/ملف Auth غير معتمدين|
|4 Offline Functionality|BLOCKED كقبول شامل|حساب/محادثات/PDF محلية مثبتة حسب الاختبارات، لكن AI/Quiz الحقيقيين غير متاحين؛ لا نعمم نجاح PDF على AI|
|5 AI/RAG|BLOCKED|لا runtime/LLM/Embedding/Index/Biology Gold معتمدة، لا G2/G3 أو RAG_READY|
|6 PDF/Quiz|BLOCKED كقبول مشترك|PDF engine فعلي ناجح اصطناعيًا على المحاكي؛ لا كتب رسمية/توليد وتصحيح علمي حقيقيان|
|7 Device Acceptance|BLOCKED|لا هاتف فعلي/Samsung متاح؛ إعدادات قبول الجهاز السابق باقية ولا تستبدلها اختبارات Linux أو emulator|
|8 Release Readiness|BLOCKED|هوية/توقيع/مفاتيح إنتاج، Auth benchmark+security، موارد/تراخيص ومدخلات علمية وقبول بصري لم تكتمل|

## المدخلات الخارجية المحددة

| المدخل المطلوب | الهوية/الصيغة/الدليل اللازم | سبب الحاجة |
|---|---|---|
| أصل الهوية | PNG أصلي عالي الدقة أو SVG للشعار والرمز، مع نسخة light/dark ومرجع اعتماد/SHA؛ الملف `Siraj Educational App Brand Board(1).png` المستقل إن كان هو الأصل الوحيد | تجهيز Launcher/adaptive foreground/background/splash دون تضخيم رمز صغير أو قص اللوحة |
| كتالوج PDF/الكتب | LibraryBook/DownloadSpec موثوق: id/revision/HTTPS/destination/size/SHA256/category/AR-ENtitles، ملف PDF الفعلي وترخيص/مصدر اعتماد | اختبار الكتاب الحقيقي وتعبئة المكتبة دون نسخ عناوين العرض التوضيحي |
| Local LLM | runtime build/Commit/ترخيص/ABI/minSDK/bridge API، أوزان وصيغة وquantization/size/SHA256، tokenizer/prompt/capabilities | Native ModelBackend فعلي قابل للمراجعة؛ لا اختيار Runtime تخميني |
| Shared Embedding | build/license/ABI، model+sidecars/config/tokenizer path/size/SHA، pooling/normalization/dimension/id/revision | Query vectors مطابقة لفهرس Biology؛ لا Hash من metadata منزلة غير موثوقة |
| Biology Dataset/Index | fixture revision/chunks/source register/hashes، index format+reader+binding/vector settings، Gold queries/vectors/ranking/evidence | G2 ثم G3 مبكرًا على Android الحقيقي؛ لا انتظار PDF أو خمس حزم |
| السياسات العلمية | scope/evidence/partial/answer/Quiz policies، Few-shot/تقييم كتابي/دقة Numeric/Gold مراجعة | لا اختراع سماحية أو أسئلة/نتائج علمية؛ عقودها موجودة وFail-closed |
| Auth/device | هاتف Android الفعلي6GB ونسخةOS/ABI، KDF benchmark/security approval، profile معتمد موثق | إغلاق بوابة Auth دون خفض PBKDF2 أو تفعيل مرشح المحاكي كإنتاج |
| إصدار | applicationId/سياسة انتقال معتمدة، signing credentials عبر مخزن أسرار فقط وملف إصدار/توزيع | لا Debug key fallback ولا أسرار في Git/ZIP؛ الهوية الحالية `.unifiedtest` للتجربة |

المصفوفة الأوسع للـAI موجودة في `B09_PRODUCTION_INTEGRATION_READINESS_AR.md` ولا تُلغى هنا. لا حاجة لنسخ كود siraj-p0 أو إعادة شرح المشروع.

## الخطوة الصحيحة التالية

داخليًا: إغلاق الفروق البصرية الصريحة في Visual Fidelity Matrix، دون تغيير عقود Auth أو Quiz أو استعمال Fake Catalog كمنتج. بالتوازي، بعد وصول أصل الهوية تُجهز أيقونات/Launch/Splash وتُعاد المقارنات. لمسار التعليم الأعلى أولوية: إدخال Biology fixture وnative build/LLM/Embedding/Index المتوافقة ثم **G2 على جهاز Android فعلي، وبعده G3**. لا إعادة بناء B07/B08/B09/B11/B12 ولا انتظار PDF/الحزم الخمس. لا Merge لـPR12 قبل إغلاق البوابات واعتماد المالك صراحة.

ملاحظة الهوية المثبتة بالمعاينة: ملفات Android Launcher الحالية ما تزال رمز Flutter القالبي، رغم تصحيح الاسم إلى SIRAJ. لم تُعلن أيقونة سراج أو Adaptive/Splash الرسمية مكتملة؛ تحتاج الأصل الموضح أعلاه.


تحديث التحقق عند990b247: Driver الرسمي نجح وأعاد أعداد Binding الفعلية:10 KDF و1PDF و1App دون فشل/تخطٍّ، مع حفظ الصور على المضيف. فشل restart-setup قبل الضغط على Signup بسبب hit-test بعد إدخال الحقول، فلم تُنفذ restore. صُحح المشغل لخفض IME عبر unfocus والانتظار المشروط حتى يصبح inset=0 قبل قياس/تمرير الهدف؛ لم يتغير AuthService ولم يُلغَ assert قابلية الضغط. نتيجة التشغيل التالي هي المرجع النهائي لهذا الاختبار.


## سجل التشغيل النهائي داخل حزمة المصدر

الـZIP النهائي يُنشأ **بعد** نجاح Host والأهداف الأصلية الخمسة، لا قبل الاختبارات. المشغّل يقرأ Flutter JSON وعدّادات Binding الفعلية، ويرفض التغليف عند غياب هدف أو وجود فشل/تخطٍّ. يضيف إلى المصدر `docs/qa/CI_ACCEPTANCE.json` و`CI_ACCEPTANCE_AR.md` مولّدين من التشغيل نفسه، مع Commit/Run والبوابات المحجوبة، ثم يحسب SHA256SUMS. هذان ملفا أدلة CI وليسا تعديل كود أو ملفين يُزعم وجودهما في Git؛ يوجدان أيضًا بجوار APK في Artifact. هذا السجل الأحدث يحسم نتائج Android الجديدة بدل نقل أرقام قديمة إلى تقرير ثابت قبل انتهاء CI. APK Debug يُنسخ من main قبل أن تعيد أهداف الاختبار بناء APKاتها الخاصة.
