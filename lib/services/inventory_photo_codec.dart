import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

class InventoryPhotoCodec {
  static const maxBytes = 500 * 1024;

  static Future<String> encode(Uint8List bytes, {int maxWidth = 480}) async {
    if (maxWidth < 32 || maxWidth > 480) throw ArgumentError.value(maxWidth);
    if (bytes.isEmpty || bytes.length > 8 * 1024 * 1024) {
      throw StateError('Elige una foto de menos de 8 MB.');
    }
    for (final width in [maxWidth, maxWidth * 2 ~/ 3, maxWidth * 5 ~/ 12]) {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: width, allowUpscaling: false);
      try {
        final frame = await codec.getNextFrame();
        try {
          final encoded = await frame.image.toByteData(format: ui.ImageByteFormat.png);
          if (encoded != null && encoded.lengthInBytes <= maxBytes) {
            return 'data:image/png;base64,${base64Encode(encoded.buffer.asUint8List(encoded.offsetInBytes, encoded.lengthInBytes))}';
          }
        } finally { frame.image.dispose(); }
      } finally { codec.dispose(); }
    }
    throw StateError('La foto es demasiado grande. Elige otra imagen.');
  }

  static Uint8List? decode(String value) {
    const prefix = 'data:image/png;base64,';
    if (!value.startsWith(prefix)) return null;
    final bytes = base64Decode(value.substring(prefix.length));
    if (bytes.length > maxBytes) throw const FormatException('Foto demasiado grande');
    return bytes;
  }
}
