import 'package:drift/wasm.dart';

/// Drift's shared/dedicated web worker entry point. Compiled to
/// drift_worker.js by `dart run tool/setup_web.dart` so the worker always
/// matches the project's resolved drift version.
void main() {
  WasmDatabase.workerMainForOpen();
}
