# SIRAJ P0 — Resource Intake & Independent Download 01

تاريخ الفحص: **2026-11-05 UTC / 2026-11-06 عدن**. النطاق: استلام STAGING وتدقيقه، وإعادة التحقق من B-07 القائمة. المرجع التنفيذي: [طلب المالك الكامل](../spec/RESOURCE_INTAKE_USER_REQUEST_2026-11-06_AR.md)، وعقود P0 المشار إليها في [وثيقة الجاهزية](../architecture/RESOURCE_INTEGRATION_READINESS.md). لا يعني هذا التقرير اعتماد الموارد أو إتمام التطبيق.

النتيجة: **سلامة البايتات والتغليف PASS؛ الدمج المباشر لـAAR بمترجم Kotlin الحالي FAIL؛ تشغيل النموذجين PENDING_VERIFICATION؛ G2/G3 NOT RUN.** لا READY/ACTIVE/RAG_READY أو تشغيل Runtime أو تغيير سياسة علمية.

## 1. Git Baseline

- المستودع الوحيد: `shehab5552/siraj-codex`، الفرع الافتراضي `main`.
- Fetch والتحقق من GitHub: `main = 651af0d62d05761c80d9a8cbc9d1f51b836929eb`، مطابق للقاعدة المطلوبة.
- الفرع المطلوب موجود أصلًا: `codex/b07-independent-download-01`؛ HEAD قبل هذا العمل `27ff8e5265e03092ccf84fedeae39d5bb4d008a7`، وmerge-base مطابق للقاعدة أعلاه. PR #3 **OPEN**، وGitHub أظهر `CLEAN` قبل تحديثه.
- أعيد استخدام الفرع وPR #3 بدل استبدال الفرع أو نسخ DownloadService أو إنشاء PR مكرر. تغييرات التنزيل الأصلية موجودة في `b2e96d1` و`256399e` ثم تقارير `cd18c57` و`27ff8e5`؛ ليست إعادة تنفيذ في هذه الجولة.
- فرق PR الأصلي مقابل main يحتوي16 ملفًا خاصًا بالتنزيل؛ الإضافات الحالية أدوات تدقيق واختبارات وتوثيق وCI فقط. لا تغييرات Auth/Chat/Quiz/Schema/Gradle أو نقل من فرع UI/PR #12. آخر SHA قابل للتحقق في رأس PR؛ لا يوضع SHA ذاتي داخل الملف الذي ينشئه الالتزام.
- لم يُدمج أي PR، ولم يُفتح `siraj-p0` أو جهاز المالك.

## 2. Artifact Inventory

المصدر الرسمي: [Release STAGING](https://github.com/shehab5552/siraj-codex/releases/tag/siraj-ai-resources-staging-v1)، release ID `435805343`، منشور `2026-11-05T22:57:54Z`، `prerelease=true` و`draft=false`. نُزّلت الملفات الفعلية خارج ملفات التطبيق إلى مجلد فحص خاص. لا تدخل البيناريات Git أو Assets أو Dependencies.

| Artifact | الحجم الفعلي/المعتمد بالبايت | النتيجة |
|---|---:|---|
| Biology.zip | 873028 | PASS |
| embeddinggemma-2-text-270m.litertlm | 164626432 | PASS |
| litertlm-android-0.19.0.aar | 21197249 | PASS |
| Qwen3-0.6B.litertlm | 613722264 | PASS |
| SIRAJ_AI_RESOURCES_MANIFEST.json | 2494 | PASS |

استُخدم GitHub CLI/API الرسمي والحساب المتصل المصرح له، دون طباعة بيانات المصادقة أو signed redirect URLs. تمت التنزيلات الخمسة بنجاح؛ لا فشل HTTP/حظر نطاق لتنزيل هذه الموارد. نطاقا API/الأصول المستخدمان `api.github.com` و`release-assets.githubusercontent.com`؛ لا نزعم تسجيل كل HTTP hop إذ CLI اتبعها داخليًا. جلب مرجع مساعد غير موجود `schema/core/litertlm_header.cc` من upstream أعاد **HTTP404** من **api.github.com** وCLI exit1؛ أُعيد التحقق من HTTP status بالـAPI. السبب: المسار غير موجود عند commit المرجع المثبت؛ استُخدم FBS الفعلي وbuilder بدل تخمينه. ليس ذلك حظر شبكة أو فشل Artifact من الملفات الخمسة.

## 3. SHA-256 Verification

الحساب من الملفات الفعلية بقراءة متدفقة ومقارنة الحجم والبصمة بقيم المالك المستقلة، ثم بيانات Release API وManifest؛ لم تُشتق البصمات المتوقعة من الملف المنزل. [الأدلة القابلة للقراءة](../qa/b07-resource-intake/static-intake.json).

| الملف | SHA-256 الفعلي المطابق |
|---|---|
| Biology.zip | `8111e6cedd0a045e3368b02905ac2a15776e850ec50ea54794c32e3bdf6c015c` |
| EmbeddingGemma | `2d079ee2f6f066b1f368e8d7c819f55214eaef1d0513b312321901f30ab286fb` |
| AAR | `e5c7a86048225efba8ab6d35fcd91f5870c86c65ca2538c07c3c1f63d02efa2b` |
| Qwen3 | `c5f39b4191926786c3e6668b62af4d6eb15248dfc7a5348252a9b406f33f2108` |
| Manifest | `1a1fdf3e4cde89feb3f089583ba54efcf8dbc9f188967d63cbecb20d582eb4f4` |

PASS لكل ملف يعني تطابق البايتات، ولا يثبت الترخيص أو التنفيذ أو التوافق. كما استدعى مسبار Dart الفاحص الموجود على ملفات Biology/Embedding/Qwen الثلاثة: كلها byte-integrity PASS؛ [النتائج](../qa/b07-resource-intake/existing-dart-validators.json) تُبقي الفحوص المتخصصة المطلوبة.

## 4. Manifest Validation

**PASS:** UTF-8 صارم وJSON، منع مفاتيح مكررة وNaN/Infinity/overflow، حد64KiB، schema1.0.0 وPackage SIRAJ_AI_RESOURCES و`STAGING_NOT_PRODUCTION_APPROVED`، أربع Resources مطابقة للأسماء والأدوار والأحجام والبصمات؛ Manifest نفسه ليس ضمن قائمته الذاتية. مقارنة Release تتم على الملفات الخمسة.

RuntimeRequirement يصرّح AAR0.19.0 لـAndroid وLLM/EMBEDDING، و`AlternativeRuntimeAllowed=false` و`CompatibilityStatus=NOT_YET_VERIFIED`. BiologyDataset يصرّح وحدتي Unit_01/02 و`REQUIRES_COMPATIBILITY_VALIDATION`.

**غير موفر:** URLs داخل Manifest، Resource IDs وrevisions الإنتاجية، Catalog binding، تراخيص النموذجين، عقود tokenizer/pooling/normalization مكتملة. لا تُملأ من الامتداد/الاسم أو افتراضات المحرك. روابط Release هي مصدر STAGING للتدقيق، وليست Catalog إنتاجيًا مضافًا للتطبيق.

## 5. Biology Archive Audit

**PASS لتغليف الملفات والربط الثابت فقط.** الفحص recursive للـZIP، دون استخراج إلى التطبيق:11 حاوية تشمل الخارجية والعشر الداخلية،68 ملفًا/71 entry مع الدلائل، expanded bytes2254248 محسوبة مع نسخ الحاويات المتداخلة. اجتازت CRC والأسماء والروابط وعدم التكرار وتعارض file/directory وحدود الحجم/العمق. طابقت **48 checksum في10 قوائم**، و**14 قيد Manifest** في حزمتي Integration. [قائمة كل الملفات وأحجامها وبصماتها](../qa/b07-resource-intake/biology-file-inventory.json).

| البند | Unit01 | Unit02 |
|---|---|---|
| content/map/vector rows المتطابقة | 67 | 63 |
| dimensions | 768 | 768 |
| vectors.f32le bytes | 205824 | 193536 |
| التخزين | float32 little-endian row-major | نفسه |
| index | Exact Flat raw vectors؛ لا ملف ANN منفصل | نفسه |
| فحص القيم | كلها finite وغير صفرية | كلها finite وغير صفرية |
| L2 norms المرصودة | 0.999999428–1.000000839 | 0.999999522–1.000000514 |
| pack/subject/source/lesson IDs | null في67 صفًا لكل حقل | null في63 صفًا لكل حقل |

الـcontent وvector_map لهما IDs فريدة، ترتيب الصفوف مطابق، وبصماتهما وبصمة المتجهات مرتبطة بالـindex؛ بصمة Embedding المشار إليها تطابق النموذج الحقيقي المنزل. JSON/JSONL الداخلي كله يُقرأ قراءة صارمة. لا تنسخ الأداة النص التعليمي إلى Git.

**BLOCKED للإنتاج:** Unit01 يصرح dataset_revision=null وidentity binding محجوبًا؛ Unit02 لديه dataset_id خاص لكنه ليس ربط Catalog معتمدًا ولا dataset_revision موثقة. العقود الحالية تحتاج SourceRegister/pack/subject/source/lesson/revision وفاحص pack/index متخصصًا؛ لم نخترع mapping أو نغير SQLite. عقد Production Candidate لخمس مواد وEmbedder مشترك يبقى كما هو؛ وحدتان للأحياء لا تحققانه.

السلاسل content/embeddings/flat/policy تطابق أرشيفات موجودة؛ Golden وvalidation السابقة، وlive فيUnit02، غير مرفقة: **NOT RUN** للتحقق من بايتاتها. تقارير PC داخل الحزمة ادعاءات مصدر محفوظة، وليست نتائج Android أعدنا تشغيلها.

**السياسات غير المحسومة:** وصف normalization مختلف بين الوحدتين رغم norms قريبة من1؛ query prefix المصرح `task: search result | query: ` وdocument prefix `title: none | text: `. لا نستنتج منهما pooling أو parity. tie-break مؤقت مختلف الاتجاه؛ وصف filter فيUnit02 يقول NOT_DECIDED_STEP05 بينما Manifest Integration يذكر استبعاد question_block. لا نختار أحدها تلقائيًا، ولا نحذف question chunks أو ننشئ Quiz/تقييمًا علميًا. PDF مستقل وغير مرفق؛ وجود source_pdf_sha لا يثبت فحص الكتاب نفسه.

## 6. LiteRT-LM AAR Inspection

**PASS للفحص الثابت:**8 entries خارجية، classes.jar وR.txt وLICENSE وTHIRD_PARTY_NOTICE، manifest XML وnative libs. الفحص المتداخل لـclasses.jar أيضًا اجتاز CRC؛ إجمالي107 ملفات و52483984 expanded bytes يشمل محتواه. Manifest package **com.google.ai.edge.litertlm** وminSDK **24**. Native ELF64 حقيقي لـ**arm64-v8a وx86_64**، SONAME liblitertlm_jni.so. لا ABI32 مرفق. لا consumer-proguard أو aar-metadata.properties أو POM ضمن الملف؛ لا نخترع قواعد shrinker أو إصدارات dependencies.

واجهات فعلية من javap، مع التواقيع في [دليل AAR](../qa/b07-resource-intake/aar-inspection.txt):

- Engine(EngineConfig)، initialize/isInitialized، createConversation/createSession، close.
- Conversation.sendMessage(String) وsendMessageAsync(String,MessageCallback)، cancelProcess وclose.
- EngineConfig.modelPath وbackend وmaxNumTokens/cacheDir؛ ConversationConfig وSamplerConfig موجودان فعلًا.
- EmbeddingEngine(EmbeddingEngineConfig)، initialize، computeEmbedding(List<InputData>,EmbeddingOptions)، async callback/suspend، close؛ EmbeddingResponse.getEmbedding() يعيد float[].
- EmbeddingOptions.normalize/insertSpecialTokens/outputSize nullable؛ null يعني إعدادات المحرك، ولا يثبت سياسة parity. ModelInfo يوفر minRuntimeVersion/maxContextTokens/supportedBackends، لكن تنفيذه يحتاج JNI ولم يُشغّل على Linux.

المطلوب لاحقًا Native Adapter خلف ports القائمة: ملكية Engine/EmbeddingEngine والمسار الخاص، background execution، إلغاء/lifecycle وtyped errors، لا Business Logic في Widgets ولا إعادة تنزيل عبر Adapter. هذه نقطة تصميم تكامل مستقبلي، لم ينفذ أو يختبر Runtime في المهمة.

**FAIL مثبت لمسار Kotlin المباشر الحالي:** classes تحمل Java major65 (Java21) وKotlin metadata **2.4.0**، بينما المشروع Kotlin **2.2.20**، JVM target17، AGP8.11.1. شُغّل compiler2.2.20 الرسمي على JDK21، target17 وclasses.jar وstdlib، مع مصدر يقرأ EngineConfig.modelPath؛ exit1:

```text
The binary version of its metadata is 2.4.0, expected version is 2.2.0.
compiler version 2.2.0 can read versions up to 2.3.0.
```

لم يستخدم `-Xskip-metadata-version-check` أو تغيير Gradle/Kotlin/JVM. هذا يثبت فشل مسار الاستهلاك المباشر بمترجمنا؛ ليس حكمًا بأن النموذج لا يعمل على أي Android أو أن Java wrapper بديل مثبت. D8/R8 وJava21 bytecode وshrink/release تبقى **NOT RUN** مع AAR. minSDK24 يتفق عدديًا مع Flutter3.38.5 minSdk24، ولا يحل باقي التوافق.

jdeps يكشف مراجع Gson وKotlin stdlib/reflect وkotlinx.coroutines، لكن AAR المفرد بلا POM لا يثبت إصداراتها أو graph قابلة للحل. Native NEEDED: libandroid/libz/libGLESv2/libEGL/libm/liblog/libdl/libGLESv3/libc.so؛ وجودها في dynamic table لا يثبت تحميلها على جهاز. LICENSE يبدأ Apache2 وnotices موجودة؛ مراجعة الامتثال وتراخيص الأوزان **BLOCKED** قبل اعتماد الإنتاج.

## 7. Qwen3 Compatibility Findings

سلامة الحجم/Hash **PASS**. فحص header المحدود ضد schema upstream مثبتة في LiteRT-LM v0.19.0، commit `83ce6067f2e2a3fb697556928f93936693ded971`: magic LITERTLM، container1.7.0، header_end552، أقسام LlmMetadataProto وHF_Tokenizer_Zlib وTFLiteModel (tf_lite_prefill_decode)، offsets داخل حدود الملف ومحاذاة16KiB.

Tokenizer HF JSON مضغوط ببادئة8-byte uncompressed length وفق builder الفعلي؛ فُك بحد16MiB. المرصود BPE وvocab151643، JSONversion1.0، padding/truncation=null. هذا لا يثبت engine tokenization أو stop-token correctness على الهاتف.

Proto المضمن يصرح max_num_tokens4096 وJinja template، sampler type2/TOP_P وk20 وp≈0.95 وtemperature≈0.6، دون seed/min_runtime_version صريحين. هذه **قيم مرصودة داخل Artifact، وليست إعدادات علمية معتمدة أو overrides أضيفت للتطبيق**. لم نشغل Prompt/Generation أو نختبر التفكير/التوقف/الذاكرة/السياق على Android.

الفاحص الموجود ResourceFormatPreflight يدعم GGUFv2/v3 فقط، لذلك النتيجة الفعلية `unrecognizedHeader`؛ لم يضف استثناء اعتماد لـLiteRT-LM. **BLOCKED** لإدخاله في ذلك المسار قبل Format/Runtime Adapter معتمد؛ **PENDING_VERIFICATION** لتوافق LiteRT-LM0.19.0 الفعلي، و**PENDING DEVICE TEST** لـarm64. [الملاحظات الثابتة](../qa/b07-resource-intake/model-container-observations.json).

## 8. EmbeddingGemma Compatibility Findings

الحجم/Hash **PASS**؛ container1.7.0، header_end880، أقسام EmbeddingMetadataProto وSP_Tokenizer وTFLite text_encoder/embedder وexternal weights؛ الحدود والمحاذاة سليمة في الفحص الثابت. SentencePiece section4689013 bytes، البصمة في ملف الملاحظات؛ لم ندّع نوع algorithm أو token outputs دون تنفيذ decoder معتمد.

Proto max_input_length **1024**؛ min_input_length/min_runtime_version غير مصرحين في الحقل المفحوص. **Pooling وأبعاد output من engine نفسه غير مثبتة**؛ 768 مثبتة لمتجهات Dataset فقط. واجهة EmbeddingResponse.float[] موجودة، لكن Query Embedding لم يُنفذ. Normalization nullable/options، near-unit norms وادعاء Windows CPU ليست إثبات parity أو ترخيص اختيار default.

النتيجة: **PENDING_VERIFICATION** لدعم runtime والـtokenizer/pooling/normalization الفعلية، و**PENDING DEVICE TEST** لاستخراج query vector768 ومقارنة prefixes والنتائج الرقمية/Retrieval مع Windows. لا Re-embedding تلقائيًا ولا تغيير بايتات المتجهات لحل فجوة.

## 9. DownloadService Implementation

**أعيد استخدام التنفيذ الموجود، دون خدمة بديلة أو إعادة كتابة.** العقد عام لنقل البيانات؛ السياسات المتخصصة LLM/RAG/PDF مستقلة. `DownloadService<T>` وDownloadStaging وDownloadSpec وResourceDownloadValidator وAndroidDownloadSpaceProbe موجودة في هذا الفرع. لا تُربط الروابط التجريبية بتطبيق الإنتاج.

المثبت بالاختبارات: HTTPS مع TLS verification افتراضي، Progress، Pause/Resume/Cancel/ManualRetry، private staging، فحص مساحة قبل الكتابة، SHA/size streaming، provenance identity/partial digest، typed errors، lease يمنع كاتبًا/فاحصًا متزامنين، إغلاق الملف قبل validator، حفظ الملف السابق عند فشل بديل.

Resume يتطلب **strong ETag** وIf-Range وContent-Range متسقة؛ ضعف/غياب ETag يعيد من الصفر حتى مع Last-Modified. هذه سياسة أمان قائمة موثقة، لا اعتماد Last-Modified وحده كهوية. تجاهل Range بـ200 يعيد الكتابة من الصفر؛ ETag مختلف أو416 يؤدي إلى full restart محدود؛ malformed206 لا يلحق بايتات بالجزء. لا redirect/token leakage تلقائيًا؛ Production redirects تحتاج سياسة صريحة.

Metadata Provenance محدودة16KiB وUTF-8 صارم، ومربوطة بهوية الطلب والـrevision/hash/size/URL/destination/maxBytes؛ لا raw URL tokens في السجل. التلف/invalidUTF8/oversize يرفض الاستكمال. completed staging immutable؛ خطأ طلب مختلف لا يحذف المورد المكتمل. Restart/control races مغطاة.

الخدمة لا تكتب SQLite أو READY/ACTIVE/RAG_READY، ونجاح Result هو نقل+فحص أولي؛ Atomic Activation مسار B-12 مستقل غير مضاف هنا. لم نربط Biology Pilot بعقد إنتاج خمس مواد أو نغير policy لصالح مدخل لا يجتازها.

## 10. Architecture Changes

إضافات الجولة:

| الملفات | المسؤولية |
|---|---|
| tool/resource_intake/{common,manifest,archive,biology}.py | تدقيق developer read-only: pins/JSON/ZIP/vector binding؛ لا استخراج أو activation |
| tool/resource_intake_audit.py وREADME | CLI وقيود الفحص وإعادة إنتاج النتائج |
| tool/staging_resource_integrity_probe.dart | استدعاء الفاحصين الحاليين على الملفات الحقيقية |
| tool/tests/test_*.py |29 اختبارًا مع ملفات مصغرة مولدة داخل Temp فقط |
| integration_test/b07_download_storage_test.dart | اختباران native للتخزين الخاص ورفض المسار الخارجي |
| .github/workflows/b07-resource-intake-verification.yml | Flutter/Python/إعادة تنزيل STAGING والـhash وأرشفة أدلة صغيرة، واختبار تخزين Android منفصل |
| docs/qa/b07-resource-intake/* | أدلة JSON/text؛ لا ملفات تعليمية أو Models/ZIP/AAR |
| docs/architecture/RESOURCE_INTEGRATION_READINESS.md | تحديث مؤرخ مع الإبقاء على جرد أكتوبر كتاريخ |
| docs/spec/RESOURCE_INTAKE_USER_REQUEST_2026-11-06_AR.md وdocs/superpowers/plans/2026-11-06-resource-intake.md | متطلبات المالك وخطة العمل المتتبعة |
| هذا التقرير | النتائج والموانع وحدود القبول |

**لا Dependencies جديدة** أو DB/Migration/Resource IDs أو Runtime/Gradle/Widgets changes. أدوات Python خارج طبقات التطبيق. لا merge أو نسخ implementations من فروع أخرى. بقاء الفرع main-based يعني أن نتائج184 تخص قاعدة B-07 هذه؛ لا تُنسب إلى فرع UI أو اختبارات615 القديمة.

## 11. Security Review

استُخدمت مهارة code-review لمراجعتين مستقلتين: Standards وSpec، مع تثبيت base وHEAD؛ نتائج المراجعة وإصلاحاتها تضاف إلى سجل التسليم. لا يُستبدل التنفيذ بعبارة «المراجع وافق»؛ تُفحص النتائج والاختبارات الفعلية.

حدود الأدوات: private directory دون concurrent writers، رفض symlinks/المسارات غير الآمنة وstat-before/after وO_NOFOLLOW متى توفر، stream SHA64KiB. JSON محدود وصارم. ZIP بلا extraction وبحد128MiB expanded/4096 entries/depth3 مع فحص CRC/checksums. stdlib يقرأ central directory قبل budget؛ الأداة ليست sandbox لخدمة public uploads أو OS-level attacker. لا تُقدم تلك الحدود كسياسة تشغيل AI معتمدة.

شهادة HTTPS ومفتاحها السابقان تحت test/support/download_tls فقط؛ localhost fixture وinjected test trust داخل الاختبارات. لا badCertificateCallback إنتاجي ولا ربط للشهادة/المفتاح بـAssets/Android/main. فحص TLS الافتراضي يرفض الشهادة غير الموثوقة. لا كلمات مرور/credentials/signed URLs/بيانات طلاب أو ملفات جهاز المالك في التسليم.

لا يستخلص نجاح checksum صحة المحتوى أو اعتماد المورد؛ أخطاء AAR والغموض العلمي ظلت fail-closed. لم نستخدم manifest قائمًا بذاته لمنح جاهزية.

## 12. Test Results

نتائج محلية جديدة وليست إعادة استخدام عدد أكتوبر: [JSON التحقق](../qa/b07-resource-intake/local-verification.json).

| الفحص | النتيجة المحلية |
|---|---|
| Flutter3.38.5 / Dart3.10.4 | PASS؛ saved environment setup |
| flutter pub get --enforce-lockfile | PASS؛ lockfile دون تغيير؛35 تحديثًا أحدث غير متوافق معلومات فقط |
| dart format للملفين Dart الجديدين | PASS |
| flutter analyze --no-pub | PASS؛ No issues found |
| flutter test --no-pub --machine، كامل | **184 passed /0 failed /0 skipped**؛ success=true وstderr فارغ |
| Python adversarial audits | **29 passed /0 failed /0 skipped** |
| تدقيق الموارد الخمسة الفعلية | PASS في البايتات/التغليف فقط |
| Dart validators على3 موارد حقيقية | Hash/size PASS؛ format status وحدود الفحوص موثقة منفصلة |
| Kotlin2.2.20 + AAR compile probe | **FAIL**؛ metadata2.4.0 غير مقبولة؛ خطأ توافق حقيقي لا regression في Flutter |
| Android native storage test2 | NOT RUN محليًا؛ CI مستقل مضاف |

التغطية المطلوبة14 حالة:

| الحالات | الدليل |
|---|---|
| success / interruption / cancel / resume / ETag | b07_download_service_test.dart وخادم HTTPS محلي حقيقي وملفات مؤقتة |
| hash/size/HTTP failure / disk low أوIO | اختبارات الخدمة والفاحص وspace probe الحالية |
| ZIP تالف / traversal / Manifest غير صالح | tool/tests مع CRC/قطع/روابط/duplicates/UTF8/JSON/حدود/size/hash |
| فشل بديل يحافظ على السابق | اختبارات transport/checkpoint وsentinel في اختبار رفضZIP |
| لا تفعيل غير معتمد | tests الحالية لحالات repository/integrity/transport، وغياب أي persistence/activation API من أداة الاستلام |

TDD: common/archive بدأ19 اختبارًا RED ثم GREEN؛ Manifest أضاف5 (24)، وvector bundle أضاف5 (29). تشمل الطفرات generated bad bytes والـrow binding والـNaN/zero vectors. هذه fixtures اختبارية معزولة وليست بيانات إنتاج. نتائج CI تربط أدناه بعد التشغيل الفعلي؛ تعريف workflow وحده ليس PASS.

## 13. Android Validation Status

`flutter devices --machine` أظهر Linux فقط؛ لا adb/sdkmanager/emulator محليًا. لا ادعاء جهاز Android أو Samsung. الاختباران الجديدان يستدعيان MethodChannel الحقيقي للـStatFs ورفض Directory('/') على emulator فيCI، دون AI AAR أو تغيير Gradle.

حتى نجاحهما يعني Android transport/storage boundary فقط؛ لا يثبت TLS/network/disk interruption على الهاتف ولا JNI/LLM/Embedding/airplane-mode/RAM/Latency. **G2/G3 وSamsung/arm64 physical device = PENDING DEVICE TEST /NOT RUN**. لا APK مبني مع هذه النماذج ولا Runtime initialization أو generation في المهمة.

## 14. Known Limitations

- Root manifest لا يحتوي Catalog production URLs/IDs/revisions أو model licenses/config كاملة؛ prerelease قابل للتغيير، لذلك pins الحالية ثابتة ويجب رفض أي تغير.
- full SHA وقراءة container/tokenizer metadata ليست tensor validation أو inference. min_runtime_version غير موجود في proto المفحوص؛ لا نستنتج compatibility من container1.7.0 مقابل SDK0.19.0.
- AAR external dependency versions وbuild provenance وD8/R8 والتشغيل غير مثبتة؛ source tag مذكور كمرجع schema/API semantics، لا ادعاء أن AAR أعيد بناؤه منه.
- بيانات الوحدتين Pilot؛ source PDFs/Golden/بعض مراحل validation غير مرفقة. فحص JSON/finite vectors ليس Grounding أو Recall@5 أو Scientific Gold.
- normalization/tie/filter متباينة أو مؤقتة، ولا يجوز تحويل defaults أو policy عابرة إلى قرار علمي.
- أداة ZIP developer audit مستقلة عن أي extractor/pack validator في التطبيق؛ لا نزعم تنفيذ ذلك لمجرد نجاحها.
- هذه الجولة لا تكمل UI/Production Auth أو PR12 ولا تختبر كامل فرع التكامل؛ لا تغيير نطاق صامت.

## 15. Remaining Blockers

ترتيب المتابعة الصحيح، دون تنفيذه تلقائيًا في هذا PR:

1. **BLOCKED:** إغلاق توافق AAR/toolchain بمسار معتمد وموثق: مصدر/إصدارات dependencies/consumer rules/Java21+D8/Kotlin2.4 metadata، ثم compile/shrink/load على Android. لا skip-version-check أو Runtime بديل مفترض.
2. **BLOCKED:** اعتماد Native Adapter وvalidator لصيغة LiteRT-LM في طبقات الموارد القائمة، مع failure/cancel/lifecycle/model identity؛ لا تعطيل فاحص GGUF عشوائيًا.
3. **PENDING_VERIFICATION:** تشغيل Qwen وEmbeddingGemma فعليًا على arm64، تثبيت tokenizer/pooling/normalization/output768 وخياراتالسياق/التوليد المتوافقة وترخيص الأوزان وRAM/Latency وcancel/reload.
4. **BLOCKED:** ربط Biology Catalog/SourceRegister/lesson/pack/subject وdataset_revision، حل اختلاف tie/filter ومرجع التقييم العلمي؛ لا إعادة بناء المتجهات أو اختراع IDs.
5. **PENDING DEVICE TEST:** **G2 أولًا** لتحميل Shared Query Embedding ومقارنة vector/retrieval parity على الوحدتين بالمصادر المعتمدة، ثم **G3** للإجابة grounded/refusal والمصادر الصحيحة والإلغاء وairplane mode مع LLM فعلي. لا تنتظر PDF/UI النهائي أو المواد الخمس لبدء Pilot معزول، ولا تمنحه RAG_READY إنتاجية.

**قرار الإغلاق:** أصبحت لدينا ملفات STAGING سليمة وأدلة API وتغليف واختبارات نقل قابلة للمراجعة، لكن **لسنا جاهزين لاعتماد دمج LiteRT-LM وتشغيل النموذجين إنتاجيًا** بسبب الموانع أعلاه. هذه نتيجة هندسية مثبتة، وليست فشل تنزيل أو سببًا لإعادة كتابة الخدمة المكتملة.

## 16. Pull Request URL

[PR #3 — codex/b07-independent-download-01 → main](https://github.com/shehab5552/siraj-codex/pull/3). يعاد استخدامه لأنه نفس الفرع المطلوب ونفس أساس B-07؛ يظل مفتوحًا دون Merge. آخر Commit وFiles Changed وروابط CI في رأسPR وسجل تسليمه. تُحدّث نتائج CI بعد ظهور تشغيل فعلي، ولا يصنف workflow المضاف وحده PASS.

مراجع format أولية مثبتة: [FBS schema](https://github.com/google-ai-edge/LiteRT-LM/blob/83ce6067f2e2a3fb697556928f93936693ded971/schema/core/litertlm_header_schema.fbs)، [core constants](https://github.com/google-ai-edge/LiteRT-LM/blob/83ce6067f2e2a3fb697556928f93936693ded971/python/litert_lm_builder/litertlm_core.py)، [tokenizer builder](https://github.com/google-ai-edge/LiteRT-LM/blob/83ce6067f2e2a3fb697556928f93936693ded971/python/litert_lm_builder/litertlm_builder.py)، [LLM proto](https://github.com/google-ai-edge/LiteRT-LM/blob/83ce6067f2e2a3fb697556928f93936693ded971/runtime/proto/llm_metadata.proto)، [embedding proto](https://github.com/google-ai-edge/LiteRT-LM/blob/83ce6067f2e2a3fb697556928f93936693ded971/runtime/proto/embedding_metadata.proto).
