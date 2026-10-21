import 'app_database.dart';

/// Owns exactly one AppDatabase per application runtime.
///
/// Pass [database] to repositories instead of constructing databases in each
/// feature. Startup/Auth wiring belongs to B-04; creating this owner alone
/// does not log in a user or expose any debug routes.
class DatabaseRuntime {
  DatabaseRuntime({AppDatabase Function()? createDatabase})
    : _createDatabase = createDatabase ?? AppDatabase.new;

  final AppDatabase Function() _createDatabase;
  AppDatabase? _database;
  bool _closed = false;

  AppDatabase get database {
    if (_closed) {
      throw StateError('SIRAJ DatabaseRuntime was already closed');
    }
    return _database ??= _createDatabase();
  }

  /// Safe to call even when the database was never opened.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final opened = _database;
    _database = null;
    if (opened != null) {
      await opened.close();
    }
  }
}
