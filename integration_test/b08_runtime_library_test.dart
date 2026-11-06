import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('B08 actual Android AAR and JNI via Flutter', (tester) async {
    final status = await const MethodChannel(
      'siraj/ai_runtime/methods_v1',
    ).invokeMapMethod<String, Object?>('getRuntimeStatus');
    expect(status?['declaredRuntimeVersion'], '0.19.0');
    expect(status?['jniLoaded'], isTrue);
    expect(status?['abi'], anyOf('arm64-v8a', 'x86_64'));
    expect(status?['llmInitialized'], isFalse);
    expect(status?['embeddingInitialized'], isFalse);
  });
}
