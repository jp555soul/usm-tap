// lib/core/utils/download_service.dart
// Conditionally exports web or stub implementation based on platform

export 'download_service_stub.dart'
    if (dart.library.html) 'download_service_web.dart';
