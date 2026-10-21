import 'package:drift/drift.dart';

import 'app_database.dart';

/// Device-scoped resource registry (never account-owned).
/// B-07/B-12 will provide verification-gated READY/ACTIVE transitions.
class ResourceRepository {
  final AppDatabase db;
  const ResourceRepository(this.db);

  static const kinds = {'LLM', 'RAG_PACK', 'RAG_EMBEDDING', 'PDF'};
  static const unverifiedStates = {'MISSING', 'DOWNLOADING', 'FAILED'};

  Future<QueryRow?> find({required String kind, required String resourceId}) =>
      db
          .customSelect(
            '''
      SELECT * FROM installed_resource WHERE kind = ? AND resource_id = ?
    ''',
            variables: [
              Variable.withString(kind),
              Variable.withString(resourceId),
            ],
          )
          .getSingleOrNull();

  /// Never expose a public 'READY' setter without integrity checks.
  Future<int> recordUnverified({
    required String kind,
    required String resourceId,
    required String state,
    required String nowUtc,
    String? revision,
  }) {
    if (!kinds.contains(kind) ||
        !unverifiedStates.contains(state) ||
        resourceId.trim().isEmpty) {
      throw ArgumentError('Unsupported resource identity/state');
    }
    return db.customUpdate(
      '''
      INSERT INTO installed_resource
        (kind, resource_id, revision, state, updated_at)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(kind, resource_id) DO UPDATE SET
        revision=excluded.revision, state=excluded.state,
        local_path=NULL, manifest_json=NULL,
        updated_at=excluded.updated_at
    ''',
      variables: [
        Variable.withString(kind),
        Variable.withString(resourceId),
        Variable<String>(revision),
        Variable.withString(state),
        Variable.withString(nowUtc),
      ],
    );
  }
}
