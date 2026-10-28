# SIRAJ P0 — Release Readiness، 29 أكتوبر 2026

**Integration Testing. غير معتمد كـRelease Candidate أو Production Ready.**

التفاصيل والملفات والاختبارات في [تقرير التنفيذ/QA](SIRAJ_PRODUCTION_COMPLETION_2026-10-29_AR.md)، والمطابقة في [Visual Fidelity Matrix](../design/visual_verification_2026-10-29/README_AR.md). مسار التشغيل الحقيقي `lib/main.dart`؛ Preview ليس الحزمة المسلّمة.

| المجال | المثبت | المطلوب قبل إصدار إنتاجي |
|---|---|---|
| Code quality | Flutter3.38.5/Dart3.10.4، Lockfile enforced، analyze نظيف،591 host test ناجحًا | آخر CI مطابق للكود وسجل حزم SHA256؛ لا تجاوز فشل |
| Auth/security | PBKDF2-HMAC-SHA256 وKeystore/SQLiteNonce/session guards؛ مرشح 600k على المحاكي فقط | Benchmark للهاتف6GB ومراجعة أمنية وProfile معتمد؛ يبقى Release credential entry Fail-closed |
| Signing | Debug key للتجربة، وRelease evaluation غير موقع عند غياب المدخلات؛ لا debug fallback | مفاتيح/هوية إنتاج من مخزن أسرار، توقيع APK/AAB وفحصه؛ لا أسرار داخلSource/Git |
| Identity/backup | `com.example.siraj.unifiedtest` معزول، Label=SIRAJ، backup/transfer محجوبان بقواعدAndroid | applicationId/سياسة انتقال معتمدة؛ لا تغيير هوية المشروع الأصلي |
| PDF | Android PdfRenderer فعلي، ملفات داخل files الخاص بالتطبيق، الحجم وSHA والترويسة والقراءة والإغلاق ثم النقل النهائي، حدود ذاكرة وleases | Catalog/كتب مرخصة ومعتمدة، مراجعة كل كتاب وقبول على الجهاز؛ لا ادعاء أن وثيقة اختبار تعادل الكتب |
| AI/RAG/Quiz | Ports/B07/B08/B09/B11/B12 موجودة وFail-closed؛ فصل الموارد ومنع readiness زائفة | Runtime/native build وترخيص/ABI/LLM/Embedding/BiologyIndex/Gold وسياسات معتمدة؛ G2 ثم G3 على جهاز حقيقي |
| UI/branding |30 Golden بالثيمين و18 مقارنة380×737، Responsive/RTL/LTR/System/200%، خانة تبويبكاملة وحد لمس 48dp | أصل رمز الكتاب/المشكاة، Launcher/adaptive/splash، إغلاق فروق V2 وقبول المالك؛ لا ادعاء pixel-perfect |
| Native/lifecycle | KDF/PDF/app مثبتة على API33 emulator؛ force-stop حسب سجل CI المصحح | هاتفAndroid/Samsung فعلي، OS/ABI/ذاكرة/ضغط موارد/خلفية وقتلProcess، Security/PerformanceQA |
| Dependencies/licenses | لا Runtime/plugin/PDFABI جديد؛ Framework OS، lockfile بلاupgrade، تراخيص التطبيق الحالية محفوظة | مراجعة ترخيص الأوزان والكتب والـnative AIحين تتوفر، سياسة تحديث أمان Android والتبعيات |
| Packaging | SourceZIP وAPK Debug منMain، SHA256SUMS فيArtifact؛ APK evaluation وليس منتجًا موقعًا | حزمة Release موقعة/مراجعة وحجم/أداء/ثبات وأجهزة معتمدة؛ خطة الإصدار/الأعطال |

لا Merge تلقائي. PR12 يبقى Draft إلى حين إغلاق البوابات؛ اعتماد الدمج النهائي صريح من المالك بعد التقرير. لا تُعرض أجهزة Linux/Emulator أو Hash/Header وحدها كنجاح G2/G3 أو قبول أمني/علمي/بصري.

المخرجات المقررة: `SIRAJ_P0_FINAL_FLUTTER_SOURCE.zip`، `SIRAJ_P0_UNIFIED_ANDROID_DEBUG.apk`، `SHA256SUMS`، سجلاتnative والعدادات والصور وتقاريرQA/Visual/Readiness. روابط الـRun/Artifact والـCommit المعني تُثبت في سجل التسليم؛ Artifacts مؤقتة 7 أيام ولا تعادل GitHub Release دائمًا.
