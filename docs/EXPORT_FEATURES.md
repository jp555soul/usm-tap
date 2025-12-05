# USM TAP - Export Features Documentation

This document provides a comprehensive breakdown of all export and data-sharing features available in the USM TAP application.

---

## 📋 Summary

| Feature | Location | Format | Status |
|---------|----------|--------|--------|
| Export Response | Analysis Panel | JSON | ✅ Active |
| Copy Response | Analysis Panel | Clipboard | ✅ Active |
| Export API Logs | Control Panel | TXT | 🚫 Hidden |
| Download Installer | Header | Binary | ✅ Active (web only) |
| Configuration State | Internal | JSON | 🔧 Developer only |

---

## 1. Export Individual Analysis Response

**Location:** Analysis Output Module (right panel)

**Trigger:** Click the download icon (📥) on any individual response in the analysis panel

| Property | Value |
|----------|-------|
| Format | `.json` |
| Filename | `ocean_analysis_response_{index}_{source}.json` |
| Save Location | Application Documents Directory |

### Exported Data Structure

```json
{
  "id": "response_id",
  "timestamp": "2025-12-04T21:21:55.000Z",
  "content": "Analysis text content...",
  "source": "api",
  "type": "chart",
  "frame": 1,
  "parameter": "oceanCurrents",
  "depth": 0,
  "retryAttempt": 0
}
```

### Source Code Location

- **File:** `lib/presentation/widgets/panels/output_module_widget.dart`
- **Function:** `_handleExportResponse()`

---

## 2. Copy Response to Clipboard

**Location:** Analysis Output Module (right panel)

**Trigger:** Click the copy icon (📋) on any individual response

| Property | Value |
|----------|-------|
| Format | Plain text |
| Action | Copies response content to system clipboard |
| Feedback | Shows "Response copied to clipboard" snackbar |

### Source Code Location

- **File:** `lib/presentation/widgets/panels/output_module_widget.dart`
- **Function:** `_handleCopyResponse()`

---

## 3. Export API Logs

> ⚠️ **Note:** This feature is currently hidden from the UI but remains functional in the codebase.

**Location:** Control Panel footer (hidden)

**Trigger:** "Export Logs" button in the control panel footer

| Property | Value |
|----------|-------|
| Format | `.txt` |
| Filename | `api_logs_{timestamp}.txt` (e.g., `api_logs_20251204_212155.txt`) |
| Save Location | Application Documents Directory |

### Log Format

Each log entry follows this format:

```
[YYYY-MM-DD HH:MM:SS] query_content
```

### Source Code Locations

- **Widget:** `lib/presentation/widgets/panels/control_panel_widget.dart`
- **Bloc Handler:** `lib/presentation/blocs/ocean_data/ocean_data_bloc.dart` → `_onExportApiLogs()`
- **Logger:** `lib/core/utils/api_logger.dart` → `saveLogsToFile()`

---

## 4. Download Native App Installer

**Location:** Header (top right of the app - web version only)

**Trigger:** "Download App" button in the header

### Supported Platforms

| Platform | File Type | Source |
|----------|-----------|--------|
| Windows | `.exe` / `.zip` | GitHub Releases |
| macOS | `.dmg` / `.zip` | GitHub Releases |
| Linux | `.AppImage` | Local Assets |
| Android | `.apk` | Local Assets |
| iOS | N/A | Redirects to App Store |

### Download URLs

Downloads are sourced from GitHub Releases:

```
https://github.com/jp555soul/usm-tap/releases/download/v{version}/{platform}-release.zip
```

### Source Code Locations

- **Widget:** `lib/presentation/widgets/layout/header_widget.dart`
- **Download Button:** `_buildDownloadButton()`, `_handleDownload()`
- **Download Service:** `lib/core/utils/download_service_web.dart`
- **Platform Detection:** `lib/core/utils/platform_detector_web.dart`

---

## 5. Configuration Export State (Developer Feature)

**Location:** Internal state management (not exposed in UI)

**Access:** Programmatic via `exportConfiguration` getter on `UIControlsLoadedState`

### Exported Data Structure

```json
{
  "timestamp": "2025-12-04T21:21:55.000Z",
  "selections": {
    "area": "USM",
    "model": "NGOFS2",
    "depth": 0,
    "activeParameter": "oceanCurrents",
    "date": "2025-12-04",
    "time": "21:00",
    "station": "Station Name"
  },
  "validation": {
    "isValid": true,
    "errors": [],
    "warnings": []
  },
  "availableOptions": {
    "models": ["NGOFS2"],
    "depths": [0, 5, 10, 20],
    "areas": ["USM", "MBL", "MSR"],
    "dates": ["..."],
    "times": ["..."]
  }
}
```

### Source Code Location

- **File:** `lib/presentation/blocs/ui_controls/ui_controls_bloc.dart`
- **Property:** `UIControlsLoadedState.exportConfiguration`

---

## File Save Locations

All exported files are saved to the **Application Documents Directory**, which varies by platform:

| Platform | Typical Path |
|----------|--------------|
| macOS | `~/Library/Containers/com.bluemvnt.usmTap/Data/Documents/` |
| Windows | `C:\Users\{username}\Documents\` |
| Linux | `~/Documents/` |
| iOS | App sandbox Documents folder |
| Android | App-specific external storage |

---

## Related Dependencies

- `path_provider` - For accessing the documents directory
- `package_info_plus` - For version information in download URLs
- `dart:io` (File) - For writing files to disk
- `dart:convert` (JsonEncoder) - For JSON formatting

---

*Last updated: December 4, 2025*
