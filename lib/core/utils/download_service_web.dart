// lib/core/utils/download_service.dart

import 'dart:html' as html;
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
class DownloadService {
  /// Downloads the installer for the detected operating system
  static Future<DownloadResult> downloadInstaller() async {
    final os = PlatformDetector.detectOS();
    return downloadInstallerForOS(os);
  }

  /// Downloads the installer for a specific operating system
  static Future<DownloadResult> downloadInstallerForOS(
      OperatingSystem os) async {
    if (kDebugMode) {
      print('Download requested for OS: ${PlatformDetector.getOSDisplayName(os)}');
    }

    // Handle iOS separately - redirect to App Store or show message
    if (os == OperatingSystem.ios) {
      return DownloadResult(
        success: false,
        message: 'iOS app is available on the App Store',
        errorMessage:
            'Please visit the App Store to download the USM TAP app for iOS.',
      );
    }

    // Handle unknown OS
    if (os == OperatingSystem.unknown) {
      return DownloadResult(
        success: false,
        errorMessage:
            'Unable to detect your operating system. Please contact support for manual download instructions.',
      );
    }

    // Check if direct download is supported
    if (!PlatformDetector.supportsDirectDownload(os)) {
      return DownloadResult(
        success: false,
        errorMessage: 'Direct download is not supported for this platform.',
      );
    }

    try {
      final filename = PlatformDetector.getInstallerFilename(os);
      final downloadUrl = PlatformDetector.getDownloadUrl(os);

      // Trigger download using HTML anchor element
      _triggerDownload(downloadUrl, filename);

      return DownloadResult(
        success: true,
        message: 'Download started for ${PlatformDetector.getOSDisplayName(os)}',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error downloading installer: $e');
      }
      return DownloadResult(
        success: false,
        errorMessage:
            'Failed to download installer. The file may not be available yet. Please try again later or contact support.',
      );
    }
  }

  /// Triggers a download using an HTML anchor element
  static void _triggerDownload(String url, String filename) {
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';

    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }

  /// Gets information about the installer for the current OS
  static String getDownloadInfo() {
    final os = PlatformDetector.detectOS();
    final osName = PlatformDetector.getOSDisplayName(os);
    final filename = PlatformDetector.getInstallerFilename(os);

    if (os == OperatingSystem.ios) {
      return 'iOS app available on the App Store';
    }

    if (os == OperatingSystem.unknown) {
      return 'Unable to detect operating system';
    }

    return 'Download $osName installer ($filename)';
  }

  /// Checks if an installer is available for the current OS
  static bool isInstallerAvailable() {
    final os = PlatformDetector.detectOS();
    return PlatformDetector.supportsDirectDownload(os);
  }
}
