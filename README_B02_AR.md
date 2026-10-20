# SIRAJ — B-02 Flutter Foundation (Debug UI)

هذه حزمة **ملفات مصدر فقط**، وليست مشروع Flutter مستقلًا أو APK.

## مسار المشروع المعتمد

`D:\SIRAJ\App Flutter`

## الملفات التي تُنسخ

- `lib/main.dart` (يستبدل ملف العداد الافتراضي)
- `lib/app/siraj_app.dart`
- `lib/app/app_bootstrap.dart`
- `lib/app/app_routes.dart`
- `lib/features/home/home_page.dart`
- `lib/features/chat/chat_page.dart`
- `test/widget_test.dart` (يستبدل اختبار العداد الافتراضي)

احتفظ بملف `pubspec.yaml` ومجلد `android` وكل ملفات مشروعك الأخرى دون تعديل.

## التنفيذ

1. احتفظ بنسخة من `lib/main.dart` و`test/widget_test.dart` عند الحاجة.
2. استخرج محتويات ZIP، ثم انسخ المجلدين `lib` و`test` إلى جذر مشروع Flutter مع دمج المجلدات، ووافق على استبدال **هذين الملفين الافتراضيين فقط**.
3. افتح PowerShell ونفّذ:

```powershell
Set-Location 'D:\SIRAJ\App Flutter'
flutter analyze
flutter test
flutter run -d R3CR40J3XRZ
```

## حدود الإنجاز

- التطبيق يعرض شاشة عربية ومعاينة Chat في وضع Debug فقط.
- نسخة Profile/Release لا تعرض معاينة المحادثة؛ شاشة البدء مغلقة حتى بناء نظام الحساب والجلسة.
- زر الإرسال معطل عمدًا؛ لا حسابات حقيقية ولا SQLite ولا RAG ولا AI مزعوم.
- لا توجد إضافات Dependencies جديدة.
- ينبغي تنفيذ الاختبارات فعليًا على بيئة المستخدم؛ هذه الحزمة لم تُفحص باستخدام Flutter SDK في بيئة إعداد الملفات.
