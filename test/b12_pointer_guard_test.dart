import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/resource_repository.dart';

void main() {
  test(
    'unverified resource API cannot erase the reserved dataset pointer',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        await db.customStatement(
          "INSERT INTO installed_resource (kind,resource_id,revision,state,local_path,updated_at) VALUES ('RAG_PACK','__ACTIVE_DATASET__','r1','READY','/test/r1','2026-10-23T00:00:00Z')",
        );
        await expectLater(
          Future.sync(
            () => ResourceRepository(db).recordUnverified(
              kind: 'RAG_PACK',
              resourceId: '__ACTIVE_DATASET__',
              state: 'DOWNLOADING',
              revision: 'r2',
              nowUtc: '2026-10-23T00:00:00Z',
            ),
          ),
          throwsArgumentError,
        );
        final row = await ResourceRepository(
          db,
        ).find(kind: 'RAG_PACK', resourceId: '__ACTIVE_DATASET__');
        expect(row?.read<String>('revision'), 'r1');
        expect(row?.read<String>('state'), 'READY');
      } finally {
        await db.close();
      }
    },
  );
}
