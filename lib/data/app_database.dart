import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// SIRAJ P0 local database; the resource registry is device-scoped.
/// User-specific records are linked through foreign keys.
@DriftDatabase(include: {'schema.drift'})
class AppDatabase extends _$AppDatabase {
  /// Use in the app after B-04 wires up startup and session validation.
  AppDatabase() : super(driftDatabase(name: 'siraj_p0'));

  /// Tests should use NativeDatabase.memory() to avoid device state.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // This is the initial schema, so no upgrade path exists yet.
      // Fail closed if a later version is introduced without a reviewed
      // migration. Never delete and recreate user data to 'fix' a schema.
      throw StateError('Unsupported SIRAJ database migration: $from -> $to');
    },
    beforeOpen: (details) async {
      // Must be set on each connection after schema migrations.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
