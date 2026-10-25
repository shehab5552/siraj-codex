# تقرير تسليم شجرة SIRAJ الموحدة — 25 أكتوبر 2026

**الحالة: تسليم تكامل واختبار قابل للمراجعة، وليس إعلان اكتمال P0 أو إصدار إنتاجي.**

تم العمل حصرًا في `shehab5552/siraj-codex`. لم يُفتح `siraj-p0` أو الكمبيوتر المحلي، ولم تُقرأ بيانات التطبيق الأصلي أو مفاتيحه. تاريخ التقرير وفق Asia/Aden. أوقات GitHub في ملفات الأدلة تبقى UTC كما وردت.

## 1. مرجع Git وحدود التسليم

- `main` والفرع الافتراضي مثبتان عند `651af0d62d05761c80d9a8cbc9d1f51b836929eb`؛ PR #2 مدمج سابقًا.
- فرع التكامل: `codex/unified-siraj-v2-integration-20261024`؛ [PR #12](https://github.com/shehab5552/siraj-codex/pull/12) مفتوح ومسودة.
- بداية هذه الدفعة: `ca17aed5b31344cc9f90874e2abd05ee0b504c55`، مع إعادة استخدام الشجرة الموحدة الموجودة، دون إعادة Cherry-pick للفروع المتراكبة.
- **Commit الكود المختبر لهذه الحزمة:** [`06f231026aa63fa9900f834ff5a1ba9c2d35a192`](https://github.com/shehab5552/siraj-codex/commit/06f231026aa63fa9900f834ff5a1ba9c2d35a192).
- أي Commit توثيق تالٍ يضيف هذا التقرير والأدلة فقط، ولا يغيّر كود التطبيق. بصمات حزمة الكود المثبتة أدناه لا تُنسب إلى ZIP آخر.
- لم يُنفذ Merge أو Force Push، ولم تُغلق PRs القديمة. PRs #1 و#3–#11 ما زالت مفتوحة عند التحقق؛ حالة #12 موضحة أعلاه.

المراجع الملزمة محفوظة في `docs/spec/`: المواصفة المصححة P0 v1.0.1 كاملة، وخطة الفريق B المعدلة، والتكليف الموحد. تم التحقق من `SHA256SUMS`؛ الأصلان الرسميان لم يتغير محتواهما. حزمة UI/UX V2 مرجع بصري وتفاعلي؛ أمثلتها لا تنشئ مواد علمية أو كتبًا أو سياسات حساب جديدة.

## 2. إجابات التسليم الثلاث عشرة

| السؤال | النتيجة المثبتة والحدود |
|---|---|
| 1. شجرة Flutter واحدة؟ | نعم: مشروع عادي و`lib/main.dart` وMaterialApp وAppBootstrap واحدان؛ الفروع الموروثة مدمجة في فرع التكامل. أداة Preview منفصلة ولا تبني APK التسليم. |
| 2. تصميم V2؟ | نظام تصميم مركزي وخط عربي مرخص، أربع وجهات فعلية، Home وOnboarding والحساب والإعدادات والسجل والمحادثة والموارد وQuiz والمكتبة. AR/EN وRTL/LTR وLight/Dark/System. حالات الموارد الغائبة حقيقية؛ قارئ PDF والتوليد الحقيقي ليسا مكتملين. Goldens للـHome وليست إثباتًا بصريًا لكل شاشة. |
| 3. Auth إنتاجي متصل وآمن؟ | Debug Android العادي متصل بخدمات الحساب الحقيقية وNative PBKDF2 وKeystore وSQLite. لا Mock Auth. Release credential gate **مغلق** حتى اعتماد ملف KDF واختبارات الجهاز والمراجعة الأمنية المطلوبة؛ لا ادعاء اعتماد إنتاجي. |
| 4. المحادثات والحفظ والسجل؟ | العقود والمنسق والحفظ والسجل وإعادة الفتح والمتابعة والإلغاء والحماية من الطلبات القديمة موجودة ومختبرة، بما فيها حد10. حُفظ USER حقيقي على المحاكي؛ لا جواب علمي لأن AI غير متاح. Fakes داخل الاختبارات لا تثبت المسار التعليمي. |
| 5. الموارد B-07/B-12؟ | موصولتان بمنسق تنزيل→فحص→تجميع→تحقق Runtime→مؤشر SQLite ذري، مع الموافقة والإلغاء وإعادة المحاولة وإصلاح Staging التالف بأمان. الاتصال الافتراضي غير مهيأ لغياب Catalog/Runtime معتمدين؛ لا زر يختلق خطة إنتاجية. |
| 6. Quiz وفق P0؟ | طبقات الطلب الموثوق والأنواع الأربعة والإجابات والمراجعة والتأكيد والنتائج مفصولة، في RAM فقط. Correct/Incorrect/Undetermined وشرح كل سؤال، مع استبعاد Undetermined من المحسوم. لا Question Bank يقدم اختبارًا. مولد LLM/السياسة العلمية لا يزالان غير متاحين. |
| 7. LLM وRAG جاهزان؟ | **لا**؛ Runtime والأوزان وEmbedding وIndex والبيانات والسياسات المرجعية المعتمدة ناقصة. العقود والـAdapters المستقلة موجودة؛ المسار الافتراضي Fail-closed، ولا RAG_READY أو G2/G3. |
| 8. PDF؟ | Catalog/Controller/Search/Categories وحالات الكتب وعقود الإجراءات جاهزة هندسيًا. لا Catalog كتب رسمي، ولا Native PDF reader backend أو تنزيل PDF إنتاجي موصول. فتح/تكبير/تنقل Offline حقيقي **غير مثبت وغير مكتمل**. |
| 9. الاختبارات وAndroid؟ |566 Flutter ناجحة،0 فشل،0 تخطٍ؛ Pub enforce والتحليل ناجحان. CI Android لهذه الحزمة موثق في القسم6؛ لا Samsung أو جهاز فعلي أو G2/G3. |
| 10. main؟ | لم يُدمج. لا نساوي نجاح المحاكي باعتماد Auth/جاهزية المنتج، ولم تستكمل بوابات القبول الإنتاجية. يبقى فرع التكامل وPR12 محفوظين وقابلين للمراجعة. |
| 11. السورس؟ | ZIP كامل من `git archive` لنفس Commit الكود، داخل Artifact GitHub المرتبط في القسم7؛ يتطلب حساب GitHub مخولًا إن كان المستودع خاصًا. |
| 12. APK؟ | ملف واحد للاختبار `SIRAJ_P0_UNIFIED_ANDROID_DEBUG.apk` داخل الحزمة ذاتها، من `main.dart` وبهوية `com.example.siraj.unifiedtest`. ليس Preview ولا Release إنتاجيًا. |
| 13. ما المطلوب لاحقًا؟ | مدخلات A/C الدقيقة في القسم9، واعتماد ملف KDF/اختبار Android الفعلي، ثم Biology G2 وبعده G3. قارئ PDF وتوقيع/هوية الإصدار مساران مستقلان ولا يؤخران بدء Biology عند توفر موارده الدنيا. |

## 3. ما نُفذ فعليًا والمعمارية

اتجاه الاعتماد محفوظ: `UI → Controller/Service → Repository/Port → SQLite/Native`، و`Chat/Quiz → TutorPort/QuizPort → Runtime/RAG`. لم تُنشأ خدمة Auth أو Download موازية.

### الحساب والجلسة

- أُعيد استخدام AuthService وCAS وnonce وSessionGuard. Adapter Native PBKDF2-HMAC-SHA256 محدود التشغيل، في Executor خلفي، مع Cancel منطقي سريع واحتفاظ بالمسار مشغولًا حتى ينتهي الـProvider. لا fallback ضعيف.
- KDF يمسح الذاكرة التي يملكها فقط؛ لا ادعاء بمسح Dart Strings أو ذاكرة Platform codec غير القابلة للتعديل. أُصلح عطل Unmodifiable bytes ظهر فعليًا على Android، ثم أُعيد إنتاجه باختبار Envelope خام قبل اعتماد الإصلاح.
- Navigator خاص بهوية جلسة مبهمة، دون nonce في WidgetKey؛ انتهاء الجلسة يزيل المسارات والحوارات الخاصة. فشل DB أو Callback قديم لا يفتح بيانات أو يلغي جلسة أحدث.
- الخروج يحتفظ بالحساب والمحادثات والموارد. الحذف يحتاج نص تحذير وCheckbox، ويحذف بيانات الحساب مع الحفاظ على الموارد المشتركة. لا تغيير لسياسة الحساب الواحد.
- اللغة والمظهر في SQLite عبر SettingsRepository وبحراسة account/epoch/nonce وRevocation fence؛ تحفظان ذريًا مع Locale الحساب. تفشل الكتابة دون ادعاء الحفظ. Onboarding فقط على مستوى الجهاز. قراءة ما قبل الدخول تقتصر على Enums لغة/مظهر منقحة، ولا تمنح صلاحية أو تعرض هوية أو رسائل.

### الواجهات وQuiz

- Semantic Tokens وTypography وSpacing/Radius/Themes ومكونات مشتركة، وخط Noto Sans Arabic مضمّن مع OFL وProvenance، دون تنزيل خط وقت التشغيل.
- أربع Tabs محفوظة؛ NavigationBar للهاتف وRail للعرض الواسع. آخر محادثة من السجل الفعلي، دون محتوى تجريبي في التطبيق العادي.
- Quiz يستهلك Catalog رسميًا محقونًا وحدود عدد الخدمة، ومادة واحدة ووحدة تابعة ونوعًا واحدًا من الأربعة. لا أسماء HTML تجريبية في الإنتاج.
- Draft Answers والتنقل والمراجعة والتأكيد والتقييم في RAM. الإدخال العددي غير الصالح يبقى للتصحيح؛ لا يصبح خطأ أو Undetermined بصمت. النتائج تعرض الشرح المحايد لكل سؤال بعد التأكيد فقط.
- `SirajProblem` يعرض الأخطاء typed بالعربية والإنجليزية مع الإجراء المتاح، دون مسارات أو Stack Trace أو أسرار. نص الطالب والمصادر لا يُترجمان اصطناعيًا.

### التنزيل والتفعيل

- `withCompletedArtifact` يمسك قفل الكاتب نفسه طوال فحص Provenance والحجم/Hash وValidator واستهلاك الملف غير المتزامن؛ لا READY/ACTIVE من انتهاء التنزيل وحده.
- DatasetPreparationCoordinator يستخدم B07 وDatasetReleaseManager الموجودين، وموافقة واحدة للحزم الخمس وShared Embedding، وتجميعًا محدود الصلاحيات، ثم Runtime validation قبل Atomic pointer commit.
- DirectDatasetFileAssembler يقبل ملفًا واحدًا بتوقعات معتمدة؛ أرشيفات الموارد تحتاج Extractor معتمدًا مستقلًا، دون تخمين الصيغة.
- فشل الترقية لا يمس النسخة السابقة/Pins؛ Orphan تمت ترقيته أو Commit DB ملتبس لا يُحذف على أنه Candidate عادي. لا إلغاء زائف بعد الحد الدائم للمعاملة.
- الإصلاح الصريح للملف المكتمل التالف يطلب Provenance سليمة تطابق الهوية والحجم وHash المعتمدين، ويحذف فقط Payload/Metadata داخل Staging تحت القفل. يحمي الملف السليم أو المستخدم أو ذا الهوية الأجنبية. رفض Metadata التالفة يخص هذا الإصلاح؛ Restart النقل القديم قد يحذف Checkpoint غير موثوق في Staging، دون سلطة على Active release.

## 4. الملفات والاعتماديات

جرد كامل مقابل main في [files_since_main.tsv](../qa/unified_2026-10-25/files_since_main.tsv)، وجرد هذه الدفعة فقط منذ `ca17aed` في [files_current_delivery.tsv](../qa/unified_2026-10-25/files_current_delivery.tsv). الجردان مثبتان عند Commit الكود أعلاه:271 ملفًا مقارنة بـmain و91 ملفًا في هذه الدفعة منذ ca17aed، ولا يشملان إضافات التقرير اللاحقة.

| المجال | أهم الملفات المتأثرة |
|---|---|
| Composition | `lib/main.dart`, `app_bootstrap.dart`, `siraj_app.dart`, `app_session_controller.dart`, `authenticated_workspace.dart`, `app_preferences.dart`, `resource_preparation_binding.dart` |
| Native/Auth | `native_pbkdf2.dart`, `kdf_worker.dart`, `password_hasher.dart`, `MainActivity.kt`, `SirajPasswordKdfChannel.kt`, `SirajAppearanceChannel.kt`, `android/app/build.gradle.kts` |
| SQLite Settings | `lib/data/settings_repository.dart`, `features/settings/account_appearance.dart`, `settings_page.dart`؛ لا جدول QuizAttempt ولا Migration مخطط جديدة في هذه الدفعة |
| V2/Locales | `core/design/siraj_design.dart`, `siraj_components.dart`, `core/localization/siraj_copy.dart`, `features/home/`, `features/onboarding/`, واجهات Auth/Chat/History/Resources |
| Quiz | `quiz_controller.dart`, `quiz_curriculum.dart`, `quiz_copy.dart`, `quiz_page.dart`, `quiz_widgets.dart`, `integrations/ai/quiz_port.dart` |
| الموارد | `download_service.dart`, `download_staging.dart`, `download_contracts.dart`, `dataset_preparation.dart`, `dataset_preparation_card.dart`, `dataset_release_manager.dart` |
| Library | `library_contracts.dart`, `library_controller.dart`, `library_page.dart`؛ Ports حقيقية بحدودها، دون Reader وهمي |
| التسليم | Workflow موحد، `tool/android_test_with_evidence.sh`, `integration_test/unified_*`, `test/unified_*`, Goldens، README، VS Code، التراخيص، المواصفات والأدلة |

الاعتماديات الجديدة لهذه الدفعة: `flutter_localizations` من SDK واعتماد `intl 0.20.2` المقيد بواسطة SDK في Lockfile؛ الخط مرخص ومضمّن. أُبقي Drift/SQLite وcryptography وuuid وcryptography_flutter القائمة، دون Runtime AI أو PDF plugin غير معتمد، ودون `dependency_overrides`. Android يحتاج JDK17 وminSdk26 بسبب Provider الأصلي؛ التنفيذ المرصود API33 فقط. قواعد Backup الآمنة وINTERNET retained، وشهادة HTTPS ومفتاح الاختبار العامان في `test/support/download_tls` فقط، وليسا Assets أو Trust override للإنتاج.

## 5. المراجعتان وإصلاح الأخطاء

[تفصيل المراجعة](../qa/unified_2026-10-25/INDEPENDENT_REVIEWS.md): محور معايير/أمان مستقل عن محور المواصفة، على `3090097`، ثم تحقق محدد من دورة إصلاح واحدة عند `b2fa500`. ليست شهادة أمن إنتاجي، ولم يشغّل المراجعان الاختبارات بنفسيهما. Qodo غير متاح ولم يُدّع تشغيله.

| المحور | المشكلة المثبتة | الإصلاح ودليله |
|---|---|---|
| Standards — Important | showDialog يستخدم Root Navigator ويتجاوز عمر الجلسة | nearest Navigator؛ اختبارات Logout أثناء حوارات الحساب/المصدر/التسليم/الموافقة |
| Spec — Important | ملف مكتمل تالف يبقى في حلقة Retry/candidateExists | إصلاح صريح مقفل؛ TLS وملفات فعلية لتلف الحجم وHash مع بقاء Active السابق |
| Spec — Important | النتيجة لا تعرض Feedback كل سؤال | استخدام QuizFeedbackCard بعد التأكيد، وشرح Undetermined محايد |
| Spec — Important | اختيار Catalog r1 يصل إلى Request r2 أثناء await | تمرير Expected revision ورفض التغير قبل QuizPort.create |

جميع الملاحظات الأربع أُغلقت في التحقق المحدد دون ملاحظة Important/Critical جديدة ضمن الإصلاح. أعيد إنتاج الأعطال قبل التصحيح؛ حالة Payload المفقود كانت ناجحة مسبقًا وأبقيت كـRegression. محاولات Harness الفاشلة/المقاطعة ليست نجاحات؛ أُصلح Scroll للوصول إلى الأزرار وFake-clock teardown بدل حذف اختبارات. لم تُحذف اختبارات لتحسين العدد.

### فشل Android لاحق وإصلاح ترتيب Native KDF

فشل [CI40156003414](https://github.com/shehab5552/siraj-codex/actions/runs/40156003414) عند b2fa500 بعد نجاح Debug وunsigned Release:7 اختبارات Native ناجحة و1 فاشل (متجه600k)، ولم يُشغّل اختبار التطبيق. **حزمته ليست معتمدة**. كان الاستثناء يخفي رمز Platform الأصلي؛ لذلك لا يُدّعى أن KDF_BUSY كان السبب المقاس لذلك الفشل.

أكد فحص المصدر ومراجعة مستقلة سباقًا حقيقيًا متسقًا مع العرض: نشر Success/Error من خيط Native قبل تنظيف Provider وتحرير Global occupancy. عُدل الترتيب إلى Cleanup→Release lane→Publish، مع مسح نسخة الاستجابة بعد النشر/التخلص أو فشل Post. يُنقل رمز KDF_BUSY وحده إلى خطأ Busy typed دون تفاصيل المنصة. الاختبار السحابي الجديد أثبت RED→GREEN لهذا التحويل؛ لا يُمثّل إعادة إنتاج لجدولة Kotlin. أُضيف اختبار Android64 طلبًا متتابعًا عبر عاملين واختبار تنافس Global/تعافٍ، وأُبقيت المتجهات7 والإلغاء. فحص المراجع التعديل محددًا دون ملاحظة Important/Critical جديدة، ولا يغني ذلك عن CI الفعلي أدناه.

## 6. نتائج التحقق

- Flutter **3.38.5**، Dart **3.10.4**.
- `flutter pub get --enforce-lockfile`: نجح؛ Lockfile محفوظ.
- `flutter analyze --no-pub`: **No issues found**.
- `flutter test --no-pub --reporter json`: **566 passed / 0 failed / 0 skipped**؛ سجل Done success=true، نحو65.991 ثانية. العدد554 كان للـCommit السابق ولا يُستخدم نتيجة نهائية.
- Unit/Widget/Persistence/Concurrency وHTTPS محلي فعلي، Resume/ETag/Range/Cancel/Provenance/مسارات/قرص وتلف، Guards/حذف/كتابات متأخرة، وAtomic upgrade/Pins، وQuiz/RAM ضمن المجموعة.
- 8 مصفوفات للشجرة الفعلية AR/EN×Light/Dark×320/1024 عند200% نص؛ Goldens اثنتان inspected للهاتف العربي الفاتح واللوحي الإنجليزي الداكن، مع اختبارات Semantics وتسميات وأهداف لمس Android. ليس ذلك اختبار TalkBack فعليًا.
- **CI الحزمة الحالية:** [40156855257](https://github.com/shehab5552/siraj-codex/actions/runs/40156855257)، حالة `SUCCESS` عند تثبيت التقرير.
- **Android:** `محاكي Android API33 / Google APIs / x86_64 فعلي في GitHub Actions؛10 اختبارات Native ناجحة/0 فشل/0 تخطٍ (المتجهات7، تتابع64 طلبًا عبر عاملين، التنافس/التعافي، الإلغاء/drain)، واختبار تطبيق1 ناجح/0 فشل/0 تخطٍ: Startup/Signup/Keystore/SQLite/حفظ USER/حالة AI غير متاح/تنقل/لغة ومظهر/Logout/Login/Delete. لا هاتف فعلي`.
- القياسات: `600000 دورة في 2849ms، و283 نبضة Dart؛ Logical cancel0ms ثم Provider drained=true. physical_device=false وproduction_approved=false`. قياس المحاكي ليس معيار إنتاج أو شهادة KDF ولا قياس Samsung.
- الدليل السابق [40144201787](https://github.com/shehab5552/siraj-codex/actions/runs/40144201787) نجح عند3090097:566 لا تُنسب إليه؛ كانت554 على Host، و8 native+1 app Android. احتفظ به كتاريخ فقط.

| Gate | حكم هذا التسليم |
|---|---|
| A سلامة الشجرة | Checkout موحد، لا تعارض Git، لا اعتماد Runtime على مسارات Codex؛ CI يبدأ من Checkout جديد. لا ادعاء بإثبات غياب كل دورة محتملة رياضيًا. |
| B Static | نجح Pub enforced والتحليل. |
| C Regression |566/0/0 على الشجرة بعد الإصلاح؛ CI الحالي كما أعلاه. |
| D UI | المصفوفات/Goldens المذكورة ناجحة؛ اختبار بصري شامل وTalkBack على الجهاز متبقيان. |
| E Build | `نجح بناء Debug من main.dart وRelease غير موقّع`؛ آلية توقيع آمنة موثقة. لا مفاتيح إنتاج متاحة ولا APK إنتاجي موقع مُدّعى. |
| F Runtime | `نجحت10 native+1 app على المحاكي API33`؛ لا Samsung/Physical Android أو Native AI acceptance. تنزيل/تفعيل حزمة إنتاج حقيقية على الجهاز غير مختبر لغياب الموارد. |
| G Readiness | المسارات الغائبة Not Ready؛ لا RAG_READY أو G2/G3. |

## 7. تنزيل الحزمة وبصماتها

[Artifact الحزمة](https://github.com/shehab5552/siraj-codex/actions/runs/40156855257/artifacts/12585306737) يحتوي:

1. `SIRAJ_P0_FLUTTER_SOURCE.zip`: مشروع كامل تحت `SIRAJ_P0/`، وليس Build output؛ يفتح في VS Code بعد الاستخراج.
2. `SIRAJ_P0_UNIFIED_ANDROID_DEBUG.apk`: APK واحد للتثبيت الاختباري، هوية معزولة، وليس Production.
3. `SHA256SUMS` وسجلات Android ولقطات UI إن أنتجتها الاختبارات.

| الملف | SHA-256 |
|---|---|
| Source ZIP عند 06f2310 | `662de9ba0551be2c5f7b04fa3138d58312fff669d15af1fb396d418713dad03c` |
| Debug APK عند 06f2310 | `e7a28ae5e6c1a3154a9967a87c248e3e9333d1a46de395180cc7950ca0a2ecb4` |

حالة الصلاحية: `غير منتهية عند التحقق؛ انتهاء GitHub المعلن 2026-11-01T06:13:57+03:00 (Asia/Aden)، Retention7 أيام`. Artifacts مؤقتة بحسب Retention؛ ليست إصدار GitHub Release دائمًا. لا تنزّل حزمة وسيطة من Run فاشل وتعتبرها هذه الحزمة. هذه بصمات حزمة Commit الكود06f2310؛ قد يرتبط PR12 بحزمة توثيق لاحقة تشمل هذا التقرير دون تغيير كود التطبيق، ولها SHA256SUMS مستقلة منشورة في CI نفسه.

قيد الشبكة المرصود في البيئة السحابية: Host **`results-receiver.actions.githubusercontent.com`** يرجع **HTTP403 Forbidden** من Envoy/CONNECT proxy عند جلب سجلات/Artifacts Actions. السبب المحدد من الاستجابة: رفض النفق عبر سياسة الوكيل؛ لم يُثبت فشل مصادقة GitHub. `api.github.com` يعمل، واستُخدم Check annotations لاستخراج نتائج Android والبصمات الرسمية دون تجاوز Proxy/TLS. لذلك لم أُعد تنزيل الحزمة محليًا من هذا Host أو أحسب بصمتها مستقلاً بعد التنزيل؛ القيم من SHA256SUMS الذي حسبه CI ونشره كـAnnotations. لم تُكشف روابط موقعة أو بيانات اعتماد.

## 8. تشغيل وتوقيع واختبار Samsung المعزول

README العربي يحتوي تثبيت Flutter/JDK/Android SDK وVS Code وأوامر doctor/pub/analyze/test/devices/run/debug/release، دون Visual Studio2022 أو ملفات سرية أو مسارات Codex. لا حاجة إلى تجميع الفروع يدويًا.

هوية الاختبار `com.example.siraj.unifiedtest`؛ لا تستبدل التطبيق الأصلي ولا تستورد DB/Keystore منه. هذا الإصدار يحتاج Android API26 فما فوق من جهة البناء، مع إثبات تشغيل API33 فقط.

Debug موقّع بمفتاح اختبار CI، وليس مفتاح الإنتاج. تحديث تثبيت اختبار سابق يتطلب توقيعًا متوافقًا؛ لا يُغيّر هذا التسليم هوية التطبيق الأصلي أو بياناته. Release يُبنى غير موقّع إن غابت المفاتيح، ولا يستعمل Debug signing fallback. عند توافر المفاتيح توثق الآلية أربع متغيرات بيئة تُقدّم معًا من مخزن أسرار، ولا تدخل Git. لا يُوزع unsigned Release بوصفه APK إنتاجيًا، ولا يفتح توقيعه بوابة Auth تلقائيًا.

إجراءات القبول المتبقية على جهاز اختبار معزول، لا على بيانات التطبيق الأصلي:

| السيناريو | التوقع والدليل المطلوب |
|---|---|
| Native KDF | المتجهات7، Unicode/NUL، heartbeat/cold-warm/cancel/drain؛ طراز الجهاز/Android/ABI/build ومعاملات الملف؛ لا اعتماد600k من المحاكي فقط |
| Startup/حساب واحد | Onboarding مرة واحدة، Signup حقيقي، Restart/Restore، إغلاق التطبيق/فتحه Offline، عدم إنشاء حساب ثان |
| Login/Logout/Delete | كلمة خاطئة آمنة، خروج يحفظ البيانات، حذف بتأكيد يزيل الخاصة ويبقي المشتركة؛ لا عودة بالزر الخلفي أو حوار قديم |
| الحوارات والجلسة | إبطال الجلسة والمصدر/تأكيد Quiz/الموافقة مفتوحة، ومنع النتائج والكتابات المتأخرة |
| المحادثة | USER save ذري، Retry دون تكرار، History/Reopen/Follow-up، حد10، Fail-closed عند غياب AI |
| UI | AR/EN وRTL/LTR وLight/Dark/System، لوحة مفاتيح وتكبير النص وTalkBack، هاتف/لوحي، مصادر وأخطاء |
| الموارد | بعد تقديم موارد معتمدة: انقطاع/Resume/Cancel/تلف/مساحة/ترقية وفشلها وإعادة تشغيل؛ بقاء Active السابق وPins، Offline بعد التنزيل |
| Biology | G2 أولًا: Runtime/Embedding/Index/Memory/cancel/unload فعلي؛ ثم G3 بسؤال Biology ودليل ومصدر وحفظ/reopen بنفس Revision |

هذه إجراءات مستقبلية موثقة، وليست نتائج منفذة على هاتف المستخدم، ولم يُطلب الوصول إليه.

## 9. النواقص الدقيقة وأول خطوة تالية

| المسار | ما ينقص فعليًا | معيار المتابعة |
|---|---|---|
| Local LLM | Native build/Commit ثابت وترخيص وتبعيات وABI/minSDK، أوزان معتمدة وهوية/صيغة/حجم/SHA256، Tokenizer/Prompt/Capabilities | ربط Backend حقيقي بالعقد الموجود واختبار load/generate/cancel/unload/OOM |
| Shared Embedding | Runtime/build/license/ABI، النموذج وSidecars وHashes، preprocessing/tokenizer/pooling/normalization/dimension مطابقة | Vectors فعلية بمعايير مقارنة معتمدة، دون تعديل تطبيع افتراضي |
| Biology RAG/Index | Fixture علمية مراجعة وRevision وChunk/Source IDs/Hashes؛ صيغة Index وقارئه وتوافق Vector/Pack؛ Gold queries/evidence والسياسات | Integration fixture معزولة لا تغيّر Product pointer؛ لا انتظار PDF أو الحزم الخمس لبدء G2/G3 |
| Tutor/Quiz العلمي | Scope/evidence/answer validation وFew-shot/QuestionValidator ومفاتيح ووحدات وسماحيات مراجعة | لا إبدالها بثقة IDs أو Fake؛ Quiz generation bounded وفق عقد المحاولتين |
| Dataset إنتاجي | Catalog/URLs/Hashes/Schema/Coverage للخمس وEmbedder، Extractor عند الأرشيف، Runtime validator فعلي | النقل والتجميع وحدهما لا يحققان RAG_READY |
| Auth Release | ملف إعداد معتمد وقياسات جهاز Android مستهدف ومراجعة القبول الأمني | توصيل Credential gate في تغيير منفصل بعد الدليل، لا خفض KDF |
| PDF | Catalog/كتب C رسمية، اختيار Reader backend وترخيصه ثم Adapter وDownload/Open/zoom/navigation Offline | B-10 متبقٍ جزئيًا، مستقل عن LLM وRAG؛ لا ندّعي أن نسخ PDF وحده يكمل القارئ |
| الإصدار | Keystore/هوية إصدار وخطة انتقال معتمدة، Release signing واختبارات B-13 الباقية | لا Debug كإنتاج ولا نقل أسرار إلى Git |

**أول خطوة تطويرية تالية:** إدخال الحد الأدنى المعتمد لمسار Biology في بيئة Integration fixture معزولة: تثبيت Runtime build/ABI والترخيص، وLLM وShared Embedding وIndex/Fixture متوافقة بهويات وHashes ومعايير قبول علمية. ثم تنفيذ/توصيل Native Backend على Ports الموجودة، وتشغيل **G2 على Android حقيقي ثم G3**. لا نعيد B04/B07/B08/B09/B11/B12 ولا ننتظر PDF أو Dataset الإنتاج الكامل لبدء هذه البوابة. إذا لم تصل المدخلات، تظل هذه المسارات Fail-closed؛ يمكن إغلاق اعتماد ملف Auth أو اختيار Reader في تسليم مستقل دون خلط السياسات أو ادعاء جودة تعليمية.

## 10. سجل Commits

| Commit | الأثر |
|---|---|
| `b287ac8fc50a66d819b01d8be17d3b3690769c3c` | Native KDF والعقود وأساس Composition |
| `9f8f9112f9d7520e5f37c75dac31c88d8a2376e7` | حساب حقيقي وواجهة V2/localization وتنقل محروس |
| `7abd8ae5ffe588ab848462829129044878bc6a2a` | اختيار Quiz موثوق ومراجعة/تأكيد RAM |
| `c151d6b773755dc0b0db1beef3517d1b8d22a7f5` | تنزيل موثوق→تجميع→تفعيل ذري |
| `30900976912100252bb4cae3828293ada3abd38c` | إعدادات SQLite ومكتبة/واجهة متحققة وحدودها |
| `b2fa50044ff9628fb186debfbc4fd7c4eeca403d` | إصلاح ملاحظات المراجعة الأربع،565 اختبارًا |
| `06f231026aa63fa9900f834ff5a1ba9c2d35a192` | ترتيب إكمال Native KDF وBusy typed و566 اختبارًا |

الأدلة المقروءة آليًا في `docs/qa/unified_2026-10-25/verification.json`؛ وسجل التنفيذ والقرارات في `docs/plans/UNIFIED_V2_EXECUTION.md`.
