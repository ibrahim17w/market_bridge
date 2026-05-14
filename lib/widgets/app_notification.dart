import 'package:flutter/material.dart';
import '../providers/locale_provider.dart';

void showAppNotification(
  BuildContext context, {
  required String message,
  bool isError = false,
  bool isSuccess = false,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  bool isRemoved = false;

  final bgColor = isSuccess
      ? const Color(0xFF2E7D32)
      : isError
      ? const Color(0xFFC62828)
      : const Color(0xFFEF6C00);

  final icon = isSuccess
      ? Icons.check_circle_rounded
      : isError
      ? Icons.error_rounded
      : Icons.info_rounded;

  entry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(
                  isRTL(localeNotifier.value)
                      ? (1 - value) * 20
                      : (1 - value) * -20,
                  0,
                ),
                child: child,
              ),
            );
          },
          child: GestureDetector(
            onTap: () {
              if (!isRemoved && entry.mounted) {
                isRemoved = true;
                entry.remove();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _cleanMessage(message),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (!isRemoved && entry.mounted) {
                        isRemoved = true;
                        entry.remove();
                      }
                    },
                    child: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  Future.delayed(duration, () {
    if (!isRemoved && entry.mounted) {
      isRemoved = true;
      entry.remove();
    }
  });
}

String _cleanMessage(String raw) {
  return raw
      .replaceAll('Exception:', '')
      .replaceAll('Exception', '')
      .replaceAll('Error:', '')
      .trim();
}
