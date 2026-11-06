import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'artifact_integrity_validator.dart';
import 'litertlm_schema/litertlm_header_schema_litert.lm.schema_generated.dart'
    as schema;
import 'resource_validation_contracts.dart';

enum LiteRtLmFormatFailureCode {
  invalidArtifact,
  unsafePath,
  unsupportedVersion,
  malformedHeader,
  invalidSectionBounds,
  overlappingSections,
  missingSection,
  invalidSectionPayload,
  unsupportedRuntime,
  fileChanged,
  ioFailure,
}

sealed class LiteRtLmFormatResult {
  const LiteRtLmFormatResult();
}

final class LiteRtLmFormatFailure extends LiteRtLmFormatResult {
  const LiteRtLmFormatFailure(this.code);
  final LiteRtLmFormatFailureCode code;
}

final class LiteRtLmFormatMatch extends LiteRtLmFormatResult {
  LiteRtLmFormatMatch._({
    required this.version,
    required this.sectionCount,
    required this.minimumRuntimeVersion,
    required Set<ResourceValidationCheck> remainingChecks,
  }) : remainingChecks = Set.unmodifiable(remainingChecks);
  final String version;
  final int sectionCount;
  final String? minimumRuntimeVersion;
  final Set<ResourceValidationCheck> remainingChecks;
}

/// Container structure only; caller must retain the integrity check's lease.
/// Never supplies runtime/device/model-load evidence or any readiness state.
class LiteRtLmFormatValidator {
  const LiteRtLmFormatValidator();

  Future<LiteRtLmFormatResult> inspect({
    required Directory stagingRoot,
    required ArtifactIntegrityMatch artifact,
  }) async {
    if (!artifact.sha256Matched ||
        !{
          ResourceContractKind.llm,
          ResourceContractKind.ragEmbedding,
        }.contains(artifact.kind)) {
      return const LiteRtLmFormatFailure(
        LiteRtLmFormatFailureCode.invalidArtifact,
      );
    }
    RandomAccessFile? input;
    try {
      if (await FileSystemEntity.type(stagingRoot.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        throw const _Problem(LiteRtLmFormatFailureCode.unsafePath);
      }
      final root = await stagingRoot.resolveSymbolicLinks();
      final file = File('$root/${artifact.relativePath}');
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
              FileSystemEntityType.file ||
          await file.resolveSymbolicLinks() != file.path) {
        throw const _Problem(LiteRtLmFormatFailureCode.unsafePath);
      }
      if (!artifact.matchesFileSnapshot(
        canonicalPath: file.path,
        stat: await file.stat(),
      )) {
        throw const _Problem(LiteRtLmFormatFailureCode.fileChanged);
      }
      input = await file.open();
      final prefix = await input.read(32);
      if (prefix.length != 32 ||
          ascii.decode(prefix.sublist(0, 8), allowInvalid: true) !=
              'LITERTLM') {
        throw const _Problem(LiteRtLmFormatFailureCode.malformedHeader);
      }
      final data = ByteData.sublistView(prefix);
      final version = [
        for (final offset in [8, 12, 16]) data.getUint32(offset, Endian.little),
      ];
      // The pinned upstream0.19.0 schema/core declares format1.9.0. Older
      // major1 headers are parsed structurally, never assumed runtime-compatible.
      if (version[0] != 1 || _compare(version, [1, 9, 0]) > 0) {
        throw const _Problem(LiteRtLmFormatFailureCode.unsupportedVersion);
      }
      final headerEnd = data.getUint64(24, Endian.little);
      if (headerEnd <= 32 ||
          headerEnd > 1024 * 1024 ||
          headerEnd > artifact.bytesRead) {
        throw const _Problem(LiteRtLmFormatFailureCode.malformedHeader);
      }
      final headerBytes = await input.read(headerEnd - 32);
      if (headerBytes.length != headerEnd - 32) {
        throw const _Problem(LiteRtLmFormatFailureCode.fileChanged);
      }
      // A standalone bounded buffer prevents lazy schema readers from seeing
      // bytes beyond header_end. Lists are lazy; check their counts first.
      final header = schema.LiteRtlmmetaData(Uint8List.fromList(headerBytes));
      final budget = _MetadataBudget();
      if (header.systemMetadata != null) {
        final entries = header.systemMetadata!.entries;
        if (entries == null) {
          throw const _Problem(LiteRtLmFormatFailureCode.malformedHeader);
        }
        budget.read(entries);
      }
      final sections = header.sectionMetadata?.objects;
      if (sections == null || sections.isEmpty || sections.length > 4096) {
        throw const _Problem(LiteRtLmFormatFailureCode.malformedHeader);
      }
      var previousEnd = headerEnd;
      final types = <int>[];
      for (final section in sections) {
        final begin = section.beginOffset;
        final end = section.endOffset;
        if (begin < headerEnd ||
            begin % 16384 != 0 ||
            end <= begin ||
            end > artifact.bytesRead) {
          throw const _Problem(LiteRtLmFormatFailureCode.invalidSectionBounds);
        }
        // Half-open ranges: real EmbeddingGemma weight sections legitimately
        // meet at an aligned end==begin boundary. No overlap is allowed.
        if (begin < previousEnd) {
          throw const _Problem(LiteRtLmFormatFailureCode.overlappingSections);
        }
        previousEnd = end;
        final type = section.dataType.value;
        if (type == 0) {
          throw const _Problem(LiteRtLmFormatFailureCode.malformedHeader);
        }
        types.add(type);
        if (section.items != null) budget.read(section.items!);
      }
      final metadataType = artifact.kind == ResourceContractKind.llm ? 5 : 8;
      if (types.where((t) => t == metadataType).length != 1 ||
          types.contains(metadataType == 5 ? 8 : 5) ||
          !types.contains(3) ||
          types.where((t) => t == 4 || t == 6).length != 1) {
        throw const _Problem(LiteRtLmFormatFailureCode.missingSection);
      }
      String? minimumRuntime;
      for (final section in sections) {
        final type = section.dataType.value;
        final size = section.endOffset - section.beginOffset;
        await input.setPosition(section.beginOffset);
        if (type == 3) {
          final magic = await input.read(8);
          if (magic.length != 8 ||
              ascii.decode(magic.sublist(4), allowInvalid: true) != 'TFL3') {
            throw const _Problem(
              LiteRtLmFormatFailureCode.invalidSectionPayload,
            );
          }
          final rootOffset = ByteData.sublistView(
            magic,
          ).getUint32(0, Endian.little);
          if (rootOffset < 8 || rootOffset > size - 4) {
            throw const _Problem(
              LiteRtLmFormatFailureCode.invalidSectionPayload,
            );
          }
        } else if ({4, 5, 6, 8}.contains(type)) {
          if (size > _maxSectionMetadata) {
            throw const _Problem(
              LiteRtLmFormatFailureCode.invalidSectionPayload,
            );
          }
          final bytes = await input.read(size);
          if (bytes.length != size) {
            throw const _Problem(LiteRtLmFormatFailureCode.fileChanged);
          }
          if (type == 6) {
            _inspectHfTokenizer(bytes);
          } else {
            final minimum = _inspectProto(
              bytes,
              runtimeField: type == 5
                  ? 14
                  : type == 8
                  ? 7
                  : null,
            );
            if (type == metadataType) minimumRuntime = minimum;
          }
        }
      }
      if (minimumRuntime != null) {
        final parsed = _version(minimumRuntime);
        if (parsed == null || _compare(parsed, [0, 19, 0]) > 0) {
          throw const _Problem(LiteRtLmFormatFailureCode.unsupportedRuntime);
        }
      }
      if (!artifact.matchesFileSnapshot(
            canonicalPath: await file.resolveSymbolicLinks(),
            stat: await file.stat(),
          ) ||
          await input.length() != artifact.bytesRead ||
          await stagingRoot.resolveSymbolicLinks() != root) {
        throw const _Problem(LiteRtLmFormatFailureCode.fileChanged);
      }
      return LiteRtLmFormatMatch._(
        version: version.join('.'),
        sectionCount: sections.length,
        minimumRuntimeVersion: minimumRuntime,
        remainingChecks: ResourceValidationRequirements.forKind(
          artifact.kind,
        ).difference({ResourceValidationCheck.sha256Matched}),
      );
    } on _Problem catch (error) {
      return LiteRtLmFormatFailure(error.code);
    } on FileSystemException {
      return const LiteRtLmFormatFailure(LiteRtLmFormatFailureCode.ioFailure);
    } on RangeError {
      return const LiteRtLmFormatFailure(
        LiteRtLmFormatFailureCode.malformedHeader,
      );
    } on StateError {
      return const LiteRtLmFormatFailure(
        LiteRtLmFormatFailureCode.malformedHeader,
      );
    } on FormatException {
      return const LiteRtLmFormatFailure(
        LiteRtLmFormatFailureCode.malformedHeader,
      );
    } finally {
      await input?.close();
    }
  }
}

const _maxSectionMetadata = 16 * 1024 * 1024;

class _Problem implements Exception {
  const _Problem(this.code);
  final LiteRtLmFormatFailureCode code;
}

List<int>? _version(String value) {
  if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(value)) return null;
  final parts = value.split('.').map(int.tryParse).toList();
  return parts.any((p) => p == null) ? null : parts.cast<int>();
}

int _compare(List<int> a, List<int> b) {
  for (var i = 0; i < 3; i++) {
    final order = a[i].compareTo(b[i]);
    if (order != 0) return order;
  }
  return 0;
}

class _MetadataBudget {
  var count = 0;
  void read(List<schema.KeyValuePair> entries) {
    if (entries.length > 4096 || (count += entries.length) > 4096) {
      throw const _Problem(LiteRtLmFormatFailureCode.malformedHeader);
    }
    final keys = <String>{};
    for (final entry in entries) {
      final key = entry.key;
      final value = entry.value;
      if (key == null ||
          !keys.add(key) ||
          entry.valueType == null ||
          value == null) {
        throw const _Problem(LiteRtLmFormatFailureCode.malformedHeader);
      }
      final Object? scalar = switch (value) {
        schema.StringValue() => value.value,
        schema.Uint8() => value.value,
        schema.Int8() => value.value,
        schema.Uint16() => value.value,
        schema.Int16() => value.value,
        schema.Uint32() => value.value,
        schema.Int32() => value.value,
        schema.Float32() => value.value,
        schema.Bool() => value.value,
        schema.Uint64() => value.value,
        schema.Int64() => value.value,
        schema.Double() => value.value,
        _ => null,
      };
      if (scalar == null || scalar is double && !scalar.isFinite) {
        throw const _Problem(LiteRtLmFormatFailureCode.malformedHeader);
      }
    }
  }
}

String? _inspectProto(List<int> bytes, {int? runtimeField}) {
  var position = 0;
  String? minimum;
  int varint() {
    var result = 0;
    for (var i = 0; i < 10 && position < bytes.length; i++) {
      final byte = bytes[position++];
      if (i == 9 && byte > 1) break;
      result |= (byte & 127) << (i * 7);
      if (byte < 128) return result;
    }
    throw const _Problem(LiteRtLmFormatFailureCode.invalidSectionPayload);
  }

  while (position < bytes.length) {
    final tag = varint();
    final field = tag >> 3;
    final wire = tag & 7;
    if (field <= 0 || field == runtimeField && wire != 2) {
      throw const _Problem(LiteRtLmFormatFailureCode.invalidSectionPayload);
    }
    switch (wire) {
      case 0:
        varint();
      case 1:
        position += 8;
      case 2:
        final size = varint();
        if (size < 0 || size > bytes.length - position) {
          throw const _Problem(LiteRtLmFormatFailureCode.invalidSectionPayload);
        }
        if (field == runtimeField) {
          if (minimum != null) {
            throw const _Problem(
              LiteRtLmFormatFailureCode.invalidSectionPayload,
            );
          }
          minimum = utf8.decode(bytes.sublist(position, position + size));
        }
        position += size;
      case 5:
        position += 4;
      default:
        throw const _Problem(LiteRtLmFormatFailureCode.invalidSectionPayload);
    }
    if (position > bytes.length) {
      throw const _Problem(LiteRtLmFormatFailureCode.invalidSectionPayload);
    }
  }
  if (bytes.isEmpty) {
    throw const _Problem(LiteRtLmFormatFailureCode.invalidSectionPayload);
  }
  return minimum;
}

void _inspectHfTokenizer(Uint8List bytes) {
  try {
    if (bytes.length < 9) throw const FormatException();
    final expected = ByteData.sublistView(bytes).getUint64(0, Endian.little);
    if (expected <= 0 || expected > _maxSectionMetadata) {
      throw const FormatException();
    }
    final collector = _BoundedTokenizerOutput(expected);
    final inflater = ZLibDecoder().startChunkedConversion(collector);
    for (var offset = 8; offset < bytes.length; offset += 65536) {
      inflater.add(
        Uint8List.sublistView(
          bytes,
          offset,
          (offset + 65536).clamp(0, bytes.length),
        ),
      );
    }
    inflater.close();
    if (collector.length != expected) throw const FormatException();
    final parsed = jsonDecode(utf8.decode(collector.output.takeBytes()));
    if (parsed is! Map<String, dynamic> ||
        parsed['model'] is! Map<String, dynamic>) {
      throw const FormatException();
    }
  } on FormatException {
    throw const _Problem(LiteRtLmFormatFailureCode.invalidSectionPayload);
  } on IOException {
    throw const _Problem(LiteRtLmFormatFailureCode.invalidSectionPayload);
  }
}

class _BoundedTokenizerOutput implements Sink<List<int>> {
  _BoundedTokenizerOutput(this.limit);
  final int limit;
  final BytesBuilder output = BytesBuilder(copy: false);
  int length = 0;

  @override
  void add(List<int> bytes) {
    if (bytes.length > limit - length) throw const FormatException();
    length += bytes.length;
    output.add(bytes);
  }

  @override
  void close() {}
}
