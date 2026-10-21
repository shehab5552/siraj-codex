import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/data/app_database.dart';
import 'package:siraj/data/resource_repository.dart';
import 'package:siraj/features/resources/resource_status.dart';
import 'package:siraj/features/resources/resource_status_page.dart';
import 'package:siraj/features/resources/resource_status_reader.dart';

const _utc = '2026-10-22T00:00:00.000Z';

void main() {
  group('B-07 read-only resource status', () {
    late AppDatabase db;
    late ResourceRepository repo;
    late ResourceStatusReader reader;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = ResourceRepository(db);
      reader = ResourceStatusReader(repo);
    });
    tearDown(() async => db.close());

    test(
      'empty registry means no registered rows, not a ready catalog',
      () async {
        final snapshot = await reader.read();
        expect(snapshot.entries, isEmpty);
        expect(snapshot.llm, isEmpty);
        expect(snapshot.ragPacks, isEmpty);
        expect(snapshot.pdfBooks, isEmpty);
      },
    );

    test('four resource kinds remain independent', () async {
      for (final pair in [
        ('LLM', 'model'),
        ('RAG_PACK', 'biology'),
        ('RAG_EMBEDDING', 'shared'),
        ('PDF', 'biology-book'),
      ]) {
        await repo.recordUnverified(
          kind: pair.$1,
          resourceId: pair.$2,
          state: 'MISSING',
          nowUtc: _utc,
        );
      }
      final snapshot = await reader.read();
      expect(snapshot.entries.length, 4);
      expect(snapshot.llm.single.resourceId, 'model');
      expect(snapshot.ragPacks.single.resourceId, 'biology');
      expect(snapshot.ragEmbedding.single.resourceId, 'shared');
      expect(snapshot.pdfBooks.single.resourceId, 'biology-book');
    });

    test('MISSING, DOWNLOADING, FAILED are display-only states', () async {
      for (final pair in [
        ('LLM', 'MISSING'),
        ('PDF', 'DOWNLOADING'),
        ('RAG_PACK', 'FAILED'),
      ]) {
        await repo.recordUnverified(
          kind: pair.$1,
          resourceId: pair.$1,
          state: pair.$2,
          nowUtc: _utc,
        );
      }
      final snapshot = await reader.read();
      expect(snapshot.llm.single.displayState, ResourceDisplayState.missing);
      expect(
        snapshot.pdfBooks.single.displayState,
        ResourceDisplayState.downloading,
      );
      expect(
        snapshot.ragPacks.single.displayState,
        ResourceDisplayState.failed,
      );
    });

    test(
      'untrusted persisted READY or ACTIVE never becomes verified',
      () async {
        await db.customInsert(
          '''
        INSERT INTO installed_resource
          (resource_id, kind, state, updated_at)
        VALUES ('model', 'LLM', 'READY', ?),
               ('bio', 'RAG_PACK', 'ACTIVE', ?)
      ''',
          variables: [Variable.withString(_utc), Variable.withString(_utc)],
        );
        final snapshot = await reader.read();
        expect(
          snapshot.llm.single.displayState,
          ResourceDisplayState.verificationRequired,
        );
        expect(
          snapshot.ragPacks.single.displayState,
          ResourceDisplayState.verificationRequired,
        );
      },
    );

    test('read operations never modify database rows', () async {
      await repo.recordUnverified(
        kind: 'PDF',
        resourceId: 'book',
        state: 'FAILED',
        nowUtc: _utc,
        revision: 'v1',
      );
      final before = await repo.find(kind: 'PDF', resourceId: 'book');
      await reader.read();
      final after = await repo.find(kind: 'PDF', resourceId: 'book');
      expect(after?.read<String>('state'), before?.read<String>('state'));
      expect(
        after?.read<String?>('revision'),
        before?.read<String?>('revision'),
      );
    });

    test('existing repository still rejects fake READY', () async {
      expect(
        () => repo.recordUnverified(
          kind: 'RAG_EMBEDDING',
          resourceId: 'shared',
          state: 'READY',
          nowUtc: _utc,
        ),
        throwsArgumentError,
      );
    });

    testWidgets(
      'status screen shows separate sections and no download action',
      (tester) async {
        await repo.recordUnverified(
          kind: 'LLM',
          resourceId: 'model-A',
          state: 'MISSING',
          nowUtc: _utc,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: ResourceStatusPage(reader: reader),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('حالة الموارد'), findsOneWidget);
        expect(find.text('النموذج المحلي (LLM)'), findsOneWidget);
        expect(find.text('model-A'), findsOneWidget);
        expect(find.text('حزم بيانات RAG'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('كتب PDF'), 160);
        await tester.pumpAndSettle();
        expect(find.text('كتب PDF'), findsOneWidget);
        expect(find.text('تنزيل'), findsNothing);
      },
    );

    testWidgets('empty resource registry is represented honestly', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: ResourceStatusPage(reader: reader)),
      );
      await tester.pumpAndSettle();
      expect(find.text('لا توجد موارد مسجلة في هذا القسم.'), findsWidgets);
      await tester.scrollUntilVisible(find.text('كتب PDF'), 160);
      await tester.pumpAndSettle();
      expect(find.text('كتب PDF'), findsOneWidget);
    });
  });
}
