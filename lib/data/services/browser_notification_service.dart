import 'package:flutter/foundation.dart';
import 'dart:js_interop';

/// Service for browser push notifications (Web only)
/// Uses JS interop to access the Web Notification API
class BrowserNotificationService {
  static final BrowserNotificationService _instance =
      BrowserNotificationService._internal();

  factory BrowserNotificationService() => _instance;

  BrowserNotificationService._internal();

  /// Check if notifications are supported in current environment
  bool get isSupported {
    if (!kIsWeb) return false;
    return _isNotificationSupported();
  }

  /// Get current permission status: 'granted', 'denied', or 'default'
  String get permissionStatus {
    if (!isSupported) return 'unsupported';
    return _getPermission();
  }

  /// Request notification permission from user
  /// Returns true if permission was granted
  Future<bool> requestPermission() async {
    if (!isSupported) return false;

    try {
      final result = await _requestNotificationPermission();
      return result == 'granted';
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return false;
    }
  }

  /// Show a browser notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? icon,
    String? tag,
  }) async {
    if (!isSupported) return;
    if (permissionStatus != 'granted') {
      debugPrint('Notification permission not granted');
      return;
    }

    try {
      _showNotification(
        title,
        body,
        icon ?? '/icons/Icon-192.png',
        tag ?? 'usm-tap-${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  /// Register the push notification service worker
  Future<void> registerServiceWorker() async {
    if (!kIsWeb) return;
    try {
      await _registerServiceWorker();
      debugPrint('Push notification service worker registered');
    } catch (e) {
      debugPrint('Error registering service worker: $e');
    }
  }
}

// ============================================================================
// JS Interop bindings for Web Notification API
// ============================================================================

@JS('Notification.permission')
external String get _notificationPermission;

@JS('Notification')
external JSFunction? get _notificationConstructor;

bool _isNotificationSupported() {
  return _notificationConstructor != null;
}

String _getPermission() {
  try {
    return _notificationPermission;
  } catch (e) {
    return 'default';
  }
}

@JS('Notification.requestPermission')
external JSPromise<JSString> _jsRequestPermission();

Future<String> _requestNotificationPermission() async {
  final result = await _jsRequestPermission().toDart;
  return result.toDart;
}

@JS()
@staticInterop
class _NotificationOptions {
  external factory _NotificationOptions({
    String body,
    String icon,
    String tag,
  });
}

@JS('Notification')
@staticInterop
class _JsNotification {
  external factory _JsNotification(String title, _NotificationOptions options);
}

void _showNotification(String title, String body, String icon, String tag) {
  _JsNotification(
    title,
    _NotificationOptions(body: body, icon: icon, tag: tag),
  );
}

@JS('navigator.serviceWorker.register')
external JSPromise<JSAny> _jsRegisterSw(String path);

Future<void> _registerServiceWorker() async {
  await _jsRegisterSw('/push-notification-sw.js').toDart;
}
