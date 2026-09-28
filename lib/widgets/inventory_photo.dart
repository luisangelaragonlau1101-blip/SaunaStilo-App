import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/inventory_photo_codec.dart';

/// Reads both original Storage links and photos persisted with the product.
class InventoryPhoto extends StatelessWidget {
  final String imageUrl;
  final double? width, height;
  final BoxFit? fit;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;
  const InventoryPhoto({super.key, required this.imageUrl, this.width, this.height, this.fit, this.placeholder, this.errorWidget});
  @override
  Widget build(BuildContext context) {
    Widget failed(Object error) => errorWidget?.call(context, imageUrl, error) ?? const Icon(Icons.broken_image_outlined);
    try {
      final bytes = InventoryPhotoCodec.decode(imageUrl);
      if (bytes != null) return Image.memory(bytes, width: width, height: height, fit: fit, errorBuilder: (c, e, s) => failed(e));
      return CachedNetworkImage(imageUrl: imageUrl, width: width, height: height, fit: fit, placeholder: placeholder, errorWidget: errorWidget);
    } catch (error) { return failed(error); }
  }
}
