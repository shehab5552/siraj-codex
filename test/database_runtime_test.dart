import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/database_runtime.dart';

void main() {
  test('runtime creates a single shared AppDatabase, then closes', () async {
    var creations = 0;
    final runtime = DatabaseRuntime(
      createDatabase: () {
        creations++;
        return AppDatabase.forTesting(NativeDatabase.memory());
      },
    );
    expect(creations, 0, reason: 'No eager database opening');
    final db = runtime.database;
    expect(identical(db, runtime.database), isTrue);
    expect(creations, 1);

    final result = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(result.read<int>('foreign_keys'), 1);

    await runtime.close();
    await runtime.close(); // idempotent shutdown
    expect(() => runtime.database, throwsStateError);
    expect(creations, 1);
  });

  test('closing an unused runtime never opens SQLite', () async {
    var creations = 0;
    final runtime = DatabaseRuntime(
      createDatabase: () {
        creations++;
        return AppDatabase.forTesting(NativeDatabase.memory());
      },
    );
    await runtime.close();
    expect(creations, 0);
    expect(() => runtime.database, throwsStateError);
  });
}
