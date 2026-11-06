# B-08 — دمج LiteRT-LM Android Runtime مع Flutter

**تاريخ التقرير:** 6 نوفمبر 2026، توقيت عدن. **نجح التكامل والتشغيل الهندسي للنموذجين؛ B-08/P0 غير مكتملتين لأن G2/G3 ما زالتا BLOCKED.**

الحالات: `PASS` نتيجة منفذة ومثبتة؛ `FAIL` فشل منفذ؛ `BLOCKED` مدخل خارجي مفقود؛ `NOT RUN` لم ينفذ؛ `PENDING DEVICE TEST` يحتاج جهازًا فعليًا.

## 1. Git Baseline

- المستودع: `shehab5552/siraj-codex` فقط.
- `main` المرجعي: `651af0d62d05761c80d9a8cbc9d1f51b836929eb`.
- نقطة الفصل: `208511419bea03600793a24125795fcf3780b1bc` من `codex/b07-independent-download-01`؛ PR #3 مفتوح وغير مدمج وقت بدء المهمة.
- فرع التنفيذ: `codex/b08-litertlm-android-runtime-01`؛ PR #14 يستهدف فرع B-07، حتى يعرض تغييرات B-08 وحدها.
- لم يُدمج PR #3 أو #14، ولم يُعدل main مباشرة. لم يُفتح siraj-p0 أو مشروع الكمبيوتر المحلي.
- سبب تصحيح أول Fetch: كان remote-tracking لفرع B-07 قديمًا بسبب refspec ضيق؛ جُلب المرجع الصريح وصُحح بالـfast-forward قبل تعديل المصدر، دون إعادة كتابة التاريخ.

## 2. Dependency Compatibility Investigation

`PASS` للفحص المستقل: AAR الحقيقي من Maven يطابق مورد المالك حجمًا وبصمة، وPOM والاعتماديات الفعلية محفوظة تحت `docs/qa/b08-runtime/`.

- AAR: `21,197,249` بايت؛ SHA-256 `e5c7a86048225efba8ab6d35fcd91f5870c86c65ca2538c07c3c1f63d02efa2b`.
- POM: HTTP 200، 1,543 بايت؛ SHA-256 `9f4e78a67f31a7f94c9527b623f21a7810fac286270e09b2fb78acfab35a5b06`.
- Java class major 65 وKotlin metadata 2.4.0 من الملف الفعلي. نجاح javac وحده لم يُعد دليل Android.

## 3. Kotlin/Java Compatibility Resolution

`PASS` لاختبارات المترجمات: Kotlin 2.2.20 رفض Metadata؛ 2.3.0 قرأها دون تجاوزات. جُرب Java facade على target17، ومستهلك Kotlin2.2.20 لا يرى أنواع AAR مباشرة.

أثبت بناء التطبيق بعد ذلك أن Java facade وحده غير كافٍ: `kotlin-stdlib:2.4.0` تصل إلى app عبر POM، ورفضها KGP2.2.20 عند `:app:compileDebugKotlin`. لذلك استُخدم أصغر إصدار اختُبر بنجاح، KGP2.3.0، مع إبقاء Java facade حدًا معماريًا. نُقل JVM target17 إلى `kotlin.compilerOptions` لأن DSL السابق أصبح خطأً في KGP2.3.

لم يُستخدم `-Xskip-metadata-version-check` أو تعديل Metadata أو إجبار stdlib أقدم أو تعطيل D8/R8.

## 4. Maven/POM Dependency Audit

الإصدار ثابت: `com.google.ai.edge.litertlm:litertlm-android:0.19.0`؛ SHA gate قبل بناء الوحدة، دون AAR محلي في Git.

الاعتماديات الثماني المحلولة فعليًا: LiteRT-LM0.19.0، Gson2.14.0، error_prone_annotations2.48.0، kotlin-reflect2.4.0، kotlin-stdlib2.4.0، coroutines-android1.11.0، coroutines-core-jvm1.11.0، annotations23.0.0. المصدر: `resolved-graph.json`.

أضيف إلى Dart اعتماد واحد مثبت: `flat_buffers:25.9.23` مع lockfile؛ لا تحديثات جانبية للحزم. روجعت تراخيص الأوزان قبل تمكين سجل Debug: الملفان طابقا SHA في مستودعات Hugging Face بإصدارات ثابتة، وبطاقتاهما تعلنان Apache-2.0. قُرئت البطاقتان ونص الترخيص الكامل؛ التفاصيل في `model-license-review.json`. هذا تصريح استخدام هندسي معزول، وليس اعتماد Catalog إنتاجي أو إعادة توزيع للأوزان.

## 5. Android Gradle Changes

- وحدة Java `android/ai_runtime`، AGP8.11.1 وGradle8.14 كما هما؛ KGP2.3.0 بالسبب المثبت أعلاه؛ Java target17 مع JDK21 في CI.
- compileSdk36/minSdk24 الموافقان لـFlutter3.38.5؛ ABI هما arm64-v8a وx86_64، المطابقان لـAAR.
- Release يبني مع R8 وتقليص الموارد؛ قواعد المستهلك تحفظ أسماء حدود JNI الفعلية وMetadata المطلوبة، دون `dontwarn` أو تعطيل التحسين.
- استخراج نصوص ترخيص SDK من AAR المتحقق منه إلى assets مولدة عبر AGP variant sources؛ لا تُحفظ AAR أو الأوزان أو APK في Git.
- لم يتغير Manifest أو Kotlin الخاصان بـAuth/Keystore/DownloadStorage. أضيف تسجيل AI وتنظيفه إلى MainActivity إلى جانب القناتين القائمتين.
- توقيع Release ما زال إعداد debug السابق للمستودع؛ ليس توقيع نشر إنتاجي.

## 6. Native Runtime Implementation

`RuntimeBackend` يعزل أنواع SDK؛ `LiteRtBackend` يستدعي Engine وEmbeddingEngine الحقيقيين. `RuntimeManager` يملك المقابض على worker واحد؛ لا تحميل أو توليد أو انتظار إغلاق على Android Main Thread.

لكل طلب Conversation جديدة مع System Instruction. النص يستخرج من `Message.contents.contents` ثم `Content.Text.text` فقط. تُرفض الأدوات/المحتويات غير المدعومة صراحة، ولا يُعاد Message.toString كجواب. تُحجب قنوات reasoning عن نص الإجابة. Streaming وCancel يستخدمان API الرسمية 0.19.0.

الإغلاق ينتظر terminal الأصلي قبل تحرير Conversation/Engine. إذا فشل طلب الإلغاء لا يُدمّر مقبض ما زال يعمل؛ تبقى ملكيته مع worker حتى وصول terminal، ثم يُعاد الخطأ بعد التنظيف. انعدام terminal يُبقي المورد محجوزًا؛ لا ادعاء باستعادة عملية Native عالقة أو قتلها بأمان.

الملكية تربط ID فريدًا وlistener epoch وlease؛ طلب مكرر مرفوض لا يحذف ملكية طلب قائم. لا تهيئة مزدوجة أو توليد متزامن. إبقاء LLM وEmbedding مقيمين معًا مغلق إلى أن تُقاس سلامته على الجهاز المستهدف.

## 7. Flutter Bridge Implementation

- MethodChannel: `siraj/ai_runtime/methods_v1`: initializeLlm، generate، cancelGeneration، closeLlm، initializeEmbedding، embed، closeEmbedding، getRuntimeStatus.
- EventChannel: `siraj/ai_runtime/events_v1`: Started/Chunk/Completed/Failed/Cancelled مع requestId وsequence.
- `AiRuntimeClient` و`MethodChannelAiRuntimeClient` مستقلان عن Widgets وSQLite، بأخطاء typed وإلغاء وتحقق من ترتيب الأحداث ومتانة متجهات Embedding.
- المخرجات قبل MethodChannel acknowledgement تُخزن للمستمع؛ الأحداث القديمة والـterminal المكرر لا تصل إلى طلب جديد. انقطاع القناة يلغي الطلب المحلي/الأصلي ويغلق قبول توليد جديد حتى يتخلص المالك من العميل ويُنشئ عميلًا جديدًا.
- Flutter يرسل resource ID فقط. Native resolver يثبت جذر Context الموثوق ويمنع إعادة توجيه child/model بالـsymlink أو traversal ويعيد فحص الحجم وSHA قبل التحميل. سجل Release فارغ؛ سجل Debug يقبل الملفين المثبتين فقط في مجلد fixture خاص بالتطبيق.

## 8. LLM Model Loading and Generation Results

`PASS` للتشغيل الهندسي الحقيقي على Android API33 x86_64 في تطبيق SIRAJ نفسه، عبر Flutter → Method/EventChannel → SDK/JNI؛ المصدر `0c9212cd8ae81d798b0ef7a4fd5f52e5877fcf4b` والتشغيل [CI](https://github.com/shehab5552/siraj-codex/actions/runs/42291190266).

- حُمل Qwen3-0.6B المثبت حجمًا وSHA. عاد النص من Content.Text، مع فحص `trim().isNotEmpty` في آخر نسخة، دون طباعة السؤال أو النص.
- نجحت ثلاثة طلبات عربية/إنجليزية متسلسلة، ثم طلب رابع بعد Dispose/Reload للمحرك. لكل طلب مكتمل terminal واحدة.
- خمسة طلبات توليد إجمالًا: أربعة اكتملت، وواحد أُلغي عمدًا. صفر فشل غير مقصود داخل هذا التشغيل، دون تعميم لمعدل أعطال إنتاجي.
- جاء `generationCancelled` من Native فعلًا؛ لم يُكتف بحدث الإلغاء المحلي في Dart. انتهت عملية الإلغاء الأصلية خلال `4`ms من طلبها؛ هذا ليس إجمالي زمن إعداد تجربة الإلغاء.
- تهيئة LLM عبر العميل: `4177`ms؛ إعادة التحميل: `3234`ms. هذه أزمنة ذلك المحاكي فقط.

تم الاختبار بمدخلات هندسية ثابتة غير حقيقية للطلاب. لا تمثل النتائج إجابات Biology مسندة أو G3. Runtime في Release ما زال مغلقًا دون Catalog معتمد؛ الاختبار الفعلي Debug، داخل Android module/package الحالي، وليس تطبيقًا تجريبيًا منفصلًا.

## 9. Embedding Model Results

`PASS` لخرج Embedding حقيقي: تهيئة EmbeddingGemma `1168`ms، وثلاثة استعلامات عربية/إنجليزية. كل خرج768 بُعدًا، finite وغير صفري.

| الاستعلام الهندسي | الأبعاد | L2 norm | الزمن ms |
|---|---:|---:|---:|
| 1 | 768 | 1.000000230178 | 685.168 |
| 2 | 768 | 1.000000170612 | 716.091 |
| 3 | 768 | 1.000000020492 | 644.479 |

أُغلق Embedding قبل تحميل LLM، ولم تُختبر إقامة المحركين معًا. استُخدمت `EmbeddingOptions()` بقيم SDK nullable الافتراضية؛ لم تُحدد pooling/prefix/normalize من عندنا، ولم تتغير متجهات Biology. كون norm قريبًا من1 لا يثبت سياسة Dataset أو parity؛ G2 باقية BLOCKED.

## 10. Resource Format Validator

`PASS` للفحص البنيوي المنفذ على الملفين الحقيقيين والاختبارات المحلية.

`LiteRtLmFormatValidator` يستخدم FBS الرسمية من مصدر LiteRT-LM المثبت `83ce6067f2e2a3fb697556928f93936693ded971` وDart binding مولدة بـflatc25.9.23. يفحص الترويسة والإصدار وحدود FlatBuffer والأقسام ومحاذاتها ونوع الموارد وmetadata المطلوبة؛ حد الترويسة1MiB وعدد/تجميع metadata محدود.

يفحص TFL3/root bounds، protobuf framing، ومقطعي SentencePiece أو HF JSON ذي فك ضغط محدود وUTF-8 صارم. هذا ليس TFLite tensor verifier كاملًا أو برهان تشغيل. الحدود نصف مفتوحة وتسمح بقسم ينتهي حيث يبدأ التالي؛ هذا موجود فعليًا في Gemma وليس تلفًا.

رُبط بالفاحص الحالي داخل lease التنزيل، مع الحفاظ على GGUF. دليل SHA خاص بالملف/snapshot ولا يمكن اختلاقه من constructor عام. نجاح البنية يبقي فحوص Runtime/ModelLoad/اعتماد الموارد مطلوبة ولا يكتب READY/ACTIVE/RAG_READY.

## 11. Biology G2 Results

`BLOCKED`: وحدتا Biology تحويان 67 و63 سجلًا بمتجهات768، لكن pack/chunk/source/lesson mapping وDataset revision المعتمدة وparity/reference اللازمة غير مكتملة. لم تُنشأ معرفات أو فهارس أو متجهات بديلة، ولم يُعتمد التطبيع من قياس norm وحده.

المطلوب: هوية Dataset/Index مع SHA، Shared Embedding artifact/tokenizer/config، سياسة prefix/pooling/normalization الأصلية، مرجع retrieval موثق ومصادر قابلة للتتبع، ثم اختبار G2 على Android الحقيقي. Pilot لا يستبدل شرط Packs المواد الخمس في الإنتاج.

## 12. Grounded RAG G3 Results

`BLOCKED`: غياب G2/source authority/التقييم العلمي يمنع اعتماد إجابات Biology. LLM خام ناجح، إن ثبت، لا يفتح هذه البوابة.

لا Fake Retrieval أو Sources أو إجابات علمية في Release؛ `UnavailableTutorEvidence` يعيد خطأ عدم جاهزية تشغيليًا قبل أي استدعاء Native. توفير TutorEvidencePort حقيقي يحتاج سياسة وسياقًا ومراجع معتمدة وفحصًا بعد التوليد؛ لم تُخترع thresholds أو ضمانات semantic grounding.

## 13. Chat Integration

التدفق: تحقق جلسة → حفظ USER → Tutor Application Service → Evidence Gate → Native عند السماح → فحص المرجع/الإصدار/النتيجة → حفظ ASSISTANT → عرض.

`TutorResult` له ثلاث حالات رسمية ANSWER/REFUSAL/ERROR؛ Partial صفة ANSWER وفق FR-05. SourceReference هي pack_id/chunk_id/dataset_revision، لا ينشئها LLM ولا تُخترع صفحة.

`ChatTurnCoordinator` ينسق المسار الحالي بدل إعادة بناء Repository. أضيفت متابعة بالمحادثة نفسها وIDs ثابتة وإعادة محاولة idempotent، مع الحفاظ على حد10 ومعاملة الرسالة الأولى وترتيب المحادثات. التحقق من nonce hash داخل معاملة الكتابة يمنع سباق Logout، والحذف يمنع إحياء المحادثة. الإلغاء/Dispose/revision guards تمنع كتابة جواب قديم.

التغيير في UI محدود للإرسال والمتابعة/الإلغاء/الرسالة التشغيلية/عرض النتيجة والمصادر. لا Native call أو SQL أو سياسة علمية داخل Widgets. Auth الإنتاجي لم يُفتح أو يُغير؛ مسار Chat الحقيقي ما زال يتطلب جلسة قائمة صحيحة.

## 14. Memory and Performance Measurements

`PASS` للقياسات الهندسية التالية من المصدر/CI المحددين في `android-final-results.json`؛ ليست قياسات Samsung أو حد قبول إنتاجي.

| الطلب | أول جزء نصي s | إجمالي الطلب s | TTFT كما أعاده SDK s | Decode tokens من SDK | Decode tok/s من SDK |
|---|---:|---:|---:|---:|---:|
| 1 | 6.549 | 10.876 | 5.246361 | 7 | 3.216563 |
| 2 | 4.953 | 9.733 | 3.960017 | 9 | 3.926470 |
| 3 | 4.902 | 9.348 | 3.854151 | 8 | 3.779824 |

فُحصت API الفعلية في AAR: `BenchmarkInfo` توفر عدادات tokens وTTFT/rates. مُكّنت `ExperimentalFlags.enableBenchmark` في Debug فقط، وقُرئت القيم قبل إغلاق Conversation. القيم غير الصالحة/الغائبة تبقى غير مقاسة؛ لا تقدير tokens من الحروف. Release يعطل Benchmark.

TTFT الخاص بـSDK وأول جزء نصي لهما نطاقا قياس مختلفان، وقد تتضمن عدادات SDK رموزًا داخلية؛ لم يُفترضا متساويين. حقل `initializeSeconds` المنقول من SDK محفوظ باسمه ونطاقه الأصلي في JSON، ولا يُستبدل به قياس initialize عبر العميل أو يُختلق تفسير لاختلافهما.

- `231` عينة PSS/native heap بفترة مستهدفة250ms.
- قمة PSS الملتقطة: `2045675`KiB ≈`1997.73`MiB.
- قمة native heap الملتقطة: `1261598208` بايت ≈`1203.15`MiB.
- هذه قمم مرصودة بالعينات لعملية التطبيق، وليست ضمان التقاط القمة المطلقة، ولا تصريح co-residency أو أداء جهاز فعلي.

## 15. Security Review

مراجعتان مستقلتان، Standards وSpec، على diff مثبت، ثم مراجعات الإصلاحات؛ النتيجة النهائية بلا ملاحظات جوهرية متبقية في النطاق المراجع، كما في `docs/qa/b08-runtime/review.md`. عولجت باختبارات رجعية: فقدان قناة الأحداث، حذف listener عند رفض ID مكرر، فقدان worker أثناء استثناء الإلغاء، وتسرب خطأ إغلاق إلى طلب لاحق. أضيفت حماية لاختبار terminal السابقة للـack ولسباق اكتمال الطلب قبل الإلغاء.

لا تُسجل prompts/answers/vectors/nonces أو stack traces أو signed redirects. مستوى Native log هو INFINITY الرسمي لمنع تسريب النص؛ أخطاء SDK تُختصر إلى codes تشغيلية. إعدادات Debug fixtures ليست في Release؛ APK لا يحتوي أوزانًا. لا تغييرات في PBKDF2/Keystore أو schema/migrations أو DownloadService.

## 16. Flutter Test Results

`PASS` محليًا: **250 passed / 0 failed / 0 skipped**، وFlutter analyze بلا ملاحظات. Flutter3.38.5 / Dart3.10.4 مؤكدان بالأوامر، وpubspec.lock مثبت.

```bash
source /workspace/.siraj-tooling/env.sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub --machine
bash tool/ai_runtime/run_core_tests.sh
python3 -m unittest discover -s tool/tests
```

Java: **35 passed** لعقود المكتبة/الأخطاء/المسارات/التزامن والإلغاء والإغلاق وتهيئة متزامنة وفشل تهيئة ثم تعافٍ. Fake ports هنا داخل src/test فقط، وليست إثبات استدلال. Python: **36 passed**؛ تشمل رفض إثبات CI الناقص أو zero/partial cases أو scope خاطئ. تحقق CI يعيد Flutter والاختبارات اللازمة، مع تمييز أعداد Linux عن حالات Android الست.

تحتفظ اختبارات Flutter باختبارات B-07 القائمة، وتضيف الصيغة والعميل وSQLite وSession/Delete/Cancel/Revision races وWidgets. نقص مساحة cache الفعلي/OOM المتعمد على جهاز6GB وAPI24 وSamsung لم يُنفذ؛ لا تُسجل PASS لهذه الحالات.

## 17. Android Build Results

`PASS`: بُنيت نسختا lib/main.dart Debug وRelease بأدوات Flutter/Gradle، مع D8/R8 وتقليص Release، وبقيت الاعتماديات والأصناف المطلوبة موجودة.

```bash
flutter build apk --debug
flutter build apk --release
gradle -p android :app:dependencies :app:assembleDebug :app:assembleRelease --no-daemon
```

الملفات الفعلية: `android/ai_runtime/**`، إعدادات app/settings Gradle، MainActivity والقناة الجديدة. لم يُعدل Manifest أو Auth/Keystore/DownloadStorage أو النسخةGradle8.14/AGP8.11.1. KGP2.3.0 هو التغيير المتوافق المثبت؛ Java target17 وJDK21 في CI.

أخطاء سابقة عولجت دون إخفاء: wrapper غائب في bare checkout، اسم THIRD_PARTY_NOTICE.txt، Metadata عبر stdlib2.4، DSL Kotlin القديم، اعتماد lint على assets مولدة، ثم غياب التراخيص من APK. عالجت AGP generated variant assets المشكلة الأخيرة، وأثبت الفحص وجود التراخيص لاحقًا. حزمة Release ما زالت موقعة بمفتاح debug وفق إعداد المستودع السابق؛ ليست توقيع متجر.

## 18. APK Inspection

`PASS` للحزمتين المبنيتين من lib/main.dart والمربوطتين بالمصدر `0c9212cd8ae81d798b0ef7a4fd5f52e5877fcf4b`. [تحميل APK وأدلة البناء](https://github.com/shehab5552/siraj-codex/actions/runs/42291190266/artifacts/13540267633).

| الحزمة | الحجم بالبايت | SHA-256 |
|---|---:|---|
| app-debug.apk | 206695244 | `294b9c66ede6c1bc126a6ad6be3d2534977b44897eb2e7c5be0022f9bb9d8a49` |
| app-release.apk | 104731977 | `9bda26e7bc43a8be6cfaded7b393bca92a0783a46e3e6f5ff6253cb1cfa7609f` |

فُحص DEX لأصناف Engine/EmbeddingEngine الحقيقية، وملفا liblitertlm_jni.so عبر readelf: ELF64 وe_machine183 لـarm64-v8a و62 لـx86_64 وSONAME، مع R8 mapping في Release وملفات LICENSE/THIRD_PARTY_NOTICE داخل APK. بصمات المكتبتين محفوظة في JSON؛ لا اعتماد على أسماء مجلدات ABI فقط.

حقل `model_execution=NOT RUN` داخل سجل فحص ZIP يخص ذلك الفاحص الساكن قبل تشغيل الجهاز. نتيجة الاستدلال المستقلة في قسم `android` هي PASS؛ لم يُحوّل فاحص ZIP إلى اختبار استدلال. APK lib/main.dart للتسليم؛ تطبيق اختبار Flutter يستخدم entrypoint اختبار داخل package/module SIRAJ نفسه. لا يُدعى اختبار استدلال Release ذي Catalog المغلق.

## 19. Device/Emulator Test Results

`PASS`: **6 passed / 0 failed / 0 skipped** على Android API33 x86_64 emulator، في invocation موحدة:

1. SQLite وقيود/cascade B-03 على Android.
2. Keystore والجلسة/logout/delete B-04 ببيانات اختبار معزولة.
3. StatFs على staging خاص بالتطبيق.
4. رفض مسار خارج التخزين الخاص.
5. JNI عبر Flutter ورفض تحميل مسار اعتباطي.
6. النموذجان الحقيقيان والتوليد/Embedding والإلغاء والإغلاق/reload/offline.

نُقلت الملفات تحت app UID بعد فحص الحجم/SHA محليًا، وأُعيد SHA/size على الجهاز. Wi-Fi/mobile data=0، وAndroid active default network=none، مع تسجيل3 مسارات kernel متبقية دون تسميتها شبكات إنترنت فعالة. فشل اتصال التطبيق إلى api.github.com:443 قبل الاستدلال؛ لم يُرسل نص سؤال عبره.

اختبار أولي فشل بـintegrityFailure لأن Flutter3.38.5 يزيل التطبيق عند نهاية كل invocation، فحذف الأوزان قبل هدف النماذج. جُمعت الحالات في entrypoint واحدة مع تحقق device bytes، ثم نجح التشغيل الفعلي. سجل الأخطاء السابق محفوظ ولا يعد فشلًا للنموذج نفسه.

Samsung/arm64 فعلي: **PENDING DEVICE TEST**؛ وجود ARM64 ELF لا يثبت تشغيل جهاز فعلي. G2/G3 ما زالتا **BLOCKED**.

## 20. CI Results

`PASS` لتشغيل المصدر `0c9212cd8ae81d798b0ef7a4fd5f52e5877fcf4b`: [https://github.com/shehab5552/siraj-codex/actions/runs/42291190266](https://github.com/shehab5552/siraj-codex/actions/runs/42291190266). النجاح يتطلب خروج العملية0، protocol done ناجحة، الحالات الست كاملة دون skip/fail، وrecord وحيدة بنطاق هندسي صحيح وتنفيذ نماذج فعلي وإلغاء Native؛ print أو exit0 وحدهما ليسا نجاحًا.

Workflow مستقل: `.github/workflows/b08-runtime-verification.yml`. Maven/license audit منفصلان عن build/runtime. تُرفع APK كـActions artifact فقط. لا تُرفع أوزان أو AAR أو ZIP موارد إلى Git أو artifacts. نتائج النموذج لا تتضمن prompts/answers/vectors/raw logs.

النتائج الكاملة وبصمات APK وروابط artifacts في `docs/qa/b08-runtime/android-final-results.json`. تاريخ الفشل/التصحيح موثق في `android-build-history.json`. الإلغاءات كانت لرؤوس مستبدلة أو runs مكررة، وليست نجاحات. تقارير الإثبات فقط لا تعيد بناء APK غير متغير؛ inputs مثل model-license-review.json تبقى ضمن التحقق.

## 21. Known Limitations

- B-08 الكلية/P0 غير مكتملتين؛ Native engineering نجح، وG2/G3 غير مجتازتين.
- سجل Release فارغ، ولا Production Catalog/Manifest أو موارد مفعلة. لا أوزان في APK ولا RAG_READY زائفة.
- Grounding/Semantic correctness/approved FR-05 scientific policy لم تُخترع. واجهة الأدلة الحقيقية تحتاج مدخلات A/C المعتمدة.
- لا اختبار Samsung أو ARM64 فعلي أو API24 أو co-residency أو OOM/disk-full متعمد على جهاز6GB.
- static parser ليس tensor verifier أو model-load proof؛ نجاح التشغيل المعزول لا يعتمد Dataset.
- توقيع المتجر وبوابات Auth/المحتوى والإنتاج السابقة لم تُغلق ضمن هذه المهمة. History/Reopen وPDF/Quiz ليست ادعاء اكتمال في هذا PR المخصص لـNative/Chat integration الحالي.
- upstream Native call بلا terminal تُحجز موارده حتى يستجيب؛ لا تحرير مبكر غير آمن أو ادعاء تعافٍ مضمون من Native عالق.

## 22. Remaining Blockers

`BLOCKED` لـG2/G3: توفير Source Registry وpack/chunk/lesson IDs وDataset Revision الفعلية، Index identity/version/hashes، سياسة Shared Embedding الأصلية (tokenizer/pooling/normalization/query/document prefix)، مرجع parity/gold set وقواعد الأدلة والتقييم العلمي. لا يُنشأ أي منها بالحدس.

أول مهمة تالية صحيحة: **B-09 Biology G2 parity** على وحدتي Pilot بهويات وسياسات معتمدة، ثم G3 grounded answers/refusal/citations على Android الحقيقي. يبقى شرط خمس Subject Packs للإنتاج كما هو؛ PDF/Quiz ليسا شرط بدء Biology. قبل توفير المدخلات يمكن مراجعة/تجهيز harness منفصل، دون إعلان parity أو إدخاله في هذا PR.

شبكة Cloud المحلية: `maven.google.com` و`dl.google.com` و`huggingface.co` أعادت Proxy CONNECT403 دون استجابة origin. المصدر الدقيق في `cloud-network-probes.json`. لم يُغيّر proxy/TLS/VPN. Maven/التراخيص نجحت في CI المصرح به؛ GitHub release fixture downloads نجحت مع SHA مطابق.

تنزيل سجلات/Artifacts Actions محليًا عبر Azure Blob كان محجوبًا؛ استُخدمت annotations API لأدلة صغيرة وروابط Actions للمستخدم، دون كشف signed URLs أو credentials. هذا قيد أداة البيئة، وليس فشل تحميل نموذج على Android.

## 23. Commit SHAs

المصدر الهندسي المثبت ومرجع APK/الأداء: `0c9212cd8ae81d798b0ef7a4fd5f52e5877fcf4b`. الالتزامات اللاحقة للتوثيق أو الاختبارات تُفصل عن هوية APK المبني؛ آخر SHA للتسليم يظهر في PR وGit ولا يُختلق داخل الملف ذاتي الإحالة.

```text
ba2e914 build(android): investigate fixed LiteRT-LM dependency and compiler paths
5ff88bf build(android): isolate verified LiteRT AAR behind Java module
4f9e3bd fix(android): package actual LiteRT notice filenames
beda63c build(android): use minimum proven Kotlin compiler for stdlib metadata
6a51d0c build(android): migrate JVM target to Kotlin 2.3 compiler DSL
84dfbcf feat(resources): validate verified LiteRT-LM containers without activation
4c88a43 fix(android): track generated notice assets for release lint
eca7b5a feat(android): add worker-owned LiteRT runtime and versioned Flutter bridge
0aa03ba feat(flutter): add typed cancellable AI runtime client
06c4c0d feat(chat): guard grounded tutor turns and follow-up persistence
364cd72 test(android): retain bounded license and optimized APK evidence
5aa438b fix(ai): preserve request and cleanup ownership across transport failures
87b0df8 test(ci): expose complete bounded model license documents
4abe529 fix(android): register notice assets through generated variant sources
2c03054 test(android): exercise licensed private model fixtures offline
90d8ab4 test(ai): observe early native terminals and prove offline routing
3a17d88 fix(test): preserve app-private models through Android acceptance run
292c849 feat(ai): expose verified SDK benchmark counters in debug probes
230c158 fix(ai): reject blank generated text as an operational failure
4381b1d test(ci): require all six Android cases and genuine probe scope
0c9212c test(ai): cover concurrent initialization and run evidence regressions in CI
```

عدد الملفات في diff التسليم: **83**. قائمة الملفات الكاملة: `docs/qa/b08-runtime/files-changed.txt`. تشمل: وحدة Native/Gradle؛ القناة وDebug/Release catalogs؛ typed Dart client؛ الفاحص المتخصص والـFBS binding؛ ConversationRepository/controller/Tutor/Chat/bootstrap؛ الاختبارات/أدوات CI والتقارير. لا تعديلات في DownloadService أو schema أو Auth crypto، ولا binary موارد في diff.

## 24. Pull Request URL

https://github.com/shehab5552/siraj-codex/pull/14

Base: `codex/b07-independent-download-01`؛ PR #3 ما زال OPEN وmerged=false، وmain عند651af0d. لم يُدمج أي PR. تسليم Native مستقل وقابل للمراجعة مع بقاء البوابات العلمية/الجهاز الفعلي واضحة، وليس إعلان اكتمال التطبيق.

