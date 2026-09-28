import 'package:flutter/material.dart';
import '../services/inventory_photo_codec.dart';

class InlinePhoto extends StatelessWidget {
  final String url;
  final double? width, height;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  const InlinePhoto(this.url, {super.key, this.width, this.height, this.fit, this.errorBuilder, this.loadingBuilder});
  @override Widget build(BuildContext context) {
    try {
      final bytes = InventoryPhotoCodec.decode(url);
      if (bytes != null) return Image.memory(bytes, width: width, height: height, fit: fit, errorBuilder: errorBuilder);
      return Image.network(url, width: width, height: height, fit: fit, errorBuilder: errorBuilder, loadingBuilder: loadingBuilder);
    } catch (error, stack) { return errorBuilder?.call(context, error, stack) ?? const Icon(Icons.broken_image_outlined); }
  }
}
