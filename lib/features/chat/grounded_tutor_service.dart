import 'dart:async';
import '../ai_runtime/ai_runtime_client.dart';
import 'tutor_contracts.dart';

/// Raw native text never becomes a persisted/displayed educational answer
/// without approved retrieval, revision and post-generation evidence checks.
class GroundedTutorService implements TutorPort {
  const GroundedTutorService({
    required this.runtime,
    this.evidence = const UnavailableTutorEvidence(),
  });
  final AiRuntimeClient runtime;
  final TutorEvidencePort evidence;
  @override
  bool isRevisionCurrent(String revision) =>
      evidence.isRevisionCurrent(revision);
  @override
  Future<TutorResult> ask(
    String question,
    TutorCancellation cancellation,
  ) async {
    AiGeneration? generation;
    try {
      if (cancellation.isCancelled) {
        return TutorResult.error(TutorReason.cancelled);
      }
      final context = await evidence.prepare(question, cancellation);
      if (cancellation.isCancelled) {
        return TutorResult.error(TutorReason.cancelled);
      }
      if (context == null) return TutorResult.refusal(TutorReason.noEvidence);
      if (!evidence.isRevisionCurrent(context.revision)) {
        return TutorResult.error(TutorReason.sourceUnavailable);
      }
      generation = await runtime.generate(
        systemInstruction: context.systemInstruction,
        input: context.prompt,
      );
      final running = generation;
      Future<void> requestCancellation() async {
        try {
          await running.cancel();
        } on AiRuntimeFailure {
          // The user abandoned this turn; Native still owns the request until
          // its terminal callback. Never expose text or invent cancellation
          // confirmation, and never leak a failing Future from the void hook.
        }
      }

      cancellation.onCancel = () => unawaited(requestCancellation());
      if (cancellation.isCancelled) await requestCancellation();
      final text = StringBuffer();
      bool completed = false;
      await for (final event in generation.events) {
        if (cancellation.isCancelled) {
          return TutorResult.error(TutorReason.cancelled);
        }
        switch (event.type) {
          case AiGenerationEventType.chunk:
            text.write(event.text);
          case AiGenerationEventType.completed:
            completed = true;
          case AiGenerationEventType.failed:
            return TutorResult.error(TutorReason.generationFailed);
          case AiGenerationEventType.cancelled:
            return TutorResult.error(TutorReason.cancelled);
          case AiGenerationEventType.started:
            break;
        }
      }
      if (!completed || text.toString().trim().isEmpty) {
        return TutorResult.error(TutorReason.generationFailed);
      }
      if (!evidence.isRevisionCurrent(context.revision)) {
        return TutorResult.error(TutorReason.sourceUnavailable);
      }
      if (!await evidence.validateAnswer(context, text.toString())) {
        return TutorResult.refusal(TutorReason.noEvidence);
      }
      if (cancellation.isCancelled) {
        return TutorResult.error(TutorReason.cancelled);
      }
      if (!evidence.isRevisionCurrent(context.revision)) {
        return TutorResult.error(TutorReason.sourceUnavailable);
      }
      return TutorResult.answer(text.toString(), context.sources);
    } on AiRuntimeFailure catch (e) {
      return TutorResult.error(
        e.code == AiRuntimeErrorCode.resourceUnavailable
            ? TutorReason.resourcesUnavailable
            : TutorReason.runtimeUnavailable,
      );
    } on Exception {
      return TutorResult.error(TutorReason.generationFailed);
    } finally {
      cancellation.onCancel = null;
    }
  }
}
