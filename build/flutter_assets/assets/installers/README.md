# USM TAP Native Installers

This directory contains the native installers for the USM TAP application.

## Required Files

Place the following installer files in this directory to enable native app downloads from the web application:

### Windows
- **Filename:** `usm_tap-windows.exe`
- **Format:** Standalone executable installer or MSIX package
- **Build command:** `flutter build windows --release`
- **Location after build:** `build/windows/x64/runner/Release/`

### macOS
- **Filename:** `usm_tap-macos.dmg`
- **Format:** DMG disk image
- **Build command:** `flutter build macos --release`
- **Location after build:** `build/macos/Build/Products/Release/`
- **Note:** You'll need to create a DMG from the .app bundle

### Linux
- **Filename:** `usm_tap-linux.AppImage`
- **Format:** AppImage portable application
- **Build command:** `flutter build linux --release`
- **Location after build:** `build/linux/x64/release/bundle/`
- **Note:** You'll need to package as AppImage using additional tools

### Android
- **Filename:** `usm_tap.apk`
- **Format:** APK package
- **Build command:** `flutter build apk --release`
- **Location after build:** `build/app/outputs/flutter-apk/app-release.apk`

### iOS
- **Note:** iOS apps are distributed through the App Store
- Users on iOS will see a message directing them to the App Store
- No installer file is needed for iOS

## Building Installers

### Prerequisites
- Flutter SDK installed
- Platform-specific build tools:
  - Windows: Visual Studio 2022
  - macOS: Xcode
  - Linux: Build essentials
  - Android: Android SDK
  - iOS: Xcode + valid Apple Developer account

### Build Steps

1. **Clean previous builds:**
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Build for specific platform:**

   **Windows:**
   ```bash
   flutter build windows --release
   # Copy from build/windows/x64/runner/Release/
   # Rename the main executable to usm_tap-windows.exe
   ```

   **macOS:**
   ```bash
   flutter build macos --release
   # Create DMG using create-dmg or hdiutil
   # Rename to usm_tap-macos.dmg
   ```

   **Linux:**
   ```bash
   flutter build linux --release
   # Package as AppImage using appimagetool
   # Rename to usm_tap-linux.AppImage
   ```

   **Android:**
   ```bash
   flutter build apk --release
   # Copy build/app/outputs/flutter-apk/app-release.apk
   # Rename to usm_tap.apk
   ```

3. **Copy the built installer to this directory**

4. **Rebuild the Flutter web app to include the new assets:**
   ```bash
   flutter build web --release
   ```

## File Size Considerations

- Keep installer files reasonably sized (compress if necessary)
- Consider using app bundles or split APKs for Android to reduce size
- Test download speeds on typical internet connections

## Testing

After placing installers in this directory:

1. Rebuild the web app: `flutter build web --release`
2. Deploy to your web server
3. Test the download functionality from different platforms
4. Verify the downloaded installers work correctly

## Security

- **Code Signing:** Always sign your installers for production
  - Windows: Use signtool with a valid certificate
  - macOS: Sign with valid Apple Developer certificate
  - Android: Sign APK with your keystore

- **Checksums:** Consider providing SHA-256 checksums for verification

## Deployment

When deploying to production:

1. Place signed installers in this directory
2. Run `flutter build web --release`
3. Deploy the entire web build to your hosting service
4. Ensure the assets/installers/ directory is accessible via HTTP/HTTPS

## Troubleshooting

**Download fails:**
- Check that the installer file exists in assets/installers/
- Verify file naming matches exactly (case-sensitive)
- Check web server MIME types for executable files
- Ensure CORS headers allow asset downloads

**Large file sizes:**
- Consider hosting installers on a CDN instead
- Modify the download service to use external URLs
- Implement delta updates for smaller downloads

## Version Management

- Keep installer filenames consistent
- Consider using version-specific URLs for different releases
- Update installers regularly with security patches and new features

---

For questions or issues, please contact the development team or refer to the Flutter documentation at https://docs.flutter.dev
