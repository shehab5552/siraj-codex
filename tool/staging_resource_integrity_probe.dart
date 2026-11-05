import 'dart:convert';
import 'dart:io';

import 'package:siraj/features/resources/artifact_integrity_validator.dart';
import 'package:siraj/features/resources/resource_format_preflight.dart';
import 'package:siraj/features/resources/resource_validation_contracts.dart';

/// Developer-only STAGING byte probe with owner-provided expectations.
/// No downloads, DB writes, format-policy overrides or activation.
Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty || arguments.length > 2) {
    stderr.writeln(
      'Usage: dart run tool/staging_resource_integrity_probe.dart DIRECTORY [REPORT_JSON]',
    );
    exitCode = 64;
    return;
  }
  const pins = [
    (
      'Biology.zip',
      ResourceContractKind.ragPack,
      873028,
      '8111e6cedd0a045e3368b02905ac2a15776e850ec50ea54794c32e3bdf6c015c',
    ),
    (
      'embeddinggemma-2-text-270m.litertlm',
      ResourceContractKind.ragEmbedding,
      164626432,
      '2d079ee2f6f066b1f368e8d7c819f55214eaef1d0513b312321901f30ab286fb',
    ),
    (
      'Qwen3-0.6B.litertlm',
      ResourceContractKind.llm,
      613722264,
      'c5f39b4191926786c3e6668b62af4d6eb15248dfc7a5348252a9b406f33f2108',
    ),
  ];
  final results = <Map<String, Object?>>[];
  for (final (name, kind, size, hash) in pins) {
    final result = await const ArtifactIntegrityValidator().validate(
      stagingRoot: Directory(arguments.first),
      relativePath: name,
      kind: kind,
      expectedSizeBytes: size,
      expectedSha256: hash,
    );
    switch (result) {
      case ArtifactIntegrityFailure(:final code):
        results.add({'file': name, 'integrity': 'FAIL', 'code': code.name});
        exitCode = 1;
      case ArtifactIntegrityMatch():
        final format = ResourceFormatPreflight.inspect(result);
        results.add({
          'file': name,
          'kind': kind.dbKind,
          'integrity': 'PASS',
          'size_bytes': result.bytesRead,
          'sha256': result.sha256,
          'header_status': format.status.name,
          'remaining_checks': format.remainingChecks.map((c) => c.name).toList()
            ..sort(),
          'activation_performed': false,
        });
    }
  }
  final json = const JsonEncoder.withIndent('  ').convert(results);
  if (arguments.length == 2) {
    // A dedicated evidence file avoids Dart build-hook diagnostics in stdout.
    await File(arguments[1]).writeAsString('$json\n', flush: true);
  } else {
    stdout.writeln(json);
  }
}
