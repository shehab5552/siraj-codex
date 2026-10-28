import '../../features/library/library_contracts.dart';
import '../../features/library/pdf_reader_contracts.dart';
import '../../features/chat/chat_models.dart';
import '../../features/chat/chat_copy.dart';
import '../../features/quiz/quiz_copy.dart';
import '../../integrations/ai/quiz_port.dart';
import '../../core/localization/siraj_copy.dart';
import '../../features/auth/auth_models.dart';
import '../../features/resources/artifact_integrity_validator.dart';
import '../../features/resources/download_contracts.dart';
import '../../features/resources/dataset_release_contracts.dart';
import '../../integrations/ai/runtime_contract.dart';

enum ProblemArea { account, chat, quiz, download, dataset, llm, pdf }

enum ProblemAction { retry, redownload, resources, login, back }

/// Safe bilingual presentation from typed codes. Raw exception text, filesystem
/// paths, password data and platform stack traces never enter user copy.
class SirajProblem {
  const SirajProblem({
    required this.area,
    required this.action,
    required this.arabic,
    required this.english,
  });
  final ProblemArea area;
  final ProblemAction action;
  final String arabic, english;
  factory SirajProblem.from(
    Object error, {
    ProblemArea area = ProblemArea.download,
  }) {
    SirajProblem message(ProblemAction action, String ar, String en) =>
        SirajProblem(area: area, action: action, arabic: ar, english: en);
    if (error is PdfFailure) {
      final (action, ar, en) = switch (error.code) {
        PdfFailureCode.unavailable => (
          ProblemAction.resources,
          'قارئ PDF المحلي غير متاح على هذا الجهاز.',
          'The local PDF reader is unavailable on this device.',
        ),
        PdfFailureCode.invalidFile ||
        PdfFailureCode.missingFile ||
        PdfFailureCode.unsafePath => (
          ProblemAction.redownload,
          'تعذر التحقق من الكتاب أو قراءته. أعد تنزيله من الفهرس المعتمد.',
          'The book could not be verified or read. Download it again from the approved catalog.',
        ),
        PdfFailureCode.resourceLimit => (
          ProblemAction.retry,
          'تتجاوز الصفحة حدود ذاكرة القارئ الآمنة. أعد المحاولة أو افتح صفحة أخرى.',
          'The page exceeds the reader memory limits. Retry or open another page.',
        ),
        PdfFailureCode.cancelled || PdfFailureCode.closed => (
          ProblemAction.back,
          'أُغلقت عملية الكتاب بأمان.',
          'The book operation was closed safely.',
        ),
        PdfFailureCode.sessionExpired => (
          ProblemAction.login,
          'انتهت الجلسة. سجّل الدخول مجددًا.',
          'Session expired. Log in again.',
        ),
        PdfFailureCode.busy => (
          ProblemAction.retry,
          'الكتاب قيد الاستخدام أو إغلاق القارئ. انتظر ثم أعد المحاولة.',
          'The book is in use or the reader is closing. Wait and retry.',
        ),
        _ => (
          ProblemAction.retry,
          'تعذر إكمال عملية القارئ. أعد المحاولة.',
          'The reader operation could not finish. Please retry.',
        ),
      };
      return SirajProblem(
        area: ProblemArea.pdf,
        action: action,
        arabic: ar,
        english: en,
      );
    }
    if (error is LibraryFailure) {
      return SirajProblem(
        area: ProblemArea.pdf,
        action: error.code == LibraryFailureCode.readerUnavailable
            ? ProblemAction.resources
            : ProblemAction.retry,
        arabic: error.code == LibraryFailureCode.readerUnavailable
            ? 'القارئ المحلي المعتمد غير متاح. لن يُفتح ملف غير متحقق منه.'
            : 'تعذر قراءة الفهرس المعتمد أو تجهيز الكتاب. راجع المورد ثم أعد المحاولة.',
        english: error.code == LibraryFailureCode.readerUnavailable
            ? 'The approved local reader is unavailable. An unverified file will not be opened.'
            : 'The approved catalog or book could not be read or prepared. Check the resource and retry.',
      );
    }
    if (error is ChatFailure) {
      final action = error.code == ChatFailureCode.sessionExpired
          ? ProblemAction.login
          : error.code == ChatFailureCode.tutorFailure ||
                error.code == ChatFailureCode.sourceUnavailable ||
                error.code == ChatFailureCode.invalidResponse
          ? ProblemAction.resources
          : ProblemAction.retry;
      final ar = chatFailureText(error);
      return SirajProblem(
        area: ProblemArea.chat,
        action: action,
        arabic: ar,
        english: SirajCopy.english(ar),
      );
    }
    if (error is QuizFailure) {
      final ar = quizErrorText(error.code);
      return SirajProblem(
        area: ProblemArea.quiz,
        action: error.code == QuizErrorCode.sessionExpired
            ? ProblemAction.login
            : error.code == QuizErrorCode.modelRequired ||
                  error.code == QuizErrorCode.notAvailable
            ? ProblemAction.resources
            : ProblemAction.retry,
        arabic: ar,
        english: SirajCopy.english(ar),
      );
    }
    if (error is AuthFailure) {
      if (error.code == AuthFailureCode.sessionInvalid) {
        return SirajProblem(
          area: ProblemArea.account,
          action: ProblemAction.login,
          arabic: 'انتهت الجلسة. سجّل الدخول مجددًا للمتابعة.',
          english: 'Session expired. Log in again to continue.',
        );
      }
      return SirajProblem(
        area: ProblemArea.account,
        action: ProblemAction.retry,
        arabic:
            'تعذر إكمال عملية الحساب بأمان. تحقق من البيانات وأعد المحاولة.',
        english:
            'The account operation could not finish safely. Check your details and retry.',
      );
    }
    if (error is ArtifactIntegrityFailure) {
      if (error.code == ArtifactIntegrityFailureCode.missingFile) {
        return message(
          ProblemAction.redownload,
          'ملف المورد غير موجود. لن يُعرض كجاهز. أعد تنزيله من المصدر المعتمد.',
          'The resource file is missing and will not be shown as ready. Download it again from the approved source.',
        );
      }
      if ([
        ArtifactIntegrityFailureCode.hashMismatch,
        ArtifactIntegrityFailureCode.sizeMismatch,
        ArtifactIntegrityFailureCode.fileChanged,
      ].contains(error.code)) {
        return message(
          ProblemAction.redownload,
          'لم يتطابق حجم الملف أو بصمته مع المورد المطلوب. لا تستخدمه؛ أعد التنزيل من المصدر المعتمد.',
          'The file size or hash did not match the requested resource. Do not use it; download it again from the approved source.',
        );
      }
      return message(
        ProblemAction.resources,
        'تعذر التحقق من سلامة المورد. راجع بياناته ومساره المعتمد قبل المحاولة.',
        'Resource integrity could not be verified. Check its approved metadata and location before retrying.',
      );
    }
    if (error is DownloadFailure) {
      switch (error.code) {
        case DownloadFailureCode.insufficientStorage:
          return message(
            ProblemAction.retry,
            'لا توجد مساحة كافية لإكمال التنزيل والتجهيز. حرر مساحة ثم أعد المحاولة.',
            'There is not enough space to complete download and preparation. Free space and retry.',
          );
        case DownloadFailureCode.integrityFailure:
        case DownloadFailureCode.sizeMismatch:
          return message(
            ProblemAction.redownload,
            'لم يجتز الملف فحص الحجم أو البصمة. لم يُفعّل. أعد تنزيله من المصدر المعتمد.',
            'The file failed size or hash verification and was not activated. Download it again from the approved source.',
          );
        case DownloadFailureCode.networkFailure:
          return message(
            ProblemAction.retry,
            'تعذر إكمال النقل عبر HTTPS. لا يكفي ذلك لتحديد سبب الشبكة؛ تحقق من الاتصال ثم حاول الاستئناف.',
            'The HTTPS transfer could not finish. This alone does not identify the network cause; check connectivity and retry resume.',
          );
        case DownloadFailureCode.httpFailure:
          return message(
            ProblemAction.retry,
            'لم يقبل الخادم طلب التنزيل${error.httpStatus == null ? '' : ' (HTTP ${error.httpStatus})'}. أعد المحاولة أو راجع المصدر المعتمد.',
            'The server did not accept the download request${error.httpStatus == null ? '' : ' (HTTP ${error.httpStatus})'}. Retry or check the approved source.',
          );
        case DownloadFailureCode.busy:
          return message(
            ProblemAction.retry,
            'المورد قيد عملية أخرى. انتظر انتهاءها ثم أعد المحاولة.',
            'Another operation owns this resource. Wait for it to finish, then retry.',
          );
        case DownloadFailureCode.storageUnavailable:
        case DownloadFailureCode.ioFailure:
          return message(
            ProblemAction.retry,
            'تعذر قراءة التخزين الخاص بالتطبيق أو الكتابة إليه. لم يُستبدل مورد نشط. راجع التخزين وأعد المحاولة.',
            'App-private storage could not be read or written. No active resource was replaced. Check storage and retry.',
          );
        default:
          return message(
            ProblemAction.resources,
            'تعذر اعتماد ملف التنزيل أو هويته بأمان. راجع المورد المعتمد قبل إعادة المحاولة.',
            'The download or its identity could not be verified safely. Check the approved resource before retrying.',
          );
      }
    }
    if (error is DatasetFailure) {
      if (error.code == DatasetFailureCode.cancelled) {
        return message(
          ProblemAction.retry,
          'أُلغي التجهيز. تبقى الموارد النشطة محمية. يمكنك إعادة المحاولة.',
          'Preparation was cancelled. Active resources remain protected. You can retry.',
        );
      }
      if (error.code == DatasetFailureCode.insufficientStorage) {
        return message(
          ProblemAction.retry,
          'لا توجد مساحة كافية لتجهيز الإصدار مع الاحتفاظ بالإصدار السابق. حرر مساحة ثم أعد المحاولة.',
          'There is not enough space to prepare the new revision while retaining the previous one. Free space and retry.',
        );
      }
      return message(
        ProblemAction.resources,
        'لم يثبت اكتمال المورد وتوافقه أو توفر فاحصه المعتمد. لم تُثبت جاهزية جديدة. راجع هوية Dataset وEmbedding وIndex وبيانات الموارد.',
        'The resource completeness, compatibility or approved validator is unavailable or unverified. No new readiness was established. Check Dataset, Embedding, Index and resource identities.',
      );
    }
    if (error is RuntimeFailure) {
      if (error.code == RuntimeErrorCode.outOfMemory) {
        return message(
          ProblemAction.retry,
          'تعذر تشغيل المورد بالذاكرة المتاحة. أوقف العمليات غير اللازمة ثم أعد المحاولة.',
          'The resource could not run with the available memory. Stop unnecessary work and retry.',
        );
      }
      return message(
        ProblemAction.resources,
        'المحرك أو المورد المحلي غير جاهز أو غير متوافق. راجع حالة الموارد قبل المحاولة؛ لن تُعرض إجابة تجريبية.',
        'The local runtime or resource is unavailable or incompatible. Check resource status before retrying; no demo answer will be shown.',
      );
    }
    return message(
      ProblemAction.retry,
      'تعذر إكمال العملية بأمان. لم يُحدد السبب؛ أعد المحاولة دون مشاركة بيانات حساسة.',
      'The operation could not finish safely. Its cause is not identified; retry without sharing sensitive data.',
    );
  }
}
