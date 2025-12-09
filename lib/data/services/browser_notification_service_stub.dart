import 'package:flutter/foundation.dart';

/// Service for browser push notifications (Web only)
/// Uses conditional imports to only include web-specific code on web platform
class BrowserNotificationService {
  static final BrowserNotificationService _instance =
      BrowserNotificationService._internal();

  factory BrowserNotificationService() => _instance;

  BrowserNotificationService._internal();

  /// Check if notifications are supported in current environment
  bool get isSupported => false;

  /// Get current permission status: 'granted', 'denied', or 'default'
  String get permissionStatus => 'unsupported';

  /// Request notification permission from user
  /// Returns true if permission was granted
  Future<bool> requestPermission() async => false;

  /// Show a browser notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? icon,
    String? tag,
  }) async {
    // Not supported on non-web platforms
    debugPrint('Browser notifications not supported on this platform');
  }

  /// Register the push notification service worker
  Future<void> registerServiceWorker() async {
    // Not supported on non-web platforms
  }
}
