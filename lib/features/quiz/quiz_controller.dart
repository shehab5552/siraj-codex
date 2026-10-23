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

enum QuizPhase { loading, idle, generating, question, summary, sessionExpired }

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

  Future<void> start(
    String text, {
    int? desiredCount,
    QuizQuestionType? desiredType,
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
      final r = QuizRequest(
        requestId: _newId(),
        userId: session.userId,
        accountEpoch: session.accountEpoch,
        text: text.trim(),
        datasetRevision: availability.datasetRevision!,
        cancellation: TutorCancellation(),
        desiredCount: desiredCount,
        desiredType: desiredType,
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
