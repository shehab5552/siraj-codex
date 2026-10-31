import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../auth/auth_models.dart';
import '../../integrations/ai/quiz_port.dart';
import '../../integrations/ai/tutor_contract.dart';
import '../../integrations/ai/tutor_port.dart';
import 'quiz_access.dart';
import 'quiz_cleanup_owner.dart';
import 'quiz_scorer.dart';
import 'quiz_curriculum.dart';

enum QuizPhase {
  loading,
  idle,
  generating,
  question,
  review,
  summary,
  sessionExpired,
}

class QuizSummary {
  const QuizSummary({
    required this.totalPresented,
    required this.correct,
    required this.incorrect,
    required this.undetermined,
  });
  final int totalPresented, correct, incorrect, undetermined;
  int get judgeable => correct + incorrect;
}

/// Presentation never receives the reviewed answer key.
class QuizQuestionView {
  QuizQuestionView(QuizQuestion q)
    : id = q.id,
      stem = q.stem,
      type = q.type,
      options = q.options,
      sources = q.sources;
  final String id, stem;
  final QuizQuestionType type;
  final List<QuizOption> options;
  final List<SourceReference> sources;
}

class QuizController extends ChangeNotifier {
  QuizController({
    required this.session,
    required QuizAccessPort access,
    QuizPort port = const UnavailableQuizPort(),
    SourceResolverPort sources = const UnavailableSourceResolver(),
    QuizScorer scorer = const QuizScorer(),
    QuizCleanupOwner? cleanup,
    String Function()? newId,
  }) : _access = access,
       _port = port,
       _sources = sources,
       _scorer = scorer,
       _cleanup = cleanup ?? QuizCleanupOwner(),
       _newId = newId ?? Uuid().v4;
  final AuthSession session;
  final QuizAccessPort _access;
  final QuizPort _port;
  final SourceResolverPort _sources;
  final String Function() _newId;
  final QuizScorer _scorer;
  final QuizCleanupOwner _cleanup;
  QuizPhase _phase = QuizPhase.loading;
  QuizErrorCode? _error;
  QuizSession? _session;
  Object? _sessionIdentity;
  QuizRequest? _request;
  final _answers = <String, QuizAnswer>{};
  final _feedback = <String, QuizFeedback>{};
  StreamSubscription<bool>? _watch;
  Future<void>? _initialization, _job, _closing;
  bool _closed = false, _submitting = false;
  int _index = 0, _version = 0;
  QuizPhase get phase => _phase;
  QuizErrorCode? get error => _error;
  bool get busy => _job != null || _submitting;
  bool get needsCleanupRetry => _cleanup.needsRetry;
  int get index => _index;
  int get questionCount => _session?.questions.length ?? 0;
  QuizQuestionView? get question =>
      _session == null ? null : QuizQuestionView(_session!.questions[_index]);
  QuizFeedback? get feedback =>
      _session == null ? null : _feedback[_session!.questions[_index].id];
  QuizSummary? get summary => _phase != QuizPhase.summary
      ? null
      : QuizSummary(
          totalPresented: questionCount,
          correct: _feedback.values
              .where((f) => f.verdict == QuizVerdict.correct)
              .length,
          incorrect: _feedback.values
              .where((f) => f.verdict == QuizVerdict.incorrect)
              .length,
          undetermined: _feedback.values
              .where((f) => f.verdict == QuizVerdict.undetermined)
              .length,
        );
  List<QuizQuestionView> get reviewQuestions => List.unmodifiable(
    _session?.questions.map(QuizQuestionView.new) ?? const <QuizQuestionView>[],
  );
  QuizAnswer? get draftAnswer =>
      question == null ? null : _answers[question!.id];
  QuizAnswer? answerAt(int index) =>
      _session == null || index < 0 || index >= questionCount
      ? null
      : _answers[_session!.questions[index].id];
  QuizFeedback? feedbackAt(int index) =>
      _session == null || index < 0 || index >= questionCount
      ? null
      : _feedback[_session!.questions[index].id];
  bool _answerIsValid(QuizQuestion question, QuizAnswer? answer) {
    if (answer == null) return false;
    try {
      _scorer.grade(question, answer);
      return true;
    } on QuizFailure {
      return false;
    }
  }

  int get answeredCount =>
      _session?.questions
          .where((q) => _answerIsValid(q, _answers[q.id]))
          .length ??
      0;

  /// Opaque UI guard; never exposes or retains reviewed question/answer data.
  Object? get sessionIdentity => _sessionIdentity;
  void setDraftAnswerFor(String questionId, QuizAnswer? answer) {
    if (question?.id != questionId) return;
    setDraftAnswer(answer);
  }

  void setDraftAnswer(QuizAnswer? answer) {
    if (_closed || busy || _phase != QuizPhase.question || question == null) {
      return;
    }
    final id = question!.id;
    if (answer == null) {
      _answers.remove(id);
    } else {
      _answers[id] = answer;
    }
    _feedback.remove(id);
    _error = null;
    _notify();
  }

  Future<void> goToQuestion(int index) async {
    if (_closed ||
        busy ||
        ![QuizPhase.question, QuizPhase.review].contains(_phase) ||
        index < 0 ||
        index >= questionCount) {
      return;
    }
    final version = _version;
    if (!await _current(version)) return;
    _index = index;
    _phase = QuizPhase.question;
    _error = null;
    _notify();
  }

  Future<void> enterReview() async {
    if (_closed || busy || _phase != QuizPhase.question || _session == null) {
      return;
    }
    final version = _version;
    if (!await _current(version)) return;
    _phase = QuizPhase.review;
    _error = null;
    _notify();
  }

  /// No score or answer key is published before explicit confirmed submission.
  /// All inputs must validate; unanswered/invalid inputs are never scored wrong
  /// or silently converted to UNDETERMINED.
  Future<void> finishReview() async {
    final value = _session;
    if (_closed || busy || _phase != QuizPhase.review || value == null) return;
    _submitting = true;
    final version = _version;
    try {
      if (!await _current(version)) return;
      final results = <String, QuizFeedback>{};
      for (final question in value.questions) {
        final answer = _answers[question.id];
        if (answer == null) throw const QuizFailure(QuizErrorCode.invalidInput);
        results[question.id] = _scorer.grade(question, answer);
      }
      if (!await _current(version)) return;
      _feedback
        ..clear()
        ..addAll(results);
      _phase = QuizPhase.summary;
      _error = null;
    } on QuizFailure catch (e) {
      if (!_closed && version == _version) _error = e.code;
    } catch (_) {
      if (!_closed && version == _version) _error = QuizErrorCode.runtimeFailed;
    } finally {
      _submitting = false;
      _notify();
    }
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    try {
      final version = _version;
      await _cleanup.retry();
      if (!await _current(version)) return;
      _watch = _access.watchValidity().listen(
        (valid) {
          if (!valid && !_closed) _expire();
        },
        onError: (Object _, StackTrace _) {
          if (!_closed) _expire();
        },
      );
      if (!_closed && version == _version) {
        _phase = QuizPhase.idle;
        _notify();
      }
    } catch (_) {
      if (!_closed) _expire();
    }
  }

  Future<bool> _current(int version) async {
    if (_closed || version != _version) return false;
    bool valid;
    try {
      valid = await _access.isCurrent();
    } catch (_) {
      valid = false;
    }
    if (_closed || version != _version) return false;
    if (!valid) _expire();
    return valid;
  }

  void _track(Future<void> Function() action) {
    unawaited(
      _cleanup.track(action).then((_) {
        if (!_closed && _cleanup.needsRetry) {
          _error = QuizErrorCode.runtimeFailed;
          _notify();
        }
      }),
    );
  }

  void _discard(QuizSession value) {
    // Retry metadata must not capture questions, answers or a student request.
    final requestId = value.requestId;
    final sessionId = value.id;
    final port = _port;
    _track(() => port.discard(requestId: requestId, sessionId: sessionId));
  }

  void _clear() {
    _version++;
    final request = _request;
    _request = null;
    if (request != null && !request.cancellation.isCancelled) {
      request.cancellation.cancel();
      final requestId = request.requestId;
      final port = _port;
      _track(() => port.cancel(requestId));
    }
    final saved = _session;
    _session = null;
    _sessionIdentity = null;
    if (saved != null) _discard(saved);
    _answers.clear();
    _feedback.clear();
    _index = 0;
    _error = null;
  }

  void _expire() {
    _clear();
    _phase = QuizPhase.sessionExpired;
    _error = QuizErrorCode.sessionExpired;
    _notify();
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }

  Future<void> end() async {
    final expired = _phase == QuizPhase.sessionExpired;
    _clear();
    _phase = expired ? QuizPhase.sessionExpired : QuizPhase.idle;
    _notify();
  }

  Future<void> retryCleanup() async {
    await _cleanup.retry();
    if (!_cleanup.needsRetry) _error = null;
    _notify();
  }

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true;
    _clear();
    await _watch?.cancel();
    await _job;
    await _cleanup.drain();
  }

  QuizAvailability get availability => _port.availability;
  Future<void> startSelection(QuizSelection selection) async {
    if (!selection.isValid ||
        !_port.availability.isReady ||
        selection.catalog.datasetRevision !=
            _port.availability.datasetRevision) {
      _error = QuizErrorCode.notAvailable;
      _notify();
      return;
    }
    await start(
      'Subject: ${selection.scope.subjectId}\nUnit: ${selection.scope.unitId}',
      desiredCount: selection.count,
      desiredType: selection.type,
      scope: selection.scope,
      expectedDatasetRevision: selection.catalog.datasetRevision,
    );
  }

  Future<void> start(
    String text, {
    int? desiredCount,
    QuizQuestionType? desiredType,
    QuizScope? scope,
    String? expectedDatasetRevision,
  }) async {
    if (_closed ||
        busy ||
        _session != null ||
        _phase == QuizPhase.loading ||
        _phase == QuizPhase.sessionExpired) {
      return;
    }
    if (text.trim().isEmpty || (desiredCount != null && desiredCount <= 0)) {
      _error = QuizErrorCode.invalidInput;
      _notify();
      return;
    }
    if (_cleanup.needsRetry || _cleanup.busy) {
      _error = QuizErrorCode.runtimeFailed;
      _notify();
      return;
    }
    final version = ++_version;
    final completion = Completer<void>();
    _job = completion.future;
    _phase = QuizPhase.generating;
    _error = null;
    _notify();
    try {
      if (!await _current(version)) return;
      final availability = _port.availability;
      if (!availability.isReady) {
        throw QuizFailure(availability.error ?? QuizErrorCode.notAvailable);
      }
      if (expectedDatasetRevision != null &&
          availability.datasetRevision != expectedDatasetRevision) {
        throw const QuizFailure(QuizErrorCode.notAvailable);
      }
      final r = QuizRequest(
        requestId: _newId(),
        userId: session.userId,
        accountEpoch: session.accountEpoch,
        text: text.trim(),
        datasetRevision: availability.datasetRevision!,
        cancellation: TutorCancellation(),
        desiredCount: desiredCount,
        desiredType: desiredType,
        scope: scope,
      );
      _request = r;
      final value = await _port.create(r);
      final owned =
          value.userId == r.userId &&
          value.accountEpoch == r.accountEpoch &&
          value.requestId == r.requestId;
      if (!await _current(version) || r.cancellation.isCancelled) {
        if (owned) _discard(value);
        return;
      }
      if (!owned) {
        final requestId = r.requestId;
        final port = _port;
        _track(() => port.cancel(requestId));
        throw const QuizFailure(QuizErrorCode.invalidResponse);
      }
      if (!_validSession(value, r)) {
        _discard(value);
        throw const QuizFailure(QuizErrorCode.invalidResponse);
      }
      if (desiredCount != null && value.questions.length != desiredCount) {
        _discard(value);
        throw const QuizFailure(QuizErrorCode.notAvailable);
      }
      _session = value;
      _sessionIdentity = Object();
      _index = 0;
      _phase = QuizPhase.question;
      _error = null;
    } on QuizFailure catch (e) {
      if (!_closed && version == _version) {
        _error = e.code;
        _phase = QuizPhase.idle;
      }
    } catch (_) {
      if (!_closed && version == _version) {
        _error = QuizErrorCode.runtimeFailed;
        _phase = QuizPhase.idle;
      }
    } finally {
      if (version == _version) _request = null;
      _job = null;
      completion.complete();
      _notify();
    }
  }

  bool _validId(String value) =>
      value.isNotEmpty &&
      value == value.trim() &&
      !RegExp(r'[\x00-\x1f]').hasMatch(value);
  bool _validSession(QuizSession s, QuizRequest r) {
    if (!_validId(s.id) ||
        s.datasetRevision != r.datasetRevision ||
        s.questions.isEmpty ||
        s.questions.map((q) => q.id).toSet().length != s.questions.length ||
        s.questions.map((q) => q.stem.trim()).toSet().length !=
            s.questions.length) {
      return false;
    }
    for (final q in s.questions) {
      if (!_validId(q.id) ||
          q.stem.trim().isEmpty ||
          q.origin != QuizOrigin.llmGenerated ||
          !_scorer.referenceIsValid(q) ||
          q.sources.isEmpty ||
          q.sources.toSet().length != q.sources.length ||
          q.sources.any(
            (ref) => !ref.isValid || ref.datasetRevision != s.datasetRevision,
          ) ||
          (r.desiredType != null && q.type != r.desiredType)) {
        return false;
      }
      if (q.type == QuizQuestionType.mcq &&
          (q.options.any((o) => !_validId(o.id) || o.text.trim().isEmpty) ||
              q.options.map((o) => o.text.trim()).toSet().length !=
                  q.options.length)) {
        return false;
      }
      if (q.type != QuizQuestionType.mcq && q.options.isNotEmpty) return false;
    }
    return true;
  }

  Future<void> submit(QuizAnswer answer) async {
    final s = _session;
    if (_closed ||
        busy ||
        s == null ||
        _phase != QuizPhase.question ||
        feedback != null) {
      return;
    }
    _submitting = true;
    final version = _version;
    try {
      if (!await _current(version)) return;
      final q = s.questions[_index];
      final result = _scorer.grade(q, answer);
      if (version != _version || _closed) return;
      _answers[q.id] = answer;
      _feedback[q.id] = result;
      _error = null;
    } on QuizFailure catch (e) {
      if (version == _version) _error = e.code;
    } finally {
      _submitting = false;
      _notify();
    }
  }

  void next() {
    if (_closed || _phase != QuizPhase.question || feedback == null) return;
    if (_index + 1 < questionCount) {
      _index++;
      _error = null;
    } else {
      _phase = QuizPhase.summary;
    }
    _notify();
  }

  Future<ResolvedSource?> openSource(SourceReference reference) async {
    final version = _version;
    final questionId = question?.id;
    bool sameQuestion() =>
        _phase == QuizPhase.question &&
        questionId != null &&
        question?.id == questionId;
    if (!sameQuestion() ||
        !question!.sources.contains(reference) ||
        !await _current(version)) {
      return null;
    }
    try {
      final result = await _sources.resolve(reference);
      if (!await _current(version) ||
          !sameQuestion() ||
          result == null ||
          result.reference != reference ||
          result.snippet.trim().isEmpty ||
          (result.page != null && result.page! <= 0)) {
        return null;
      }
      return result;
    } catch (_) {
      return null;
    }
  }
}
