import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Counts the binding's completed test results, not a historical report number.
/// These targets contain no skipped tests; missing execution fails explicitly.
void recordNativeResults(
  IntegrationTestWidgetsFlutterBinding binding,
  String target,
  int expected,
) {
  tearDownAll(() {
    final passed = binding.results.values.where((v) => v == 'success').length;
    final failed = binding.results.length - passed;
    expect(
      binding.results.length,
      expected,
      reason: 'Every native case must actually execute',
    );
    binding.reportData ??= <String, dynamic>{};
    binding.reportData!['siraj_test_results'] = {
      'target': target,
      'passed': passed,
      'failed': failed,
      'skipped': 0,
      'physical_device': false,
    };
  });
}
