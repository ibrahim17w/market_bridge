import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Reusable cached image widget with loading shimmer and error fallback.
/// This prevents images from reloading every time they scroll off-screen.
class CachedAppImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final int? memCacheWidth;

  const CachedAppImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.memCacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder(context);
    }

    final image = CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth ?? 400,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (context, url) => _buildShimmer(context),
      errorWidget: (context, url, error) => _buildError(context),
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  Widget _buildPlaceholder(BuildContext context) {
    final widget = Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: placeholder ?? Icon(Icons.image, color: Colors.grey.shade400),
    );
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: widget);
    }
    return widget;
  }

  Widget _buildShimmer(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final widget = Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: Icon(Icons.broken_image, color: Colors.grey.shade400),
    );
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: widget);
    }
    return widget;
  }
}
