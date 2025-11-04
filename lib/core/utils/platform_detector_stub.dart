// lib/core/utils/platform_detector_stub.dart
// Stub implementation for non-web platforms

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

/// Utility class for detecting the user's operating system
/// This is a stub implementation for non-web platforms
class PlatformDetector {
  /// Returns unknown OS for non-web platforms
  static OperatingSystem detectOS() {
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
        return 'assets/installers/usm_tap-windows.exe';
      case OperatingSystem.macos:
        return 'https://github.com/jp555soul/usm-tap/releases/download/v$version/usm_tap.dmg';
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
