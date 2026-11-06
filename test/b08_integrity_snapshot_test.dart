import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/resources/artifact_integrity_validator.dart';
import 'package:siraj/features/resources/resource_validation_contracts.dart';

void main() {
  late Directory root;
  late File file;
  late ArtifactIntegrityMatch proof;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('b08-proof-');
    file = File('${root.path}/model')..writeAsStringSync('abc');
    proof =
        await const ArtifactIntegrityValidator().validate(
              stagingRoot: root,
              relativePath: 'model',
              kind: ResourceContractKind.llm,
              expectedSizeBytes: 3,
              expectedSha256:
                  'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
            )
            as ArtifactIntegrityMatch;
  });
  tearDown(() async => root.delete(recursive: true));

  test(
    'integrity proof binds the file snapshot used by a later parser',
    () async {
      expect(
        proof.matchesFileSnapshot(
          canonicalPath: await file.resolveSymbolicLinks(),
          stat: await file.stat(),
        ),
        isTrue,
      );
    },
  );

  test('integrity proof cannot be transplanted to a different path', () async {
    expect(
      proof.matchesFileSnapshot(
        canonicalPath: '${root.path}/different',
        stat: await file.stat(),
      ),
      isFalse,
    );
  });

  test(
    'same-size modification between hash and parser invalidates proof',
    () async {
      final original = await file.lastModified();
      await file.writeAsString('abd');
      await file.setLastModified(original.add(const Duration(seconds: 3)));
      expect(
        proof.matchesFileSnapshot(
          canonicalPath: await file.resolveSymbolicLinks(),
          stat: await file.stat(),
        ),
        isFalse,
      );
    },
  );
}
