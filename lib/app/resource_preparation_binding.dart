import 'package:uuid/uuid.dart';
import '../features/resources/dataset_preparation.dart';

/// App-scoped composition input supplied only from an approved catalog/runtime
/// adapter. Default main has no binding until those inputs exist. The owner must
/// cancel/drain and close its manager on application shutdown, not on logout.
class ResourcePreparationBinding {
  const ResourcePreparationBinding({
    required this.coordinator,
    required this.revision,
  });
  final DatasetPreparationCoordinator coordinator;
  final String revision;
  Future<String> prepare({required bool consented}) =>
      coordinator.prepareAndActivate(
        revision: revision,
        candidateId: const Uuid().v4(),
        consented: consented,
      );
}
