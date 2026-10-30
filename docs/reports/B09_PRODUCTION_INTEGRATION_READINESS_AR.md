# B-09 — جاهزية التكامل الإنتاجي والمدخلات الناقصة

التاريخ المرجعي:24 أكتوبر2026، Asia/Aden. هذه **مصفوفة أدلة ومتطلبات** وليست شهادة جاهزية إنتاجية. المراجع: P0 v1.0.1 §§6.5–6.9،7.4.1،9.4،10.3،14،G2/G3 وTC13/20/26/32؛ خطة B المعدلة B-07/08/09/12. لم يُفتح siraj-p0 أو الكمبيوتر المحلي.

## الحالة المثبتة قبل التغيير

| الاعتماد | المرجع الذي فُحص | ما ثبت وما ينقص |
|---|---|---|
| main |651af0d62d05761c80d9a8cbc9d1f51b836929eb|لم يتغير؛ PR2 مدمج سابقًا|
| B07 / PR3 مفتوح |27ff8e5265e03092ccf84fedeae39d5bb4d008a7|HTTPS/Resume/Staging/byte validators موجودة؛ Downloaded ليس READY|
| B08 / PR4 مسودة مفتوحة |306b3a69bb855a49b3bf01bbb1b6bd30a1c087f5|TutorPort/SourceResolver/guards/history/persistence؛ لا Native AI|
| B09 / PR7 مفتوح |dd1d7c42af0ef0d727c9ae6b70dfdfc17d53b994|ModelRuntime lifecycle وPinnedRetriever وTutor pipeline بعقود سياسات؛ QueryEmbedder كان واجهة فقط|
| B12 / PR9 مفتوح |ebe1a11220466e0681df88d5fb1209da8fd4e9d9|Promotion/SQLite pointer/file pins/recovery؛ Catalog/semantic+runtime validators غير متاحة افتراضيًا|

فرع هذه الدفعة `codex/b09-shared-embedding-readiness` مبني على PR7 ويستهدفه؛ لا Merge لأي PR ولا إعادة نسخ أعمال B12. اختبارات الأساس أُعيدت فعليًا:261 ناجحًا/0 فاشل/0 متخطى. Flutter3.38.5/Dart3.10.4؛ SQLite native مخبأة مطابقة SHA256 دون pubspec override.

## مصفوفة المدخلات والقبول

| المجال | المدخل الدقيق المطلوب | الدليل الحالي / الحالة | مالك المدخل ومعيار التحقق |
|---|---|---|---|
| Local LLM Runtime |اسم المشروع، إصدار/Commit build ثابت، ترخيص المحرك والتبعيات وشروط التوزيع، build/native-library hashes|ModelBackend عقد فقط؛ **غير مقدم/غير معتمد**|A؛ ترخيص ومصدر build قابلان للمراجعة، لا اختيار runtime من طرف Flutter|
| Android Bridge |FFI/MethodChannel ABI/API، قائمة ABI الفعلية المدعومة وmin/target SDK وNDK/native dependencies، cancel/unload/OOM/thread rules|لا Native bindings معتمدة في B09؛ APK build السابق ليس هذا الدليل|A+B؛ load/generate/cancel/unload على جهاز6GB وبنفس native build؛ لا نفترض arm64 أو أي ABI من دون الدليل|
| هوية LLM |model_id/model_version، مصدر/ترخيص الأوزان، artifact revision/path/size/SHA256، الصيغة/quantization المراجعة|ModelConfig يفرض حقول الهوية والحجم/Hash وGGUF preflight؛ **لا ملف نموذج معتمد**|A؛ hash/size ثم parser/load فعلي، لا يكفي GGUF header|
| Prompt/Tokenizer LLM |context_length، prompt_profile_id/template/tokenizer/generation defaults مراجعة، token counting الفعلي|PromptPolicy وModelCapabilities عقود؛ لا سياسة أو tokenizer فعلي معتمد|A؛ لا character-count بديلًا عن tokens ولا profile تخميني|
| Shared Embedding Runtime |build/revision/license/ABI مستقل أو مشترك بدليل، preprocessing exact config، cancellation/lifetime|أضيف ManagedQueryEmbedder؛ Backend الافتراضي unavailable؛ **لا native embedding فعلي**|A+C؛ تشغيل artifact/config الفعليين ومقارنة vectors وفق معيار مراجع|
| ملفات Shared Embedding |model_id/artifact_revision وملف النموذج وكل sidecar/config/tokenizer path+size+SHA256 داخل Revision الممسوكة|SharedEmbeddingConfig/EmbeddingArtifact وbyte checks منفذة؛ **التوقعات والملفات الإنتاجية غير مقدمة**|C+A؛ resolver من Catalog معتمد، لا توقعات من metadata منزل غير موثوق|
| توافق Vector |dataset_revision، embedding model/artifact/path، dimension، tokenizer_id، pooling_id، normalization_id|مطابقة كاملة في Binding وقدرات Backend وIndexBinding؛ لا تعديل تلقائي للـvector|A+C؛ نفس القيم المراجعة لكل index؛ ممنوع تبديل embedder أو normalization افتراضي|
| Biology Fixture |fixture_id وRevision، درس/Chunks/Source IDs مراجعة، metadata، كل files/hashes وأدلة SourceRegister|الموجود test doubles صناعية؛ **لا Biology fixture علمية معتمدة في الملفات المراجعة**|C؛ Debug/Test فقط، لا تحتاج الخمس ولا Product pointer|
| Index |format/type/version/runtime reader، pack IDs، dataset revision، vector settings، artifact hashes، row/chunk mapping|IndexPort عقد، PinnedRetriever يحمي الهوية؛ **لا parser/index فعلي معتمد**|C+A؛ فتح وفحص فهرس حقيقي وmetadata على الجهاز، لا index وهمي|
| مرجع Vector/جودة |نصوص Gold Queries وExpected Vectors أو بروتوكول reproducibility وسماحيات معتمدة، ranking/evidence gold|لا vectors مرجعية أو سماحية علمية معتمدة؛ **لا عتبة مخترعة**|A+C؛ اعتماد المعايير قبل Holdout، توثيق actual/expected/cannot-judge|
| Scope/Evidence/Answer |Scope resolution، حد Evidence وpartial policy، prompt/answer validation وسياسة المراجع|Ports لازمة ومحقونة، لا permissive defaults؛ التنفيذ الدلالي **غير مقدم**|A+C؛ Gold claims ومصادر تؤيدها فعليًا؛ IDs صحيحة ليست برهان Grounding|
| B12 lifetime adapter |ملكية file pin ثم Embedding/Index resources، root/config resolver، historical source revision policy|الطبقتان بعقدين مختلفين على فروع غير مدمجة؛ **لا wiring مجمع مُدّعى**|B+A+C؛ release file pin بعد actual runtime drain؛ لا مزج إصدارين؛ PR منفصل عند توفر base مناسب|
| Product Dataset |Catalog رسمي لخمس Packs وShared Embedder من عملية واحدة، manifests/schema/coverage/URLs/hashes، validator sample-query|B12 atomic mechanism فقط؛ **لا عملية إنتاجية مكتملة أو RAG_READY**|C+A+B؛ لا تساوي Biology-only/Fixture بشروط الخمس|
| Quiz |Few-shot مراجعة وNEW-items generation وQuestionValidator، answer specs وnumeric precision policy|B11 UI/RAM/contracts؛ المولد وسياسة precision غير متاحين افتراضيًا|A+C؛ محاولتان كحد أقصى، لا bank fallback، لا QuizAttempt في SQLite|
| Auth والجمع |تسوية B04/B08 في user_repository/conversation_repository/conversation_draft_controller، مع Keystore وحساب حقيقي|PR5/6 وPR4 منفصلة؛ بوابة Auth بقيت مغلقة؛ تعارضات سابقة موثقة|B؛ لا تسوية بدمج غير مفوض؛ يلزم acceptance للجلسة قبل G3|
| G2 |جهاز Android فعلي6GB، Android/ABI/build IDs، load/cancel/unload/OOM وcold/warm/peak RAM وvector/index evidence Offline|**لم يُنفذ**؛ Linux/Fakes/Compilation لا يحققونه|A+B+C؛ قياسات حقيقية دون اختراع حدود أداء|
| G3 بعد G2 |جلسة مستمرة، first USER atomic save، Biology retrieval→evidence→local LLM→answer/refusal/error→source→save/reopen Offline|**لم يُنفذ**؛ المنتج يظل fail-closed|A+B+C؛ نفس resource revisions وactual Android، fixture لا تغير Product Readiness|

## ما نُفذ في هذه الدفعة

`ManagedQueryEmbedder` ينفذ load/embed/unload وحالات التشغيل حول Backend محقون، مع فحص B07 الحقيقي لكل الملفات المعلنة وتطابق Binding كامل. `RuntimeOperationLane` يستخرج منطق الإلغاء/timeout/drain من ManagedModelRuntime لإعادة الاستخدام، دون خدمة مكررة أو تغيير واجهة Chat/Repository. vectors finite ودقيقة الأبعاد وimmutable؛ لا normalization علمية مفترضة. خطأ embedding تشغيلي typed ولا يصبح Refusal معرفيًا. قبل الاستفادة يلزم adapter أصلي ومورد مراجع؛ الافتراضي unavailable.

أرقام الاختبارات النهائية وGit/PR/CI ستثبت بعد انتهاء المراجعة والفحوص. لا ادعاء Product Ready أو G2/G3 أو نجاح Android حقيقي. لا تغيير Auth أو main أو المصدر الأصلي.

## الفحوص والمراجعة الفعلية

`flutter pub get --enforce-lockfile`:PASS،0.808ث. `flutter analyze --no-pub`:PASS دون ملاحظات،2.187ث. `flutter test --no-pub --machine`:**293 ناجحًا/0 فاشل/0 متخطى**،20.993ث؛32 جديدة فوق261 موروثة. الاختبارات تستخدم ملفات فعلية وHashes وفحص مسارات، وBackend صناعي عند الحد الأصلي فقط؛ لا Embedding علمية أو Android. اختبارات ModelRuntime القديمة الاثنا عشر نجحت بعد الاستخراج.

المراجعة المستقلة بمحوري المواصفة والمعايير للشجرة95a6297 أشارت إلى احتمال ترتيب whenIdle/state. لم تُعد ثلاثة اختبارات مباشرة إنتاج الخلل على التنفيذ الأصلي؛ لا يُدّعى إصلاح عطل مثبت أو RED→GREEN له. نُشر state/metrics عبر callbacks متزامنة قبل تحرير lane لإزالة الاعتماد على ترتيب callbacks؛ بعدها نجحت44 حالة lifecycle مركزة والفحص الكامل. هذه قاعدة تنفيذية للمحافظة على السلوك، لا قرار علمي؛ تكلفة الخطأ المحتملة regression في التتابع، ويغطيها تشغيل الاختبارات المذكور. محاولة RED أولى تداخلت مع تحرير الكود فاستُبعدت من أدلة الفشل؛ إعادة التشغيل على المصدر القديم مثبتة في QA. Qodo غير مثبت في PATH والمسار القياسي، ولذلك لم تُدّع مراجعته؛ المراجعتان المستقلتان منفذتان فعليًا.

الملفات الجديدة:runtime_operation_lane.dart،shared_embedding_runtime_contract.dart،managed_query_embedder.dart،test/b09_managed_query_embedder_test.dart،test/support/shared_embedding_fixture.dart،وثائق الخطة/المعمارية/المصفوفة/QA وworkflow خاص. المعدلة:managed_model_runtime.dart لإعادة استخدام lane،runtime_contract.dart لإضافة embeddingFailed،pipeline_tutor_port.dart لترجمتها إلى خطأ موارد تشغيلي. لا تعديل Chat UI/ConversationRepository/Auth/Android source/pubspec.

لم يفشل تنزيل جديد خلال فحوص هذه الدفعة. أعيد استخدام SQLite native المطابقة SHA256=b17729184e5a2818055ecbddd5ed6642521bfe6e56aafa472330e483c0e2e0d2. نجاح GitHub/pub لا يثبت حالة policy المرصودة unknown؛ لا تغيير سياسة شبكة أو تجاوز Proxy/TLS. CI يطلب APK بمعرف مستقل، وستسجل نتيجته الفعلية؛ ليس تشغيل AI على Android.
