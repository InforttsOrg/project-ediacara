// Selects the Web Audio engine in the browser and the silent stub elsewhere.
export 'symphony_engine_stub.dart'
    if (dart.library.js_interop) 'symphony_engine_web.dart';
