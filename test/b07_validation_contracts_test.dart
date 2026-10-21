import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/resources/rag_candidate_contract.dart';
import 'package:siraj/features/resources/resource_validation_contracts.dart';

const subjects = ['biology', 'chemistry', 'physics', 'mathematics', 'english'];

RagCandidateDeclaration candidate({
  List<String> expected = subjects,
  List<RagPackDeclaration>? packs,
  SharedEmbeddingDeclaration? embedding,
  bool omitEmbedding = false,
}) {
  return RagCandidateDeclaration(
    datasetRevision: 'rev-1',
    expectedSubjectIds: expected,
    packs:
        packs ??
        subjects
            .map(
              (subject) => RagPackDeclaration(
                subjectId: subject,
                datasetRevision: 'rev-1',
                embeddingModelId: 'shared-embed',
                vectorDimensions: 384,
                indexType: 'hnsw',
                indexVersion: '1',
              ),
            )
            .toList(),
    sharedEmbedding: omitEmbedding
        ? null
        : embedding ??
              const SharedEmbeddingDeclaration(
                datasetRevision: 'rev-1',
                modelId: 'shared-embed',
                vectorDimensions: 384,
                tokenizerId: 'tokenizer-A',
                pooling: 'mean',
                normalization: 'l2',
              ),
    expectedIndexType: 'hnsw',
    expectedIndexVersion: '1',
  );
}

void main() {
  group('B-07 validation requirements (not actual verification)', () {
    test('DB kind identities remain stable and distinct', () {
      expect(ResourceContractKind.values.map((e) => e.dbKind).toSet(), {
        'LLM',
        'RAG_PACK',
        'RAG_EMBEDDING',
        'PDF',
      });
    });

    test('LLM requires hash, runtime, device, and load proof', () {
      final checks = ResourceValidationRequirements.forKind(
        ResourceContractKind.llm,
      );
      expect(
        checks,
        containsAll({
          ResourceValidationCheck.sha256Matched,
          ResourceValidationCheck.runtimeCompatible,
          ResourceValidationCheck.deviceCompatible,
          ResourceValidationCheck.modelLoadProven,
        }),
      );
    });

    test('RAG pack needs archive safety and index checks', () {
      final checks = ResourceValidationRequirements.forKind(
        ResourceContractKind.ragPack,
      );
      expect(
        checks,
        containsAll({
          ResourceValidationCheck.safeArchiveExtraction,
          ResourceValidationCheck.archiveIntegrity,
          ResourceValidationCheck.validPackSchema,
          ResourceValidationCheck.validIndexVersion,
          ResourceValidationCheck.sha256Matched,
        }),
      );
    });

    test('shared embedding requires full configuration and Android sample', () {
      final checks = ResourceValidationRequirements.forKind(
        ResourceContractKind.ragEmbedding,
      );
      expect(
        checks,
        containsAll({
          ResourceValidationCheck.tokenizerCompatible,
          ResourceValidationCheck.poolingCompatible,
          ResourceValidationCheck.normalizationCompatible,
          ResourceValidationCheck.vectorDimensionsCompatible,
          ResourceValidationCheck.androidSampleQueryPassed,
        }),
      );
    });

    test('PDF hash is conditional, readability is always required', () {
      final noHash = ResourceValidationRequirements.forKind(
        ResourceContractKind.pdf,
      );
      final withHash = ResourceValidationRequirements.forKind(
        ResourceContractKind.pdf,
        pdfCatalogHashProvided: true,
      );
      expect(noHash, contains(ResourceValidationCheck.pdfReadable));
      expect(noHash, isNot(contains(ResourceValidationCheck.sha256Matched)));
      expect(withHash, contains(ResourceValidationCheck.sha256Matched));
    });

    test('missing reported checks are detected, not silently passed', () {
      final audit = ResourceValidationRequirements.audit(
        kind: ResourceContractKind.llm,
        reportedPassed: {ResourceValidationCheck.transferComplete},
      );
      expect(audit.evidenceListComplete, isFalse);
      expect(
        audit.outstanding,
        contains(ResourceValidationCheck.modelLoadProven),
      );
    });

    test('conflicting pass and fail evidence is always rejected', () {
      final audit = ResourceValidationRequirements.audit(
        kind: ResourceContractKind.pdf,
        reportedPassed: {
          ResourceValidationCheck.transferComplete,
          ResourceValidationCheck.pdfReadable,
        },
        reportedFailed: {ResourceValidationCheck.pdfReadable},
      );
      expect(audit.evidenceListComplete, isFalse);
      expect(
        audit.contradictory,
        contains(ResourceValidationCheck.pdfReadable),
      );
    });

    test('unexpected check flags cannot complete a checklist', () {
      final audit = ResourceValidationRequirements.audit(
        kind: ResourceContractKind.pdf,
        reportedPassed: {
          ResourceValidationCheck.transferComplete,
          ResourceValidationCheck.pdfReadable,
          ResourceValidationCheck.modelLoadProven,
        },
      );
      expect(audit.evidenceListComplete, isFalse);
      expect(
        audit.unexpected,
        contains(ResourceValidationCheck.modelLoadProven),
      );
    });
  });

  group('B-07 structural preflight: never implies READY', () {
    test('complete declared layout is structurally consistent only', () {
      expect(
        RagCandidateContract.preflight(candidate()).structureConsistent,
        isTrue,
      );
    });

    test(
      'biology pilot alone cannot impersonate five-subject production release',
      () {
        final onePack = candidate().packs.take(1).toList();
        final result = RagCandidateContract.preflight(
          candidate(packs: onePack),
        );
        expect(result.structureConsistent, isFalse);
        expect(result.issues, contains(RagCandidateIssue.missingPack));
      },
    );

    test('missing shared embedding is rejected', () {
      final result = RagCandidateContract.preflight(
        candidate(omitEmbedding: true),
      );
      expect(result.issues, contains(RagCandidateIssue.missingSharedEmbedding));
    });

    test('duplicate subject cannot fill a missing subject', () {
      final base = candidate().packs.toList();
      base[4] = base[0];
      final result = RagCandidateContract.preflight(candidate(packs: base));
      expect(result.issues, contains(RagCandidateIssue.duplicatePack));
      expect(result.issues, contains(RagCandidateIssue.missingPack));
    });

    test('unapproved subject catalog or extra pack is rejected', () {
      final base = candidate().packs.toList();
      base[4] = const RagPackDeclaration(
        subjectId: 'extra',
        datasetRevision: 'rev-1',
        embeddingModelId: 'shared-embed',
        vectorDimensions: 384,
        indexType: 'hnsw',
        indexVersion: '1',
      );
      final result = RagCandidateContract.preflight(candidate(packs: base));
      expect(result.issues, contains(RagCandidateIssue.unexpectedPack));
      expect(result.issues, contains(RagCandidateIssue.missingPack));
    });

    test('pack revision mixing is rejected', () {
      final base = candidate().packs.toList();
      base[0] = const RagPackDeclaration(
        subjectId: 'biology',
        datasetRevision: 'rev-0',
        embeddingModelId: 'shared-embed',
        vectorDimensions: 384,
        indexType: 'hnsw',
        indexVersion: '1',
      );
      expect(
        RagCandidateContract.preflight(candidate(packs: base)).issues,
        contains(RagCandidateIssue.packRevisionMismatch),
      );
    });

    test('shared embedding model mismatch is rejected', () {
      final result = RagCandidateContract.preflight(
        candidate(
          embedding: const SharedEmbeddingDeclaration(
            datasetRevision: 'rev-1',
            modelId: 'wrong-embed',
            vectorDimensions: 384,
            tokenizerId: 'tok',
            pooling: 'mean',
            normalization: 'l2',
          ),
        ),
      );
      expect(
        result.issues,
        contains(RagCandidateIssue.embeddingIdentityMismatch),
      );
    });

    test('embedding dimension mismatch is rejected', () {
      final result = RagCandidateContract.preflight(
        candidate(
          embedding: const SharedEmbeddingDeclaration(
            datasetRevision: 'rev-1',
            modelId: 'shared-embed',
            vectorDimensions: 768,
            tokenizerId: 'tok',
            pooling: 'mean',
            normalization: 'l2',
          ),
        ),
      );
      expect(
        result.issues,
        contains(RagCandidateIssue.vectorDimensionsMismatch),
      );
    });

    test('index type/version mismatch is rejected', () {
      final base = candidate().packs.toList();
      base[1] = const RagPackDeclaration(
        subjectId: 'chemistry',
        datasetRevision: 'rev-1',
        embeddingModelId: 'shared-embed',
        vectorDimensions: 384,
        indexType: 'unsupported',
        indexVersion: '0',
      );
      expect(
        RagCandidateContract.preflight(candidate(packs: base)).issues,
        contains(RagCandidateIssue.indexConfigMismatch),
      );
    });

    test('invalid expected subject catalog is rejected', () {
      final result = RagCandidateContract.preflight(
        candidate(
          expected: ['biology', 'biology', 'physics', 'math', 'english'],
        ),
      );
      expect(result.issues, contains(RagCandidateIssue.invalidSubjectCatalog));
    });
  });
}
