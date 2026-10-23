import 'dart:async';
import 'package:flutter/foundation.dart';

import 'pinned_retriever.dart';
import 'rag_runtime_contract.dart';
import 'runtime_contract.dart';
import 'tutor_contract.dart';
import 'tutor_pipeline_contract.dart';
import 'tutor_port.dart';

/// Offline application adapter for existing B08 ports. Required policy/runtime
/// dependencies have no permissive defaults and no embedded fixture answers.
class PipelineTutorPort implements TutorPort, SourceResolverPort {
  PipelineTutorPort({
    required DatasetProvider datasets,
    required ModelRuntime runtime,
    required PinnedRetriever retriever,
    required ScopeResolver scope,
    required EvidenceGate evidence,
    required TutorPromptBuilder prompts,
    required AnswerValidator answers,
    required Duration requestTimeout,
  }) : _datasets = datasets,
       _runtime = runtime,
       _retriever = retriever,
       _scope = scope,
       _evidence = evidence,
       _prompts = prompts,
       _answers = answers,
       _timeout = requestTimeout {
    if (requestTimeout <= Duration.zero) {
      throw ArgumentError.value(requestTimeout);
    }
  }
  final DatasetProvider _datasets;
  final ModelRuntime _runtime;
  final PinnedRetriever _retriever;
  final ScopeResolver _scope;
  final EvidenceGate _evidence;
  final TutorPromptBuilder _prompts;
  final AnswerValidator _answers;
  final Duration _timeout;
  bool _closed = false;
  _PipelineTurn? _active;
  Future<TutorReply>? _job;
  final _sourceReads = <Future<void>>{};

  @override
  TutorAvailability get availability {
    final revision = _datasets.availableRevision;
    if (_closed ||
        _active != null ||
        _runtime.state != ModelRuntimeState.ready ||
        _runtime.configuration == null ||
        _runtime.capabilities == null ||
        revision == null ||
        !validIdentity(revision) ||
        (_datasets.mode == DatasetRunMode.integrationFixture && !kDebugMode)) {
      return const TutorAvailability.unavailable();
    }
    return TutorAvailability.ready(revision);
  }

  TutorReply _reply(
    TutorRequest r,
    TutorResult result, [
    List<SourceReference> approved = const [],
  ]) => TutorReply(
    requestId: r.requestId,
    userId: r.userId,
    accountEpoch: r.accountEpoch,
    conversationId: r.conversationId,
    datasetRevision: r.datasetRevision,
    result: result,
    approvedSources: approved,
  );
  TutorReply _error(TutorRequest r, TutorErrorCode code) =>
      _reply(r, TutorResult.error(code));

  @override
  Future<TutorReply> ask(TutorRequest request) async {
    if (request.cancellation.isCancelled) {
      return _error(request, TutorErrorCode.requestCancelled);
    }
    final ready = availability;
    if (!ready.isReady || request.datasetRevision != ready.datasetRevision) {
      return _error(request, TutorErrorCode.resourceNotReady);
    }
    if ([
          request.requestId,
          request.userId,
          request.accountEpoch,
          request.conversationId,
        ].any((v) => !validIdentity(v)) ||
        request.question.trim().isEmpty) {
      return _error(request, TutorErrorCode.invalidResponse);
    }
    final token = TutorCancellation();
    final r = TutorRequest(
      requestId: request.requestId,
      userId: request.userId,
      accountEpoch: request.accountEpoch,
      conversationId: request.conversationId,
      question: request.question,
      datasetRevision: request.datasetRevision,
      cancellation: token,
      history: request.history,
    );
    final turn = _PipelineTurn(r);
    _active = turn;
    final completion = Completer<TutorReply>();
    _job = completion.future;
    void complete(TutorReply result) {
      if (identical(_active, turn)) {
        _active = null;
        _job = null;
      }
      completion.complete(result);
    }

    unawaited(
      _execute(r).then(
        complete,
        onError: (Object _, StackTrace _) =>
            complete(_error(r, TutorErrorCode.generationFailed)),
      ),
    );
    request.cancellation.whenCancelled.then((_) {
      if (identical(_active, turn)) token.cancel();
    });
    final timer = Timer(_timeout, () {
      turn.timedOut = true;
      token.cancel();
    });
    try {
      final result = await Future.any([
        completion.future,
        token.whenCancelled.then(
          (_) => _error(
            r,
            turn.timedOut
                ? TutorErrorCode.generationFailed
                : TutorErrorCode.requestCancelled,
          ),
        ),
      ]);
      return token.isCancelled
          ? _error(
              r,
              turn.timedOut
                  ? TutorErrorCode.generationFailed
                  : TutorErrorCode.requestCancelled,
            )
          : result;
    } finally {
      timer.cancel();
    }
  }

  void _checkpoint(TutorRequest r) {
    if (r.cancellation.isCancelled) {
      throw const RagFailure(TutorErrorCode.requestCancelled);
    }
  }

  Future<TutorReply> _execute(TutorRequest r) async {
    RevisionPinnedHandle? handle;
    var generated = false;
    try {
      try {
        _checkpoint(r);
        handle = await _datasets.openRevision(r.datasetRevision!);
        _checkpoint(r);
        if (handle == null ||
            handle.configuration.revision != r.datasetRevision ||
            handle.configuration.mode != _datasets.mode) {
          throw const RagFailure(TutorErrorCode.resourceNotReady);
        }
        _retriever.validate(handle);
        final scope = await _scope.resolve(
          r,
          handle.configuration,
          r.cancellation,
        );
        _checkpoint(r);
        if (scope.needsClarification) {
          return _reply(
            r,
            TutorResult.refusal(TutorReason.needsScopeClarification),
          );
        }
        final retrieved = await _retriever.search(
          handle,
          r.question,
          scope.packIds,
          r.cancellation,
        );
        _checkpoint(r);
        final assessment = await _evidence.evaluate(
          r,
          retrieved,
          r.cancellation,
        );
        _checkpoint(r);
        final approved = _approved(assessment, retrieved);
        switch (assessment.decision) {
          case EvidenceDecision.insufficient:
            return _reply(r, TutorResult.refusal(TutorReason.noEvidence));
          case EvidenceDecision.ambiguous:
            return _reply(
              r,
              TutorResult.refusal(TutorReason.needsScopeClarification),
            );
          case EvidenceDecision.full:
          case EvidenceDecision.partialIndependent:
            break;
        }
        final config = _runtime.configuration;
        if (config == null || _runtime.state != ModelRuntimeState.ready) {
          throw const RagFailure(TutorErrorCode.resourceNotReady);
        }
        final prompt = await _prompts.prepare(
          r,
          approved,
          assessment,
          config,
          r.cancellation,
        );
        _checkpoint(r);
        if (!identical(_runtime.configuration, config) ||
            _runtime.state != ModelRuntimeState.ready) {
          throw const RagFailure(TutorErrorCode.resourceNotReady);
        }
        if (prompt.requestId != r.requestId ||
            prompt.prompt.trim().isEmpty ||
            prompt.promptTokens <= 0 ||
            prompt.maxTokens <= 0 ||
            prompt.promptTokens + prompt.maxTokens > config.contextLength) {
          throw const TutorContractFailure();
        }
        generated = true;
        final text = await _runtime.generate(prompt, r.cancellation);
        _checkpoint(r);
        final result = await _answers.validate(
          r,
          text,
          approved,
          assessment,
          r.cancellation,
        );
        _checkpoint(r);
        if (result.status == TutorStatus.answer &&
            assessment.decision == EvidenceDecision.partialIndependent &&
            !result.isPartial) {
          throw const TutorContractFailure();
        }
        final reply = _reply(r, result, assessment.approvedSources);
        reply.checkedFor(r);
        return reply;
      } finally {
        // A cancelled runtime may have settled its logical caller while native
        // memory/index use continues. Do not free this revision until drainage.
        if (generated) await _runtime.whenIdle;
        if (handle != null) await handle.close();
      }
    } on RagFailure catch (e) {
      return _error(r, e.code);
    } on TutorContractFailure {
      return _error(r, TutorErrorCode.invalidResponse);
    } on RuntimeFailure catch (e) {
      return _error(r, _runtimeError(e.code));
    } catch (_) {
      return _error(r, TutorErrorCode.generationFailed);
    }
  }

  List<ResolvedSource> _approved(
    EvidenceAssessment e,
    List<ResolvedSource> retrieved,
  ) {
    final refs = e.approvedSources;
    final found = {for (final chunk in retrieved) chunk.reference: chunk};
    if (refs.toSet().length != refs.length ||
        refs.any((r) => !found.containsKey(r))) {
      throw const TutorContractFailure();
    }
    switch (e.decision) {
      case EvidenceDecision.full:
        if (refs.isEmpty) throw const TutorContractFailure();
      case EvidenceDecision.partialIndependent:
        if (refs.isEmpty ||
            e.supportedSubparts.isEmpty ||
            e.unsupportedSubparts.isEmpty ||
            [
              ...e.supportedSubparts,
              ...e.unsupportedSubparts,
            ].any((s) => s.trim().isEmpty)) {
          throw const TutorContractFailure();
        }
      case EvidenceDecision.insufficient:
      case EvidenceDecision.ambiguous:
        if (refs.isNotEmpty) throw const TutorContractFailure();
    }
    return List.unmodifiable(refs.map((r) => found[r]!));
  }

  TutorErrorCode _runtimeError(RuntimeErrorCode code) => switch (code) {
    RuntimeErrorCode.notReady ||
    RuntimeErrorCode.incompatible => TutorErrorCode.resourceNotReady,
    RuntimeErrorCode.embeddingFailed => TutorErrorCode.resourceNotReady,
    RuntimeErrorCode.loadFailed => TutorErrorCode.modelLoadFailed,
    RuntimeErrorCode.cancelled => TutorErrorCode.requestCancelled,
    RuntimeErrorCode.outOfMemory => TutorErrorCode.outOfMemory,
    RuntimeErrorCode.invalidOutput => TutorErrorCode.invalidResponse,
    _ => TutorErrorCode.generationFailed,
  };

  @override
  Future<void> cancel(String requestId) async {
    final active = _active;
    if (active?.request.requestId == requestId) {
      active!.request.cancellation.cancel();
    }
  }

  Future<void> get whenIdle async {
    final job = _job;
    await Future.wait([
      ..._sourceReads,
      if (job != null) job.then<void>((_) {}),
    ]);
  }

  Future<void> close() async {
    _closed = true;
    _active?.request.cancellation.cancel();
    await whenIdle;
  }

  @override
  Future<ResolvedSource?> resolve(SourceReference reference) async {
    if (_closed || !reference.isValid) return null;
    final completion = Completer<ResolvedSource?>();
    final drained = completion.future.then<void>((_) {});
    _sourceReads.add(drained);
    void finish(ResolvedSource? source) {
      _sourceReads.remove(drained);
      completion.complete(source);
    }

    unawaited(
      _resolve(
        reference,
      ).then(finish, onError: (Object _, StackTrace _) => finish(null)),
    );
    return completion.future;
  }

  Future<ResolvedSource?> _resolve(SourceReference reference) async {
    final handle = await _datasets.openRevision(reference.datasetRevision);
    if (handle == null) return null;
    try {
      final c = handle.configuration;
      if (_closed ||
          c.revision != reference.datasetRevision ||
          c.mode != _datasets.mode ||
          (c.mode == DatasetRunMode.integrationFixture && !kDebugMode) ||
          !c.packs.any((p) => p.packId == reference.packId)) {
        return null;
      }
      final source = await handle.resolve(reference);
      if (_closed ||
          source == null ||
          source.reference != reference ||
          source.snippet.trim().isEmpty ||
          (source.page != null && source.page! <= 0)) {
        return null;
      }
      return source;
    } finally {
      await handle.close();
    }
  }
}

class _PipelineTurn {
  _PipelineTurn(this.request);
  final TutorRequest request;
  bool timedOut = false;
}
