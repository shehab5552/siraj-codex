import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

/// Central UI copy. IDs, student text and scientific evidence are never translated.
abstract final class SirajCopy {
  static bool isArabic(BuildContext context) =>
      Localizations.of<SirajLocale>(
        context,
        SirajLocale,
      )?.locale.languageCode !=
      'en';
  static String choose(BuildContext context, String arabic, String english) =>
      isArabic(context) ? arabic : english;
  static String text(BuildContext context, String arabic) =>
      isArabic(context) ? arabic : (_english[arabic] ?? arabic);
  static const _english = <String, String>{
    'إجابة صحيحة وفق المفتاح المراجَع.':'Correct according to the reviewed answer key.',
    'الإجابة لا تطابق المعيار المراجَع.':'The answer does not match the reviewed criteria.',
    'تعذر الحكم بثقة وفق المعيار المراجَع المتاح.':'A confident verdict is not possible with the available reviewed criteria.',

    "آخر سؤال محفوظ بلا إجابة. يمكنك إعادة المحاولة.":
        "Your last question is saved without an answer. You can retry.",
    "أدخل عددًا صحيحًا موجبًا.": "Enter a positive whole number.",
    "أنت": "You",
    "أنواع متنوعة": "Mixed types",
    "أُلغي الطلب. يمكنك المحاولة مجددًا.":
        "Request cancelled. You can try again.",
    "أُلغي طلب الإجابة.": "Answer request cancelled.",
    "أُلغي طلب الاختبار.": "Quiz request cancelled.",
    "إجابة جزئية": "Partial answer",
    "إجابة صحيحة": "Correct answer",
    "إجابة غير صحيحة": "Incorrect answer",
    "إجابة قصيرة": "Short answer",
    "إجابتك": "Your answer",
    "إرسال السؤال": "Send question",
    "إعادة محاولة الإنهاء": "Retry cleanup",
    "إلغاء الطلب": "Cancel request",
    "إنشاء الاختبار": "Generate quiz",
    "إنهاء الاختبار": "End quiz",
    "احتفظ بكلمة المرور في مكان آمن؛ لا توجد آلية لاستعادتها في هذه النسخة.":
        "Keep your password safe; this version has no password recovery.",
    "اختيار من متعدد": "Multiple choice",
    "استخدم الوحدة المطلوبة في السؤال، أو اتركها فارغة للكمية بلا وحدة.":
        "Use the unit requested in the question, or leave blank for a unitless quantity.",
    "استخدم حساب سراج المحلي المسجل على هذا الجهاز.":
        "Use the local SIRAJ account registered on this device.",
    "اطلب اختبارًا في درس أو وحدة. تُولد الأسئلة محليًا بعد جاهزية الموارد والتحقق منها. لا تُحفظ نتيجة الاختبار بعد إنهائه.":
        "Request a quiz on a lesson or unit. Questions are generated locally after resources are verified and ready. Results are not retained after ending the quiz.",
    "اكتب سؤالك أو رسالة متابعة": "Write your question or a follow-up",
    "اكتب سؤالًا قبل الإرسال.": "Write a question before sending.",
    "اكتب طلب الاختبار.": "Enter your quiz request.",
    "الاختبار غير متاح بالموارد أو العدد المطلوب حاليًا.":
        "A quiz with the requested resources or question count is currently unavailable.",
    "الجلسة تُحفظ على هذا الجهاز بعد التحقق من بيانات الحساب.":
        "Your session is saved on this device after verifying your credentials.",
    "الذكاء الاصطناعي غير جاهز حاليًا. يمكنك حفظ أسئلتك محليًا.":
        "AI is currently unavailable. You can save your questions locally.",
    "السؤال التالي": "Next question",
    "القيمة": "Value",
    "المحادثة": "Conversation",
    "المحادثة غير متاحة لهذه الجلسة.":
        "This conversation is unavailable for this session.",
    "المصادر المسجلة غير متاحة.": "The recorded sources are unavailable.",
    "المصدر غير متاح حاليًا.": "The source is currently unavailable.",
    "المصدر غير متاح لهذه الإجابة حاليًا.":
        "The source for this answer is currently unavailable.",
    "النموذج المحلي غير جاهز لتوليد الاختبار. جهّز الموارد ثم أعد المحاولة.":
        "The local model is not ready to generate a quiz. Prepare the resources, then retry.",
    "الوحدة": "Unit",
    "انتهت الجلسة. المصدر غير متاح.":
        "Session expired. The source is unavailable.",
    "انتهت الجلسة. سجّل الدخول مجددًا لعرض محادثاتك.":
        "Session expired. Log in again to view your conversations.",
    "انتهت جلسة الاختبار؛ لن يعرض المصدر.":
        "The quiz session has ended; its source will not be shown.",
    "انتهت صلاحية الجلسة. يلزم تسجيل الدخول.":
        "Session expired. Please log in.",
    "تابع أسئلتك من حيث توقفت": "Continue where you left off",
    "تبقى هذه النتيجة في الجلسة الحالية فقط، وتُمحى عند إنهائها.":
        "These results remain in this session only and are cleared when it ends.",
    "تحديث المحادثات": "Refresh conversations",
    "تحقق من الإجابة": "Check answer",
    "تسجيل الدخول غير مفعّل مؤقتًا حتى اعتماد حماية كلمة المرور الإنتاجية.":
        "Login is temporarily unavailable pending approval of the production password protection profile.",
    "تعذر إكمال العملية بأمان. أعد المحاولة لاحقًا.":
        "The operation could not finish safely. Please retry later.",
    "تعذر الحكم": "Undetermined",
    "تعذر عرض الاختبار لأن بياناته لم تجتز التحقق.":
        "This quiz cannot be shown because its data failed validation.",
    "تعذّر إعداد الإجابة المحلية. سؤالك محفوظ ويمكنك إعادة المحاولة.":
        "Could not prepare a local answer. Your question is saved and you can retry.",
    "تعذّر إكمال الإجابة بسبب الذاكرة المتاحة. سؤالك محفوظ.":
        "The answer could not finish with the available memory. Your question is saved.",
    "تعذّر إنشاء الحساب. تحقق من البيانات وحاول مجددًا.":
        "Could not create the account. Check your details and try again.",
    "تعذّر التجهيز": "Preparation failed",
    "تعذّر التحقق من الإجابة ومصادرها؛ لم تُحفظ إجابة.":
        "The answer and its sources could not be verified; no answer was saved.",
    "تعذّر التحقق من مصدر الإجابة.": "The answer source could not be verified.",
    "تعذّر تحميل النموذج المحلي. سؤالك محفوظ.":
        "Could not load the local model. Your question is saved.",
    "تعذّر تسجيل الدخول. تحقق من بيانات الحساب.":
        "Could not log in. Check your credentials.",
    "تعذّر حفظ الرسالة أو قراءة المحادثة. أعد المحاولة.":
        "Could not save the message or read the conversation. Please retry.",
    "تُحفظ حتى عشر محادثات على هذا الجهاز. عند حفظ أول رسالة صالحة في المحادثة الحادية عشرة، تُحذف أقدم محادثة تلقائيًا.":
        "Up to ten conversations are saved on this device. Saving the first valid message in an eleventh conversation automatically deletes the oldest.",
    "جارٍ إعداد أسئلة الاختبار والتحقق منها…":
        "Preparing and validating quiz questions…",
    "جارٍ إعداد الإجابة…": "Preparing an answer…",
    "جارٍ التنزيل": "Downloading",
    "جارٍ حفظ الرسالة…": "Saving your message…",
    "جارٍ فتح المحادثة…": "Opening the conversation…",
    "حساب واحد على هذا الجهاز، دون إنترنت أو خادم للحسابات.":
        "One account on this device, without an online account server.",
    "حُذفت أقدم محادثة بعد حفظ سؤالك؛ يُحفظ آخر عشر محادثات.":
        "The oldest conversation was deleted after saving your question; the last ten conversations are retained.",
    "حُفظ الحساب، وتعذّر إكمال الجلسة. سجّل الدخول للمتابعة.":
        "The account was saved, but the session could not finish. Log in to continue.",
    "خطأ": "False",
    "راجع الإجابة أو عدد الأسئلة المدخل قبل المتابعة.":
        "Check your answer or question count before continuing.",
    "سراج — المعلم المحلي": "SIRAJ — Local tutor",
    "صح": "True",
    "صح أو خطأ": "True or false",
    "عدد الأسئلة (اختياري)": "Question count (optional)",
    "عرض النتيجة": "View results",
    "غير متوفر": "Unavailable",
    "لا تتوفر استعادة كلمة المرور أو إضافة حساب ثانٍ في SIRAJ P0.":
        "Password recovery and a second account are not available in SIRAJ P0.",
    "لم ينتج المعلّم أسئلة اجتازت التحقق. يمكنك إعادة المحاولة.":
        "No generated questions passed validation. You can retry.",
    "ما الذي تريد التدرب عليه؟": "What would you like to practise?",
    "محادثة جديدة": "New conversation",
    "محادثة جديدة مؤقتة. تُحفظ عند إرسال أول سؤال صالح.":
        "A new temporary conversation. It is saved when you send the first valid question.",
    "مسألة عددية": "Numeric question",
    "مصدر الإجابة": "Answer source",
    "مصدر السؤال": "Question source",
    "موارد الذكاء الاصطناعي غير جاهزة. سؤالك محفوظ ويمكنك إعادة المحاولة بعد تجهيزها.":
        "AI resources are not ready. Your question is saved; retry after preparing them.",
    "نتيجة الجلسة": "Session results",
    "نوع الأسئلة": "Question type",
    "هذه المحادثة لم تعد متاحة.": "This conversation is no longer available.",
    "واجهة إنشاء الحساب جاهزة، لكنها غير مفعّلة حتى اعتماد حماية كلمة المرور الإنتاجية.":
        "Account creation is unavailable pending approval of the production password protection profile.",
    "يتطلب التحقق من السلامة والتوافق":
        "Integrity and compatibility verification required",
    "يلزم تسجيل دخول صالح لفتح محادثاتك وإرسال الأسئلة.":
        "A valid login is required to open your conversations and send questions.",
    "يُحفظ الحساب محليًا. لا تتوفر استعادة كلمة مرور منسية في P0.":
        "The account is stored locally. Forgotten passwords cannot be recovered in P0.",
    "تعذر قراءة حالات الموارد المحلية.":
        "Could not read local resource status.",
    "هذه حالات مسجلة محليًا وليست شهادة بجاهزية الملفات. لا تُفعّل الموارد إلا بعد فحص السلامة والتوافق.":
        "These locally recorded states do not certify file readiness. Resources must pass integrity and compatibility checks before activation.",
    "النموذج المحلي (LLM)": "Local model (LLM)",
    "حزم بيانات RAG": "RAG dataset packs",
    "نموذج Query Embedding المشترك": "Shared Query Embedding model",
    "نموذج Embedding جزء من تجهيز Dataset، وليس تنزيلًا منفصلًا. لا تتحقق RAG_READY من سجلات الموارد وحدها.":
        "The Embedding model is part of Dataset preparation, not a separate download. Resource records alone do not establish RAG_READY.",
    "كتب PDF": "PDF books",
    "كتب PDF مستقلة عن نموذج الذكاء الاصطناعي وبيانات RAG.":
        "PDF books are independent of the AI model and RAG data.",
    "لا توجد موارد مسجلة في هذا القسم.":
        "No resources are registered in this section.",

    'سراج': 'SIRAJ',
    'الرئيسية': 'Home',
    'المساعد': 'Assistant',
    'المكتبة': 'Library',
    'الاختبارات': 'Quizzes',
    'مرحبًا بك في سراج': 'Welcome to SIRAJ',
    'الإعدادات': 'Settings',
    'حالة الموارد': 'Resource status',
    'محادثاتي المحفوظة': 'Saved conversations',
    'تعلّم بثقة، حتى دون اتصال بالإنترنت':
        'Learn with confidence, even offline',
    'فتح المحادثة': 'Open conversation',
    'فتح معاينة المحادثة': 'Open chat preview',
    'اختبر فهمك': 'Test your understanding',
    'ابدأ الآن': 'Get started',
    'جاهزية الموارد': 'Resource readiness',
    'إعادة المحاولة': 'Retry',
    'إلغاء': 'Cancel',
    'إغلاق': 'Close',
    'تأكيد': 'Confirm',
    'متابعة': 'Continue',
    'السابق': 'Back',
    'التالي': 'Next',
    'اللغة': 'Language',
    'المظهر': 'Appearance',
    'العربية': 'Arabic',
    'الإنجليزية': 'English',
    'فاتح': 'Light',
    'داكن': 'Dark',
    'حسب النظام': 'System',
    'الحساب': 'Account',
    'تسجيل الخروج': 'Log out',
    'حذف الحساب': 'Delete account',
    'معلومات التطبيق': 'About SIRAJ',
    'أحدث محادثة محفوظة': 'Latest saved conversation',
    'لا توجد محادثات محفوظة بعد.': 'No saved conversations yet.',
    'تجهيز الموارد': 'Prepare resources',
    'الوصول السريع': 'Quick access',
    'المساعد المحلي': 'Local assistant',
    'محادثاتك': 'Your conversations',
    'إنشاء الحساب المحلي': 'Create local account',
    'تسجيل الدخول': 'Log in',
    'إنشاء الحساب': 'Create account',
    'اسم المستخدم': 'Username',
    'كلمة المرور': 'Password',
    'تأكيد كلمة المرور': 'Confirm password',
    'اسم المستخدم مطلوب': 'Username is required',
    'كلمة المرور مطلوبة': 'Password is required',
    'تأكيد كلمة المرور مطلوب': 'Password confirmation is required',
    'كلمتا المرور غير متطابقتين': 'Passwords do not match',
    'إظهار كلمة المرور': 'Show password',
    'إخفاء كلمة المرور': 'Hide password',
    'إظهار التأكيد': 'Show confirmation',
    'إخفاء التأكيد': 'Hide confirmation',
  };
}

extension SirajCopyContext on BuildContext {
  String tr(String arabic) => SirajCopy.text(this, arabic);
  String copy(String arabic, String english) =>
      SirajCopy.choose(this, arabic, english);
}

class SirajLocale {
  const SirajLocale(this.locale);
  final Locale locale;
}

class SirajCopyDelegate extends LocalizationsDelegate<SirajLocale> {
  const SirajCopyDelegate();
  @override
  bool isSupported(Locale locale) =>
      const ['ar', 'en'].contains(locale.languageCode);
  @override
  Future<SirajLocale> load(Locale locale) =>
      SynchronousFuture(SirajLocale(locale));
  @override
  bool shouldReload(covariant SirajCopyDelegate old) => false;
}
