import 'dart:typed_data';
const isWebCapture = false;
class ChatAudioCapture {
  Future<void> start(int maximumSeconds) async => throw UnsupportedError('Web only');
  Future<Uint8List> stop() async => throw UnsupportedError('Web only');
  Future<void> dispose() async {}
}
