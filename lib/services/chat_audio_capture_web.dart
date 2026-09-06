import 'dart:js_interop';
import 'dart:typed_data';
const isWebCapture = true;
@JS('createSaunaChatAudioCapture')
external _Capture _create();
extension type _Capture(JSObject _) implements JSObject {
  external JSPromise<JSAny?> start(JSNumber maximumSeconds);
  external JSPromise<JSUint8Array> stop();
  external JSPromise<JSAny?> dispose();
}
class ChatAudioCapture {
  late final _Capture _capture = _create();
  bool _used = false;
  Future<void> start(int maximumSeconds) async {_used = true; await _capture.start(maximumSeconds.toJS).toDart;}
  Future<Uint8List> stop() async => (await _capture.stop().toDart).toDart;
  Future<void> dispose() async {if (_used) await _capture.dispose().toDart;}
}
