# SIRAJ P0 — Resource Intake & B-07 Independent Download

أنت تعمل كمهندس Android AI Integration Architect وSenior Flutter Engineer.

نفّذ المهمة التالية على المستودع:

`https://github.com/shehab5552/siraj-codex`

## 1. نقطة البداية

- Code branch: `main`
- Base commit: `651af0d62d05761c80d9a8cbc9d1f51b836929eb`
- Resource release:
  `https://github.com/shehab5552/siraj-codex/releases/tag/siraj-ai-resources-staging-v1`
- Release tag: `siraj-ai-resources-staging-v1`
- Release classification: STAGING ONLY.

ابدأ بقراءة هذه الملفات قبل التعديل:

1. `docs/architecture/RESOURCE_INTEGRATION_READINESS.md`
2. `docs/reports/B-07_INDEPENDENT_VALIDATION_01_AR.md`
3. `lib/features/resources/artifact_integrity_validator.dart`
4. `lib/features/resources/resource_format_preflight.dart`
5. `lib/features/resources/resource_validation_contracts.dart`
6. `lib/features/resources/rag_candidate_contract.dart`
7. `lib/data/resource_repository.dart`

لا تعِد تنفيذ ما هو موجود بالفعل.

## 2. المرحلة الأولى: فحص الموارد الحقيقية

نزّل الملفات الخمسة من GitHub Release إلى مجلد مؤقت خارج ملفات التطبيق الإنتاجية.

الملفات المعتمدة في هذه المرحلة:

| Artifact | Expected Size (Bytes) | Expected SHA-256 |
|---|---:|---|
| Biology.zip | 873028 | 8111e6cedd0a045e3368b02905ac2a15776e850ec50ea54794c32e3bdf6c015c |
| embeddinggemma-2-text-270m.litertlm | 164626432 | 2d079ee2f6f066b1f368e8d7c819f55214eaef1d0513b312321901f30ab286fb |
| litertlm-android-0.19.0.aar | 21197249 | e5c7a86048225efba8ab6d35fcd91f5870c86c65ca2538c07c3c1f63d02efa2b |
| Qwen3-0.6B.litertlm | 613722264 | c5f39b4191926786c3e6668b62af4d6eb15248dfc7a5348252a9b406f33f2108 |
| SIRAJ_AI_RESOURCES_MANIFEST.json | 2494 | 1a1fdf3e4cde89feb3f089583ba54efcf8dbc9f188967d63cbecb20d582eb4f4 |

هذه القيم مأخوذة من GitHub Release API.

لكل ملف:

- تحقق من نجاح التنزيل.
- قارن الحجم الفعلي بالحجم المعلن.
- احسب SHA-256 من الملف الفعلي.
- قارنه بالقيمة المعلنة.
- سجل النتيجة في تقرير.
- لا تعتمد على امتداد الملف لإثبات سلامته أو توافقه.

إذا فشل تنزيل أو تحقق أي ملف، أوقف قبول ذلك الملف ولا تتجاوز فشل التحقق.

## 3. المرحلة الثانية: فحص Manifest وBiology Dataset

افحص `SIRAJ_AI_RESOURCES_MANIFEST.json` فعليًا.

تحقق من:

- صحة UTF-8 وJSON.
- بنية Manifest.
- أسماء الموارد وإصداراتها.
- الروابط والأحجام والبصمات.
- تطابق بيانات Manifest مع GitHub Release.
- أي معلومات عن Runtime وEmbedding وDataset.

بعدها افحص `Biology.zip`:

- قائمة الملفات الداخلية.
- سلامة ZIP.
- منع Path Traversal وAbsolute Paths والروابط الرمزية.
- بنية وحدات الأحياء 01 و02.
- ملفات البيانات والفهارس وMetadata.
- SHA-256 الداخلي إن كان محددًا في Manifest.
- توافق Schema مع العقود الموجودة في المشروع.

لا تفترض أن Biology.zip يمثل Dataset إنتاجيًا للمواد الخمس.

يظل Biology Pilot منفصلًا عن Production RAG.

## 4. المرحلة الثالثة: فحص LiteRT-LM AAR

افحص الملف:

`litertlm-android-0.19.0.aar`

استخرج محتوياته إلى مجلد مؤقت وافحص:

- AndroidManifest.xml.
- classes.jar.
- واجهات Java/Kotlin الفعلية.
- Native Libraries.
- ABI المدعومة، خصوصًا arm64-v8a.
- Dependencies.
- Consumer ProGuard Rules إن وجدت.
- متطلبات Android SDK وGradle وKotlin.
- التوافق مع إعدادات المشروع الحالية.

لا تخمّن أسماء Packages أو Classes أو API Methods.

استخرج واجهات الاستخدام الفعلية من المكتبة، وحدد ما يلزم لربطها مع Flutter عبر Platform Channel أو Native Adapter.

لا تعدّل Gradle قبل إثبات توافق المكتبة ومتطلباتها.

## 5. المرحلة الرابعة: فحص النموذجين

افحص:

`Qwen3-0.6B.litertlm`

و:

`embeddinggemma-2-text-270m.litertlm`

المطلوب تحديده:

### Qwen3

- سلامة الملف.
- دعم LiteRT-LM 0.19.0.
- طريقة تحميل النموذج.
- واجهة Prompt/Generation الفعلية.
- Tokenizer ومتطلباته.
- Context Configuration.
- Generation Parameters.
- إمكانية التشغيل على Android arm64-v8a.

### EmbeddingGemma

- سلامة الملف.
- طريقة تحميله.
- Tokenizer الفعلي.
- Pooling.
- Normalization.
- Vector Dimensions.
- واجهة استخراج Embeddings.
- إمكانية تنفيذ Query Embedding على Android.

لا تستنتج توافق النموذجين من تطابق الامتداد أو نجاح SHA-256.

إذا لم تتوفر أداة أو واجهة تثبت التوافق، صنّف النتيجة PENDING_VERIFICATION.

## 6. المرحلة الخامسة: تنفيذ B-07 Independent Download

بعد اجتياز بوابة التحقق من المدخلات، نفّذ DownloadService وفق معمارية المشروع والوثيقة المعتمدة.

المتطلبات:

- HTTPS فقط.
- TLS Verification دون تعطيل.
- Download Progress.
- Pause / Cancel.
- Resume آمن مرتبط بهوية Artifact.
- ETag أو Last-Modified عند توفرهما.
- Restart نظيف عند تغير هوية الملف أو عدم دعم Range.
- Disk Space Validation.
- Staging خاص بالتطبيق.
- SHA-256 Streaming.
- Size Verification.
- Typed Errors.
- منع الكتابة المتزامنة أثناء التحقق.
- عدم إتلاف المورد السابق عند فشل المورد البديل.

استخدم العقود والفاحصات الحالية بدل إنشاء أنظمة مكررة.

لا تضف Dependencies إلا عند الضرورة مع تبريرها.

## 7. القيود المعمارية والأمنية

التزم بما يلي:

- Clean Architecture الحالية.
- Feature-First.
- Repository Pattern.
- فصل UI عن Services وValidators.
- فصل LLM عن Dataset عن PDF.
- عدم إضافة جداول SQLite جديدة.
- عدم إجراء Database Migration.
- عدم تغيير Auth أو PBKDF2 أو Keystore.
- عدم تعديل Chat أو Quiz خارج الحاجة المثبتة.
- عدم تخزين النماذج أو ملفات ZIP داخل Git.
- عدم استخدام بيانات وهمية في مسار الإنتاج.

ممنوع تمامًا:

- منح READY بناءً على اكتمال التنزيل فقط.
- منح ACTIVE قبل اجتياز التحقق والتفعيل المعتمد.
- منح RAG_READY من خلال فحص Manifest وحده.
- خلط Biology Pilot مع Production Dataset.
- تغيير SHA-256 لتجاوز فشل التحقق.
- اختراع Schema أو Resource IDs أو Model Configuration.

## 8. الاختبارات

أضف اختبارات تغطي:

1. تنزيل ناجح.
2. انقطاع الشبكة.
3. إلغاء التنزيل.
4. استئناف التنزيل.
5. تغير ETag.
6. عدم تطابق SHA-256.
7. عدم تطابق الحجم.
8. استجابة HTTP غير ناجحة.
9. مساحة تخزين غير كافية.
10. ZIP تالف.
11. ZIP يحتوي على Path Traversal.
12. Manifest غير صالح.
13. فشل التحقق دون التأثير على المورد السابق.
14. عدم تفعيل أي مورد غير معتمد.

نفّذ:

`dart format`

`flutter analyze`

`flutter test`

وشغّل اختبارات Android عندما تكون البيئة والجهاز متاحين.

## 9. Git Workflow

- أنشئ فرعًا مستقلًا:
  `codex/b07-independent-download-01`
- لا تعمل مباشرة على main.
- لا تحذف أو تستبدل ملفات سابقة.
- نفّذ Commits واضحة.
- ارفع الفرع.
- أنشئ Pull Request للمراجعة.

## 10. التقرير النهائي المطلوب

أنشئ:

`docs/reports/B-07_RESOURCE_INTAKE_AND_DOWNLOAD_01_AR.md`

يحتوي على:

1. Git Baseline.
2. Artifact Inventory.
3. SHA-256 Verification.
4. Manifest Validation.
5. Biology Archive Audit.
6. LiteRT-LM AAR Inspection.
7. Qwen3 Compatibility Findings.
8. EmbeddingGemma Compatibility Findings.
9. DownloadService Implementation.
10. Architecture Changes.
11. Security Review.
12. Test Results.
13. Android Validation Status.
14. Known Limitations.
15. Remaining Blockers.
16. Pull Request URL.

يجب أن تفرق بوضوح بين:

- PASS
- FAIL
- BLOCKED
- NOT RUN
- PENDING DEVICE TEST

لا تكتب PASS دون دليل فعلي.

## شرط الإغلاق

هذه المهمة لا تعني اعتماد موارد الإنتاج أو إثبات تشغيل الذكاء الاصطناعي على الهاتف.

لا تنتقل تلقائيًا إلى دمج Runtime أو تفعيل RAG.

عند اكتمال المهمة، قدم تقريرًا واضحًا يحدد هل أصبحنا جاهزين للانتقال إلى دمج LiteRT-LM وتشغيل Qwen3 وEmbeddingGemma فعليًا على Android، أم ما زالت هناك موانع.

الجودة وصحة النتائج أهم من سرعة إغلاق المهمة.