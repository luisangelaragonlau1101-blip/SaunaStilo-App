import 'dart:js_interop';
import 'dart:typed_data';
const isWebCapture = true;
@JS('saunaVoiceCapture')
external _VoiceCapture get _capture;
extension type _VoiceCapture(JSObject _) implements JSObject {
  external JSPromise<JSAny?> start(JSNumber maximumSeconds);
  external JSPromise<JSUint8Array> stop();
  external JSPromise<JSAny?> dispose();
}
Future<void> beginCapture() async { await _capture.start(10.toJS).toDart; }
Future<Uint8List> finishCapture() async => (await _capture.stop().toDart).toDart;
Future<void> disposeCapture() async { await _capture.dispose().toDart; }
