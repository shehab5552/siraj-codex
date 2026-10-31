# مرجع نقل B-04

هذه **أدلة نقل وليست برنامج ترقية تلقائيًا**. الأصل المحلي لم يُقرأ أو يقارن.
ابدأ بـ[الدليل التنفيذي](../../guides/B04_LOCAL_WINDOWS_REPRODUCTION_GUIDE_AR.md).

- `manifest.json`: 32 مسارًا، SHA قاعدة Codex وCommit الإصلاح وSHA-256 لكل
  Patch وللمحتوى قبل/بعد. البصمات هنا للملفات العامة، وليست hashes كلمات مرور.
- `patches/<path>.patch`: الفرق الكامل الحقيقي لكل ملف، بما فيه imports
  وSQL/تواقيع الدوال. لا تغييرات مخترعة أو snippets ناقصة بديلًا عن Patch.
- `new_files/<path>.txt`: المحتوى الكامل للملف الجديد. امتداد txt يمنع
  Flutter analyze من اعتباره كودًا ثانيًا؛ أزله عند إضافة ملف متوافق فقط.
- `complete_platform/.../SirajSecureSessionChannel.kt.txt`: class القناة كاملة
  من Commit الإصلاح، إذا لم توجد قناة في مشروعك أصلًا؛ طابق package/namespace
  والعقد قبل إضافتها. ليست أمرًا باستبدال قنوات Activity أو Auth/SQLite.
- `.gitattributes`: يمنع تحويل LF/CRLF في مواد المرجع، كي تبقى البصمات
  مستقرة بعد clone على Windows مع core.autocrlf.
  فراغ سطر context الفارغ في unified diff جزء من صيغة Patch؛ لا تزيله عند التنسيق.

المصدر: `shehab5552/siraj-codex`؛ قبل
`651af0d62d05761c80d9a8cbc9d1f51b836929eb` وبعد
`80b4f0fe1a228731ff6ae57ccdeb5598d201f681`. اختُبرت إعادة تطبيق كل الـ32
على قاعدة Codex المعزولة ومطابقة النتيجة بايتًا ببايت. هذا لا يثبت صلاحية
تطبيقها تلقائيًا على مشروع آخر.

لا تستخدم Cherry-pick شاملًا أو replace شاملًا لـAuth/SQLite. إذا خالف
base hash المحلي مرجع Codex، فهذا متوقع في مشروع مستقل: راجع Patch وادمج
العقد يدويًا، لا تستخدم `--reject` أو `--unsafe-paths` أو حذف DB لإجبار النقل.
عند المطابقة التامة والمراجعة فقط يمكن فحص ملف بعينه بـ`git apply --check`؛
نجاح فحص النص ليس وحده دليل توافق المعمارية.

إعادة توليد مواد المرجع من checkout Codex: `python tool/export_b04_reference.py`.
تظل ملفات README و.gitattributes يدويّة ولا يمسها المصدر.
