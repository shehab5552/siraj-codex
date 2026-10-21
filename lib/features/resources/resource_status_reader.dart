import '../../data/resource_repository.dart';
import 'resource_status.dart';

/// Reads only the resource registry; it NEVER writes READY or ACTIVE.
/// Absence of a row means only "not registered", not catalog availability.
class ResourceStatusReader {
  const ResourceStatusReader(this.repository);

  final ResourceRepository repository;

  Future<ResourceStatusSnapshot> read() async {
    final rows = await repository.db.customSelect('''
      SELECT kind, resource_id, revision, state
      FROM installed_resource
      ORDER BY kind, resource_id
    ''').get();

    return ResourceStatusSnapshot(
      rows.map(
        (row) => ResourceStatusEntry(
          kind: row.read<String>('kind'),
          resourceId: row.read<String>('resource_id'),
          revision: row.read<String?>('revision'),
          storedState: row.read<String>('state'),
        ),
      ),
    );
  }
}
