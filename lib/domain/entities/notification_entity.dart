import 'package:equatable/equatable.dart';

/// Types of notifications for visual styling
enum NotificationType {
  info,
  success,
  warning,
  error,
}

/// Domain entity representing an in-app notification
class NotificationEntity extends Equatable {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final Duration duration;
  final bool isDismissable;
  final bool sendBrowserNotification;

  const NotificationEntity({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.duration = const Duration(seconds: 4),
    this.isDismissable = true,
    this.sendBrowserNotification = false,
  });

  /// Factory constructor for quick info notification
  factory NotificationEntity.info({
    required String title,
    required String message,
    bool sendBrowserNotification = false,
  }) {
    return NotificationEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: NotificationType.info,
      title: title,
      message: message,
      timestamp: DateTime.now(),
      sendBrowserNotification: sendBrowserNotification,
    );
  }

  /// Factory constructor for quick success notification
  factory NotificationEntity.success({
    required String title,
    required String message,
    bool sendBrowserNotification = false,
  }) {
    return NotificationEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: NotificationType.success,
      title: title,
      message: message,
      timestamp: DateTime.now(),
      sendBrowserNotification: sendBrowserNotification,
    );
  }

  /// Factory constructor for quick warning notification
  factory NotificationEntity.warning({
    required String title,
    required String message,
    bool sendBrowserNotification = true,
  }) {
    return NotificationEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: NotificationType.warning,
      title: title,
      message: message,
      timestamp: DateTime.now(),
      sendBrowserNotification: sendBrowserNotification,
    );
  }

  /// Factory constructor for quick error notification
  factory NotificationEntity.error({
    required String title,
    required String message,
    bool sendBrowserNotification = true,
  }) {
    return NotificationEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: NotificationType.error,
      title: title,
      message: message,
      timestamp: DateTime.now(),
      duration: const Duration(seconds: 6), // Errors stay longer
      sendBrowserNotification: sendBrowserNotification,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        title,
        message,
        timestamp,
        duration,
        isDismissable,
        sendBrowserNotification,
      ];
}
