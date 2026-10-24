# سراج SIRAJ P0 — Flutter

تطبيق تعلم محلي بنظام حساب واحد. هذه شجرة التكامل الجاري في PR #12؛ لا تعني جاهزية إنتاجية أو نجاح Biology G2/G3. لا توجد إجابات أو كتب أو أسئلة تجريبية في التطبيق العادي.

## فتح المشروع على Windows باستخدام VS Code

1. ثبّت Git، وFlutter **3.38.5** (يتضمن Dart **3.10.4**) وأضف `flutter/bin` إلى PATH.
2. ثبّت Android Studio لتوفير Android SDK وPlatform Tools والمحاكي، وJDK 17. استخدم `flutter doctor --android-licenses` للموافقات الرسمية.
3. ثبّت Visual Studio Code وإضافتي Flutter/Dart المقترحتين. **Visual Studio 2022 ليس شرطًا لتطوير Android**.
4. استنسخ فرع التكامل، ثم افتح المجلد الذي يحتوي `pubspec.yaml`:

```powershell
git clone --branch codex/unified-siraj-v2-integration-20261024 https://github.com/shehab5552/siraj-codex.git
cd siraj-codex
code .
flutter doctor -v
flutter --version
dart --version
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter devices
flutter run -d <DEVICE_ID> -t lib/main.dart
flutter build apk --debug
```

يولّد Gradle ملف `android/local.properties` المحلي من إعدادات SDK؛ لا يحتاج المشروع مسار Codex أو قاعدة بيانات أو مفتاحًا خارج المستودع. قد يتطلب أول بناء اتصالًا لتنزيل اعتماديات Pub/Gradle/Android وSQLite الرسمية. لا تستخدم `dependency_overrides` أو مكتبة SQLite مجهولة لحل حجب الشبكة.

## الهوية والبيانات

- هوية الحزمة المعزولة: **com.example.siraj.unifiedtest**، لكل من Debug وRelease التقييمي. لا تستورد بيانات التطبيق الأصلي أو مفاتيحه. لا تغيّر الهوية إلى هوية إنتاجية دون خطة انتقال معتمدة.
- المدخل الطبيعي الوحيد: `lib/main.dart`. ملف `main_v2_preview.dart` أداة Debug منفصلة، لا يُستخدم في حزمة التسليم.
- الحساب وكلمات المرور والجلسات محلية؛ Keystore يحمي علامة الجلسة، وSQLite يحفظ تجزئة nonce. الخروج يحافظ على الحساب والمحادثات والموارد. الحذف المؤكد يزيل الحساب ومحادثاته ويحافظ على الموارد المشتركة.
- Debug Android يستخدم PBKDF2-HMAC-SHA256 أصليًا في خيط خلفي، بمعامل التقييم القوي **600000**. هذا ليس موافقة أداء أو اعتماد أمن إنتاجي. واجهة إدخال بيانات الاعتماد في Release تبقى مغلقة حتى اعتماد ملف إعداد KDF على Android المستهدف.
- المظهر/اللغة/إكمال التعريف تفضيلات جهاز غير سرية. لا تمنح صلاحية دخول للحساب.

## بناء Release والتوقيع

```powershell
flutter build apk --release
```

عند عدم توفير مفاتيح، ينتج بناء Release **غير موقّع**، وليس إصدارًا إنتاجيًا قابلًا للتثبيت. لا يُستخدم مفتاح Android Debug لتوقيعه تلقائيًا. لتوقيع نسخة تقييم معزولة أو إصدار معتمد، أدخل القيم التالية من مخزن أسرار محلي أو CI؛ لا تحفظها في Git أو سجل أو README:

- `SIRAJ_KEYSTORE_PATH`
- `SIRAJ_KEYSTORE_PASSWORD`
- `SIRAJ_KEY_ALIAS`
- `SIRAJ_KEY_PASSWORD`

يجب توفير الأربع معًا. إنشاء المفتاح وحفظه ونسخه الاحتياطي مسؤولية مالك الإصدار. توقيع APK لا يعتمد تلقائيًا Auth أو AI أو G2/G3.

**Flutter 3.38.5:** عند الانتقال بين Debug وRelease لا تستخدم `--no-pub` لأمر البناء الأول في الوضع الجديد؛ تحتاج أدوات Flutter لإعادة توليد تسجيل إضافات الوضع وإبعاد `integration_test` عن Release. لا تعدّل `GeneratedPluginRegistrant.java` يدويًا. أعد `flutter pub get --enforce-lockfile` وتحقق أن `pubspec.lock` لم يتغير.

## حدود التشغيل الفعلي

- LLM وShared Embedding وBiology RAG وIndex وعقود الدقة/المصادر يجب أن تكون معتمدة ومتوافقة ومختبرة. الخدمات الافتراضية ترجع أخطاء عدم الجاهزية؛ لا تُظهر READY أو إجابات وهمية.
- لا يوجد فهرس كتب PDF رسمي مضمّن. لا يُستنتج فهرس من أمثلة التصميم أو ملفات مجهولة.
- Quiz يحتاج LLM+RAG وأدلة وأمثلة مراجعة؛ لا يوجد Question Bank يقدّم اختبارًا جاهزًا. بيانات المحاولة في RAM فقط، وUndetermined خارج مقام النتائج المحسومة.
- اختبارات Flutter السحابية وبناء APK ليست اختبار هاتف Samsung أو اعتماد جودة تعليمية. يلزم G2 ثم G3 على Android فعلي عند توفير الموارد المتوافقة.

## الاختبارات والتسليمات

```powershell
flutter test integration_test/unified_native_kdf_test.dart -d <ANDROID_DEVICE_ID>
flutter test integration_test/unified_application_test.dart -d <ANDROID_DEVICE_ID>
```

شغّل اختبارات التكامل فقط على تثبيت **معزول مخصص للاختبار**؛ اختبار التطبيق ينشئ حسابًا اصطناعيًا ويحذفه داخل هذه الهوية، ولا يقرأ التطبيق الأصلي. أول اختبار واجهة يفترض بيانات تثبيت نظيفة لهذه الهوية المعزولة.

Workflow `SIRAJ unified integration verification` يبني Debug من main ويصدر ZIP للسورس مع Commit SHA وSHA-256، ويختبر محاكي API33 عند نجاح متطلبات Android. راجع نتائج التشغيل والتقرير المرتبط بالالتزام؛ لا تستنتج النجاح من مجرد وجود ملف Artifact جزئي.

الخط المضمّن Noto Sans Arabic مرخص بـSIL OFL 1.1؛ المصدر وبصماته في `assets/fonts/PROVENANCE.md` والترخيص بجواره. رموز Material من Flutter. لا تُحمّل الخطوط عبر الشبكة أثناء تشغيل التطبيق.
