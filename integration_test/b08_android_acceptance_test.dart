// One Flutter integration invocation owns the app lifecycle. Flutter3.38.5
// uninstalls the app after each separate invocation; splitting targets would
// delete the private licensed fixtures before the model test.
import 'b03_android_database_test.dart' as database;
import 'b04_android_secure_session_test.dart' as secure_session;
import 'b07_download_storage_test.dart' as storage;
import 'b08_runtime_library_test.dart' as runtime_library;
import 'b08_real_models_test.dart' as models;

void main() {
  database.main();
  secure_session.main();
  storage.main();
  runtime_library.main();
  models.main();
}
