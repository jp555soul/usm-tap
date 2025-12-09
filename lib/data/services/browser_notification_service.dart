// Platform-conditional export for BrowserNotificationService
// Uses stub implementation for non-web platforms
export 'browser_notification_service_stub.dart'
    if (dart.library.js_interop) 'browser_notification_service_web.dart';
