import 'dart:convert';
import 'dart:io';

import 'package:siraj/features/resources/artifact_integrity_validator.dart';
import 'package:siraj/features/resources/litertlm_format_validator.dart';
import 'package:siraj/features/resources/resource_validation_contracts.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/ai_runtime/litertlm_format_probe.dart DIRECTORY REPORT_JSON',
    );
    exitCode = 64;
    return;
  }
  const pins = [
    (
      'Qwen3-0.6B.litertlm',
      ResourceContractKind.llm,
      613722264,
      'c5f39b4191926786c3e6668b62af4d6eb15248dfc7a5348252a9b406f33f2108',
    ),
    (
      'embeddinggemma-2-text-270m.litertlm',
      ResourceContractKind.ragEmbedding,
      164626432,
      '2d079ee2f6f066b1f368e8d7c819f55214eaef1d0513b312321901f30ab286fb',
    ),
  ];
  final reports = <Map<String, Object?>>[];
  for (final (name, kind, size, sha) in pins) {
    final artifact = await const ArtifactIntegrityValidator().validate(
      stagingRoot: Directory(arguments.first),
      relativePath: name,
      kind: kind,
      expectedSizeBytes: size,
      expectedSha256: sha,
    );
    if (artifact is! ArtifactIntegrityMatch) {
      reports.add({'file': name, 'integrity': 'FAIL'});
      exitCode = 1;
      continue;
    }
    final result = await const LiteRtLmFormatValidator().inspect(
      stagingRoot: Directory(arguments.first),
      artifact: artifact,
    );
    reports.add(switch (result) {
      LiteRtLmFormatFailure(:final code) => {
        'file': name,
        'structure': 'FAIL',
        'code': code.name,
      },
      LiteRtLmFormatMatch() => {
        'file': name,
        'integrity': 'PASS',
        'structure': 'PASS',
        'container_version': result.version,
        'section_count': result.sectionCount,
        'minimum_runtime_declared': result.minimumRuntimeVersion,
        'remaining_checks': result.remainingChecks.map((c) => c.name).toList()
          ..sort(),
        'model_execution': 'NOT RUN',
        'activation_performed': false,
      },
    });
    if (result is LiteRtLmFormatFailure) exitCode = 1;
  }
  await File(arguments[1]).writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(reports)}\n',
    flush: true,
  );
}
