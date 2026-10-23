# SIRAJ P0 — جاهزية دمج الموارد

تاريخ التحقق: 2026-10-22. مرجع القرارات: المواصفة الرسمية P0 v1.0.1 المصححة، DD-01/02/03، FR-12/21/22، §6.4–6.6 و§9–10، وخطة B المعدّلة. هذه الوثيقة تصف عقد الدمج والعمل المتبقي؛ لا تشهد بجاهزية الموارد أو الإنتاج.

## 1. الحالة الفعلية

المستودع المستهدف هو `shehab5552/siraj-codex` فقط. التنفيذ مستقل من قاعدة Codex الحالية؛ لا يتطلب نقل كود المشروع الأصلي. لا توجد في هذه الشريحة موارد إنتاجية أو نتائج Android مثبتة، ولا اختيار معتمد لمحرك LLM أو Query Embedding أو النموذج أو ABI أو عتباته.

| المكوّن | الموجود في الكود | الحالة المتبقية |
|---|---|---|
| سجل الموارد وشاشة حالته | قراءة الحالة، وكتابة الحالات غير الموثقة فقط | لا يفعّل موردًا؛ READY المخزنة تحتاج تحققًا جديدًا |
| عقود التحقق والمرشح | قائمة متطلبات؛ اتساق تصريح خمس مواد وEmbedder واحد | التصريح ليس فحصًا للملفات |
| `ArtifactIntegrityValidator` | قراءة ملف فعلي، SHA-256، حجم اختياري، رفض مسارات وروابط غير آمنة، prefix محدود | يحتاج Catalog موثوقًا وStaging خاصًا بالتطبيق دون كتابات متزامنة |
| `ResourceFormatPreflight` | تعرف محدود على ترويسة GGUF/PDF من البايتات المقروءة نفسها | لا يثبت صحة الملف كاملة أو قابلية تشغيله/قراءته |
| التنزيل الآمن | `DownloadService<T>` و`DownloadStaging` وسياسة `ResourceDownloadValidator`؛ HTTPS وPause/Resume/Retry/Cancel وفحص مساحة وProvenance | منفذ ومختبر بخادم TLS محلي؛ ليس تنزيل موارد إنتاجية أو إثبات Android |
| فك الأرشيف، Validators المتخصصة، النشر والمؤشر | غير منفذة في هذه الشريحة | `UNIMPLEMENTED`؛ لا تُستنتج من نجاح اختبارات النقل |
| LLM وEmbedder وبيانات الأحياء الحقيقية | لا دليل دمج أو جهاز في هذه الشريحة | التصنيف المنفصل أدناه؛ غيابها لا يعطل العمل المستقل |

تصنيفات الاعتماد المطلوبة: `AVAILABLE_VERIFIED`، `AVAILABLE_UNVERIFIED`، `NOT_AVAILABLE`، `INCOMPATIBLE`، `PENDING_APPROVAL`، `PENDING_DEVICE_TEST`. لا نضع موردًا في حالة عدم توافق دون اختباره، ولا نفترض توفر مورد غير مفحوص خارج نطاق المستودع والحزمة.

| الاعتماد الخارجي | التصنيف الحالي | الدليل وحدود الحكم |
|---|---|---|
| Flutter/Dart وحزم المشروع المقفلة | `AVAILABLE_VERIFIED` لبيئة Linux المختبرة | Flutter 3.38.5 / Dart 3.10.4 ونجاح `pub get --enforce-lockfile`؛ ليس إثبات توافق Android |
| Local LLM artifact | `NOT_AVAILABLE` في المدخلات المفحوصة | لا GGUF/وزن إنتاجي ولا Catalog تنزيل له في المستودع؛ الحزمة مرجع هندسي |
| Shared Query Embedding artifact/config | `NOT_AVAILABLE` في المدخلات المفحوصة | لا نموذج أو Tokenizer/Pooling/Normalization إنتاجية مستلمة |
| RAG Packs and Indexes | `NOT_AVAILABLE` في المدخلات المفحوصة | لا خمس Packs/فهارس إنتاجية أو Fixture Biology فعلية؛ تصريحات الاختبار ليست بيانات تعليمية |
| Official PDF Books | `NOT_AVAILABLE` في المدخلات المفحوصة | ملفات PDF الموجودة تحت docs تقارير هندسية، وليست كتب المنهج |
| Android AI runtime resources/adapter | `NOT_AVAILABLE` في المدخلات المفحوصة | لا Adapter LLM/QueryEmbedder أو موارد Runtime/ABI إنتاجية مثبتة؛ هيكل مشروع Android لا يثبت توفرها |
| توافق Runtime/ABI والموارد على جهاز Android | `PENDING_DEVICE_TEST` | `flutter devices --machine` أظهر Linux فقط؛ لم تنفذ G2/G3 أو اختبارات Android |

لا يقرر هذا الجرد ما يوجد على كمبيوتر المالك أو في المستودع الأصلي؛ لم يُفتح أي منهما.

## 2. حدود الموارد والمسؤوليات

- **LLM:** تنزيل مستقل إلى `models/`؛ ملف GGUF منفرد إذا كان Artifact بهذه الصيغة. التفعيل يحتاج Hash وصيغة ودعم Runtime/Device وModel Load حقيقيًا. لا يفترض فحص الترويسة نوع Quantization أو Tokenizer أو Context Length.
- **Dataset:** موافقة واحدة بعد Login، وخمس Subject Packs ونموذج Query Embedding مشترك واحد. Embedder مورد داخلي من Dataset، دون زر تنزيل مستقل. لا يدمج PDF ولا يشتق Embeddings منه.
- **PDF:** اختيار وتنزيل كتاب مستقل إلى `books/`؛ فتح محلي عبر PDF Reader دون اعتماد على LLM/Dataset. يلزم اكتمال التنزيل وقابلية القراءة، وHash عندما يعلنه Catalog.
- **الشبكة:** `DownloadService` وحده ينفذ HTTP(S) في التطبيق. Validators وAuth وSQLite وChat وQuiz وSourceMapper وQueryEmbedder لا ترسل محتوى الطالب للخارج. جلب حزم التطوير ليس دليلًا على سلوك التطبيق دون شبكة.
- **الطبقات:** UI تعرض تقدمًا وأخطاء محددة؛ خدمات الموارد تنسق التنزيل والتحقق؛ Validators تفحص؛ Repositories تحفظ Metadata فقط؛ Runtime/Reader يثبتان القابلية الفعلية. لا يُربط نجاح Header أو قائمة أسماء فحوص مباشرة بكتابة READY.

## 3. المدخلات المطلوبة عند توفر الموارد

| المورد/الجهة | البيانات المطلوبة | ما لا يجوز استنتاجه |
|---|---|---|
| Catalog موثوق | ID، Kind، رابط HTTPS، Revision، SHA-256 المعلن، الحجم إن توفر، Destination Key محلي | لا يُحسب Hash المتوقع من الملف المنزل نفسه؛ لا تُخترع روابط أو معرفات إنتاج |
| A: LLM/Runtime | Artifact وHash/Revision، ترخيص، صيغة، Runtime وABI، ModelConfig، Tokenizer/Prompt Profile، حدود مقاسة | لا اختيار إنتاجي أو أرقام أداء افتراضية |
| C: Subject Packs | المواد الخمس المعتمدة، Manifest/Schema، Chunks/Metadata/References، Index Type/Version، Hashes داخلية وخارجية | معرفات المواد في الاختبارات ليست Catalog إنتاجيًا |
| A+C: Shared Embedder | Model ID وArtifact Revision/Hash، Tokenizer، Pooling، Normalization، Dimension، توافق كل Index | تطابق الأبعاد وحده لا يثبت توافق المتجهات |
| PDF Catalog/Reader | Book ID، رابط، حجم/Hash إن توفرا، ملف صالح، Adapter يفتح/يحلل الملف | `%PDF-` وحدها لا تثبت قابلية القراءة |
| G2/G3 | Biology fixture مراجعة، Runtime وEmbedder فعليان، جهاز Android مناسب وأدلة القياس | لا تُستبدل هذه الأدلة باختبارات Linux أو إجابات Tutor مصطنعة |

تعريفات الحقول أعلاه مقتبسة من العقود المعتمدة وليست Schema إنتاجية جديدة. تبقى الحقول والقيم غير المستلمة صريحةً كمدخلات مطلوبة؛ لا توجد روابط تنزيل تجريبية في إعدادات المنتج.

### ملفات Configuration وخطوة الإضافة لكل مورد

| المورد | Configuration المطلوبة عند التسليم | التخزين/التفعيل | ما يبقى BLOCKED وما يمكن بناؤه الآن |
|---|---|---|---|
| Local LLM | Catalog entry و`ModelConfig` من §6.6: model/version/artifact/runtime/context/prompt/generation، وملفات Tokenizer التي يحددها Runtime المختار | `models/`؛ Hash ثم Validator/Runtime/Device وLoad قبل READY | تشغيل وتقييم النموذج BLOCKED بغيابه؛ يمكن بناء التنزيل والعقد وTyped Unavailable واختبارات الفشل |
| Shared Query Embedding | `SharedEmbeddingConfig`: model ID وRevision ومسار Artifact وTokenizer/Pooling/Normalization/Dimension، وملفات preprocessing المطابقة للفهارس | ضمن مرشح Dataset ثم الإصدار المثبت؛ لا تفعيل منفرد | Correctness/توافق Android BLOCKED؛ يمكن بناء فحوص تطابق التصريحات وملكية المرشح |
| RAG Packs/Indexes | Release Catalog للخمس وEmbedder الواحد، Manifest/Checksums، Schema وIndex Type/Version وSource Metadata من C | Staging ثم immutable Release والمؤشر الذري بعد كل الفحوص | البحث الحقيقي وSchema الإنتاجية النهائية BLOCKED بالبيانات؛ يمكن بناء الاستخراج الآمن والمعاملات واختبارات رفض المرشح |
| Official PDF Books | Book Catalog بمراجع الكتب المعتمدة وروابطها وحجم/Hash إن توفرا؛ Configuration للـReader Adapter المختار | `books/`؛ اكتمال النقل وReader Open/Parse وHash إن أعلن | قبول الكتب الرسمية BLOCKED بغيابها؛ يمكن بناء التنزيل وواجهة Reader واختبارات الأخطاء بملفات اصطناعية معزولة |
| Android Runtime Resources | حزم/مكتبات المحرك المختار وABI وModel/Embedding Config متوافقة، وتعليمات بنائه/ترخيصه وقياسات الجهاز | Adapter محلي، تحميل من المسار/Revision المثبت؛ لا استدعاء شبكة للتوليد | تحميل Runtime وG2/G3 وRAM/Latency BLOCKED بالموارد والجهاز؛ يمكن بناء Interface/Cancel/Lifecycle واختبارات المضاعفات المعزولة |

أسماء الملفات الفيزيائية وSchema النهائية غير المسلمة لا تُخترع هنا. عند وصول المورد: تثبيت مصدره/Revision وConfiguration، فحص Hash/الحجم، إمرار Validators المناسبة، ربط Adapter، تشغيل الاختبارات المحددة في الأقسام التالية، ثم اعتماد التفعيل الخاص بنوعه. تضاف Configuration إلى مالكها الحالي في المعمارية؛ لا تنشأ طبقة عامة تخلط الموارد الثلاثة.

## 4. عقد سلامة البايتات المنفذ الآن

`ArtifactIntegrityValidator.validate` يستقبل `stagingRoot` و`relativePath` و`kind` و`expectedSizeBytes?` و`expectedSha256?`. المصدر الموثوق يوفر التوقعات. Hash إلزامي لـLLM وRAG_PACK وRAG_EMBEDDING، واختياري لـPDF فقط إذا لم يعلنه Catalog. Hash معطوب أو حجم سالب ينتج خطأ توقعات، ولا يُعامل كمرجع غائب.

القارئ يستخدم دفعات 64 KiB وSHA-256 streaming من التبعية الحالية `cryptography`، ويحتفظ بأول 24 بايت فقط. يفحص الحجم المعلن قبل القراءة، ويقارن الحجم ومعلومات الملف بعد القراءة. النتيجة المحددة هي `ArtifactIntegrityFailure` برمز السبب أو `ArtifactIntegrityMatch` غير قابلة لتعديل بياناتها. `sha256Matched=false` يعني أن PDF لم يملك مرجع Hash؛ البصمة المحسوبة وحدها ليست إثبات أصالة.

قيود المسار: Relative Path واضح بفاصل `/`، دون أجزاء فارغة أو `.` أو `..` أو `\` أو `:` أو NUL. تُرفض الروابط الرمزية في الجذر المقدم ومكونات المسار والملف. لا تعديل أو حذف أو إعادة تسمية لملفات الموارد، ولا SQLite أو شبكة داخل الفاحص.

**شرط استخدام أمني:** يجب أن يكون Staging خاصًا بالتطبيق، وأن يوقف المنسق الكتابة/Resume/Replacement أثناء الفحص والنشر. فحوص المسار وStat في Dart لا توفر `openat/O_NOFOLLOW` أو قفلًا على مستوى النظام؛ رصد التغييرات العادية ليس ضمانًا ضد كاتب خصم يغير المسارات بين الفحوص. لا تستخدم النتائج كتصريح لفتح مسار قابل للتعديل لاحقًا؛ النشر/الاستخدام المستقبليان يحتاجان ملكية وHandle مناسبين وإعادة التحقق عند Startup.

## 5. حدود فحص الصيغة الحالي

المدخل `ArtifactIntegrityMatch`، وprefix مأخوذ من المرور نفسه الذي حُسبت بصمته؛ لا يفتح Preflight الملف مرة ثانية. GGUF: يتعرف على magic ونسختي الترويسة 2/3 بترتيب Little Endian وطول الرأس الثابت الأدنى 24 بايت. لا يحلل Counts/Metadata/Tensors أو يثبت صلاحيتها؛ Unsupported Version يحتاج Adapter مناسبًا، وليس حكمًا باعتماد Runtime إنتاجي. مرجع البنية العام: [GGUF specification](https://github.com/ggml-org/ggml/blob/master/docs/gguf.md).

PDF: يتعرف على `%PDF-1.0` إلى `1.7` و`2.0` متبوعة بـCR/LF في بداية الملف. هذه عينة فحص محدودة؛ لا يقرأ Pages/Xref/Trailer ولا يثبت `pdfReadable`. تظل أخطاء/قيود التعرف منفصلة عن فحص Reader الكامل. RAG Pack وEmbedder يعيدان `specializedValidatorRequired` دون افتراض صيغة لهما.

`remainingChecks` يزيل فقط `sha256Matched` عند مطابقته لمرجع معلن؛ يحتفظ بمتطلبات اكتمال النقل وصلاحية الصيغة وRuntime/Device/Load أو PDF Readability وغيرها. **`recognizedHeader` ليست READY أو ACTIVE أو RAG_READY، ولا نجاحًا لفحص الصيغة المتخصص.**

## 6. Dataset: ما يلزم قبل أي تفعيل

1. تنزيل الملفات إلى `rag/staging/<candidate_id>/` غير قابل للبحث، بموافقة Dataset واحدة. لا مساس بمجموعة Active أثناء إعداد البديل.
2. SHA-256 خارجي للأرشيف، ثم استخراج آمن يمنع Absolute Paths وTraversal والروابط والملفات غير المكتملة. هذا المستخرج غير منفذ هنا.
3. فحص Manifest وChecksums الداخلية، بما فيها Manifest باستثناء ملف Checksums ذاته، ورفض UTF-8 غير الصالح كخطأ محدد دون نجاح كاذب. فحص Schema وChunk References وIndex Type/Version.
4. تطابق Revision والخمس وEmbedder واحد وTokenizer/Pooling/Normalization/Dimension واختبار Query حقيقي على Android.
5. ترقية Directory مكتملة على FileSystem نفسه إلى `rag/releases/<revision>/` غير قابلة للتعديل، ثم تبديل مؤشر SQLite ذري واحد في جدول `installed_resource` القائم. لا إضافة جدول سادس؛ صف المؤشر المحجوز وفق §7 و§10.3 هو `RAG_PACK / __ACTIVE_DATASET__`.
6. الحفاظ على المؤشر والملفات القديمة عند فشل التحقق أو النقل أو Transaction. Promotion بلا Commit يبقى Orphan غير نشط. كل قارئ يستخدم `RevisionPinnedHandle`؛ لا تنظيف لإصدار له قارئ حي، ولا مزج Embedder جديد مع Index قديم.
7. Startup يعيد التحقق من المؤشر وملفات الإصدار قبل الجاهزية. المصدر القديم المفقود ينتج `SOURCE_UNAVAILABLE` دون استبداله بمقطع من Revision أخرى.

هذه سلسلة مطلوبة للمراحل اللاحقة، وليست كودًا مُنجزًا بواسطة هذين الفاحصين.

## 7. التنزيل الآمن والتعافي — B-07/INDEPENDENT-DOWNLOAD-01

`DownloadService<T>` ينقل البايتات فقط، ويستدعي `StagedDownloadValidator<T>` بعد إغلاق الكاتب وهو ما يزال يملك Lease. `ResourceDownloadValidator` يربط فاحصي SHA/الحجم والترويسة السابقين؛ لا تُضاف خدمة تنزيل بديلة لكل نوع مورد. `DownloadSpec` يأتي من Catalog معتمد: ID وRevision وKind وHTTPS URL وDestination Key وحجم/Hash إن توفرا، وحد نقل `maxBytes` صريح من المستدعي. لا تتضمن هذه الشريحة روابط أو Manifest إنتاجية أو اختيار نموذج.

الواجهة: `start(spec)` يعطي Handle وFuture Result؛ `progress(handle)` يعرض Snapshot؛ `pause` و`cancel` تنتظران إغلاق الكاتب/الفاحص وتسوية السجل؛ `resumeOrRestart` و`retry` يعيدان المحاولة صراحةً. Retry يدوي محدود بالمحاولة المطلوبة، وليس حلقة خلفية غير محدودة. طلب Resume أثناء نقل أو تسوية Control قائم يعيد Busy. Cancel يهيمن على Pause، وتكرار Cancel ينضم إلى Cleanup نفسها. Cancel بعد نتيجة Downloaded لا يحذف المرشح المكتمل.

التخزين محصور في `appSupportDirectory/downloads-staging-v1/<destinationKey>/`: `payload.part` و`provenance.json` وملف metadata مؤقت وWriter Lock. المفتاح ASCII محدود دون مسارات؛ الروابط والأسماء غير المملوكة ترفض، ولا حذف Recursive أو وصول إلى `models/` أو `books/` أو `rag/releases/`. المرشح المكتمل لا يستبدل حتى لو تغيرت هوية الطلب. مصدر `appSupportDirectory` يجب أن يكون مسار التطبيق الخاص، لا مسارًا يختاره الطالب. يبقى منسق Dataset مسؤولًا عن الموافقة الواحدة؛ هذه الخدمة العامة لا تبدأ تنزيلًا تلقائيًا.

### الاستئناف وProvenance

- هوية السجل SHA-256 لتصريح الطلب كاملًا، بما فيه URL/Revision/Kind/Hash/الحجم/الحد والمفتاح؛ لا تحفظ URL أو Tokens خامًا في السجل أو الأخطاء. السجل يحوي كذلك عدد بايتات الجزء وبصمته وTotal وETag وحالة اكتمال النقل.
- السجل حدّه 16 KiB، يقرأ كـBytes محدودة ويُفك UTF-8 بصرامة ثم JSON Schema صغيرة. غياب/فساد/كبر/عدم تطابق السجل أو بايتات الجزء يمنع Resume ويعيد البدء من صفر داخل Staging المملوك. Marker اكتمال موجود يُحفظ تحفظيًا بدل حذفه أو استبداله.
- Resume يتطلب **ETag قويًا** وHash/حجم الجزء مطابقين. ETag ضعيف أو غائب، ولو وُجد Last-Modified، يؤدي إلى Restart؛ لا يستخدم Last-Modified وحده كضمان هوية. الثقة تعتمد على Catalog وHTTPS وملكية التخزين الخاص؛ السجل ليس توقيعًا مشفرًا ضد خصم يستطيع الكتابة في بيانات التطبيق.
- طلب Range يرسل `If-Range`. `206` يحتاج Start مطابقًا وEnd/Total وContent-Length متسقة، وBody لا يتجاوز End. تغير ETag أو `416` يؤدي إلى GET كامل جديد واحد كحد أقصى. `200` المتجاهل Range يستخدم Body الجديدة من الصفر. النطاق المعطوب لا يدمج بايتات الرد بالجزء القديم.
- Auto Decompression معطل و`Accept-Encoding: identity`؛ الرد المضغوط يرفض. Redirects لا تتبع تلقائيًا، فلا عبور إلى HTTP أو Host/هوية مختلفين. TLS العادي مفعل دون `badCertificateCallback`؛ شهادة الاختبار موثوقة داخل Test Client فقط.
- قبل أي Append/Truncate يبطل Checkpoint السابق. بعد إغلاق/Flush البايتات تُحسب بصمة الجزء ويحفظ Metadata بـFlush ثم Rename ذري لملف السجل. الانقطاع المعالج وPause يسمحان باستئناف موثق؛ Crash أثناء النقل قبل Checkpoint صالح يؤدي إلى Restart محافظ، لا إلى الوثوق ببايتات غير مثبتة.

### المساحة والتزامن والنتيجة

`DownloadSpaceProbe` فصل لنظام التشغيل؛ `AndroidDownloadSpaceProbe` يستعمل MethodChannel و`StatFs.availableBytes` الحقيقي ضمن شجرة بيانات التطبيق الخاصة. المساحة تفحص قبل النقل ومع الحجم المعلن وقبل كل دفعة، مع حجز 32 KiB لسجل Metadata واستبداله. Unknown/خطأ الفحص = Storage Unavailable، لا مساحة وهمية. أخطاء ENOSPC/EDQUOT الفعلية تصنف Insufficient Storage؛ بقية I/O تبقى أخطاء محددة. حد `maxBytes` يحمي أيضًا Stream مجهول الحجم. إضافة INTERNET إلى Manifest الرئيسي تتيح النقل في Build التطبيق، دون تغيير TLS أو Cleartext Policy.

Lease داخل منسق التطبيق الواحد يعزل الوجهة، وFile Lock استشاري يظل حتى انتهاء الفحص وCheckpoint/Control. الاستخدام من Isolate واحد للمنسق شرط صريح؛ ليست هذه شهادة بمنسق خلفية متعدد Isolates أو قفل مقاوم لكاتب خصم. شرط App-private/عدم وجود كتّاب خارجيين وحدود Dart للمسار الموضحة في §4 تظل قائمة. تسوية Cancel بعد Pause/الفشل تعيد أخذ Lease قبل Cleanup، ولا تمس موردًا منشورًا.

الحالة النهائية `downloaded` تعني أن النقل وسياسة الفحص الأولي اجتازا فقط. Evidence تحتوي متطلبات Runtime/Model Load/PDF Readability/Archive وغيرها المتبقية. لا تكتب الخدمة SQLite أو READY/ACTIVE/RAG_READY، ولا تنفذ Atomic Dataset Activation؛ يبقى ذلك مسارًا منفصلًا وفق تكليف B-12. Adapter Android وقبول ملفات إنتاجية واختبارات G2/G3 لم تُثبت على جهاز بهذه الاختبارات السحابية.

كل فشل يسجل Host وHTTP Status والسبب القابل للإثبات، دون Tokens أو بيانات الطالب. يظل المورد القديم صالحًا إن كان البديل قد فشل. الموارد المشتركة تبقى عند حذف الحساب؛ لا تعود محادثات الحساب المحذوف أو إعداداته لحساب جديد.

## 8. خطة الدمج والقبول

| المرحلة | يمكن بناؤه دون المورد الحقيقي | الدليل الإضافي عند توفره |
|---|---|---|
| B-07 التنزيل | منفذ: State Machine واختبارات HTTPS محلية وهوية/Range/Restart/انقطاع/مساحة وفشل تحقق وControl races | Catalog/HTTPS Host فعليان؛ ملف كبير وStorage Adapter وسلوك الشبكة على Android |
| B-07 المتخصص | Safe Extraction وSchema/Checksum/Invalid UTF-8 وفشل المرشح | Schema المعتمدة وPacks/Index/Embedder حقيقية؛ لا اختراع حقول إنتاج |
| B-07 النشر | Transactions/Crash Recovery/Orphan وPinned Handles باختبارات محلية | تحقق المسار وFilesystem وStartup والتزامن على Android |
| A+B+C / G2 مبكر | Interfaces وTyped Unavailable وDebug Fixture Wiring | LLM/Embedder حقيقيان وBiology fixture مراجعة وقياسات Vector/Retrieval/RAM على Android |
| G3 مبكر | سريان السؤال/الإلغاء/المصادر واختبارات Guards | سؤال وإجابة RAG حقيقيان في Airplane Mode، ومصادر Revision صحيحة |
| Product Mode | تدفقات الفشل واختبارات الخمس/Embedder الواحد دون تفعيل مصطنع | الخمس مكتملة ومراجَعة، توافق Android، ثم بوابات القبول المعتمدة |

لا يؤخر G2/G3 حتى اكتمال UI أو موارد المواد الخمس. Fixture في Test/Debug فقط، عبر Handle مستقل لا يكتب مؤشر الإنتاج أو يعرض `RAG_READY`. fake Tutor للاختبارات المعزولة فقط. Cloud tests تثبت السلوك المختبر محليًا؛ لا تثبت Android أو جودة المحتوى أو P0 Production Acceptance.

## 9. الرجوع والاختبارات

هذه الشريحة إضافية ولا تغير DB أو البيانات أو UI؛ الرجوع يكون Revert للـPR بعد اعتماده، دون Migration أو حذف موارد. تتضمن الاختبارات ملفات مؤقتة فعلية، مرجع SHA-256 معلومًا، تلفًا بنفس الحجم، حجمًا مخالفًا، مسارات وروابط غير آمنة، ملفًا متعدد الدفعات وترويسات سليمة/مبتورة/مجهولة، مع بقاء فحوص الجاهزية المطلوبة. تقرير المرحلة المجاور يسجل الأوامر والنتائج الفعلية والقيود.
