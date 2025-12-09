import 'package:flutter/material.dart';
import '../../../domain/entities/notification_entity.dart';

/// A styled toast notification widget
class NotificationToast extends StatelessWidget {
  final NotificationEntity notification;
  final VoidCallback? onDismiss;

  const NotificationToast({
    Key? key,
    required this.notification,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final config = _getTypeConfig(notification.type);

    return Container(
      width: 360,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // slate-800
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: config.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            // Color accent bar
            Container(
              width: 4,
              height: 72,
              color: config.accentColor,
            ),
            // Icon
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                config.icon,
                color: config.iconColor,
                size: 24,
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      notification.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            // Dismiss button
            if (notification.isDismissable)
              IconButton(
                onPressed: onDismiss,
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: Colors.grey.shade500,
                ),
                splashRadius: 18,
              ),
          ],
        ),
      ),
    );
  }

  _NotificationTypeConfig _getTypeConfig(NotificationType type) {
    switch (type) {
      case NotificationType.info:
        return _NotificationTypeConfig(
          icon: Icons.info_outline,
          iconColor: const Color(0xFF60A5FA), // blue-400
          accentColor: const Color(0xFF3B82F6), // blue-500
          borderColor: const Color(0xFF1D4ED8).withOpacity(0.3), // blue-700
        );
      case NotificationType.success:
        return _NotificationTypeConfig(
          icon: Icons.check_circle_outline,
          iconColor: const Color(0xFF4ADE80), // green-400
          accentColor: const Color(0xFF22C55E), // green-500
          borderColor: const Color(0xFF15803D).withOpacity(0.3), // green-700
        );
      case NotificationType.warning:
        return _NotificationTypeConfig(
          icon: Icons.warning_amber_outlined,
          iconColor: const Color(0xFFFBBF24), // amber-400
          accentColor: const Color(0xFFF59E0B), // amber-500
          borderColor: const Color(0xFFB45309).withOpacity(0.3), // amber-700
        );
      case NotificationType.error:
        return _NotificationTypeConfig(
          icon: Icons.error_outline,
          iconColor: const Color(0xFFF87171), // red-400
          accentColor: const Color(0xFFEF4444), // red-500
          borderColor: const Color(0xFFB91C1C).withOpacity(0.3), // red-700
        );
    }
  }
}

class _NotificationTypeConfig {
  final IconData icon;
  final Color iconColor;
  final Color accentColor;
  final Color borderColor;

  _NotificationTypeConfig({
    required this.icon,
    required this.iconColor,
    required this.accentColor,
    required this.borderColor,
  });
}
