import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:siraj/features/resources/litertlm_schema/litertlm_header_schema_litert.lm.schema_generated.dart'
    as schema;

/// Synthetic container only, built with the official generated schema builders.
/// Its tiny payloads cannot establish a loadable or scientifically valid model.
Uint8List litertlmFixture({
  bool embedding = false,
  Set<int> omitTypes = const {},
  int metadataStart = 16384,
  int tokenizerStart = 32768,
  int modelStart = 49152,
  String? minimumRuntime,
  bool hfTokenizer = false,
  List<int>? tokenizerJson,
  int? declaredTokenizerSize,
  bool corruptTokenizer = false,
}) {
  final metadata = <int>[
    embedding ? 0x30 : 0x28,
    0x80,
    embedding ? 0x08 : 0x20,
  ];
  if (minimumRuntime != null) {
    final value = utf8.encode(minimumRuntime);
    metadata.addAll([embedding ? 0x3a : 0x72, value.length, ...value]);
  }
  final tflite = Uint8List(24);
  final data = ByteData.sublistView(tflite);
  data.setUint32(0, 16, Endian.little);
  tflite.setRange(4, 8, ascii.encode('TFL3'));
  data.setUint16(8, 6, Endian.little);
  data.setUint16(10, 8, Endian.little);
  data.setUint16(12, 4, Endian.little);
  data.setInt32(16, 8, Endian.little);
  data.setUint32(20, 3, Endian.little);
  List<int> tokenizer = [10, 1, 120];
  if (hfTokenizer) {
    final raw = tokenizerJson ?? utf8.encode('{"model":{"type":"BPE"}}');
    final compressed = ZLibEncoder().convert(raw);
    if (corruptTokenizer) compressed[compressed.length - 1] ^= 1;
    final length = Uint8List(8);
    ByteData.sublistView(
      length,
    ).setUint64(0, declaredTokenizerSize ?? raw.length, Endian.little);
    tokenizer = [...length, ...compressed];
  }
  final sections = <(schema.AnySectionDataType, int, List<int>, String?)>[
    (
      embedding
          ? schema.AnySectionDataType.EmbeddingMetadataProto
          : schema.AnySectionDataType.LlmMetadataProto,
      metadataStart,
      metadata,
      null,
    ),
    (
      hfTokenizer
          ? schema.AnySectionDataType.HF_Tokenizer_Zlib
          : schema.AnySectionDataType.SP_Tokenizer,
      tokenizerStart,
      tokenizer,
      null,
    ),
    (
      schema.AnySectionDataType.TFLiteModel,
      modelStart,
      tflite,
      embedding ? 'tf_lite_text_encoder' : 'tf_lite_prefill_decode',
    ),
  ].where((s) => !omitTypes.contains(s.$1.value)).toList();
  final header = schema.LiteRtlmmetaDataObjectBuilder(
    systemMetadata: schema.SystemMetadataObjectBuilder(entries: []),
    sectionMetadata: schema.SectionMetadataObjectBuilder(
      objects: sections
          .map(
            (s) => schema.SectionObjectObjectBuilder(
              beginOffset: s.$2,
              endOffset: s.$2 + s.$3.length,
              dataType: s.$1,
              items: [
                if (s.$4 != null)
                  schema.KeyValuePairObjectBuilder(
                    key: 'model_type',
                    valueType: schema.VdataTypeId.StringValue,
                    value: schema.StringValueObjectBuilder(value: s.$4),
                  ),
              ],
            ),
          )
          .toList(),
    ),
  ).toBytes();
  final bytes = Uint8List(65536);
  bytes.setRange(0, 8, ascii.encode('LITERTLM'));
  final prefix = ByteData.sublistView(bytes);
  prefix.setUint32(8, 1, Endian.little);
  prefix.setUint32(12, 7, Endian.little);
  prefix.setUint32(16, 0, Endian.little);
  prefix.setUint64(24, 32 + header.length, Endian.little);
  bytes.setRange(32, 32 + header.length, header);
  for (final section in sections) {
    bytes.setRange(section.$2, section.$2 + section.$3.length, section.$3);
  }
  return bytes;
}
