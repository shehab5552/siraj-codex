# SIRAJ — B-08.1 Runtime Lifecycle Hardening

## 1. Executive Summary — الملخص التنفيذي

تسليم محدود داخل PR [#14](https://github.com/shehab5552/siraj-codex/pull/14)، على الفرع `codex/b08-litertlm-android-runtime-01`. نقطة البداية المتحقق منها `33c335485b959a394130f92940027ccaa9045729`، والتزام الإصلاح `4951875ae5ce09ff5ff396fca827428ab4f58de8`. أساس PR يبقى `codex/b07-independent-download-01` كما هو، و`origin/main` عند `651af0d62d05761c80d9a8cbc9d1f51b836929eb`. لا Merge أو Close أو Rebase أو Force Push. لم يُعدّل `main` أو PR #3.

أُصلحت دلالة الإلغاء وملكية Embedding عند فشل الإغلاق، وأضيف حاجز ملكية عبر إعادة إنشاء Activity. نتائج Linux الجديدة: Flutter **263/0/0**، Java **57/0**، Python **36/0**؛ ترتيب الأرقام Passed/Failed/Skipped عند توفره. نتائج التشغيل الجديد [CI 42301592619](https://github.com/shehab5552/siraj-codex/actions/runs/42301592619): Android **6/0/0**، Debug/Release **PASS**، JNI وتشغيل النماذج دون اتصال والإلغاء/reload **PASS**. لم تُستعر أعداد B-08 التاريخية.

## 2. Root Cause Analysis — السبب الجذري

**الإلغاء:** كانت `_cancel()` تنهي Stream محليًا وتحذف `_active` قبل رد Native، وكان `cancelActive()` يضع `cancelled=true` قبل استدعاء SDK. كان `finish()` يقدّم هذا العلم على النتيجة الفعلية، فيحوّل اكتمالًا طبيعيًا أو خطأً إلى إلغاء ناجح. كما كان Adapter يختزل `CancellationException` إلى `generationFailed`.

**Embedding:** كانت `requestClose(true)` و`closeIdle()` تمسحان المرجع قبل استدعاء `close()`؛ عند الرمي تضيع ملكية المقبض بينما قد يبقى Native حيًا. المصدر المثبت لـLiteRT-LM **0.19.0**: [EmbeddingEngine.kt، close](https://github.com/google-ai-edge/LiteRT-LM/blob/v0.19.0/kotlin/java/com/google/ai/edge/litertlm/EmbeddingEngine.kt#L236) يستدعي Native delete ثم يصفر handle. و[nativeDeleteEmbeddingEngine](https://github.com/google-ai-edge/LiteRT-LM/blob/v0.19.0/kotlin/java/com/google/ai/edge/litertlm/jni/litertlm.cc#L2185) يحذف المؤشر؛ لا يوجد ضمان transactional لإعادة المحاولة بعد استثناء. المسارات الدقيقة للمصدر مثبتة أيضًا في تقرير B-08 السابق؛ لا يُفترض أن `isInitialized` يثبت سلامة إعادة الحذف.

## 3. Before/After Behavior — قبل/بعد

| الحالة | سابقًا | الآن |
|---|---|---|
| قبول API الإلغاء | نهاية Flutter فورية | قبول فقط، Stream والملكية مستمران |
| API يرمي | قد يظهر cancelled رغم الفشل | `cancelFailed` مع Busy حتى Native terminal |
| cancel ثم onDone | cancelled | completed عند وجود نص صالح كامل |
| cancel ثم onError | cancelled | failed بالرمز المنقح، أو cancelled فقط لتأكيد SDK الحقيقي |
| Callback متزامن ثم API يرمي | تناقض ممكن | يسجل Worker فشل API قبل معالجة terminal |
| نص يصل بعد طلب cancel | يُسقط | يُحفظ حتى النهاية الفعلية؛ لا اقتطاع لنتيجة completed |
| Embedding close يرمي | المرجع مفقود | المرجع محفوظ، Quarantined، لا استخدام أو استبدال |
| Activity بديلة والطلب القديم عالق | حاجز خاص بكل Manager | حاجز Process Owner يمنع تجاوز الملكية |

## 4. Architecture Changes — المعمارية والملفات

نفس الحدود: Flutter → Method/EventChannel v1 → Java RuntimeManager → SDK/JNI. لا Backend أو Service جديد. لم تتغير نسخة SDK أو Thread Count أو CPU backend أو Model Configuration أو سياسات Embedding أو الاعتماديات.

- `RuntimeManager.java`: فصل cancelRequested/cancelFailure عن terminal؛ قفل ملكية process؛ إغلاق Embedding ثم مسح المرجع فقط عند النجاح؛ quarantine عند الفشل.
- `LiteRtBackend.java`: تحويل JVM `CancellationException` الرسمي إلى الرمز الموجود `cancelled`، دون كشف النص أو Throwable.
- `RuntimeFailure.java` و`ai_runtime_client.dart`: `cancelFailed` و`embeddingCloseFailed`، وتوثيق أن Future الإلغاء قبول فقط.
- `SirajAiRuntimeChannel.java`: إضافة حالة تشخيصية `embeddingQuarantined` إلى status مع إبقاء القنوات والأحداث وRequestOwnership كما هي.
- `method_channel_ai_runtime_client.dart`: انتظار Native terminal، توحيد طلبات cancel المتكررة، تمرير الخطأ المنقح، إغلاق Native عند dispose دون اختلاق cancelled، وإغلاق قبول العمل بعد تلف بروتوكول الأحداث.
- `grounded_tutor_service.dart`: معالجة فشل Future الإلغاء داخل hook ذي عائد void، مع انتظار terminal ونتيجة طلب cancel معًا، وحجب أي جواب لدور تخلى عنه المستخدم؛ و`chat_turn_coordinator.dart` يحافظ على الخطأ التشغيلي ولا يحوله إلى إلغاء ناجح.
- الاختبارات: `RuntimeLifecycleHardeningTest.java` الجديد، تحديث توقعين في `RuntimeManagerTest.java`، اختبارات Client/Tutor، تقوية تطابق terminal في `b08_real_models_test.dart`، وإضافة runner إلى `run_core_tests.sh`.

القائمة الكاملة في `docs/qa/b08-1-runtime/files-changed.txt`. لا تغييرات UI/Auth/SQLite/Dataset/RAG/DownloadService أو Production Catalog.

## 5. Cancellation State Machine — آلة حالات الإلغاء

`ACTIVE → CANCEL_REQUESTED → انتظار Native terminal`.

نجاح API لا يحرر active أو Conversation. فشل API يعيد `cancelFailed` ويبقي الطلب مملوكًا؛ لا يعيد استدعاء API تلقائيًا. Native `done` ينتج completed فقط مع نص غير فارغ؛ Native failure ينتج failed؛ Native cancellation المؤكد ينتج cancelled ما لم يكن API قد فشل، وعندها ينتج failed/cancelFailed. فشل تنظيف Conversation لا يُخفى بإعلان إلغاء ناجح.

CAS يحجز أول Callback نهائي فقط، وWorker ينفذ finish مرة واحدة. لا callback نهائي يعني Busy/Quarantine مستمرًا دون Timeout يفترض انتهاء التوليد. يُزال active بعد terminal والتنظيف. يبقى LLM مملوكًا إلى close الناجح. ينتظر Tutor النهاية الفعلية ونتيجة طلب الإلغاء حتى لو وصلت النهاية قبل رد API؛ ولا ينهي الدور على chunk متأخرة. يحتفظ Coordinator بالخطأ التشغيلي، ولا يحفظ جوابًا لدور متروك.

## 6. Embedding Lifecycle State Machine — دورة Embedding

`UNLOADED → LOADING → LOADED → CLOSING → UNLOADED` عند النجاح. الفشل في close ينقل إلى `QUARANTINED` مع `embeddingLoaded()==true` و`embeddingQuarantined()==true`. Loaded هنا ملكية مقبض، وليس إذن استخدام.

في quarantine: embed وclose يفشلان بـ`embeddingCloseFailed`، ولا يُعاد Native delete. أي initialize جديد في العملية، بما فيه Manager بديل بعد Activity recreation، يُرفض. يحتفظ Process Owner بمرجع قوي حتى انتهاء العملية. dispose يبلغ الفشل دون إسقاط المرجع أو إعادة الحذف.

التعافي بعد **إغلاق ناجح** يدعم إعادة التهيئة المثبتة. التعافي بعد **فشل غير محسوم** هو إنهاء العملية وإعادة تشغيلها؛ لا توجد في SDK الحالية آلية cleanup أو retry-safe معتمدة. اختبار «إعادة المحاولة عندما يسمح SDK» غير قابل للتطبيق على هذه النسخة: لم يُخترع ضمان بديل، واختُبر رفض retry حتى لو أصبحت Fake لاحقًا قادرة على النجاح. تكرار close بعد نجاحه آمن على مستوى Manager ولا يعيد SDK close على مقبض محذوف.

## 7. Race Condition Analysis — السباقات

Callback متزامن أثناء cancel يحجز terminal ثم يضع finish في طابور Worker. لا ينفذ finish قبل عودة/رمي cancel، لذا تكون نتيجة قبول الطلب معلومة قبل اختيار terminal. Duplicate callbacks لا تصل إلى finish ثانية، والأحداث القديمة لا تتجاوز هوية Request.

قفل lifecycle مشترك يحمي اكتساب/تحرير Process Owner والتهيئة والإغلاق؛ العمل الثقيل يبقى في Worker، ولا توجد `future.get()` على Main Thread. يتوقف Admission عبر Activity replacement حتى cleanup الناجح، ويحتفظ المالك بالطلب الذي لا تصل نهايته. اختبار النص اللاحق لطلب cancel يمنع اعتبار prefix نتيجة كاملة.

## 8. Resource Ownership Guarantees — ضمانات الملكية

مالك Native واحد في العملية، وGeneration واحد لكل Runtime. لا تحرير Conversation قبل Callback نهائي؛ ولا تحرير LLM أثناء توليد جارٍ. Cancel Future لا يزيل RequestOwnership lease. Embedding لا يُنسى عند فشل الإغلاق ولا يُستبدل. بعد cleanup الناجح تتحرر ملكية process وتُسمح تهيئة بديلة.

TutorCancellation يعبر عن تخلي المستخدم عن الدور، وليس شهادة توقف Native. تبقى Session/Revision/Evidence/Persistence guards قائمة وتمنع حفظ جواب متأخر. لم تتغير سياسة حفظ USER أو مخطط المحادثات أو مفاتيح Auth.

## 9. Tests Added — الاختبارات المضافة

**22 حالة Java** جديدة: قبول cancel وتأخر terminal، normal completion، حفظ suffix بعد cancel، native failure، API throw، normal completion بعد فشل API، callback متزامن، callback ثم throw، cancel متكرر، duplicate/stale callbacks، close المنتظر، dispose أثناء cancel، Activity replacement والتعافي بعد terminal، close Embedding الناجح، close متكرر بعد النجاح، reinitialize، close failure ومرجعه، منع embed، منع replacement، رفض retry غير الآمن، dispose بعد الفشل، ومنع bypass بواسطة Manager جديد.

**13 حالة Flutter** جديدة: 8 Client و4 Tutor و1 Coordinator؛ تشمل القبول دون نهاية، normal completion/failure، API throw المنقح، terminal قبل رد MethodChannel، dispose/drain، تنظيف handles بعد رفض cancel، وحالة embedding quarantine. تشمل إضافات Tutor/Coordinator الانتظار بعد late chunk، والنهاية قبل رد API الفاشل، وحفظ الخطأ التشغيلي دون كتابة ASSISTANT. عُدل اختبار cancel القديم ليطلب terminal فعليًا قبل السماح بالطلب التالي، واختبار malformed-event يثبت رفض العمل على قناة لم تعد موثوقة.

شُغلت RED قبل الإصلاح: Java normal-completion بعد cancel، Embedding close failure، Dart admission بعد cancel، Future Tutor غير المعالج، suffix المفقود، وحاجز Activity replacement، وإنهاء Tutor المبكر وطمس فشل الإلغاء في Coordinator. ثم GREEN؛ الملخص في `local-results.json`. Fakes داخل الاختبارات فقط، لا تثبت استدلالًا أو G2/G3.

## 10. Tests Executed — ما شُغّل

`flutter pub get --enforce-lockfile`؛ `dart format --output=none --set-exit-if-changed` على lib/test وملفات integration B-08؛ `flutter analyze`؛ `flutter test --reporter json` كاملًا؛ ملفات Client/Tutor/ChatTurnCoordinator المستهدفة؛ `bash tool/ai_runtime/run_core_tests.sh`؛ `python3 -m unittest discover -s tool/tests`؛ compile Java target17 مقابل classes.jar الفعلية لـSDK0.19.0؛ `git diff --check`.

خط الأساس قبل التعديل: Flutter250، Java35، Python36. الأعداد التالية من تشغيل جديد، وليست نقلًا من التقرير السابق. لا تغيير في pubspec أو lockfile.

## 11. Flutter Results — نتائج Flutter

Flutter3.38.5 وDart3.10.4. **263 passed / 0 failed / 0 skipped**، machine done=true. المجموعة المستهدفة Client/Tutor/Coordinator: **46/0/0**. analyze: No issues found. format: **73 ملفًا، 0 تغيير**. enforce-lockfile: PASS. فُحصت إشعارات التقادم دون تحديث التبعيات خارج النطاق.

## 12. Java Results — نتائج Java

**57 passed / 0 failed**: LibraryProbe7، RuntimeManager17، TrustedResolver6، RequestOwnership5، LifecycleHardening22. التشغيل الفعلي `run_core_tests.sh`، وكل runner في JVM منفصلة؛ quarantine متعمد في نهاية runner الجديد. هذه Contract Tests وليست JNI/model evidence. Compile منفصل مقابل AAR الفعلية نجح؛ تحذير محلي معروف `system modules path not set in conjunction with -source 17` بسبب JDK البيئة المختصرة، وليس خطأ compile.

## 13. Python Results — نتائج Python

**36 passed / 0 failed** لاختبارات أدوات التحقيق والموارد والتحقق من الأدلة. بقيت قواعد رفض proof ناقص/zero cases/scope خاطئ كما هي. لم تُضف Network Dependency أو لغة/Runtime جديدة.

## 14. Android Results — نتائج Android

**PASS، 6 passed / 0 failed / 0 skipped** في [التشغيل 42301592619](https://github.com/shehab5552/siraj-codex/actions/runs/42301592619)، الالتزام `4951875ae5ce09ff5ff396fca827428ab4f58de8`، job `128180705595`. الحالات الست: DB، Session، حالتا Storage، JNI، وتشغيل النماذج الحقيقي. جميع jobs الثلاثة ناجحة، وأعاد CI enforce-lockfile/format/analyze/Flutter/Java/Python. أعداد Linux أعلاه من machine protocol المحلي؛ JSON اختبارات CI ضمن artifact البناء.

النطاق Android API33 / x86_64 / Pixel6 emulator، وليس Samsung أو ARM64 فعليًا. تبقى حقن فشل SDK close/API throw ضمن Contract Tests، ولا تُنسب إلى تجربة عطل حقيقية في SDK. [أدلة Android](https://github.com/shehab5552/siraj-codex/actions/runs/42301592619/artifacts/13543789861).

## 15. Debug APK Evidence — دليل Debug

**PASS**، من `lib/main.dart` بالالتزام `4951875ae5ce09ff5ff396fca827428ab4f58de8`. الحجم **206697040 bytes**، SHA-256: `8ad5ea1cf384155e88c8d4054971ed61320fc9f3cff17b63bbd8dc0515ad554b`. فُحص وجود Engine وEmbeddingEngine وNative libraries لـarm64-v8a وx86_64 باستخدام DEX/ELF/readelf. [تنزيل الحزمتين وأدلة البناء](https://github.com/shehab5552/siraj-codex/actions/runs/42301592619/artifacts/13544957654).

تشغيل النماذج الفعلي جرى في Debug integration target على المحاكي نفسه، عبر Flutter والقنوات وSDK/JNI الحقيقي. لا يثبت هذا اختبار تجربة Tutor الإنتاجية أو تشغيل موارد في Release.

## 16. Release APK Evidence — دليل Release

**PASS** لبناء Release/R8 وفحص mapping والـNative libraries والتراخيص. الحجم **104731977 bytes**، SHA-256: `47e644fb8775957a10912e985fdd365b431482bffe87d525794554eccd103987`. [Artifact](https://github.com/shehab5552/siraj-codex/actions/runs/42301592619/artifacts/13544957654) من التشغيل/الالتزام المذكورين.

Release Catalog بقي مغلقًا. تشغيل النماذج داخل Release: **NOT RUN**؛ البناء والفحص لا يثبتان تشغيل موارد إنتاجية. بصمات ABI وتفاصيل الفحص كاملة في `android-results.json`.

## 17. Offline Execution Evidence — دليل عدم الاتصال

**PASS** لتنفيذ الأوزان الهندسية نفسها، دون نماذج إضافية أو إنتاجية. تحقق SHA/size على الجهاز، airplane-mode exit0، wifi=0، mobile-data=0، active default network=none؛ وفشل اتصال التطبيق إلى `api.github.com:443` قبل inference. هذا فحص عدم اتصال مقصود، وليس HTTP download failure.

- **3 Embedding queries**: 768 بعدًا، finite وغير صفرية؛ close مؤكد ثم embeddingLoaded=false وquarantine=false.
- **4 nonempty completions**: ثلاث أولية وواحدة بعد إعادة تحميل LLM؛ خمسة generation attempts شاملة تجربة الإلغاء.
- إلغاء Native حقيقي من أول محاولة: `generationCancelled`؛ تطابق Flutter/Native terminal=true، وعدّ terminal واحد. زمن الطلب حتى تصريف النهاية **148ms**؛ ليس SLA أو قياس Samsung.
- إعادة تحميل LLM **2219ms** ثم توليد ناجح، وإغلاق/dispose ناجح.

لم تُسجل prompts أو answers أو vectors في الأدلة. قياسات PSS/native heap عينية للمحاكي فقط، ولا تمنح موافقة co-residency. الهوية المثبتة للأوزان كما كانت: Qwen3 SHA `c5f39b4191926786c3e6668b62af4d6eb15248dfc7a5348252a9b406f33f2108`، EmbeddingGemma SHA `2d079ee2f6f066b1f368e8d7c819f55214eaef1d0513b312321901f30ab286fb`. لا يثبت استخدامها Dataset parity أو Grounded Tutor.

## 18. Remaining Limitations — الحدود المتبقية

Quarantine بعد فشل Native Embedding close لا يضمن أن Native destructor حرر الذاكرة، ولا يدّعي إصلاح تسرب داخل SDK. إنه يحفظ الملكية ويمنع double-delete/duplicate owner ويؤجل التنظيف إلى انتهاء العملية. إذا لم يصل Generation terminal تبقى العملية Busy دون إتلاف مورد جارٍ. لا UI جديدة لإعادة التشغيل ولا Retry غير مثبت.

تشغيل ARM64/Samsung لم يُنفذ. تحذيرات CI الموروثة تخص انتقال Actions من Node20 إلى Node24 وتقادم setup-java@v4؛ لم تُغير Actions أو JDK أو SDK خارج النطاق. لم تُغير إعدادات الأداء أو سياسة الموارد أو Embedding parity. الأدلة التاريخية `docs/qa/b08-runtime/**` محفوظة دون استبدال. قيود شبكة Cloud التاريخية موثقة في `cloud-network-probes.json`: `maven.google.com` و`dl.google.com` و`huggingface.co` أعادت **Proxy CONNECT403، دون HTTP response من origin**. لا تُنسب هذه النتائج إلى تنزيل جديد لم يحدث؛ لم يسجل تشغيلا CI الجديدان فشل تنزيل. لا تجاوز Proxy/TLS/VPN. البناء الفعلي هنا عبر GitHub Actions المصرح به، وأي فشل جديد يُسجل بهويته الفعلية.

## 19. G2/G3 Status — الحالة العلمية

**G2 BLOCKED، G3 BLOCKED، Samsung PENDING DEVICE TEST**. لم تبدأ Biology retrieval parity أو Production Dataset approval/model activation/catalog. موارد التشغيل الهندسية لا تمنح Dataset Revision أو Source IDs أو Embedding/Index parity؛ لا بيانات بديلة أو نتائج علمية مختلقة. لم يُدّع RAG_READY أو جاهزية إنتاجية.

## 20. Final Engineering Assessment — التقييم النهائي

**PASS للتنفيذ المحدود على الالتزام `4951875ae5ce09ff5ff396fca827428ab4f58de8`**: أصلح الخللان، ونجحت مسارات النجاح والفشل وRegression B-08/B-07، وبناء Debug/Release وCI الحقيقي. PR #14 مفتوح وغير مدمج. لم يُنفذ Merge لأي PR.

المراجعتان المستقلتان للمواصفة والمعايير راجعتا delta ثم الإصلاحات؛ أُصلحت ملاحظات suffix وملكية process وإنهاء Tutor المبكر وطمس الخطأ في Coordinator. لا قرار معماري إضافي مطلوب لهذا الإصلاح؛ تعافي quarantine بإعادة تشغيل العملية مقصود وفق حدود SDK والمهمة.

| البند | النتيجة المثبتة |
|---|---|
| Original Commit | `33c335485b959a394130f92940027ccaa9045729` |
| Lifecycle fix | `57943be95e8c289786f719d8b4d9da154116e4f6` |
| Final application/test source | `4951875ae5ce09ff5ff396fca827428ab4f58de8` |
| Cancellation / Embedding Close | PASS / PASS |
| Flutter / Java / Python | 263/0/0، 57/0، 36/0 |
| Android | 6/0/0 |
| Debug / Release | PASS / PASS |
| Source CI | [42301592619](https://github.com/shehab5552/siraj-codex/actions/runs/42301592619) — success |
| G2 / G3 / Samsung | BLOCKED / BLOCKED / PENDING DEVICE TEST |

هذا التقرير وملفات QA والتسليم توثق تشغيل المصدر المذكور؛ بصمات APK تخص تشغيله المحدد. التزام الأدلة اللاحق يعيد CI كاملًا على HEAD، ويُذكر SHA ورابط تشغيله الفعلي في وصف PR وتقرير التسليم؛ لا تُنسب بصمات هذا التشغيل إلى rebuild مختلف. لم تُستثن ملفات QA الجديدة من workflow كي يبقى HEAD النهائي متحققًا منه.

عدد ملفات delta لهذه المرحلة **20**: 15 تنفيذ/اختبار و5 تقرير/QA. القائمة الدقيقة في `files-changed.txt`. الأدلة التاريخية السابقة محفوظة، والتشغيل الوسيط `42299971567` ناجح لكنه منفصل صراحةً عن دليل المصدر النهائي. لا مهمة تطوير تالية بدأت داخل هذا التسليم.
