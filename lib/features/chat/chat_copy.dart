import '../../integrations/ai/tutor_contract.dart';
import 'chat_models.dart';

String chatFailureText(ChatFailure failure) => switch (failure.code) {
  ChatFailureCode.invalidQuestion => 'اكتب سؤالًا قبل الإرسال.',
  ChatFailureCode.sessionExpired =>
    'انتهت الجلسة. سجّل الدخول مجددًا لعرض محادثاتك.',
  ChatFailureCode.conversationMissing => 'هذه المحادثة لم تعد متاحة.',
  ChatFailureCode.persistenceFailure =>
    'تعذّر حفظ الرسالة أو قراءة المحادثة. أعد المحاولة.',
  ChatFailureCode.invalidResponse =>
    'تعذّر التحقق من الإجابة ومصادرها؛ لم تُحفظ إجابة.',
  ChatFailureCode.sourceUnavailable => 'المصدر غير متاح لهذه الإجابة حاليًا.',
  ChatFailureCode.requestCancelled => 'أُلغي الطلب. يمكنك المحاولة مجددًا.',
  ChatFailureCode.unansweredMessage =>
    'آخر سؤال محفوظ بلا إجابة. يمكنك إعادة المحاولة.',
  ChatFailureCode.tutorFailure => switch (failure.tutorError) {
    TutorErrorCode.resourceNotReady =>
      'موارد الذكاء الاصطناعي غير جاهزة. سؤالك محفوظ ويمكنك إعادة المحاولة بعد تجهيزها.',
    TutorErrorCode.modelLoadFailed =>
      'تعذّر تحميل النموذج المحلي. سؤالك محفوظ.',
    TutorErrorCode.outOfMemory =>
      'تعذّر إكمال الإجابة بسبب الذاكرة المتاحة. سؤالك محفوظ.',
    TutorErrorCode.requestCancelled => 'أُلغي طلب الإجابة.',
    TutorErrorCode.sourceUnavailable => 'تعذّر التحقق من مصدر الإجابة.',
    _ => 'تعذّر إعداد الإجابة المحلية. سؤالك محفوظ ويمكنك إعادة المحاولة.',
  },
};
