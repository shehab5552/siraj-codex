# SIRAJ P0 — B-07 / INDEPENDENT-DOWNLOAD-01

**التاريخ:** 2026-10-22. **حالة التنفيذ:** الكود والاختبارات مكتملان ضمن نطاق النقل الآمن. **حالة التسليم المطلوبة:** معلقة على دمج PR #2 بواسطة المالك؛ لا يوجد PR جديد مبني على `main` بعد الدمج حتى الآن. هذا عائق قاعدة Git، وليس انتظارًا لكود المشروع الأصلي أو موارد AI.

## 1. المراجع وحدود النطاق

المراجع: المواصفة الرسمية `SIRAJ_P0_FINAL_MASTER_SPECIFICATION_v1.0.1_CORRECTED.md`، DD-03، §6.5، §10.1–10.5، وخطة الفريق B المعدلة، والتكليف الحالي. العمل يدعم فحوص الموارد ذات الصلة بـTC-12/13/16/26/27/28 جزئيًا؛ لا يشهد باجتياز حالات القبول هذه كاملة أو بوابة Android.

فُحص `lib` و`test` والتوثيق قبل التنفيذ. لم يوجد DownloadService سابق؛ وجدت عقود وفاحصا `ArtifactIntegrityValidator` و`ResourceFormatPreflight` فقط. أضيفت خدمة نقل واحدة عامة، مع سياسة تحقق مستقلة؛ لا خدمات مكررة لـLLM وDataset وPDF.

المستودع الوحيد المستخدم هو `shehab5552/siraj-codex`. لم يُفتح `siraj-p0` أو كمبيوتر المالك. لا روابط إنتاج أو Manifest أو نماذج غير معتمدة. لم ينفذ Atomic Dataset Activation؛ يبقى مسارًا منفصلًا وفق تكليف B-12.

## 2. قاعدة Git والنتيجة الفعلية للتسليم

| البند | القيمة المثبتة |
|---|---|
| Repository / Default branch | `shehab5552/siraj-codex` / `main` |
| `main` الفعلي عند التحقق | `de84bcfaa6ee885eccd906f933e589d876a4cdac` |
| PR #2 | https://github.com/shehab5552/siraj-codex/pull/2 — OPEN، `merged=false`، `merged_at=null` |
| قاعدة العمل التحضيري | رأس PR #2 المتحقق منه: `983ea1272bbb2e4c6319cd99aca25dd7273bc47d` |
| فرع العمل المرفوع | `codex/wip-b07-independent-download-01` |
| Commit التنفيذ | `3ebd38fb06ec6372172204d85ba17f974e5a04ff` |
| Commit تصحيح عداد Resume وتغطية السياسات | `f662ccbe3be237ee383f56f073775966b89092fc` |
| Push | نجح رفع الفرع إلى origin، ثم التحقق من SHA البعيد |
| PR جديد | **لم يُنشأ:** شرط «من main بعد دمج PR #2» غير متحقق؛ لم يُفتح PR بقاعدة مخالفة للطلب |
| Merge | لم ينفذ؛ `main` وفرع PR #2 لم يتغيرا بهذه المهمة |

الفرع تحضيري للمراجعة، وليس ادعاءً بوجود B-07 Resource Validation على `main`. لا يُستنتج الدمج من Test Merge SHA؛ الدليل المستخدم هو `merged` و`merged_at` ورأس `main` الحي. هذا التقرير يُحفظ في Commit توثيق لاحق؛ رأس الفرع النهائي متاح في GitHub وسجل Commits.

بعد دمج PR #2: يُجلب `main` الفعلي، وتُراجع أي تغييرات جديدة، ثم يُنشأ فرع مستقل منه وتُنقل Commits هذه المهمة فقط، وتُعاد الفحوص المناسبة، ويُرفع PR جديد إلى `main` دون Merge. لا حاجة لإعادة بناء الوظائف أو نقل كود من المشروع الأصلي.

## 3. المعمارية والواجهة

- `DownloadService<T>`: HTTPS وإدارة Handle وحالة النقل وPause/Cancel/Resume/Retry وتنسيق المساحة والتحقق.
- `DownloadStaging`: ملكية الملفات والمسارات وLease/Lock وCheckpoint وقراءة/كتابة Provenance وإزالة ملفات الخدمة فقط.
- `StagedDownloadValidator<T>`: حد مستقل بين النقل وسياسة نوع المورد. النقل لا يختار نموذجًا أو يحلل Dataset/PDF.
- `ResourceDownloadValidator`: Adapter للفاحصين السابقين، يعيد `ResourceDownloadEvidence` مع المتطلبات المتبقية. Hash إلزامي لـLLM/RAG، واختياري لـPDF إذا غاب من Catalog.
- `DownloadSpaceProbe`: حد قياس نظام التشغيل؛ `AndroidDownloadSpaceProbe` يستعمل قناة Native فعلية و`StatFs.availableBytes`.

`start(spec)` يعيد Handle وFuture نتيجة. `progress(handle)` يعيد State/Bytes/Total اختياريًا. `pause` و`cancel` تنتظران تسوية الكاتب والفاحص والسجل. `resumeOrRestart` و`retry` تنفذان محاولة صريحة؛ لا Retry خلفية غير محدود. المحاولة الواحدة قد تعيد GET كاملًا مرة واحدة عند تغير Validator أو `416`. طلب Resume أثناء نقل أو Control لم ينته يعيد Busy.

`DownloadSpec` يأتي من Catalog موثوق: `resourceId` و`artifactRevision` و`kind` و`url` و`destinationKey` و`expectedSize?` و`expectedSha256?` وحد نقل صريح `maxBytes`. هذا الحد سياسة نقل يحددها المستدعي؛ ليس حجم نموذج إنتاجيًا مختلقًا. Dataset Coordinator، عند تنفيذه، يبقى مسؤولًا عن الموافقة الواحدة والخمس وEmbedder المشترك؛ لا تنزيل تلقائي في Startup ولا واجهة Embedder مستقلة هنا.

## 4. الملفات المتأثرة

| الملفات | التغيير |
|---|---|
| `lib/features/resources/download_contracts.dart` | Spec/Progress/Result/Errors وحدا Storage Probe وValidator |
| `lib/features/resources/download_service.dart` | خدمة النقل العامة، HTTP/Control/Retry/Verification lifecycle |
| `lib/features/resources/download_staging.dart` | Staging خاص، سلامة المسار، Provenance وحدها الحجمي، Lease/Checkpoint |
| `lib/features/resources/download_storage_space.dart` | Adapter قناة قياس المساحة؛ Unknown يفشل صراحة |
| `lib/features/resources/resource_download_validator.dart` | ربط فاحصي SHA/الحجم والترويسة دون جاهزية |
| `android/app/src/main/kotlin/com/example/siraj/MainActivity.kt` | تسجيل قناة التخزين والتخلص منها وفق دورة Flutter Engine القائمة |
| `android/app/src/main/kotlin/com/example/siraj/SirajDownloadStorageChannel.kt` | `StatFs` ضمن شجرة بيانات التطبيق؛ Canonicalization داخل معالجة الأخطاء |
| `android/app/src/main/AndroidManifest.xml` | تصريح INTERNET للـBuild الرئيسي، دون تخفيف TLS/Cleartext |
| `test/b07_download_service_test.dart` | 49 اختبار نقل وسياسات بملفات مؤقتة وخادم TLS فعلي |
| `test/b07_download_space_probe_test.dart` | 5 اختبارات لعقد MethodChannel، وليست تشغيل Native على Android |
| `test/support/download_server.dart` و`download_tls/` | خادم HTTP فوق TLS، شهادة ومفتاح عامان كـTest Fixtures فقط، وREADME يوضح حدودهما |
| `docs/architecture/RESOURCE_INTEGRATION_READINESS.md` | تحديث الحالة والعقود والسياسات والقيود وخطوات دمج الموارد |
| `docs/reports/B-07_INDEPENDENT_DOWNLOAD_01_AR.md` | هذا التقرير |

لم تتغير Dependencies أو Lockfile أو Schema أو Repositories أو ملفات Auth/Chat. قاعدة SQLite ذات الخمسة جداول محفوظة، ولا كتابة READY/ACTIVE أو Active Pointer.

## 5. سلامة التخزين وProvenance

الكتابة محصورة في `appSupportDirectory/downloads-staging-v1/<key>/`: `payload.part` و`provenance.json` وملف Metadata مؤقت و`writer.lock`. المفتاح محدود وآمن، ولا يقبل مسارًا. الجذر/المكونات/الملفات ذات الروابط الرمزية والأسماء غير المملوكة ترفض. لا حذف Recursive أو استبدال ملفات `models/` أو `books/` أو `rag/releases/`.

Provenance تربط SHA-256 لهوية الطلب كاملة بعدد بايتات الجزء وبصمته وETag وTotal وحالة اكتمال النقل. لا تحفظ URL أو Query Tokens خامًا. قراءة Metadata محدودة بـ16 KiB مع Strict UTF-8 وSchema صغيرة. غياب/فساد/زيادة الحجم أو اختلاف هوية/Hash/حجم الجزء يمنع الاستكمال؛ تعاد البداية من صفر داخل Staging المملوك. Marker اكتمال موجود يحفظ تحفظيًا بدل إتاحة حذفه بطلب هوية أخرى.

قبل Append/Truncate يبطل Checkpoint السابق؛ بعد Flush وإغلاق الملف يحفظ سجل جديد بملف مؤقت وFlush ثم Rename. الانقطاع المعالج وPause ينتجان Checkpoint موثقًا. Crash خلال الكتابة قبل Checkpoint صالح يعني Restart محافظًا، لا افتراض صلاحية البايتات. لا ضمان Fsync لمجلد/تعافٍ يحتفظ بكل آخر بايت عند انقطاع الطاقة؛ الأولوية رفض الاستكمال غير الموثق.

الثقة تعتمد على Catalog وHTTPS وملكية App-private Staging. السجل ليس HMAC ضد خصم قادر على تعديل بيانات التطبيق. Dart path/stat checks ليست `openat/O_NOFOLLOW`، وFile Lock استشاري؛ المنسق يعمل من Isolate واحد مع عدم وجود كتّاب خارجيين. هذه حدود صريحة وليست شهادة بتنسيق Downloads متعدد Isolates/Processes أو مقاومة خصم داخل Sandbox التطبيق.

## 6. HTTP والاستئناف والمساحة

| الحالة | السلوك |
|---|---|
| HTTPS | Trust النظام الطبيعي؛ Userinfo/Fragment وHTTP ترفض؛ لا `badCertificateCallback` |
| Redirect | يرفض بStatus محدد بدل اتباع Host أو HTTP جديد تلقائيًا؛ Catalog يقدم الرابط النهائي |
| Resume | Checkpoint مطابق وETag قوي فقط؛ `Range` و`If-Range`؛ غياب/ضعف ETag يعيد البدء، ولا يستخدم Last-Modified وحده |
| 206 | Start مطابق، End/Total صحيحان، Content-Length متسق إن أعلن، وBody لا يتجاوز End |
| 200 مع Range | يعاد استخدام Body كاملة من الصفر؛ لا تضاف إلى الجزء القديم |
| ETag تغير/غاب مع 206 | ترفض مواصلة الجزء وتنفذ GET نظيفًا مرة واحدة |
| 416 | GET نظيف واحد بدل اعتبار الجزء ناجحًا تلقائيًا |
| Body encoding | `identity` وAuto Decompression معطل؛ الرد المضغوط يرفض لحفظ معنى Offset/Hash |
| `resumedFrom` | عدد البايتات المعاد استخدامها؛ صفر بعد أي Restart كامل ناجح |
| المساحة | قبل النقل، وبعد معرفة الحجم، وقبل كل دفعة؛ حجز 32 KiB للسجل واستبداله |
| Unknown/خطأ Probe | `storageUnavailable` بدل مساحة مختلقة |
| I/O | ENOSPC/EDQUOT تصنف Insufficient Storage؛ أخطاء I/O الأخرى تحتفظ بـOS Error Code عند توفره |
| Stream بلا حجم | مقيد بـ`maxBytes` وبفحص المساحة؛ EOF لا يثبت صلاحية المورد علميًا/تشغيليًا |

الأخطاء ترجع Host وHTTP Status المعلوم وسببًا محددًا/نوع خطأ أو OS Code، دون URL/Tokens خام. لا يرقى HTTP 200 أو اكتمال النقل إلى Resource READY.

## 7. التزامن والإلغاء والتحقق

يبقى Lease الوجهة حتى إغلاق الكاتب والتحقق وCheckpoint وتسوية Control. لا فحص متزامن مع كتابة الخدمة. لا تنظيف أثناء قراءة Validator؛ Cancel ينتظر انتهاء الفحص، ثم يزيل ملفات Staging الخاصة فقط. Cancel يهيمن على Pause، وتكراره ينضم إلى Cleanup نفسها؛ Resume لا يبدأ أثناء انتظار Acknowledgment.

تغطي المعالجة أيضًا Cancel أثناء Checkpoint النهائي أو إفشال Validator، وCancel أثناء تحرير Lease لنتيجة Paused. إعادة أخذ Lease للتنظيف تحصل بعد انتهاء العامل السابق. Unsafe Path وBusy وInvalid Spec وCandidate Exists لا تتجاوز لحذف تحفظي. فشل Cleanup الحقيقي يبقى فشلًا معلومًا. بعد Downloaded، Cancel لا يحذف المرشح المكتمل.

بعد إغلاق الملف يستدعى `ResourceDownloadValidator`: مطابقة SHA/الحجم ثم Header Preflight. LLM يبقى بحاجة إلى Format/Runtime/Device/Load Proof؛ RAG بحاجة إلى Archive/Schema/Index/Embedding/Android Query؛ PDF بحاجة إلى Reader Open/Parse. النتيجة `downloaded` تعني اجتياز النقل والفحوص الجزئية المحددة فقط؛ لا READY/ACTIVE/RAG_READY أو Atomic Activation.

## 8. الاختبارات الفعلية والنتائج

Flutter **3.38.5** / Dart **3.10.4** / Linux x64. كل ملفات التنزيل والبيانات الاصطناعية في Temp Directories معزولة. Test Server هو `HttpServer.bindSecure` فعلي فوق Loopback، وليس Transport Mock. الانقطاع يرسل HTTP Body أقصر من Content-Length عبر TLS Socket حقيقية. شهادة ومفتاح الخادم مواد اختبار علنية غير صالحة للإنتاج؛ Trust خاص بالـTest Client فقط.

| الأمر | النتيجة الفعلية |
|---|---|
| Baseline `flutter analyze` | exit 0، No issues found |
| Baseline `flutter test --machine` على كود PR #2 | exit 0، **130 passed / 0 failed / 0 skipped** |
| `flutter pub get --enforce-lockfile` | exit 0، دون تغيير Lockfile |
| Focused Download + Storage Channel Tests | **54** اختبارًا في النسخة النهائية: 49 نقل/سياسة و5 عقد Native Channel |
| `flutter analyze --no-pub` بعد آخر تعديل | exit 0، No issues found، نحو 1.5 ثانية |
| `flutter test --no-pub --machine` بعد آخر تعديل | exit 0، **184 passed / 0 failed / 0 skipped**، نحو 14.5 ثانية |
| `flutter test --machine` في تحقق Regression السابق | exit 0، 177/0/0 قبل إضافة 7 اختبارات سياسات الأنواع النهائية |
| Format check للملفات الجديدة | نجح، ثم Format للتعديلات النهائية؛ لا تغييرات تنسيق مطلوبة |
| `git diff --check` | نجح |
| AndroidManifest | XML صالح محليًا؛ ليس دليلًا على APK أو Manifest Merging |
| `flutter devices --machine` | Linux فقط |
| APK/Native Android/جهاز فعلي/G2/G3 | **NOT RUN**؛ لا ادعاء قبول Android أو إنتاج |

العد من `testDone` غير المخفية؛ تحميل Suites لا يعد اختبارًا. لا أخطاء أو stderr في التشغيل النهائي. الاختبارات السابقة الـ130 نجحت دون Regression.

### تغطية الحالات المطلوبة

| الحالة | الدليل المختبر |
|---|---|
| Successful download | بايتات الملف الناتج مطابقة، Hash وHeader Evidence، PDF Readability تظل مطلوبة |
| Interrupted + valid Resume | Service جديد بعد الانقطاع، Range/If-Range مطابقان، تجميع البايتات الصحيحة |
| Ignored Range | 200 ينتج ملفًا كاملًا من الصفر و`resumedFrom=0` |
| Invalid Content-Range | Range خاطئ وخمس صيغ معطوبة وChunked Body يتجاوز End؛ لا قبول أو دمج خاطئ |
| Changed ETag / identity | ETag جديد مع206 يؤدي GET كامل؛ Revision أو Identity Metadata مختلفة تمنع Resume |
| Corrupted Provenance | JSON معطوب، سجل غائب، Identity مختلفة، جزء مطول أو معطوب بنفس الحجم |
| Invalid UTF-8 / excessive metadata | بايتات UTF-8 معطوبة و128 KiB Metadata؛ Restart بلا Range |
| Wrong size/hash/header | Catalog Size مخالف، تلف بنفس الحجم، Header غير صالح رغم Hash مطابق |
| Cancellation/safe restart | Cancel حي، Pause/Resume، Cancel أثناء حفظ نهائي، أثناء رفض Validator، وطلبا Cancel أثناء إنهاء Pause، ثم Restart صالح |
| Disk/IO | Probe منخفض/غير متاح، نفاد مساحة أثناء Stream، وفشل FileSystem حقيقي من مجلد قراءة فقط |
| Path safety/active resources | Traversal وHTTP مرفوضان قبل الطلب، Symlink Root/Payload لا يقرأ أو يعدل الملف الخارجي، المرشح المكتمل لا يستبدل بهوية أخرى |
| TLS/HTTP failure | Default TLS يرفض الشهادة غير الموثوقة، Redirect302 لا يتبع،503 يحتفظ بالHost/Status ويسمح Retry صريحًا،416 وEncoding غير آمن |
| Independent resource policies | LLM/RAG Hash إلزامي قبل HTTP؛ نفس النقل لـLLM/RAG Pack/Shared Embedder، وفحوص متخصصة معلقة؛ PDF Hash اختياري عند غياب مرجع Catalog |
| No false READY/ACTIVE | حالات النقل لا تحوي READY/ACTIVE، لا كتابة DB، ومتطلبات Runtime/PDF/RAG المتبقية ظاهرة |

فحوص المساحة تستخدم Probe اختبار متحكمًا؛ لم تُملأ مساحة القرص الحقيقي عمدًا. فشل I/O يولد فعلًا داخل مجلد مؤقت غير قابل للكتابة. اختبارات MethodChannel تتحقق من عقد Flutter ورفض Unknown/Platform Error؛ لا تثبت تنفيذ Kotlin على Android.

## 9. الأخطاء المكتشفة والمراجعة

بدأت اختبارات النجاح/الرفض قبل تنفيذ السلوك وفشلت ضد Scaffold. Root cause لخلل Test Fixture كان استدعاء `detachSocket` بعد إرسال Headers؛ فُحص تنفيذ Dart SDK، وصحح الخادم ليفصل Socket قبل إرسال HTTP خام. احتاج اختبار Pause تعطيل Buffering ليصل الجزء الصغير قبل Close. هذه إصلاحات Harness، وليست نتائج جهاز أو نجاحًا مصطنعًا.

أثبتت اختبارات إضافية قبل التصحيح: قبول Body206 أطول من Range، واستبدال مرشح مكتمل بهوية أخرى، وضياع Cancel أثناء حفظ نهائي أو إنهاء Pause/رفض Validator، وحالة Progress غير صحيحة للمنافس Busy، وعداد Resume يحتفظ بإزاحة قديمة بعد Restart. عولجت الأسباب وأعيد التشغيل. ملاحظات Braces المرحلية عولجت قبل التحليل النهائي النظيف.

راجعت جهتان مستقلتان Standards/Architecture وSpec/Data Safety على Diff مثبتة، ثم التصحيحات اللاحقة. أغلقت ملاحظات Lifecycle، ولا Findings قابلة للتنفيذ باقية. المراجعتان ساكنتان؛ نتائج Flutter منفصلة عنهما. لم تنفذ مراجعة Qodo في هذه المهمة.

لم يفشل تنزيل خارجي في هذه المهمة؛ Pub وGitHub نجحا، والاختبارات محلية. رفض TLS وHTTP503/302/416 والانقطاع أخطاء اختبار مقصودة على Host `127.0.0.1`، وليست مضيفين إنتاجيين محجوبين. لا نستنتج من Cache Pub السماح بكل المضيفين. فشل تنزيل Qodo الموثق في المرحلة السابقة ليس محاولة تنزيل جديدة هنا.

## 10. القيود والرجوع والتكامل المقبل

- Kotlin/Storage Adapter وManifest لم تبنَ أو تُختبر على Android. تتطلب الأدلة القادمة جهازًا وCatalog/Artifacts حقيقية واختبارات انقطاع ومساحة وملفات كبيرة وAirplane Mode.
- لا Safe ZIP Extraction أو Pack Schema أو Embedding/Index Runtime أو PDF Reader أو Model Load أو Dataset Activation هنا. لا Fake Tutor في المنتج.
- Staging خاص ومنسق Isolate واحد وعدم وجود كتّاب خارجيين شروط استخدام. Crash قد يفقد آخر Checkpoint؛ Restart المحافظ يحفظ السلامة دون وعد بالاستئناف من آخر بايت دائمًا.
- خدمة النقل ليست موصولة بواجهة موارد/Consent نهائية أو Catalog إنتاجي؛ هذا عمل Wiring لاحق عندما يعتمد Catalog، مع إبقاء النقل مستقلًا عن نوع المورد. لا تمنع الموارد الغائبة بناء Validators والسياسات المستقلة.
- Rollback: إيقاف استخدام الفرع التحضيري، أو Revert لتغييرات هذه المهمة عند اعتمادها؛ لا Migration أو حذف بيانات/موارد Active مطلوب. لم يتغير `main` بهذه المهمة.

**الخطوة اللازمة للتسليم:** دمج PR #2 بواسطة المالك، ثم إنشاء الفرع المطلوب من `main` الفعلي وPR جديد لهذه Commits فقط، دون Merge تلقائي. **العمل الفني التالي بعد التسليم:** Validators المتخصصة/الاستخراج الآمن وWiring الموارد وفق العقود المعتمدة؛ Atomic Dataset Activation في مساره المنفصل. يظل Biology-first G2/G3 أولوية عند توفر LLM/Embedder/Fixture مراجعة وجهاز Android، دون انتظار واجهة كاملة أو خمس Packs إنتاجية، ودون اعتبار Cloud Tests بديلًا عن الجهاز.
