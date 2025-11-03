// lib/core/utils/platform_detector.dart
// Conditionally exports web or stub implementation based on platform

export 'platform_detector_stub.dart'
    if (dart.library.html) 'platform_detector_web.dart';
