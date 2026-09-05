import 'dart:typed_data';
const isWebCapture = false;
Future<void> beginCapture() async => throw UnsupportedError('Web only');
Future<Uint8List> finishCapture() async => throw UnsupportedError('Web only');
Future<void> disposeCapture() async {}
