# B-11 — واجهة Quiz والجلسة / TK-10

## نطاق التسليم والأدلة

مرجع التنفيذ: مواصفة P0 v1.0.1 المصححة §§6.9،12.1–12.5،11.4–11.5 وTC09/10/11/15/30/31، وخطة الفريق B المعدلة §4.1 B-11. بصمة المواصفة المعتمدة SHA256: `084d2f3ece9373dacc3795fb35bed99ee36ebbdbb9ba139d5cca9d0daa5727d8`.

التاريخ: 23 أكتوبر 2026؛ انتهاء الفحوص 23:19:57 بتوقيت Asia/Aden. المستودع `shehab5552/siraj-codex` فقط. الفرع `codex/b11-quiz-session-ui` مبني على B-08 عند `306b3a69bb855a49b3bf01bbb1b6bd30a1c087f5` ويستهدف فرع B-08 في PR مستقل؛ لا يتضمن كود B-09 أو B-07 أو B-04. ظل main عند `651af0d62d05761c80d9a8cbc9d1f51b836929eb` ولم يُدمج أي PR.

كان B-08 يوفر AuthSession وSessionGuard ومراقبة الجلسة وSourceReference وSourceResolverPort؛ لم يوجد QuizPort أو Quiz session UI. أُعيد استخدام هذه الحدود بدل نسخ قواعد الحساب أو إضافة قاعدة بيانات موازية.

## ما نُفذ

- `lib/integrations/ai/quiz_port.dart`: أسئلة ومفاتيح وإجابات ونتائج وأخطاء typed، جلسة مرتبطة بالطلب والحساب وDataset Revision، إلغاء وDiscard وAvailability. الأصل LLM-generated إلزامي؛ عناصر البنك مرفوضة قبل العرض. عقد MAX_GENERATION_ATTEMPTS=2 مسؤولية مولد A/C الحقيقي، وليس إعادة محاولات تلقائية في UI.
- `lib/features/quiz/quiz_decimal.dart` و`quiz_scorer.dart`: MCQ/Boolean من مفتاح مراجع، مقارنة رقمية عشرية دقيقة دون أخطاء float، وحدات مراجعة دون تحويل تخميني؛ Short المراجع صحيح وغير المعروف UNDETERMINED، دون LLM judge. الإدخال غير الصالح خطأ إدخال لا إجابة علمية خاطئة. مفتاح غير صالح بعد العرض يعطي UNDETERMINED.
- NumericAnswerSpec يحمل precision مراجعة إلزامية. NumericPrecisionPort حتمي محقون يتحقق من كامل السياسة؛ لا سياسة تقريب/أرقام معنوية مفترضة. غياب المحول المراجع يرفض السؤال الرقمي قبل عرضه، وعدم القدرة على تقييم precision يعطي UNDETERMINED. المحول الفعلي مدخل A/C متبقٍ؛ fake موجود في الاختبارات فقط.
- `quiz_controller.dart` و`quiz_access.dart` و`lib/data/quiz_session_access.dart`: جلسة في RAM فقط، SessionGuard ومراقبة SQLite القائمة، correlation ورفض الحساب/المراجعة الأجنبية، منع التكرار ونتائج الطلبات القديمة، Cancel/End/Close وتنظيف متأخر. لا INSERT/UPDATE لـQuiz ولا جدول QuizAttempt أو Quiz History.
- `quiz_cleanup_owner.dart`: مالك تنظيف على مستوى التطبيق، يحتفظ عند الفشل بـIDs وPort فقط. يعيد المحاولة عند استئناف التطبيق/فتح Quiz أو بطلب صريح، ويبقى بعد التخلص من الصفحة. يمنع الجيل الجديد أثناء تنظيف معلق أو فاشل، ولا يحتفظ بنص السؤال أو إجابات الطالب في إجراءات الفشل.
- `quiz_page.dart` و`quiz_widgets.dart`: RTL وأربعة أنواع، Loading/Cancel/Error/Unavailable، مصادر فعلية دون صفحات مختلقة، عرض Feedback وFollow-through وملخص مستقل لـCorrect/Incorrect/UNDETERMINED؛ judgeable=correct+incorrect. عرض الملخص لا يغلق الجلسة، وEnd يمسحها. نتائج المصادر ونوافذها مقيدة بالسؤال والمرحلة الأصليين.
- `lib/app/app_bootstrap.dart` و`siraj_app.dart` و`lib/features/home/home_page.dart`: حقن Quiz/precision/source، دخول من Home المصادق فقط. بوابة Auth الإنتاجية بقيت مغلقة؛ لا موارد أو أسئلة علمية وهمية ضمن lib.
- `.github/workflows/b11-quiz-verification.yml`: تحقق Linux وبناء Debug APK بمعرّف مستقل في نسخة CI المؤقتة فقط. Actions مثبتة بـSHA رسمية؛ لا تبديل دائم للـGradle أو Manifest.

## الاختبارات والمراجعة

Flutter 3.38.5 / Dart 3.10.4 على Linux x64. `flutter pub get --enforce-lockfile`: PASS خلال0.605ث. `flutter analyze --no-pub`: PASS، دون ملاحظات،1.936ث. `flutter test --no-pub --machine`: PASS، **246 ناجحًا،0 فاشل،0 متخطى**،18.255ث. الأساس197؛ الإضافات49 اختبارات scorer/controller/widgets.

تشمل الاختبارات الأربع صيغ، حدود السماحية والأرقام العربية والوحدات، precision unavailable/reject/unknown/failure، مفتاح تالف ومدخل غير صالح، عداد UNDETERMINED، رفض البنك والمراجعات المختلفة والطلبات الأجنبية، منع Duplicate Submit، Cancel/Late Result، Logout/Delete أثناء التوليد، عدم كتابة محادثات/رسائل Quiz في SQLite الحقيقي، فشل التنظيف ثم استعادته بعد Dispose، RTL ضيق مع تكبير الخط، والمصادر وحذفها عند Logout وحجبها بعد الانتقال أو الملخص.

راجعت جهتان مستقلتان المواصفة والمعايير في الشجرة `0cb6c3e55ba068fafa2d7c97af28d50776e7a490`. كُشفت ثلاث نقاط: precision ناقصة، سباق مصدر السؤال السابق، وضياع إعادة التنظيف بعد Dispose. أُثبتت باختبارات RED قبل الإصلاح، ثم GREEN. الأدلة الخام محفوظة سحابيًا في `/tmp/siraj-b11-20261023/` وبصماتها في `docs/qa/B11_CLOUD_VERIFICATION_2026-10-23.json`.

استُخدمت مكتبة SQLite native المخبأة من البيئة، وتحقق SHA256=`b17729184e5a2818055ecbddd5ed6642521bfe6e56aafa472330e483c0e2e0d2`، دون تغيير pubspec/lock أو إضافة dependency override. لم يفشل تحميل جديد خلال الفحوص النهائية. سجل إعداد B-09 السابق فشل DNS لمحمّل Dart عند `github.com` قبل HTTP؛ لم نعد هذا الطلب في B-11 بل أعدنا استخدام البايتات المخبأة المطابقة. لا ينسب ذلك إلى فساد SQLite أو فشل اختبارات التطبيق.

## الحدود وما لم يثبت

هذا تسليم Flutter لعقد Quiz وواجهته والجلسة والتصحيح المحافظ؛ **ليس إثباتًا للتوليد العلمي الحقيقي أو اكتمال B-11 النهائي**. QuizPort وNumericPrecisionPort الافتراضيان غير متاحين، ولا أسئلة بنك بديلة. ما يزال مولد NEW items من Few-shot مراجع وQuestionValidator ومفتاح/سياسة precision مراجعة وLLM/RAG/Embedding/Index المتوافقة وAndroid الحقيقي مطلوبًا. لا RAG_READY أو G2/G3 أو نجاح Offline AI. لا تختزل اختبارات fake في نجاح مسار تعليمي.

لم يُختبر هاتف أو Emulator في هذه المرحلة. نجح بناء APK في CI، وهو دليل Compilation فقط. لا تعديل Auth الإنتاجي، ولا تعارض B-04/B-08 أُخفي: ما يزال يحتاج تسوية قبل الجمع النهائي للـPRs. ملفات B-04 القائمة لم تُعدل. لم يُفتح المشروع الأصلي أو الكمبيوتر المحلي.

## التالي

الأولوية التعليمية مستمرة: ربط B-09 بالـRuntime/ABI المعتمد وموارد Biology المراجعة وتنفيذ G2/G3 على Android فور توفرها. مستقلًا عن ذلك يمكن بناء آلية B-12 للتفعيل الذري وRevision pinning فوق B-07 في فرع منفصل، مع إبقاء Product Ready مؤجلًا لحين الخمس وShared Embedder. B-10 يحتاج Catalog موثقًا وقرار PDF Viewer المعتمد؛ لا اعتماد روابط كتب أو مكتبة تخمينية.

## Git والتسليم النهائي

Commit الكود المختبر: `e0f93d6343b01f2c1a48ad26d169b62a9b6dc2df`. PR مفتوح دون دمج: https://github.com/shehab5552/siraj-codex/pull/8 . عدد الملفات:21؛ إضافات2660 وحذف سطر واحد مقابل B-08 وقت Commit الكود. Commit التوثيق اللاحق يسجل نتيجة CI ولا يغير الكود المختبر.

نجح [GitHub Actions run40018602023](https://github.com/shehab5552/siraj-codex/actions/runs/40018602023): Flutter مثبت، enforced dependencies، analyze، **246/0/0** وفق Check annotations، Android SDK، وبناء Debug APK. تحقق aapt من `com.example.siraj.quizverification`، دون تغيير المعرف في ملفات Gradle الملتزمة. [Artifact12529073917](https://github.com/shehab5552/siraj-codex/actions/runs/40018602023/artifacts/12529073917) حجمه76,484,744بايت، وبصمة أرشيف artifact `sha256:8150c88242a003af49919865bcb245f10218d53d712f83f0d727a3a5bc45863f`؛ هذه بصمة الأرشيف وليست ادعاء بصمة APK المفرد. الاحتفاظ7 أيام. لم ننفذ تثبيتًا أو تشغيلًا على جهاز/Emulator.

تحذير CI غير مانع: upload-artifact v4 المثبت يستهدف Node20 المتقادم، وشغله GitHub بـNode24 ونجح رفع artifact. لم يفشل تنزيل في هذا التشغيل، ولا HTTP failure يخصه.
