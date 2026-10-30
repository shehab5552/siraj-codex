# تسليم إغلاق فروق V2 من79ba311 — 30 أكتوبر 2026

المستودع الوحيد للعمل: `shehab5552/siraj-codex`. الفرع الحالي: `codex/unified-siraj-v2-integration-20261024`، PR [#12](https://github.com/shehab5552/siraj-codex/pull/12) يظل Draft دون Merge. نقطة المقارنة المثبتة `79ba3111fd5326ea4be95fd26c5edbe2386efce4`، وقاعدة main المعروفة `651af0d62d05761c80d9a8cbc9d1f51b836929eb`. لا وصول إلى `siraj-p0` أو الكمبيوتر المحلي.

## نطاق التنفيذ

عولجت فروق العرض المحددة في المصفوفة، بدءًا بـOnboarding وHome وHistory وSettings وChat ثم Auth وLibrary وResources/diagnostics وQuiz والحوارات. [المصفوفة والمقارنات](../design/visual_closure_2026-10-30/README_AR.md) تفصل ما قيس فعليًا عن فروق المحتوى وحدود القبول. لا تُعلن مطابقة Pixel-Accurate أو Production Ready.

- أصول SVG الثمانية والعشرون مستخرجة من paths في HTML المعتمد ومستخدمة محليًا. المربعات والترويسة والتنقل والتنبيهات والشرائح والأزرار والمسافات لها قياسات من DOM الأصلي.
- تغير العرض فقط حول المتحكمات والمستودعات الحالية. رسائل USER والمعاملة وحد10 محادثات وRetry/Cancel وحماية الجلسة والاستجابة القديمة تستمر عبر الخدمات الأصلية.
- Settings يحفظ Theme/Locale إلى SQLite للحساب عبر المتحكم نفسه؛ فشل الحفظ لا يُظهر تفضيلًا ناجحًا كاذبًا. تبقى System وAR/EN وظائف حقيقية، ولو زادت صفوف المرجع المصور.
- Chat يبقي ANSWER/PARTIAL/REFUSAL/ERROR typed contracts؛ ينفذ التاريخ والمصادر والإلغاء والمتابعة الحقيقية. اختبارات المصدر تتجاوز UI إلى حارس الجلسة وSourceResolver؛ المصادر العلمية والصفحات لا تُختلق.
- Quiz يعرض ملخصًا من الاختيار الموثوق بعد ربطه بهوية QuizSession الفعلية. لا تُعرض بيانات اختيار سابق عند تغيير هوية الجلسة. الأنواع الأربعة الأصلية باقية، وUNDETERMINED خارج مقام النتيجة، والمحاولات في RAM فقط.
- لا تعديل في KDF أو Auth production profile أو Tutor/Runtime/Embedding/Retriever أو SQLite schema أو Downloader/Validators/Atomic Activation. لا Manifest إنتاجي أو نماذج أو كتب جديدة.

## الملفات الرئيسية

| المجموعة | الملفات |
|---|---|
| التصميم | `lib/core/design/siraj_design.dart`, `siraj_components.dart`, `siraj_v2_components.dart`, `siraj_navigation.dart`, `siraj_v2_icons.dart`, `siraj_v2_illustration.dart` |
| الشاشات الأولى | `lib/features/onboarding/onboarding_page.dart`, `home/home_page.dart`, `chat/chat_page.dart`, `chat_widgets.dart`, `conversation_history_page.dart`, `settings/settings_page.dart` |
| بقية الحالات | `lib/features/auth/auth_form_frame.dart`, `signup_page.dart`, `login_page.dart`, `library/library_page.dart`, `resources/resource_status_page.dart`, `quiz/quiz_page.dart`, `quiz_widgets.dart`, `lib/app/presentation/siraj_problem_card.dart` |
| ربط التنقل | `lib/app/authenticated_workspace.dart` يمرر callback السجل إلى Chat؛ لا خدمة جديدة |
| الأصول | `assets/icons/v2/`, `assets/branding/`، موارد Android launcher/adaptive/launch/colors/styles31 |
| الاختبارات | `v2_*closure_test`, `v2_reference_geometry_test`, `v2_navigation_fidelity_test`, `v2_all_screens_golden_test`, `v2_available_states_golden_test`، وتحديث selectors/نصوص اختبارات الانحدار الحالية دون حذف assertions SQLite/الجلسة |
| الأدوات وCI | `tool/compare_v2_reference.py`, `generate_android_branding.py`, `verify_android_branding.py`, `tool/tests/test_android_branding.py`, `package_verified_source.py`, `.github/workflows/siraj-unified-verification.yml` |

## التبعيات

`flutter_svg:2.3.0` مثبتة في lockfile؛ متطلبها Dart^3.9/Flutter>=3.35 ومتوافقة مع Flutter3.38.5/Dart3.10.4. لا native runtime أو ABI جديد. أحدث2.3.2 لا يناسب SDK المثبت؛ لم نرفع SDK أو بقية الإصدارات. أضيفت تبعيات SVG العابرة الثماني مع بصماتها، ولا يُستخدم تحميل SVG من الشبكة. تراخيص الحزم متاحة عبر شاشة المصادر المفتوحة؛ OFL الخاص بالخط باقٍ.

Pillow وPlaywright وChromium أدوات تطوير/مراجعة فقط. فاحص APK في CI يثبت Pillow11.3.0، ولا يحتاج التطبيق Python أو اتصالًا لعرض الأيقونات.

## هوية Android

اسم التطبيق SIRAJ مثبت في Manifest. أزيلت PNGs الخمس الخاصة بأيقونة Flutter واستبدلت بمونوغرام V2 مؤقت مولد بدقة1024 مباشرة، وليس تكبيرًا لأيقونة صغيرة. أُعد Adaptive Icon بمساحة66/108 وSplash للكثافات الخمس وAndroid12+ مع ألوان النهار/الليل. يستخدم Flutter أصل الهوية المولد نفسه.

**الشعار الرسمي الموعود غير متاح بعد.** `official_logo_verified:false` يبقى في السجل، والـAPK ليس اعتمادًا نهائيًا للهوية. [إجراءات الاستبدال والأصل والبصمات](../../assets/branding/README_AR.md). المولد يرفض SHA خاطئًا وPNG صغيرًا وsymlink ويختبر عدم المساس بالموارد عند رفض المدخلات.

فاحص APK يفحص اسم SIRAJ، بكسلات أيقونات Launcher الخمس وForeground وSplash، وإشارة Adaptive XML إلى Foreground المتحقق. لا تكفي ملفات المصدر وحدها لحكم البناء؛ تقرير CI المولد يحفظ نتيجة APK الفعلي وبصمته.

## النتائج والأخطاء

التحقق المحلي النهائي: `flutter pub get --enforce-lockfile` نجح؛ `flutter analyze --no-pub` بلا ملاحظات؛ `flutter test --no-pub --concurrency=1 --reporter=json`: **605 ناجحة،0 فاشلة،0 متخطاة**. المصدر الآلي [host results](v2_closure_host_results_2026-10-30.json). اختبارات مولد Android: **5 ناجحة**، وفحص موارد المصدر نجح. تؤخذ أرقام Android والبناء من CI الجديد، ولا تُنسخ نتيجة14 السابقة قبل إعادة التشغيل.

يستخدم CI التسلسل بين ملفات Flutter بسبب تعطل محرك Linux الملاحظ. لم تُحذف اختبارات أو assertions، وما تزال اختبارات تزامن الطلبات والجلسات داخل كل اختبار تعمل كما هي. هذا ضبط لتشغيل المضيف وليس ادعاء إصلاح سبب SIGSEGV غير المحدد.

أثناء التطوير ظهرت اختلافات assertions لنصوص تغيرت إلى المرجع، وتجاوزات عند200% وحجم320، ومقارنة Goldens القديمة. عولجت أسبابها: selectors الجديدة تستدعي المتحكمات نفسها، صفوف الموارد تتكيف مع القيود، نص CTA يلتف دون خفض حجم الخط، وحُدثت baselines بعد المقارنة المرئية.

ظهر أيضًا `TestDeviceException(Shell subprocess crashed with segmentation fault.)` في تشغيل Linux متوازٍ داخل `b04_auth_real_widget_test.dart`، وفي تشغيل متوازٍ آخر داخل `v2_available_states_golden_test.dart` أثناء إنهاء عملية Flutter. لا خطأ Dart أو native backtrace يحدد السبب؛ core dumps معطلة في المضيف، ولم تُنسب المشكلة إلى KDF أو يُغيّر SDK. اختبار Auth المنفرد نجح2/2 دون تعديل مساره. التشغيل التسلسلي الكامل يُسجل منفصلًا، مع CI وAndroid؛ لا يُسمى هذا العطل سببًا جذريًا محلولًا أو نجاح إنتاج.

## البوابات المتبقية

- أصل شعار رسمي واعتماد بصري للصور والاختلافات المبررة في المصفوفة.
- Samsung فعلي: launcher masks/اسم التطبيق/Splash، RTL والكيبورد وBack وتكبير النص والظلال، Signup/Login600k وKeystore/restart/offline/PDF، الذاكرة والحرارة والتخزين.
- Runtime وLLM وShared Embedding وBiology Dataset/Index متوافقة ومرخصة ذات هويات وبصمات معتمدة، ثم G2 وG3 على Android الحقيقي. لا RAG_READY أو توليد/تقييم علمي ناجح معلن.
- الكتب الرسمية والكتالوج/منهج Quiz الموثوق، التوقيع وملف Auth الإنتاجي. لا PDF/Quiz أو الحزم الخمس شرطًا لتكامل الأحياء المبكر.

PR #12 لا يُدمج ضمن هذا التكليف. الخطوة التالية هي تطبيق أصل الهوية عند توفيره وتشغيل مصفوفة Samsung، ثم متابعة تكامل Biology وفق البوابات القائمة؛ لا تبدأ مرحلة علمية جديدة بإجابات محاكاة.
