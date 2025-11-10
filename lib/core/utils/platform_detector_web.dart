// lib/core/utils/platform_detector.dart

import 'dart:html' as html;
import 'package:package_info_plus/package_info_plus.dart';

/// Enum representing supported operating systems
enum OperatingSystem {
  windows,
  macos,
  linux,
  android,
  ios,
  unknown,
}

/// Utility class for detecting the user's operating system from the browser
class PlatformDetector {
  /// Detects the operating system from the browser's user agent
  static OperatingSystem detectOS() {
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    final platform = html.window.navigator.platform?.toLowerCase() ?? '';

    // Check for mobile platforms first
    if (userAgent.contains('android')) {
      return OperatingSystem.android;
    }

    if (userAgent.contains('iphone') ||
        userAgent.contains('ipad') ||
        userAgent.contains('ipod') ||
        platform.contains('iphone') ||
        platform.contains('ipad')) {
      return OperatingSystem.ios;
    }

    // Check for desktop platforms
    if (userAgent.contains('win') || platform.contains('win')) {
      return OperatingSystem.windows;
    }

    if (userAgent.contains('mac') || platform.contains('mac')) {
      return OperatingSystem.macos;
    }

    if (userAgent.contains('linux') ||
        userAgent.contains('x11') ||
        platform.contains('linux')) {
      return OperatingSystem.linux;
    }

    return OperatingSystem.unknown;
  }

  /// Gets the installer filename for the detected OS
  static String getInstallerFilename(OperatingSystem os) {
    switch (os) {
      case OperatingSystem.windows:
        return 'usm_tap-windows.exe';
      case OperatingSystem.macos:
        return 'usm_tap.dmg';
      case OperatingSystem.linux:
        return 'usm_tap-linux.AppImage';
      case OperatingSystem.android:
        return 'usm_tap.apk';
      case OperatingSystem.ios:
        return ''; // iOS uses App Store
      case OperatingSystem.unknown:
        return '';
    }
  }

  /// Gets a user-friendly display name for the OS
  static String getOSDisplayName(OperatingSystem os) {
    switch (os) {
      case OperatingSystem.windows:
        return 'Windows';
      case OperatingSystem.macos:
        return 'macOS';
      case OperatingSystem.linux:
        return 'Linux';
      case OperatingSystem.android:
        return 'Android';
      case OperatingSystem.ios:
        return 'iOS';
      case OperatingSystem.unknown:
        return 'Unknown';
    }
  }

  /// Gets the asset path for the installer
  static String getInstallerAssetPath(OperatingSystem os) {
    final filename = getInstallerFilename(os);
    if (filename.isEmpty) return '';
    return 'assets/installers/$filename';
  }

  /// Checks if the OS supports direct download
  static bool supportsDirectDownload(OperatingSystem os) {
    return os != OperatingSystem.ios && os != OperatingSystem.unknown;
  }

  /// Gets the download URL for the installer
  static Future<String> getDownloadUrl(OperatingSystem os) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version;

    switch (os) {
      case OperatingSystem.windows:
        return 'https://github.com/jp555soul/usm-tap/releases/download/v$version/windows-release.zip';
      case OperatingSystem.macos:
        return 'https://github.com/jp555soul/usm-tap/releases/download/v$version/macos-release.zip';
      case OperatingSystem.linux:
        return 'assets/installers/usm_tap-linux.AppImage';
      case OperatingSystem.android:
        return 'assets/installers/usm_tap.apk';
      case OperatingSystem.ios:
      case OperatingSystem.unknown:
        return '';
    }
  }
}
