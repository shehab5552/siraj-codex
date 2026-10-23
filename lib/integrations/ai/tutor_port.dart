import 'tutor_contract.dart';

class TutorAvailability {
  const TutorAvailability.ready(this.datasetRevision) : error = null;
  const TutorAvailability.unavailable([
    this.error = TutorErrorCode.resourceNotReady,
  ]) : datasetRevision = null;
  final String? datasetRevision;
  final TutorErrorCode? error;
  bool get isReady =>
      error == null &&
      datasetRevision != null &&
      datasetRevision!.trim().isNotEmpty;
}

/// A's adapter owns retrieval, evidence gates, runtime and revision pinning.
/// History is conversational context, never authorization for source evidence.
abstract interface class TutorPort {
  TutorAvailability get availability;
  Future<TutorReply> ask(TutorRequest request);
  Future<void> cancel(String requestId);
}

/// Safe composition default. It never fabricates an educational answer.
class UnavailableTutorPort implements TutorPort {
  const UnavailableTutorPort();
  @override
  TutorAvailability get availability => const TutorAvailability.unavailable();
  @override
  Future<TutorReply> ask(TutorRequest request) async => TutorReply(
    requestId: request.requestId,
    userId: request.userId,
    accountEpoch: request.accountEpoch,
    conversationId: request.conversationId,
    datasetRevision: request.datasetRevision,
    result: TutorResult.error(TutorErrorCode.resourceNotReady),
  );
  @override
  Future<void> cancel(String requestId) async {}
}

class ResolvedSource {
  const ResolvedSource({
    required this.reference,
    required this.snippet,
    this.subject,
    this.unit,
    this.lesson,
    this.document,
    this.page,
  });
  final SourceReference reference;
  final String snippet;
  final String? subject;
  final String? unit;
  final String? lesson;
  final String? document;
  final int? page;
}

abstract interface class SourceResolverPort {
  Future<ResolvedSource?> resolve(SourceReference reference);
}

class UnavailableSourceResolver implements SourceResolverPort {
  const UnavailableSourceResolver();
  @override
  Future<ResolvedSource?> resolve(SourceReference reference) async => null;
}
