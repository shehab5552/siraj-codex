import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/integrations/ai/tutor_contract.dart';
import 'package:siraj/integrations/ai/tutor_port.dart';

void main() {
  const source = SourceReference(
    packId: 'biology',
    chunkId: 'cell',
    datasetRevision: 'r1',
  );
  TutorRequest request() => TutorRequest(
    requestId: 'q1',
    userId: 'u1',
    accountEpoch: 'e1',
    conversationId: 'c1',
    question: 'question',
    datasetRevision: 'r1',
    cancellation: TutorCancellation(),
  );
  TutorReply reply(
    TutorResult result, {
    String revision = 'r1',
    List<SourceReference> approved = const [source],
    String requestId = 'q1',
  }) => TutorReply(
    requestId: requestId,
    userId: 'u1',
    accountEpoch: 'e1',
    conversationId: 'c1',
    datasetRevision: revision,
    approvedSources: approved,
    result: result,
  );

  test('source identity round trips all three required fields', () {
    expect(SourceReference.fromJson(source.toJson()), source);
    expect(source.isValid, true);
    expect(
      source,
      isNot(
        const SourceReference(
          packId: 'biology',
          chunkId: 'cell',
          datasetRevision: 'r2',
        ),
      ),
    );
  });
  test('malformed source identity is rejected', () {
    for (final raw in [
      null,
      {},
      {'pack_id': 'p', 'chunk_id': 'c'},
      {'pack_id': 1, 'chunk_id': 'c', 'dataset_revision': 'r'},
      {'pack_id': 'p', 'chunk_id': '', 'dataset_revision': 'r'},
    ]) {
      expect(() => SourceReference.fromJson(raw), throwsFormatException);
    }
  });
  test('answer accepts only references approved for pinned revision', () {
    final result = TutorResult.answer('supported text', [source]);
    expect(reply(result).checkedFor(request()), same(result));
  });
  test('partial is ANSWER with reason, never a fourth status', () {
    final result = TutorResult.answer('supported subpart', [
      source,
    ], partial: true);
    expect(reply(result).checkedFor(request()).isPartial, true);
    expect(result.status, TutorStatus.answer);
    expect(TutorStatus.values, hasLength(3));
  });
  test('invented source and revision mismatch reject the entire reply', () {
    const invented = SourceReference(
      packId: 'biology',
      chunkId: 'invented',
      datasetRevision: 'r1',
    );
    expect(
      () => reply(TutorResult.answer('text', [invented])).checkedFor(request()),
      throwsA(isA<TutorContractFailure>()),
    );
    expect(
      () => reply(
        TutorResult.answer('text', [source]),
        revision: 'r2',
      ).checkedFor(request()),
      throwsA(isA<TutorContractFailure>()),
    );
    expect(
      () => reply(
        TutorResult.answer('text', [source]),
        approved: [],
      ).checkedFor(request()),
      throwsA(isA<TutorContractFailure>()),
    );
  });
  test('reply from another request is rejected', () {
    expect(
      () => reply(
        TutorResult.answer('text', [source]),
        requestId: 'old',
      ).checkedFor(request()),
      throwsA(isA<TutorContractFailure>()),
    );
  });
  test('blank or unsourced answers fail closed', () {
    for (final result in [
      TutorResult.answer(' ', [source]),
      TutorResult.answer('text', []),
    ]) {
      expect(
        () => reply(result).checkedFor(request()),
        throwsA(isA<TutorContractFailure>()),
      );
    }
  });
  test('refusal and runtime error remain different and have no sources', () {
    final refusal = TutorResult.refusal(TutorReason.noEvidence);
    final error = TutorResult.error(TutorErrorCode.modelLoadFailed);
    expect(reply(refusal).checkedFor(request()).status, TutorStatus.refusal);
    expect(reply(error).checkedFor(request()).status, TutorStatus.error);
    final invalid = TutorResult(
      status: TutorStatus.error,
      sources: [source],
      error: TutorErrorCode.generationFailed,
    );
    expect(
      () => reply(invalid).checkedFor(request()),
      throwsA(isA<TutorContractFailure>()),
    );
  });
  test('reply source lists are immutable', () {
    final refs = [source];
    final result = TutorResult.answer('text', refs);
    final envelope = reply(result, approved: refs);
    refs.clear();
    expect(result.sources, [source]);
    expect(envelope.approvedSources, [source]);
    expect(() => result.sources.clear(), throwsUnsupportedError);
  });
  test(
    'default adapter returns typed unavailability, no scientific answer',
    () async {
      const port = UnavailableTutorPort();
      final req = request();
      final result = (await port.ask(req)).checkedFor(req);
      expect(port.availability.isReady, false);
      expect(result.status, TutorStatus.error);
      expect(result.error, TutorErrorCode.resourceNotReady);
      expect(result.text, isNull);
      expect(result.sources, isEmpty);
    },
  );
  test('cancellation is idempotent and signals adapters', () async {
    final cancellation = TutorCancellation();
    cancellation.cancel();
    cancellation.cancel();
    expect(cancellation.isCancelled, true);
    await cancellation.whenCancelled;
  });
}
