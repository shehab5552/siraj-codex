# SIRAJ P0 — B-07 / INDEPENDENT-DOWNLOAD-01

**التاريخ:** 2026-10-22. **حالة التنفيذ:** الكود والاختبارات مكتملان ضمن نطاق النقل الآمن. **حالة التسليم:** راجعت PR #2 واختبرته ودمجته بتفويض المالك الصريح؛ أُنشئ فرع التنزيل النهائي من `main` بعد الدمج، ونُقلت Commits الشريحة الثلاثة دون إعادة كتابة الخدمة. PR التنزيل المستقل: https://github.com/shehab5552/siraj-codex/pull/3 — دون Merge. الاختبارات أدناه أُعيدت على القاعدة النهائية، وليست نقلًا لعدد التشغيل السابق.

## 1. المراجع وحدود النطاق

المراجع: المواصفة الرسمية `SIRAJ_P0_FINAL_MASTER_SPECIFICATION_v1.0.1_CORRECTED.md`، DD-03، §6.5، §10.1–10.5، وخطة الفريق B المعدلة، والتكليف الحالي. العمل يدعم فحوص الموارد ذات الصلة بـTC-12/13/16/26/27/28 جزئيًا؛ لا يشهد باجتياز حالات القبول هذه كاملة أو بوابة Android.

فُحص `lib` و`test` والتوثيق قبل التنفيذ. لم يوجد DownloadService سابق؛ وجدت عقود وفاحصا `ArtifactIntegrityValidator` و`ResourceFormatPreflight` فقط. أضيفت خدمة نقل واحدة عامة، مع سياسة تحقق مستقلة؛ لا خدمات مكررة لـLLM وDataset وPDF.

المستودع الوحيد المستخدم هو `shehab5552/siraj-codex`. لم يُفتح `siraj-p0` أو كمبيوتر المالك. لا روابط إنتاج أو Manifest أو نماذج غير معتمدة. لم ينفذ Atomic Dataset Activation؛ يبقى مسارًا منفصلًا وفق تكليف B-12.

## 2. قاعدة Git والنتيجة الفعلية للتسليم

| البند | القيمة المثبتة |
|---|---|
| Repository / Default branch | `shehab5552/siraj-codex` / `main` |
| `main` وGit Base للفرع النهائي | `651af0d62d05761c80d9a8cbc9d1f51b836929eb` |
| PR #2 | https://github.com/shehab5552/siraj-codex/pull/2 — MERGED، `merged=true`، `merged_at=2026-10-22T06:40:21Z` |
| طريقة دمج PR #2 | GitHub REST الرسمي، Merge Commit، مع تقييد الطلب برأس PR المختبر `983ea1272bbb2e4c6319cd99aca25dd7273bc47d` |
| نقطة الفصل/قاعدة العمل التحضيري | `983ea1272bbb2e4c6319cd99aca25dd7273bc47d` |
| رأس الفرع التحضيري المحفوظ | `de3294a3fac198c0da621fc4d6fb1b2f7e3446e9` |
| فرع العمل النهائي المرفوع | `codex/b07-independent-download-01` |
| رأس الكود المنقول الذي أُعيد اختباره | `cd18c57f3d7f8893da624ad3efed38e9a926f70c`؛ تلاه تحديث هذا التقرير فقط |
| PR التنزيل الجديد / Target | https://github.com/shehab5552/siraj-codex/pull/3 / `main` |
| Merge المسموح والمنفذ | PR #2 فقط؛ لم يدمج PR #1 أو PR #3 |

عند التحقق الأول كانت PR #2 مفتوحة و`main` عند `de84bcfaa6ee885eccd906f933e589d876a4cdac`. بعد توضيح المالك وتفويضه الصريح بدمج PR #2، أُعيدت مراجعته بمحوري المعمارية والمواصفة على Diff مثبتة من تلك القاعدة إلى `983ea12`. لم توجد موانع ضمن نطاقه؛ GitHub عرض `mergeable=true` و`mergeable_state=clean` دون Checks مسجلة، ونجح التحليل و130/0/0 في اختباراته المعزولة بعد معالجة تنزيل SQLite الموثقة في §9. نجح الدمج الرسمي دون تجاوز حماية فرع.

بعد Fetch ثبت SHA الجديد لـ`main` وكون `983ea12` سلفًا له، وتطابق محتواهما. ثم أُنشئ الفرع النهائي من `origin/main` ونُقلت Commits التنزيل الثلاثة فقط دون تعارضات:

| Commit التحضيري | Commit المنقول إلى الفرع النهائي |
|---|---|
| `3ebd38fb06ec6372172204d85ba17f974e5a04ff` — التنفيذ | `b2e96d13ba8e44a321f7ee9af90adb724c98c454` |
| `f662ccbe3be237ee383f56f073775966b89092fc` — Resume/السياسات | `256399ebf02ee41c00f968069df74f875d1c8527` |
| `de3294a3fac198c0da621fc4d6fb1b2f7e3446e9` — تقرير WIP | `cd18c57f3d7f8893da624ad3efed38e9a926f70c` |

قبل تحديث التقرير كان `git diff de3294a HEAD` فارغًا: الخدمة والاختبارات لم تُعد كتابتها. فرق PR مقابل قاعدة `main` يقتصر على 16 ملفًا لهذه الشريحة. ملفات فاحصي Resource Validation واختباراتهما وتقريره السابق وملف PR #1 و`pubspec.yaml` و`pubspec.lock` لم تتغير. لا حاجة لاستيراد كود المشروع الأصلي. رأس Commit التوثيق النهائي متاح في PR وسجل Git، ولا يغير الكود المختبر.

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

أعيد الفحص الساكن: لا مراجع لـ`server_cert.pem` أو `server_key.pem` أو `download_tls` أو `badCertificateCallback` في `lib/` و`android/`. لا Assets نشطة تدرج `test/` ولا Gradle SourceSet ينقل شهادة الاختبار أو مفتاحها إلى التطبيق. القراءة والثقة بالشهادة محصورتان في `test/support/download_server.dart`، والعميل الافتراضي للخدمة `HttpClient.new` بثقة النظام. الشهادة ذات SAN لـ`127.0.0.1` و`localhost` وموضوع `SIRAJ isolated download test`؛ لم تعرض محتويات المفتاح. هذا فصل ساكن واختبار رفض TLS، وليس تحليل APK مبني.

| الأمر | النتيجة الفعلية |
|---|---|
| مراجعة PR #2 قبل الدمج: Pub/Analyze | exit 0؛ Lockfile ثابت وNo issues found |
| إعادة `flutter test --machine` على كود PR #2 المعزول قبل الدمج | exit 0، **130 passed / 0 failed / 0 skipped**؛ سبقتها محاولة توقفت قبل الاختبارات بسبب تنزيل SQLite، انظر §9 |
| `flutter pub get --enforce-lockfile` على الفرع النهائي | exit 0، دون تغيير Lockfile |
| `flutter analyze` على الفرع النهائي | exit 0، No issues found |
| `flutter test --machine` على الفرع النهائي | exit 0، **184 passed / 0 failed / 0 skipped**؛ 15.784 ثانية للأمر |
| `flutter test --no-pub --machine test/b07_download_service_test.dart test/b07_download_space_probe_test.dart` | exit 0، **54 passed / 0 failed / 0 skipped**؛ 5.797 ثانية؛ 49 نقل/سياسة و5 عقد Native Channel |
| `dart format --output=none --set-exit-if-changed` للملفات الثمانية | exit 0؛ 0 ملفات تغيرت |
| `git diff --check` | نجح |
| AndroidManifest | XML صالح محليًا؛ ليس دليلًا على APK أو Manifest Merging |
| `flutter devices --machine` | Linux فقط |
| APK/Native Android/جهاز فعلي/G2/G3 | **NOT RUN**؛ لا ادعاء قبول Android أو إنتاج |

هذا التشغيل الجديد على `cd18c57` بدأ في **06:40:58 UTC** بتاريخ 2026-10-22؛ التحليل ثم الاختبار الكامل عند 06:41:01 ثم الاختبار المركز عند 06:41:16. سجلاته في `/tmp/siraj-download-final-branch-20261022/` وملخصها `summary.json` في بيئة التنفيذ. تحديث التقرير اللاحق توثيقي فقط.

العد من `testDone` غير المخفية؛ تحميل Suites لا يعد اختبارًا. `done.success=true` في التشغيلين، ولا أحداث Error أو محتوى stderr. الـ54 جزء من الـ184 وليست إضافة إليها؛ الاختبارات السابقة الـ130 نجحت دون Regression.

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

راجعت جهتان مستقلتان Standards/Architecture وSpec/Data Safety على Diff مثبتة، ثم التصحيحات اللاحقة. وعند الإنهاء أُعيدت مراجعتان مستقلتان لـPR #2، ثم لشريحة التنزيل عند `651af0d...cd18c57`؛ لم توجد موانع برمجية باقية ضمن نطاق الشريحة وشروط الاستخدام الموثقة. المراجعات ساكنة؛ نتائج Flutter منفصلة عنها. لم تنفذ مراجعة Qodo في هذه المهمة.

**فشل تنزيل حقيقي أثناء التحقق المعزول من PR #2:** الرابط `https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.5.2/libsqlite3.x64.linux.so`، المضيف `github.com`. فشل Dart Native Hook في حل الاسم: `Temporary failure in name resolution`, errno `-3`، **دون الحصول على HTTP Status**؛ لم تبدأ حالات الاختبار في تلك المحاولة، فلا تصنف كاختبارات فاشلة أو متخطاة. الحزمة تستخدم متغيرات Proxy، لكن Dart 3.10 لا يمررها إلى Hooks كما يبدأ دعمه في 3.11، وهو ما يفسر اختلاف المساحة الجديدة عن Cache بيئة العمل المجهز سابقًا.

عولجت بيئة الاختبار بتنزيل المكتبة من الرابط الرسمي بواسطة `curl` عبر وكيل الجلسة: `github.com` أعاد **302** إلى `release-assets.githubusercontent.com` الذي أعاد **200**. طوبق SHA-256 مع المرجع المثبت داخل حزمة sqlite3 3.5.2: `b17729184e5a2818055ecbddd5ed6642521bfe6e56aafa472330e483c0e2e0d2`، وتأكد توقيع ELF قبل وضعها في Cache الـHook المعزول. يعيد الـHook أيضًا فحص Hash للـCache. لم يُعدّل كود الحزمة أو التطبيق أو التبعيات؛ نجحت بعدها 130/0/0 قبل الدمج. سجلات هذه المراجعة في `/tmp/siraj-pr2-final-review-20261022/`.

نجح Pub وGitHub واختبار الفرع النهائي دون فشل تنزيل جديد. لا دليل على حجب المضيفين أعلاه؛ فشل Hook كان قبل HTTP، ونجح الوصول عبر Proxy. رفض TLS وHTTP503/302/416 والانقطاع في اختبارات الخدمة أخطاء مقصودة على `127.0.0.1`. لا نستنتج من Cache Pub السماح بكل المضيفين. فشل تنزيل Qodo الموثق في المرحلة السابقة ليس محاولة تنزيل جديدة هنا.

## 10. القيود والرجوع والتكامل المقبل

- Kotlin/Storage Adapter وManifest لم تبنَ أو تُختبر على Android. تتطلب الأدلة القادمة جهازًا وCatalog/Artifacts حقيقية واختبارات انقطاع ومساحة وملفات كبيرة وAirplane Mode.
- لا Safe ZIP Extraction أو Pack Schema أو Embedding/Index Runtime أو PDF Reader أو Model Load أو Dataset Activation هنا. لا Fake Tutor في المنتج.
- Staging خاص ومنسق Isolate واحد وعدم وجود كتّاب خارجيين شروط استخدام. Crash قد يفقد آخر Checkpoint؛ Restart المحافظ يحفظ السلامة دون وعد بالاستئناف من آخر بايت دائمًا.
- خدمة النقل ليست موصولة بواجهة موارد/Consent نهائية أو Catalog إنتاجي؛ هذا عمل Wiring لاحق عندما يعتمد Catalog، مع إبقاء النقل مستقلًا عن نوع المورد. لا تمنع الموارد الغائبة بناء Validators والسياسات المستقلة.
- Rollback لشريحة التنزيل: Revert لتغييراتها عند اعتمادها؛ لا Migration أو حذف بيانات/موارد Active مطلوب. التغيير الوحيد المنفذ على `main` في الإنهاء هو دمج PR #2 بتفويض المالك؛ شريحة التنزيل بقيت في PR #3 للمراجعة.

**المهمة التالية من خطة B بعد تسليم PR التنزيل:** إكمال قبول B-07 لهذه الشريحة على جهاز Android فعلي: تشغيل قناة `StatFs` وHTTPS، انقطاع الشبكة وResume، Pause/Cancel وإعادة تشغيل العملية، نقص المساحة وملف كبير، والتحقق من بقاء الموارد النشطة سليمة دون READY زائفة. النتيجة المطلوبة أدلة جهاز وLogs ونسخ الموارد وحالات النجاح والفشل؛ يلزم جهاز مصرح ومتاح وروابط/Fixtures معتمدة. هذا يطابق مطلب Android network tests والقبول الفعلي في B-07 من خطة الفريق B المعدلة، ولم يبدأ داخل PR #3 أو عبر كمبيوتر المالك.

بعد ذلك تبقى Validators المتخصصة/الاستخراج الآمن وWiring الموارد وفق عقود A/C المعتمدة؛ لا اختراع Schema أو إعادة بناء المنجز. Atomic Dataset Activation يبقى منفصلًا في B-12. يظل Biology-first G2/G3 أولوية عند توفر LLM/Embedder/Fixture مراجعة وجهاز Android، دون انتظار واجهة كاملة أو خمس Packs إنتاجية، ودون اعتبار Cloud Tests بديلًا عن الجهاز.
