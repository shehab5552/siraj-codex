import 'package:drift/drift.dart';
import 'app_database.dart';

const activeDatasetResourceId = '__ACTIVE_DATASET__';

/// Internal persistence DTO, never readiness evidence or a public resource API.
class DatasetPointer {
  const DatasetPointer({
    required this.revision,
    required this.path,
    required this.state,
  });
  final String? revision, path;
  final String state;
  @override
  bool operator ==(Object other) =>
      other is DatasetPointer &&
      revision == other.revision &&
      path == other.path &&
      state == other.state;
  @override
  int get hashCode => Object.hash(revision, path, state);
}

class DatasetPointerConflict implements Exception {
  const DatasetPointerConflict();
}

/// Called only by DatasetReleaseManager after validation and promotion.
/// The only production pointer occupies the reserved existing registry row.
class DatasetPointerStore {
  const DatasetPointerStore(this.db);
  final AppDatabase db;
  Future<DatasetPointer?> read() async {
    final row = await db
        .customSelect(
          "SELECT revision,local_path,state FROM installed_resource WHERE kind='RAG_PACK' AND resource_id=?",
          variables: [Variable.withString(activeDatasetResourceId)],
        )
        .getSingleOrNull();
    return row == null
        ? null
        : DatasetPointer(
            revision: row.readNullable<String>('revision'),
            path: row.readNullable<String>('local_path'),
            state: row.read<String>('state'),
          );
  }

  Future<void> commitPromoted({
    required DatasetPointer? expected,
    required String revision,
    required String path,
    required String nowUtc,
  }) => db.transaction(() async {
    if (await read() != expected) throw const DatasetPointerConflict();
    await db.customStatement(
      '''
        INSERT INTO installed_resource(kind,resource_id,revision,state,local_path,manifest_json,updated_at)
        VALUES ('RAG_PACK',?,?,'READY',?,NULL,?)
        ON CONFLICT(kind,resource_id) DO UPDATE SET revision=excluded.revision,
          state=excluded.state,local_path=excluded.local_path,manifest_json=NULL,updated_at=excluded.updated_at
      ''',
      [activeDatasetResourceId, revision, path, nowUtc],
    );
  });
}
