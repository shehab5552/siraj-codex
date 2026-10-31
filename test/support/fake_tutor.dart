import 'dart:async';

import 'package:siraj/integrations/ai/tutor_contract.dart';
import 'package:siraj/integrations/ai/tutor_port.dart';

const testSource = SourceReference(
  packId: 'fixture-biology',
  chunkId: 'fixture-chunk',
  datasetRevision: 'fixture-r1',
);

TutorReply replyFor(
  TutorRequest request, {
  TutorResult? result,
  List<SourceReference> approved = const [testSource],
  String? revision,
}) => TutorReply(
  requestId: request.requestId,
  userId: request.userId,
  accountEpoch: request.accountEpoch,
  conversationId: request.conversationId,
  datasetRevision: revision ?? request.datasetRevision,
  approvedSources: approved,
  result: result ?? TutorResult.answer('إجابة اختبار اصطناعية', [testSource]),
);

/// Test-only transport double. No fixture answer is installed in application code.
class FakeTutor implements TutorPort {
  final requests = <TutorRequest>[];
  final cancelled = <String>[];
  final started = Completer<void>();
  FutureOr<TutorReply> Function(TutorRequest)? respond;
  @override
  TutorAvailability availability = const TutorAvailability.ready('fixture-r1');
  @override
  Future<TutorReply> ask(TutorRequest request) async {
    requests.add(request);
    if (!started.isCompleted) started.complete();
    return respond == null ? replyFor(request) : await respond!(request);
  }

  @override
  Future<void> cancel(String requestId) async {
    cancelled.add(requestId);
  }
}

class FakeSourceResolver implements SourceResolverPort {
  FutureOr<ResolvedSource?> Function(SourceReference)? respond;
  @override
  Future<ResolvedSource?> resolve(SourceReference reference) async =>
      respond == null
      ? ResolvedSource(
          reference: reference,
          snippet: 'مقتطف اختبار اصطناعي',
          subject: 'مادة اختبار',
        )
      : await respond!(reference);
}
