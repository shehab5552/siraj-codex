# B-12 — آلية تجهيز Dataset الإنتاجية / TK-19

## النطاق والمرجع

هذا تسليم **آلية التفعيل الذري وتثبيت القراءات والاستعادة**، وليس اكتمال تجهيز Dataset الإنتاجية أو B-12 النهائي. المرجع مواصفة P0 v1.0.1 §§6.5،7.4.1،10.3،15.3 TK-19 وTC12/26/32، وخطة الفريق B المعدلة §4.2 التي تسمح باختبار الآلية بفحوص محكومة قبل الموارد الإنتاجية. بصمة المواصفة `084d2f3ece9373dacc3795fb35bed99ee36ebbdbb9ba139d5cca9d0daa5727d8`.

المستودع الوحيد `shehab5552/siraj-codex`؛ الفرع `codex/b12-atomic-dataset-core` مبني على B-07/PR#3 عند `27ff8e5265e03092ccf84fedeae39d5bb4d008a7` ويستهدف فرعه في PR مستقل. لا ينسخ B-08/B-09/B-11 أو إصلاحات B-04. لا Merge ولا تغيير Auth أو موارد إنتاجية معتمدة، ولا وصول للمستودع الأصلي أو الكمبيوتر المحلي.

## الموجود قبل التنفيذ وما تغير

كان DownloadService وArtifactIntegrityValidator وRagCandidateContract موجودين ويعملان؛ لم تكن آلية Promotion/Pointer/Pinning موجودة. أُعيد استخدام فاحص SHA256/الحجم وعقد الخمس وShared Embedding وDownloadSpaceProbe. كُشف أيضًا أن recordUnverified تستطيع مسح صف المؤشر المحجوز؛ أُثبت ذلك باختبار RED ثم حُظر هذا المعرف في الواجهة العامة غير المتحققة.

| الملف | المسؤولية الفعلية |
|---|---|
| `lib/features/resources/dataset_release_contracts.dart` | خطة من Catalog معتمد، مكونات/ملفات وحجم/Hash، Typed Errors، Cancellation قابلة للرصد، حدود Catalog وRuntime Validator غير المتاحين افتراضيًا، نتيجة Recovery |
| `lib/features/resources/dataset_release_manager.dart` | ملكية Staging وكتابة Streams، Serialization، فحص الشجرة/الروابط/Hashes، Receipt خاص لا يصنعه المستدعي، Promotion ثم Pointer CAS، Handles مثبتة، استعادة وتنظيف محكوم |
| `lib/data/dataset_pointer_store.dart` | حد SQLite الداخلي: صف RAG_PACK/__ACTIVE_DATASET__، Transaction واحدة ومقارنة المؤشر المتوقع قبل استبداله |
| `lib/data/resource_repository.dart` | منع مسح المؤشر المحجوز من مسار الموارد غير المتحققة |
| `test/b12_*` و`test/support/b12_dataset_fixture.dart` | SQLite حقيقي وملفات معزولة؛ فشل/تزامن/إلغاء/Hashes/Paths/Restart؛ Fakes اختبارية فقط |
| `.github/workflows/b12-dataset-verification.yml` | فحص Linux وبناء APK منفصل المعرف في نسخة CI فقط |
| `docs/architecture/B12_ATOMIC_DATASET_CORE.md` و`docs/plans/B12_ATOMIC_DATASET_CORE_PLAN.md` | حدود المعمارية وخطة/سجل التنفيذ؛ ملف QA يحمل الأعداد والبصمات |

## دورة العمل والسلامة

1. Catalog محقون ومعتمد يحدد Revision وخمس Subject IDs وShared Embedding والملفات الفعلية. لا تُقرأ التوقعات من Manifest منزل غير موثوق. لا تنسيق Manifest إنتاجي أو Archive أو URL أو Model مختلق.
2. يُنشأ مرشح داخل app-private `rag/staging/<candidate_id>`، ويمر كل Writer عبر المالك نفسه. فحص المساحة قبل الإنشاء والكتابة؛ السعة غير المعروفة تفشل مغلقة. الإلغاء يوقظ Stream المتوقف وينتظر تنظيف الاشتراك وإغلاق الكاتب قبل تحرير الملكية.
3. فحص بنية الخمس/Shared Config وشجرة الملفات الكاملة، ثم SHA256/الحجم الحقيقيان. Validator موثوق مستقل يجب أن يفحص Schema/Chunk IDs/Indexes/Tokenizer/Pooling/Normalization/Dimensions ويجري Android sample query الحقيقي. الافتراضي يرفض؛ لا Checklist تمنح READY.
4. Receipt خاص مرتبط بالمرشح ومحاولة التحقق والخطة. يتوقف تعديل المرشح، وتُراجع التوقعات وHashes مجددًا قبل Rename. لا استبدال دليل Release موجود، حتى لو كان فارغًا، ولا Copy fallback عند EXDEV.
5. بعد Promotion في نفس شجرة التخزين يُفحص الناتج، ثم يُبدل صف المؤشر المحجوز ضمن معاملة SQLite ومقارنة CAS. الخطأ قبل Commit يترك المؤشر السابق وملفاته، والخطأ بعد Rename يترك Release غير مرجعية لا تُفعّل تلقائيًا ولا تُحذف في مسار الفشل. لا يُبلّغ Cancel بعد Commit ناجح على أنه تفعيل فاشل.
6. كل Handle يحمل Plan/Revision/Directory واحدة، ولا تحذف مراجعة حالية أو مثبتة. محرك لا يدعم تحققًا بجانب قارئ قديم ينتظر زوال قارئه عبر خطأ pinned قابل لإعادة المحاولة؛ لا يُفرّغ Runtime قديم. إثبات المحرك للإصدار نفسه يعاد استخدامه دون Reload متكرر؛ رفض إعادة الفحص يبطل الإثبات المخزن.
7. Recovery يتحقق من Pointer والملفات وRuntime ولا يستنتج جاهزية من وجود Directory. يصنف الدلائل غير المرجعية والمرشحين المتروكين؛ الحذف صريح ومقيد بالجذر والروابط والـPins. لا يميز وجود دليل وحده بين إصدار كان Active ويتيم لم يُثبت؛ لا يدّعي سجل تفعيل غير موجود.

ملفات LLM وPDF وdownloads-staging لا تُمس. لا تغيير Schema/الجداول الخمسة/التبعيات. لا Product ResourceStatus wiring ولا Fixture→Production path. قد تعرض قراءة Registry الخام READY مخزنًا، لكنه ليس دليل سلامة؛ لا يُفتح Handle قبل تحقق المدير.

## نتائج الاختبار الفعلية

انتهت الفحوص في 2026-10-23T23:41:33.818756+03:00 بتوقيت Asia/Aden. Flutter3.38.5/Dart3.10.4، Linux x64. `flutter pub get --enforce-lockfile`: PASS،0.598ث. `flutter analyze --no-pub`: PASS دون ملاحظات،1.636ث. `flutter test --no-pub --machine`: **231 ناجحًا،0 فاشل،0 متخطى**،15.231ث. تشمل47 حالة جديدة، والأساس الموروث184؛ لم تُحسب اختبارات B-08/B-09/B-11 لأنها على فروع مستقلة.

اختبارات حقيقية لبايتات الملفات وSHA256 وSQLite، مع محول Runtime صناعي داخل test فقط: نجاح المجموعة، قارئ قديم أثناء التبديل، محرك مثيل واحد، رفض Partial/Fixture/PDF/LLM والتلف وتغير الخطة، منع Overwrite، SQL Trigger Abort بعد Promotion وRollback، CAS conflict، Startup revalidation، اشتراك Stream متوقف وإلغاء/Drain، IO Fault injection، نقص المساحة/Unknown، Links/Traversal/Unexpected files، Bytes تغيرت بعد Receipt، Cleanup محكوم، وSQLite file-backed يعاد فتحه بعد فشل تفعيل R2 مع بقاء R1 وظهور R2 غير مرجعية.

المراجعة المستقلة Spec/Standards للشجرة `5bfd8cb76b749c10433bc06d8180eea09d51aa4c` اكتشفت إثبات Runtime لا يُبطل بعد فشل Recovery، وإلغاء لا يوقظ Stream متوقفًا. كلاهما أُثبت RED قبل الإصلاح ثم GREEN، مع اختبار انتظار تنظيف الاشتراك. توجد كذلك RED→GREEN لحماية المؤشر وفتح قارئين مع Runtime مثيل واحد. الأدلة الخام `/tmp/siraj-b12-20261023/`؛ بصماتها في ملف QA. لا اختبارات تعني نجاح Android sample query: الـValidator الصناعي لا يختبر Embedding أو الفهرس العلمي.

استُخدمت مكتبة SQLite native من البيئة بعد تحقق SHA256 `b17729184e5a2818055ecbddd5ed6642521bfe6e56aafa472330e483c0e2e0d2` دون pubspec/lock overrides. لا فشل تنزيل جديد في الفحوص النهائية، فلا HTTP status فاشل يخصها.

## الحدود والاعتماديات

- ما يزال Catalog/Manifest والتغطية والملفات الحقيقية وValidator الفهرس وEmbedding وAndroid Query مدخلات مطلوبة من التكامل المعتمد؛ الافتراضي لا ينشر أي Dataset.
- One-consent aggregate download UI وTrusted Archive Assembly من نتائج B-07 إلى هذه الملفات لم تُنفذ في هذا PR؛ ربطها يحتاج تنسيق C وCatalog الفعلي. writeArtifact حد التجميع وليس ادعاء دعم كل Archive مجهول.
- Handle الإنتاج لا يفتح Fixture. دمج B-09 RevisionLease مع هذا المالك يكون Adapter مستقلًا بعد جمع الفروع المعتمدة، ولا ينقل PR هذا تنفيذ B-09.
- الضمان مبني على App-private single coordinator isolate وكتّاب متعاونين؛ القفل ليس Sandbox ضد كود معادٍ داخل العملية. لا كتابة خارج الجذر، ولا Namespace models/books يُحذف.
- تمت File flush ومعاملة SQLite وRename وفحوص Restart، لكن لم يُنفذ انقطاع طاقة فعلي/Android fsync أو Power-cut أو Emulator/device. لا تعلن نتائج Linux ضمانًا ماديًا لانقطاع الطاقة. سلوك التخزين وNative Runtime والذاكرة والأداء على Android ما يزال PENDING TEST.
- لا Product Ready أو G2/G3/G4، ولا موافقة نموذج/موارد جديدة. بوابة Auth مغلقة وPRs غير مدمجة. تعارض B-04/B-08 الموثق ما يزال يحتاج تسوية مستقلة قبل الجمع.

## الأولوية التالية

الأولوية التعليمية هي B-09 Biology G2/G3: Runtime/ABI معتمد وLocal LLM وShared Embedding وFixture/Index مراجعة، ثم تشغيل Android حقيقي وربط الـLease. B-12 التالي هو توصيل Catalog والتجميع وOne-consent إلى الآلية دون إعلان الخمس جاهزة قبل فحوصها. B-10 يتطلب BookCatalog وروابط رسمية وPDF Viewer/Parser مختبرًا؛ لا تعتمد روابط أو ملفات كتب تخمينية. نتيجة CI وCommit/PR ستضاف بعد الرفع.
