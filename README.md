# usm_tap

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


# web
```
flutter build web --release
flutter run -d web-server --web-port=3000
```

# app
```
flutter run -d macos --release
```


Here's the complete build flow for your macOS app with Apple notarization:

## Complete Build & Distribution Flow

### 1. **Make Code Changes**
- Update your Dart/Flutter code
- Test locally if needed with `flutter run -d macos`

### 2. **Clean Build** (Important!)
```bash
flutter clean
flutter pub get
cd macos
rm -rf Pods Podfile.lock
pod install
cd ..
flutter build macos --release
```

### 3. **Open in Xcode** 
```bash
open macos/Runner.xcworkspace
```

### 4. **Verify Signing Settings in Xcode**
- Select "Runner" project in the left sidebar
- Select "Runner" target
- Go to "Signing & Capabilities" tab
- Make sure **Release** configuration uses your **"Developer ID Application"** certificate
- Do the same for the **Pods** project if you have dependencies

### 5. **Archive the App**
- In Xcode menu: **Product → Scheme → Runner**
- In Xcode menu: **Product → Destination → Any Mac (Apple Silicon, Intel)**
- In Xcode menu: **Product → Archive**
- Wait for the build to complete (can take 5-10 minutes)

### 6. **Validate the Archive**
- When the Organizer window opens automatically:
  - Select your new archive
  - Click **"Validate App"**
  - Choose **"Developer ID"**
  - Click through the dialogs
  - Wait for validation to complete (1-2 minutes)

### 7. **Distribute the App** (This handles notarization)
- In the Organizer window:
  - Click **"Distribute App"**
  - Select **"Direct Distribution"**
  - Click **"Next"**
  - Choose your **"Developer ID Application"** certificate
  - Click **"Next"**
  - Click **"Upload"** (this sends it to Apple for notarization)
  - Wait for "Ready to distribute" status (5-15 minutes)

### 8. **Export the .app**
- In the Organizer:
  - Select the archive marked "Ready to distribute"
  - Click **"Distribute App"** again
  - Select **"Direct Distribution"**
  - Click **"Export"**
  - Choose a save location (e.g., Desktop)
  - You now have `usm_tap.app`

### 9. **Create DMG Installer**

```
hdiutil create -volname "usm_tap" -srcfolder ~/Documents/workspace/bluemvnt/usm_tap_apps/usm_tap.app -ov -format UDZO ~/Documents/workspace/bluemvnt/usm_tap_apps/usm_tap_installer.dmg
```

- Open **Disk Utility**
- **File → New Image → Image from Folder**
- Select the exported `usm_tap.app` folder
- Save as: `usm_tap_installer.dmg`
- Format: **Compressed**
- Click **"Save"**

### 10. **Test the DMG**
- Mount the DMG
- Drag the app to Applications folder
- Launch it and verify it works without warnings

---

## Quick Reference Commands

**For code changes:**
```bash
# Clean
flutter clean
cd macos && rm -rf Pods Podfile.lock && pod install && cd ..

# Open Xcode
open macos/Runner.xcworkspace
```

**Then in Xcode:**
1. Product → Archive
2. Validate App
3. Distribute App → Direct Distribution → Upload
4. Wait for "Ready to distribute"
5. Distribute App → Direct Distribution → Export
6. Create DMG in Disk Utility

---

## Important Notes

- **Never use `flutter build macos --release`** - this won't sign correctly for notarization
- **Always archive through Xcode** to get proper signing
- The notarization happens automatically during the "Distribute" step
- If you skip validation or distribution, the app will show the malware warning
- After exporting, you can verify notarization status with:
  ```bash
  spctl -a -vvv -t install /path/to/usm_tap.app
  ```
  Should show: "accepted" and "source=Notarized Developer ID"

Does this flow make sense? Would you like me to document any specific step in more detail?