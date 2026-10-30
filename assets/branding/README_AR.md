# هوية Android — مؤقتة حتى ورود أصل الشعار

اسم التطبيق `SIRAJ`. الأيقونات الحالية تستخدم مونوغرام «س» من مرجع V2، **وليست شعار الكتاب/المشكاة الرسمي الموعود**. لم يُحوّل شعار Flutter إلى شعار سراج، ولم تُكبّر أيقونة صغيرة. رُسم الحرف مباشرة بحجم1024×1024 من Noto Sans Arabic بوزن900، الموافق لمونوغرام HTML، عبر Chromium محلي دون شبكة، بخلفية شفافة.

`reference_monogram.png` مصدر مؤقت قابل للتتبع، و`provenance.json` يسجل بصمته وتصنيف `reference-monogram` و`official_logo_verified:false`. يقرأ `SirajBrandMark` الأصل المولد نفسه `app_mark.png`، وتولّد منه نسخ Launcher الخمس وAdaptive Icon داخل مساحة66/108 وSplash قبل Android12 وبعده بالثيمين. `flutter_template_hashes.json` يحتفظ ببصمات أيقونات Flutter الأصلية من79ba311 لمنع عودتها.

عند تسلم أصل PNG معتمد لا يقل عن1024px، راجعه بصريًا وتحقق من تفويضه وبصمته، ثم شغّل:

```bash
python3 tool/generate_android_branding.py --source /workspace/path/to/approved-logo.png --expected-sha256 SHA256 --identity approved-logo
python3 tool/verify_android_branding.py
```

خيار `approved-logo` يصنّف قرار المراجع؛ لا يمنح اعتمادًا تلقائيًا ولا يستبدل الأصل أو تفويض المالك. إذا كان الأصل SVG، تُحفظ نسخته الأصلية وبصمتها ويُصدر PNG مناسب أولًا دون تكبير منخفض الدقة أو إعادة رسم توليدي. توليد الموارد تطويري ويتطلب Pillow؛ التطبيق لا يحتاج Python أو تحميل صورة من الشبكة.

التحقق من APK يستخدم `aapt` للاسم وPillow لمقارنة البكسلات الفعلية لأيقونات الكثافات الخمس، مع التحقق من Adaptive Icon وملفات Splash المجمّعة. وجود المورد المجمّع لا يثبت وحده تجربة Samsung الفعلية أو اعتماد الهوية النهائية.
