import '../../integrations/ai/quiz_port.dart';

String quizErrorText(QuizErrorCode code) => switch (code) {
  QuizErrorCode.modelRequired =>
    'النموذج المحلي غير جاهز لتوليد الاختبار. جهّز الموارد ثم أعد المحاولة.',
  QuizErrorCode.notAvailable =>
    'الاختبار غير متاح بالموارد أو العدد المطلوب حاليًا.',
  QuizErrorCode.generationRejected =>
    'لم ينتج المعلّم أسئلة اجتازت التحقق. يمكنك إعادة المحاولة.',
  QuizErrorCode.invalidResponse =>
    'تعذر عرض الاختبار لأن بياناته لم تجتز التحقق.',
  QuizErrorCode.requestCancelled => 'أُلغي طلب الاختبار.',
  QuizErrorCode.sessionExpired => 'انتهت صلاحية الجلسة. يلزم تسجيل الدخول.',
  QuizErrorCode.invalidInput =>
    'راجع الإجابة أو عدد الأسئلة المدخل قبل المتابعة.',
  QuizErrorCode.runtimeFailed =>
    'تعذر إكمال العملية بأمان. أعد المحاولة لاحقًا.',
};
