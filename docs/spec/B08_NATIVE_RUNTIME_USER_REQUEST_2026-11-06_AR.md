# SIRAJ P0 — B-08
# LiteRT-LM Native Runtime & Flutter Integration
## EXECUTION TASK — IMPLEMENT, BUILD, TEST AND INTEGRATE

أنت تعمل بصفة:

- Senior Android AI Integration Architect
- Senior Kotlin/JVM Engineer
- Senior Flutter/Dart Engineer
- LiteRT-LM Runtime Integration Engineer
- Mobile AI Performance & Security Engineer

مهمتك ليست إعداد خطة أو تقديم تقرير نظري.

**مهمتك تنفيذ الدمج البرمجي الحقيقي لـLiteRT-LM 0.19.0 داخل تطبيق SIRAJ، وربطه بـFlutter، وبناء APK، وتشغيل النموذجين واختبار التكامل الفعلي قدر الإمكان، ثم رفع التغييرات في Pull Request قابل للمراجعة.**

لا تعتبر المهمة مكتملة لمجرد إنشاء ملفات Kotlin أو MethodChannel أو نجاح flutter analyze.

يجب أن تثبت أن المحرك موجود داخل تطبيق Android، وأن Flutter يستطيع استدعاءه، وأن Native Runtime يستطيع تحميل النماذج وإرجاع نتائج حقيقية.

---

# 1. المستودع ونقطة البداية

المستودع الوحيد المسموح بالعمل عليه:

https://github.com/shehab5552/siraj-codex

الحالة المرجعية التي تم التحقق منها:

- main:
  `651af0d62d05761c80d9a8cbc9d1f51b836929eb`
- B-07 branch:
  `codex/b07-independent-download-01`
- B-07 HEAD:
  `208511419bea03600793a24125795fcf3780b1bc`
- PR #3:
  https://github.com/shehab5552/siraj-codex/pull/3
- PR #3 مفتوح وغير مدمج وقت إعداد هذا التكليف.

قبل أي تعديل:

1. نفّذ Git Fetch.
2. افحص الحالة الفعلية للفرع وPR #3.
3. تأكد من عدم وجود تغييرات غير ملتزم بها.
4. اقرأ تقرير B-07 كاملًا.
5. اقرأ RESOURCE_INTEGRATION_READINESS.md.
6. افحص الكود الحالي قبل تحديد الملفات التي ستتغير.

**استراتيجية Git:**

- إذا ظل PR #3 مفتوحًا وغير مدمج، أنشئ فرع B-08 من آخر HEAD معتمد لفرع B-07.
- اجعل PR الخاص بـB-08 يستهدف فرع B-07، حتى لا تعيد إدخال تغييرات B-07 في PR جديد إلى main.
- إذا كان PR #3 قد دُمج بالفعل، ابدأ من main المحدث واستهدف main.
- لا تحذف الفرع السابق.
- لا تستبدل PR #3.
- لا تنفذ Merge إلى main دون موافقة صريحة.
- لا تعمل على مستودع siraj-p0 أو أي مستودع آخر.

---

# 2. المراجع والملفات الإلزامية

اقرأ الملفات التالية:

`docs/reports/B-07_RESOURCE_INTAKE_AND_DOWNLOAD_01_AR.md`

`docs/architecture/RESOURCE_INTEGRATION_READINESS.md`

`docs/qa/b07-resource-intake/aar-inspection.txt`

`lib/features/resources/resource_format_preflight.dart`

`lib/features/resources/resource_download_validator.dart`

`lib/features/resources/resource_validation_contracts.dart`

`lib/features/resources/rag_candidate_contract.dart`

`lib/features/resources/download_service.dart`

`lib/features/resources/download_staging.dart`

`lib/data/resource_repository.dart`

`lib/data/conversation_repository.dart`

`lib/features/chat/conversation_draft_controller.dart`

`lib/features/chat/chat_page.dart`

`android/app/src/main/kotlin/com/example/siraj/MainActivity.kt`

`android/app/build.gradle.kts`

`android/settings.gradle.kts`

`android/gradle/wrapper/gradle-wrapper.properties`

`android/app/src/main/AndroidManifest.xml`

اقرأ أيضًا ملفات الاختبارات المرتبطة بهذه الطبقات.

لا تنشئ تنفيذًا موازيًا لخدمة موجودة بالفعل.

---

# 3. الموارد المعتمدة للاختبار الهندسي

مصدر الموارد:

https://github.com/shehab5552/siraj-codex/releases/tag/siraj-ai-resources-staging-v1

هذه الموارد STAGING للاختبارات الهندسية، وليست Production Approved.

| Artifact | Expected Size | SHA-256 |
|---|---:|---|
| litertlm-android-0.19.0.aar | 21,197,249 | e5c7a86048225efba8ab6d35fcd91f5870c86c65ca2538c07c3c1f63d02efa2b |
| Qwen3-0.6B.litertlm | 613,722,264 | c5f39b4191926786c3e6668b62af4d6eb15248dfc7a5348252a9b406f33f2108 |
| embeddinggemma-2-text-270m.litertlm | 164,626,432 | 2d079ee2f6f066b1f368e8d7c819f55214eaef1d0513b312321901f30ab286fb |
| Biology.zip | 873,028 | 8111e6cedd0a045e3368b02905ac2a15776e850ec50ea54794c32e3bdf6c015c |

تحقق من البصمات والأحجام الفعلية قبل استخدام الملفات.

ممنوع إضافة AAR أو النماذج أو ZIP إلى Git.

لا تضع روابط Release التجريبية داخل إعدادات التطبيق الإنتاجية.

تحقق من تراخيص الأوزان والنماذج قبل تشغيلها أو إعادة توزيعها. إذا تعذر إثبات السماح باستخدامها، افصل اختبار البناء عن اختبار الاستدلال وسجل القيد بوضوح.

---

# 4. المرحلة الأولى — حل توافق AAR وأدوات البناء

هذه هي أول بوابة تنفيذ.

المشكلة المثبتة في B-07:

| المكون | الإصدار الحالي |
|---|---|
| LiteRT-LM | 0.19.0 |
| Kotlin Gradle Plugin | 2.2.20 |
| Android Gradle Plugin | 8.11.1 |
| Gradle | 8.14 |
| Java Target | 17 |
| AAR Java Class Major | 65 (Java 21) |
| Kotlin Metadata | 2.4.0 |

المشكلة:

Kotlin Compiler 2.2.20 رفض قراءة Metadata 2.4.0.

لا تستخدم:

- `-Xskip-metadata-version-check`
- تعديل Metadata يدويًا.
- حذف أو إخفاء أخطاء التوافق.
- تعطيل D8/R8.
- تغيير إصدارات جميع الأدوات عشوائيًا.
- استبدال LiteRT-LM بمحرك آخر.

## 4.1 افحص Maven

تحقق من الإصدار الثابت:

`com.google.ai.edge.litertlm:litertlm-android:0.19.0`

المصدر:

https://maven.google.com/

المطلوب:

1. تنزيل POM الفعلي.
2. فحص التبعيات المباشرة والانتقالية.
3. تنزيل AAR من Maven.
4. مقارنة SHA-256 مع AAR الموجود في Release.
5. التحقق من أن الإصدار المنشور هو الإصدار نفسه فعلًا.
6. تثبيت الإصدار صراحةً.

لا تستخدم:

`latest.release`

إذا لم يكن POM متاحًا، لا تفترض وجود التبعيات تلقائيًا.

## 4.2 اختبر مساري التوافق

اختبر المسارين التاليين عمليًا:

**المسار A — Kotlin Compatibility**

- تحديد إصدار Kotlin Compiler القادر على قراءة Metadata 2.4.0.
- التحقق من توافقه مع AGP وGradle وFlutter Gradle Plugin.
- إجراء Compile Probe مستقل.
- بناء التطبيق كاملًا بعد التوافق.
- عدم ترقية الأدوات إلا بالحد الضروري.

**المسار B — Java Interoperability**

اختبر إنشاء Java Facade للوصول إلى الواجهات العامة في AAR دون أن يضطر Kotlin 2.2.20 إلى تحليل Metadata 2.4.0.

تحقق فعليًا من:

- Java 21 bytecode compatibility.
- D8.
- R8.
- Android packaging.
- JNI loading.
- Runtime execution.

لا تعتبر نجاح javac وحده إثباتًا لنجاح Android.

## 4.3 اختيار المسار

اختر أقل المسارات تغييرًا وأكثرها ثباتًا، بشرط اجتياز جميع اختبارات البناء والتشغيل.

إذا لم ينجح أي مسار، افحص إمكانية Source Build باستخدام إصدار/Commit رسمي متوافق مثبت المصدر.

لا تبنِ من Commit عشوائي ولا تدّعِ أن Source Build مطابق لـAAR دون إثبات.

**شرط اجتياز المرحلة:**

- Dependency graph موثق.
- Metadata compatibility محلولة.
- Java 21 bytecode مقبول من Android toolchain.
- Debug build ناجح.
- Release build ناجح.
- لا توجد أخطاء ClassNotFound أو Missing Dependencies.

---

# 5. المرحلة الثانية — بناء Native Runtime حقيقي

أنشئ Native Runtime منظمًا داخل Android Module.

المسؤوليات المطلوبة:

1. Engine Initialization.
2. LLM Model Loading.
3. Conversation Creation.
4. System Instruction.
5. Text Generation.
6. Streaming Responses.
7. Generation Cancellation.
8. Embedding Engine Initialization.
9. Query Embedding.
10. Resource Lifecycle.
11. Error Handling.
12. Native Memory Management.

استخدم واجهات LiteRT-LM الحقيقية التي تم التحقق منها في AAR.

واجهات API التي سبق فحصها تشمل:

- `Engine`
- `EngineConfig`
- `Conversation`
- `ConversationConfig`
- `Message`
- `Content`
- `Content.Text`
- `MessageCallback`
- `EmbeddingEngine`
- `EmbeddingEngineConfig`
- `EmbeddingOptions`
- `EmbeddingResponse`
- `InputData`

لكن أعد التحقق من التواقيع الفعلية في الإصدار الذي ستربطه.

## 5.1 استخراج الإجابة

هذه نقطة إلزامية.

ممنوع استخراج إجابة النموذج باستخدام:

`conversation.sendMessage(input).toString()`

استخدم Message الفعلية.

استخرج النص من:

`Message.contents.contents`

ثم اجمع محتوى:

`Content.Text.text`

تعامل مع أنواع Content الأخرى بصورة صريحة، ولا تحول كائن Message كاملًا إلى نص باعتباره إجابة.

يجب أن تكون النتيجة التي تعود إلى Flutter هي النص الفعلي الذي أنتجه النموذج.

## 5.2 Streaming

استخدم واجهة Streaming الرسمية إن كانت متاحة ومثبتة في AAR.

- استقبال أجزاء الإجابة.
- إرسالها إلى Flutter بترتيبها.
- دعم إلغاء التوليد.
- منع استقبال نتائج قديمة بعد إلغاء الطلب.
- التعامل مع أخطاء Callback.
- إنهاء الطلب مرة واحدة فقط.

لا تحجب Android Main Thread.

استخدم Background Executor أو Coroutine مناسبًا.

## 5.3 Lifecycle

يجب أن تكون ملكية الموارد واضحة:

- Engine واحد لكل جلسة Runtime وفق التصميم المعتمد.
- Conversation مرتبطة بعمر Engine.
- EmbeddingEngine مستقل عن LLM Engine.
- إغلاق الموارد عند Dispose.
- منع تهيئة المحرك مرتين.
- منع الاستخدام بعد الإغلاق.
- منع عمليات متزامنة غير مدعومة.
- معالجة إلغاء العمليات أثناء الإغلاق.

لا تحتفظ بالنماذج في الذاكرة بلا حاجة.

قس الذاكرة عند تحميل النموذجين، ولا تفترض أن إبقاء Embedding وLLM محملين معًا آمن على الجهاز المستهدف.

---

# 6. المرحلة الثالثة — Flutter Native Bridge

اربط Native Runtime بتطبيق Flutter الحالي.

لا تنشئ تطبيق Android تجريبيًا منفصلًا وتعتبره إنجازًا.

أنشئ طبقة واضحة داخل مشروع SIRAJ، مع واجهة Dart مستقلة عن تفاصيل Kotlin.

التصميم المطلوب:

Flutter UI
↓
Tutor / AI Application Service
↓
AiRuntimeClient
↓
MethodChannel + EventChannel
↓
Native Runtime Manager
↓
LiteRT-LM AAR
↓
JNI / Native Engine

## 6.1 MethodChannel

أنشئ Channel بإصدار واضح، مثل:

`siraj/ai_runtime/methods_v1`

يجب أن يدعم:

- initializeLlm
- generate
- cancelGeneration
- closeLlm
- initializeEmbedding
- embed
- closeEmbedding
- getRuntimeStatus

## 6.2 EventChannel

أنشئ:

`siraj/ai_runtime/events_v1`

ليعيد أحداث التوليد:

- generationStarted
- generationChunk
- generationCompleted
- generationFailed
- generationCancelled

اربط كل عملية بـrequestId.

لا تسمح باختلاط أحداث عمليتين مختلفتين.

## 6.3 Flutter Client

أنشئ Dart Interface مثل:

`AiRuntimeClient`

مع تنفيذ:

`MethodChannelAiRuntimeClient`

يجب أن تكون الواجهة:

- Typed.
- قابلة للاختبار.
- مستقلة عن Widgets.
- واضحة في أخطائها.
- تدعم Cancellation.
- تدعم Streaming.
- لا تحتوي مسارات ملفات عشوائية.

لا تسمح لـFlutter بإرسال مسار مطلق اعتباطي لتحميل أي ملف.

استخدم Resource Resolver موثوقًا من داخل التطبيق، ولا تحمل إلا ملفات موجودة في مسار التطبيق المسموح بها واجتازت فحوص الهوية والسلامة.

إذا لم توجد بعد آلية اعتماد Resource، استخدم مسار اختبار معزولًا Debug/Test Only، ولا تقدمه باعتباره مسار إنتاج.

## 6.4 MainActivity

الملف الحالي:

`android/app/src/main/kotlin/com/example/siraj/MainActivity.kt`

يسجل بالفعل:

- SirajSecureSessionChannel
- SirajDownloadStorageChannel

أضف AI Runtime Channel دون حذف أو تعطيل أي Channel قائم.

حافظ على:

- configureFlutterEngine
- cleanUpFlutterEngine
- Dispose لجميع الموارد
- عدم تغيير Authentication أو Keystore.

---

# 7. المرحلة الرابعة — LiteRT-LM Resource Format Integration

يوجد حاليًا:

`ResourceFormatPreflight`

ويتعرف على GGUF v2/v3، بينما النماذج المستلمة بصيغة:

`.litertlm`

ممنوع تجاوز فاحص GGUF أو تعطيل التحقق منه.

المطلوب:

1. بناء فاحص متخصص لصيغة LiteRT-LM.
2. الاستناد إلى Schema وContainer Format الرسميين.
3. التحقق من Header.
4. التحقق من حدود الأقسام والـOffsets.
5. التحقق من سلامة الأقسام اللازمة.
6. رفض الملفات المبتورة أو المتعارضة.
7. ربط فحص الصيغة بالـRuntime Compatibility.
8. اختبار Model Load فعليًا كدليل منفصل.

ادمج الفاحص ضمن مسار التحقق الحالي.

حافظ على دعم GGUF إن كان مطلوبًا في العقود الحالية.

لا تجعل التعرف على Header دليلًا على أن النموذج قابل للتشغيل.

لا تمنح READY أو ACTIVE لمجرد نجاح هذا الفاحص.

---

# 8. المرحلة الخامسة — Embedding Runtime وG2

اربط:

`embeddinggemma-2-text-270m.litertlm`

باستخدام:

`EmbeddingEngine`

و:

`EmbeddingEngineConfig`

و:

`InputData`

و:

`EmbeddingOptions`

واستخرج:

`EmbeddingResponse.embedding`

## الاختبارات المطلوبة

- تحميل Embedding Model فعليًا.
- تنفيذ Query Embedding فعلي.
- فحص عدد الأبعاد.
- فحص finite values.
- رفض المتجه الصفري.
- قياس L2 norm.
- تسجيل زمن التهيئة.
- تسجيل زمن الاستعلام.
- اختبار عدة استعلامات عربية وإنجليزية مناسبة.

متجهات Biology الحالية مصرح بأنها 768 بُعدًا.

لذلك يجب إثبات أن خرج Query Embedding متوافق معها فعليًا، وليس افتراض ذلك.

## 8.1 سياسات Embedding

يوجد في تقرير B-07 عدد من المسائل غير المحسومة:

- Pooling.
- Normalization.
- Query Prefix.
- Document Prefix.
- Tokenizer parity.
- اختلافات في أوصاف التطبيع بين الوحدتين.

لا تختَر قيمًا من عندك.

ابحث عن مرجع رسمي أو سجل هندسي معتمد يثبت القيم الصحيحة.

لا تضع:

`normalize = true`

أو:

`normalize = false`

دون إثبات أن الاختيار يطابق بناء متجهات Dataset.

لا تغير Embedding Vectors الحالية لمعالجة عدم التوافق.

## 8.2 Biology Pilot

استخدم وحدتي الأحياء 01 و02 للاختبارات الهندسية المعزولة فقط.

لا تغير شرط Production RAG الذي يتطلب خمس مواد وShared Embedding واحدًا.

لا تعتبر وحدتي Biology Pilot بديلًا عن خمس Subject Packs.

قبل إعلان G2 PASS يجب إثبات:

- توافق Query Embedding مع Document Embeddings.
- أبعاد 768 متوافقة.
- سياسة Prefix صحيحة.
- Pooling وNormalization صحيحان.
- Retrieval نتائجها متسقة مع مرجع موثوق.
- IDs والمصادر قابلة للتتبع.

إذا لم تتوفر مراجع parity أو Source Mapping معتمدة، نفذ ما يمكن إثباته، ثم صنف الجزء المتبقي BLOCKED.

لا تخترع معرّفات Source أو Lesson أو Pack.

---

# 9. المرحلة السادسة — LLM Runtime وG3

اربط:

`Qwen3-0.6B.litertlm`

باستخدام:

`Engine`

و:

`EngineConfig`

و:

`Conversation`

و:

`ConversationConfig`

نفذ الاختبارات التالية:

1. Engine Initialization.
2. Model Loading.
3. Conversation Creation.
4. System Instruction.
5. Text Generation.
6. Streaming.
7. Cancellation.
8. Error Handling.
9. Dispose.
10. Reload.

يجب أن تعود إجابة حقيقية غير فارغة من النموذج.

اختبر عدة استعلامات، وسجل:

- Initialization Time.
- First Token Latency.
- Total Generation Time.
- Tokens/Second إن أمكن قياسه بدقة.
- Peak Memory.
- Failure Rate.
- Cancellation Behavior.

لا تضع أرقامًا تقديرية.

## 9.1 ربط LLM بـRAG

لا تربط LLM مباشرة بـChatPage لتوليد إجابات تعليمية غير مسندة.

يجب أن يكون التدفق:

User Question
↓
Session Validation
↓
Query Embedding
↓
Local Retrieval
↓
Evidence Validation
↓
System Instruction + Retrieved Evidence
↓
Local LLM Generation
↓
Grounding / Citation Validation
↓
Save Assistant Message
↓
Display Answer

التزم ببوابة الأدلة المعتمدة.

إذا لم تتوفر أدلة كافية، لا تختلق مصادر.

يمكن تقديم إجابة جزئية فقط وفق سياسة FR-05 المعتمدة، دون اختلاق المراجع.

إذا تعذر التحقق من مصدر أو سياسة علمية، لا تجعل ذلك يتجاوز Evidence Gate.

## 9.2 اختبار G3

اختبر:

- إجابة مدعومة بالمصادر.
- رفض السؤال الذي لا توجد له أدلة كافية.
- عدم اختلاق Source References.
- صحة إسناد المراجع.
- عدم تسريب بيانات محادثة سابقة.
- Cancellation.
- إعادة تحميل المحرك.
- العمل دون اتصال بالإنترنت بعد تجهيز الموارد.

لا تعلن G3 PASS دون تشغيل هذه الاختبارات على Runtime حقيقي وبيانات موثقة.

---

# 10. المرحلة السابعة — ربط Chat في Flutter

الوضع الحالي:

`ChatPage` يحفظ السؤال الأول محليًا فقط، ولا يولد إجابة.

`ConversationDraftController` ينشئ المحادثة عند أول رسالة صالحة.

`ConversationRepository` يحتوي على:

- saveFirstUserMessage
- appendAssistantMessage
- listConversations
- listMessages

المطلوب ربط Tutor Service بالمسار الحالي دون إعادة بناء نظام المحادثات.

عند إرسال أول سؤال:

1. التحقق من الجلسة.
2. حفظ السؤال الأول ذريًا وفق العقد الحالي.
3. تنفيذ Retrieval وEvidence Gate.
4. إرسال السياق إلى Native LLM عند نجاح الشروط.
5. التحقق من نتيجة التوليد.
6. حفظ إجابة المساعد ومراجعها.
7. عرض الإجابة.

عند إرسال سؤال جديد داخل المحادثة:

- لا تنشئ محادثة جديدة.
- احفظ رسالة المستخدم وفق العقد الحالي.
- اربطها بالمحادثة نفسها.
- أعد التحقق من الجلسة.
- نفذ Retrieval من الموارد المحلية.
- احفظ إجابة المساعد بعد التحقق.

إذا احتجت إضافة دالة لحفظ رسائل المستخدم اللاحقة، استخدم الجدول الحالي دون Migration.

لا تغير:

- الحد الأقصى 10 محادثات.
- ترتيب المحادثات.
- Stable IDs.
- آلية حذف أقدم محادثة.
- حساب المستخدم الواحد.
- Persistent Login.

لا تسمح بحفظ إجابة غير متحققة.

إذا لم تجتز G2/G3، أبقِ المسار الإنتاجي مغلقًا أمام الإجابات غير المسندة، حتى لو نجح اختبار LLM المستقل.

لا تستخدم Fake Answers أو Mock Retrieval في Release.

---

# 11. القيود المعمارية والأمنية

التزم بنطاق SIRAJ P0.

ممنوع:

- Remote Backend.
- Cloud LLM.
- إرسال أسئلة الطلاب إلى الإنترنت.
- إعادة كتابة DownloadService.
- إضافة نظام تنزيل موازٍ.
- تغيير Auth أو PBKDF2 أو Keystore.
- Database Migration.
- إضافة جداول غير معتمدة.
- تخزين Models داخل Git.
- تخزين بيانات الطلاب في Logs.
- منح READY تلقائيًا.
- منح ACTIVE تلقائيًا.
- منح RAG_READY تلقائيًا.
- تغيير سياسة Retrieval دون مرجع.
- إضافة Question Bank.
- إضافة Quiz Persistence.
- إعادة تصميم واجهات التطبيق دون حاجة.
- إدخال ميزات خارج P0.

لا تسجل نص السؤال أو الإجابة أو Session Nonce أو مسارات Signed URLs في Logs.

استخدم Typed Errors ولا تعرض Stack Traces للمستخدم.

لا تحجب Main Thread.

لا تسمح باستخدام ملفات خارج مجلدات التطبيق الموثوقة.

---

# 12. المرحلة الثامنة — الاختبارات والبناء

نفذ الاختبارات على مراحل.

## Flutter

```powershell
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
```

يجب ألا تتسبب التغييرات في كسر اختبارات B-07 الحالية.

## Android

```powershell
cd android
.\gradlew.bat :app:dependencies
.\gradlew.bat :app:assembleDebug
.\gradlew.bat :app:assembleRelease
```

## Flutter APK

```powershell
cd ..
flutter build apk --debug
flutter build apk --release
```

تحقق من APK الفعلي:

- وجود LiteRT-LM classes.
- وجود liblitertlm_jni.so.
- ABI الصحيح.
- عدم فقدان المكتبات بعد R8/D8.
- عدم وجود Missing Classes.
- نجاح تشغيل التطبيق.

افحص Native Libraries باستخدام `readelf` أو `llvm-readelf`، ولا تعتمد على أسماء مجلدات APK فقط.

## Android Runtime Tests

استخدم Emulator أو Android Device متاحًا فعليًا.

نفذ:

- AAR Loading.
- JNI Loading.
- Engine Initialization.
- LLM Generation.
- Embedding Generation.
- Cancellation.
- Dispose/Reload.
- Offline Test.

إذا توفر جهاز arm64 فعلي، اختبر عليه.

إذا لم يتوفر، اختبر على Emulator يدعم ABI الموجودة في AAR، وسجل أن اختبار الجهاز الفعلي ما زال Pending.

لا تدّعِ اختبار Samsung إذا لم يكن متصلًا وتم تشغيل الاختبارات عليه بالفعل.

---

# 13. CI

جهز GitHub Actions workflow مستقلًا للتحقق من B-08.

يجب أن يشمل:

- Flutter locked dependencies.
- Format.
- Analyze.
- Flutter tests.
- Gradle dependency resolution.
- Android Debug Build.
- Android Release Build.
- فحص APK Native Libraries.

لا تجعل CI يعتمد على ملفات شخصية أو مسارات جهاز المالك.

لا تضع نماذج ضخمة داخل GitHub Repository.

إذا تعذر تشغيل Inference في CI بسبب موارد البيئة، افصلها بوضوح عن اختبارات البناء، ولا تحوّلها إلى PASS.

---

# 14. اختبارات الأمان والاستقرار

أضف اختبارات للحالات التالية:

1. AAR dependency missing.
2. Kotlin Metadata mismatch.
3. JNI library missing.
4. Unsupported ABI.
5. Invalid model path.
6. Corrupted model.
7. Model initialization failure.
8. Concurrent initialization.
9. Concurrent generation.
10. Generation cancellation.
11. Activity cleanup.
12. Engine disposed during generation.
13. Embedding output with wrong dimension.
14. NaN/Infinity embedding.
15. Zero embedding.
16. Stale request event.
17. Flutter channel exception.
18. Session expired during generation.
19. Insufficient disk space.
20. Offline execution.

اختبارات Fake Engine مسموحة لاختبار العقود وإدارة الحالات، لكنها لا تُحتسب إثباتًا لتشغيل النموذج.

---

# 15. Git وPull Request

اسم الفرع:

`codex/b08-litertlm-android-runtime-01`

نفذ Commits صغيرة وواضحة.

مثال:

- `build(android): resolve LiteRT-LM 0.19.0 compatibility`
- `feat(android): add LiteRT-LM native runtime`
- `feat(flutter): add typed AI runtime client`
- `feat(resources): validate LiteRT-LM artifacts`
- `feat(chat): integrate grounded local tutor`
- `test(android): add runtime integration coverage`

افتح PR جديدًا مرتبطًا بـB-08.

إذا ظل PR #3 مفتوحًا، اجعل PR B-08 يستهدف فرع B-07.

لا تدمج PR #3 أو PR B-08 إلى main تلقائيًا.

لا تغلق PR #3.

لا ترفع APK أو نماذج أو ملفات ZIP الكبيرة إلى Git.

ارفع APK كـGitHub Actions Artifact عند توفر ذلك.

---

# 16. التقرير النهائي

أنشئ:

`docs/reports/B-08_LITERT_LM_ANDROID_RUNTIME_INTEGRATION_01_AR.md`

ويحتوي على:

1. Git Baseline.
2. Dependency Compatibility Investigation.
3. Kotlin/Java Compatibility Resolution.
4. Maven/POM Dependency Audit.
5. Android Gradle Changes.
6. Native Runtime Implementation.
7. Flutter Bridge Implementation.
8. LLM Model Loading and Generation Results.
9. Embedding Model Results.
10. Resource Format Validator.
11. Biology G2 Results.
12. Grounded RAG G3 Results.
13. Chat Integration.
14. Memory and Performance Measurements.
15. Security Review.
16. Flutter Test Results.
17. Android Build Results.
18. APK Inspection.
19. Device/Emulator Test Results.
20. CI Results.
21. Known Limitations.
22. Remaining Blockers.
23. Commit SHAs.
24. Pull Request URL.

لكل نتيجة استخدم حالة واحدة واضحة:

- PASS
- FAIL
- BLOCKED
- NOT RUN
- PENDING DEVICE TEST

يجب إرفاق:

- الأوامر المنفذة.
- النتائج الفعلية.
- المسارات.
- إصدارات الأدوات.
- SHA-256 للـAPK.
- الأدلة المهمة.
- الأخطاء إن وجدت.

لا تكتب PASS دون دليل.

---

# 17. شروط القبول النهائية

لا تعتبر B-08 مكتملة إلا بعد إثبات النقاط التالية:

| المعيار | شرط القبول |
|---|---|
| AAR Compatibility | توافق مثبت دون تجاوز فحص Metadata |
| Dependencies | جميع التبعيات مثبتة ومحلولة |
| Android Build | Debug وRelease ناجحان |
| Native Integration | المحرك جزء من Android App |
| JNI | المكتبة الأصلية محملة فعليًا |
| Flutter Bridge | Flutter يستدعي Native Runtime بنجاح |
| LLM | Qwen3 يحمل ويولد إجابة حقيقية |
| Response Extraction | النص مستخرج من Content.Text |
| Embedding | EmbeddingGemma يولد متجهًا حقيقيًا متوافقًا |
| G2 | Retrieval parity مثبت على Biology Pilot |
| G3 | Grounded answers وEvidence Gate مجتازان |
| Chat | تدفق المحادثة يعمل دون تجاوز P0 |
| Offline | الاستدلال المحلي يعمل دون شبكة |
| Regression | اختبارات B-07 وبقية الاختبارات ناجحة |
| PR | التغييرات مرفوعة في PR قابل للمراجعة |

إذا تعذر إثبات G2 أو G3 بسبب نقص IDs أو سياسات Retrieval أو مصادر علمية معتمدة، لا تختلق بيانات لإكمال الاختبار.

استمر في تنفيذ Native Runtime وFlutter Bridge والبناء واختبارات LLM وEmbedding المستقلة، لكن أبقِ Chat Grounding غير مفعّل، وصنّف G2/G3 بوضوح على أنهما BLOCKED.

لا تساوِ بين نجاح Runtime ونجاح RAG.

ولا تساوِ بين نجاح APK ونجاح الاستدلال.

---

# 18. تعليمات التنفيذ النهائية

ابدأ الآن.

لا تكتفِ بقراءة الملفات أو كتابة خطة.

لا تتوقف بعد اكتشاف خطأ Kotlin الأول.

اختبر مسارات التوافق المسموح بها، واختر المسار الصحيح بالدليل، ثم نفذ الدمج.

إذا احتجت إلى تعديل Gradle أو Kotlin أو Android Manifest، نفذ التعديل الضروري فقط واختبر أثره على المشروع كاملًا.

إذا واجهت عائقًا، حاول حله هندسيًا دون استخدام تجاوزات غير آمنة.

إذا كان العائق ناتجًا عن غياب بيانات أو صلاحيات أو جهاز، لا تخترع بديلًا، وأكمل بقية الأجزاء الممكنة.

**الأولوية هي الحصول على تطبيق Android حقيقي يحتوي LiteRT-LM Native Runtime مرتبطًا بـFlutter، ويبني بنجاح، ويجري استدلالًا محليًا مثبتًا، مع إبقاء RAG والإجابات التعليمية مغلقة حتى اجتياز شروط الأدلة العلمية.**

لا تعلن اكتمال المهمة حتى تنتهي من البناء والاختبارات والمراجعة المستقلة وتقديم الأدلة.

ابدأ التنفيذ الفعلي الآن.
