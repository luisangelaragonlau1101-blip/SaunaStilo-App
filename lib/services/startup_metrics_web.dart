import 'dart:js_interop';

@JS('performance.mark')
external void _mark(JSString name);

void mark(String name) => _mark(name.toJS);
