/// B-07 Step 1 — read-only view of the device-scoped resource registry.
///
/// A registry row is NOT proof of file integrity, runtime compatibility or
/// activation. Readiness must be established by dedicated validators in a
/// later B-07/B-12 step; this model deliberately has no isReady getter.
enum ResourceDisplayState { missing, downloading, failed, verificationRequired }

class ResourceStatusEntry {
  const ResourceStatusEntry({
    required this.kind,
    required this.resourceId,
    required this.storedState,
    this.revision,
  });

  final String kind;
  final String resourceId;
  final String storedState;
  final String? revision;

  ResourceDisplayState get displayState {
    switch (storedState) {
      case 'MISSING':
        return ResourceDisplayState.missing;
      case 'DOWNLOADING':
        return ResourceDisplayState.downloading;
      case 'FAILED':
        return ResourceDisplayState.failed;
      default:
        // Even a persisted READY/ACTIVE must be checked against verified
        // on-device files, the active pointer, and compatibility contracts.
        return ResourceDisplayState.verificationRequired;
    }
  }

  String get statusLabel {
    switch (displayState) {
      case ResourceDisplayState.missing:
        return 'غير متوفر';
      case ResourceDisplayState.downloading:
        return 'جارٍ التنزيل';
      case ResourceDisplayState.failed:
        return 'تعذّر التجهيز';
      case ResourceDisplayState.verificationRequired:
        return 'يتطلب التحقق من السلامة والتوافق';
    }
  }
}

class ResourceStatusSnapshot {
  ResourceStatusSnapshot(Iterable<ResourceStatusEntry> entries)
    : entries = List<ResourceStatusEntry>.unmodifiable(entries);

  final List<ResourceStatusEntry> entries;

  List<ResourceStatusEntry> ofKind(String kind) =>
      List<ResourceStatusEntry>.unmodifiable(
        entries.where((entry) => entry.kind == kind),
      );

  List<ResourceStatusEntry> get llm => ofKind('LLM');
  List<ResourceStatusEntry> get ragPacks => ofKind('RAG_PACK');
  List<ResourceStatusEntry> get ragEmbedding => ofKind('RAG_EMBEDDING');
  List<ResourceStatusEntry> get pdfBooks => ofKind('PDF');
}
