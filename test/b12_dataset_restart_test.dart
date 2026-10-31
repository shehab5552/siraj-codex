import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/features/resources/dataset_release_contracts.dart';
import 'support/b12_dataset_fixture.dart';

void main() {
  test(
    'file-backed SQLite restart keeps prior pointer after a failed promoted update',
    () async {
      final f = DatasetFixture();
      await f.initialize(persistent: true);
      try {
        await f.activate('r1');
        final oldBytes = await f.releasedFile('r1').readAsBytes();
        final verified = await f.manager.verifyCandidate(
          await f.candidate('r2'),
        );
        await f.db.customStatement(
          "CREATE TRIGGER abort_dataset BEFORE UPDATE ON installed_resource BEGIN SELECT RAISE(ABORT,'test injected rollback'); END",
        );
        await expectLater(
          f.manager.commitActiveRevision(verified),
          throwsA(
            isA<DatasetFailure>().having(
              (e) => e.code,
              'code',
              DatasetFailureCode.databaseFailure,
            ),
          ),
        );
        await f.reopenDatabase();
        final recovery = await f.manager.recover();
        expect(recovery.activeRevision, 'r1');
        expect(recovery.unreferencedRevisions, ['r2']);
        expect((await f.store.read())?.revision, 'r1');
        expect(await f.releasedFile('r1').readAsBytes(), oldBytes);
        await f.manager.removeUnreferenced('r2');
        expect(await f.releasedFile('r2').exists(), false);
      } finally {
        await f.close();
      }
    },
  );
}
