// lib/core/utils/download_service_stub.dart
// Stub implementation for non-web platforms

import 'package:flutter/foundation.dart';
import 'platform_detector.dart';

/// Result of a download operation
class DownloadResult {
  final bool success;
  final String? message;
  final String? errorMessage;

  DownloadResult({
    required this.success,
    this.message,
    this.errorMessage,
  });
}

/// Service for handling app installer downloads
/// This is a stub implementation for non-web platforms
class DownloadService {
  /// Downloads the installer for the detected operating system
  /// Returns failure on non-web platforms
  static Future<DownloadResult> downloadInstaller() async {
    final os = PlatformDetector.detectOS();
    return downloadInstallerForOS(os);
  }

  /// Downloads the installer for a specific operating system
  /// Returns failure on non-web platforms
  static Future<DownloadResult> downloadInstallerForOS(
      OperatingSystem os) async {
    if (kDebugMode) {
      print('Download not supported on non-web platforms');
    }

    return DownloadResult(
      success: false,
      errorMessage:
          'Downloads are only supported in web browsers. Please visit our website to download the installer.',
    );
  }

  /// Gets information about the installer for the current OS
  static String getDownloadInfo() {
    return 'Download available on web version';
  }

  /// Checks if an installer is available for the current OS
  /// Always returns false for non-web platforms
  static bool isInstallerAvailable() {
    return false;
  }
}
