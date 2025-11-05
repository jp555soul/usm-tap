// lib/presentation/widgets/layout/header.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../../../injection_container.dart' as di;
import '../panels/holoocean_panel_widget.dart';
import '../../../data/datasources/local/encrypted_storage_local_datasource.dart';
import '../auth/login_button.dart';
import '../auth/logout_button.dart';
import '../auth/profile.dart';
import '../../../core/utils/platform_detector.dart';
import '../../../core/utils/download_service.dart';

class HeaderWidget extends StatefulWidget {
  final String dataSource;
  final String timeZone;
  final ValueChanged<String>? onTimeZoneChange;
  final VoidCallback? onSettingsClick;
  final String connectionStatus;
  final DataQuality? dataQuality;
  final bool showDataStatus;
  final bool showTutorial;
  final ValueChanged<bool>? onTutorialToggle;
  final int tutorialStep;
  final bool isFirstTimeUser;
  final bool isAuthenticated;

  const HeaderWidget({
    Key? key,
    this.dataSource = 'simulated',
    this.timeZone = 'UTC',
    this.onTimeZoneChange,
    this.onSettingsClick,
    this.connectionStatus = 'connected',
    this.dataQuality,
    this.showDataStatus = true,
    this.showTutorial = false,
    this.onTutorialToggle,
    this.tutorialStep = 0,
    this.isFirstTimeUser = false,
    this.isAuthenticated = false,
  }) : super(key: key);

  @override
  State<HeaderWidget> createState() => _HeaderWidgetState();
}

class _HeaderWidgetState extends State<HeaderWidget> {
  DateTime _currentTime = DateTime.now();
  Timer? _timer;
  bool _showSettings = false;
  bool _showHoloOceanPanel = false;
  late final EncryptedStorageService _storage;
  bool _hasSeenTutorial = false;

  @override
  void initState() {
    super.initState();
    _storage = di.sl<EncryptedStorageService>();
    _startTimer();
    _loadTutorialStatusAndCheck();
  }

  void _loadTutorialStatusAndCheck() async {
    final seen = await _storage.getData('ocean-monitor-tutorial-completed');
    if (mounted) {
      setState(() {
        _hasSeenTutorial = (seen != null);
      });
      _checkFirstTimeUser();
    }
  }

  @override
  void didUpdateWidget(HeaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFirstTimeUser != oldWidget.isFirstTimeUser ||
        widget.showTutorial != oldWidget.showTutorial) {
      _checkFirstTimeUser();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _currentTime = DateTime.now());
    });
  }

  void _checkFirstTimeUser() {
    if (widget.isFirstTimeUser && !widget.showTutorial) {
      if (!_hasSeenTutorial) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && widget.onTutorialToggle != null) {
            widget.onTutorialToggle!(true);
          }
        });
      }
    }
  }

  String _getFormattedTime() {
    switch (widget.timeZone) {
      case 'UTC':
        final utcTime = _currentTime.toUtc();
        return DateFormat('HH:mm:ss').format(utcTime);
      case 'Local':
        return DateFormat('HH:mm:ss').format(_currentTime);
      case 'CST':
        // Approximation for CST (UTC-6)
        final cstTime = _currentTime.toUtc().subtract(const Duration(hours: 6));
        return DateFormat('HH:mm:ss').format(cstTime);
      default:
        return DateFormat('HH:mm:ss').format(_currentTime);
    }
  }

  DataSourceInfo _getDataSourceDisplay() {
    switch (widget.dataSource) {
      case 'api':
        return DataSourceInfo(
          text: 'API Stream',
          color: Colors.blue[400]!,
          icon: Icons.wifi_rounded,
        );
      case 'simulated':
        return DataSourceInfo(
          text: 'Simulated',
          color: Colors.yellow[400]!,
          icon: Icons.bar_chart_rounded,
        );
      case 'none':
        return DataSourceInfo(
          text: 'No Data',
          color: Colors.red[400]!,
          icon: Icons.wifi_off_rounded,
        );
      default:
        return DataSourceInfo(
          text: 'Unknown',
          color: Colors.grey[400]!,
          icon: Icons.bar_chart_rounded,
        );
    }
  }

  Widget _getConnectionStatusIndicator() {
    switch (widget.connectionStatus) {
      case 'connected':
        return _PulsingDot(color: Colors.green[400]!);
      case 'connecting':
        return _PingingDot(color: Colors.yellow[400]!);
      case 'disconnected':
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.red[400],
            shape: BoxShape.circle,
          ),
        );
      default:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey[400],
            shape: BoxShape.circle,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataSourceInfo = _getDataSourceDisplay();
    final isSmallScreen = MediaQuery.of(context).size.width < 640;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B), // slate-800
        border: Border(
          bottom: BorderSide(color: Color(0xFF334155)), // slate-700
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 24,
        vertical: isSmallScreen ? 8 : 16,
      ),
      child: Stack(
        children: [
          Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Side - Branding
                  Expanded(
                    child: _buildBranding(dataSourceInfo, isSmallScreen),
                  ),

                  // Right Side - Controls
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildControls(isSmallScreen),
                      const SizedBox(height: 8),
                      _buildBlueMvmtLogo(isSmallScreen),
                    ],
                  ),
                ],
              ),

              // Mobile Time Display
              if (isSmallScreen) ...[
                const SizedBox(height: 8),
                Text(
                  '${_getFormattedTime()} ${widget.timeZone}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFCBD5E1),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ],
          ),

          // Overlay for closing dropdowns
          if (_showSettings || _showHoloOceanPanel)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showSettings = false;
                    _showHoloOceanPanel = false;
                  });
                },
                child: Container(color: Colors.transparent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBranding(DataSourceInfo dataSourceInfo, bool isSmall) {
    return Row(
      children: [
        Container(
          width: isSmall ? 32 : 40,
          height: isSmall ? 32 : 40,
          child: Image.asset(
            'assets/icons/roger_wicker_center_ocean_enterprise.png',
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(width: isSmall ? 8 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF60A5FA), Color(0xFF22D3EE)],
                ).createShader(bounds),
                child: Text(
                  'CubeAI',
                  style: TextStyle(
                    fontSize: isSmall ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  Text(
                    'USM Maritime Technology Solutions',
                    style: TextStyle(
                      fontSize: isSmall ? 10 : 14,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF64748B),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(dataSourceInfo.icon, size: 12, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        'Data: ${dataSourceInfo.text}',
                        style: TextStyle(
                          fontSize: isSmall ? 10 : 14,
                          color: dataSourceInfo.color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      _getConnectionStatusIndicator(),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControls(bool isSmall) {
    return Wrap(
      spacing: isSmall ? 4 : 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        // Time Zone Selector
        _buildTimeZoneSelector(isSmall),

        // Current Time (desktop only)
        if (!isSmall)
          Text(
            _getFormattedTime(),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFCBD5E1),
              fontFamily: 'monospace',
            ),
          ),

        // Data Quality
        if (widget.showDataStatus && widget.dataQuality != null)
          _buildDataQuality(isSmall),

        // HoloOcean Button
        _buildHoloOceanButton(isSmall),

        // Tutorial Button
        _buildTutorialButton(isSmall),

        // Download Button
        _buildDownloadButton(isSmall),

        // Auth Section
        if (widget.isAuthenticated) ...[
          const Profile(),
          const LogoutButton(),
        ] else
          const LoginButton(),

        // Settings Button
        _buildSettingsButton(isSmall),
      ],
    );
  }

  Widget _buildTimeZoneSelector(bool isSmall) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.access_time_rounded,
            size: isSmall ? 12 : 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: isSmall ? 4 : 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF334155),
            border: Border.all(color: const Color(0xFF475569)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: widget.timeZone,
              onChanged: (value) {
                if (value != null && widget.onTimeZoneChange != null) {
                  widget.onTimeZoneChange!(value);
                }
              },
              style: TextStyle(
                fontSize: isSmall ? 10 : 14,
                color: Colors.white,
              ),
              dropdownColor: const Color(0xFF334155),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 20),
              items: const [
                DropdownMenuItem(value: 'UTC', child: Text('UTC')),
                DropdownMenuItem(value: 'Local', child: Text('Local Time')),
                DropdownMenuItem(value: 'CST', child: Text('CST')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataQuality(bool isSmall) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF334155).withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bar_chart_rounded, size: 12, color: Color(0xFF94A3B8)),
          const SizedBox(width: 4),
          Text(
            '${widget.dataQuality!.stations}S/${widget.dataQuality!.measurements}M',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildHoloOceanButton(bool isSmall) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => setState(() => _showHoloOceanPanel = !_showHoloOceanPanel),
          icon: Icon(Icons.explore_rounded, size: isSmall ? 16 : 20),
          color: _showHoloOceanPanel ? Colors.white : const Color(0xFFCBD5E1),
          style: IconButton.styleFrom(
            backgroundColor: _showHoloOceanPanel
                ? Colors.green[600]
                : const Color(0xFF334155),
            padding: EdgeInsets.all(isSmall ? 4 : 8),
          ),
          tooltip: 'HoloOcean Agent Control Panel',
        ),
        if (_showHoloOceanPanel)
          Positioned(
            top: 50,
            right: 0,
            child: Container(
              width: 384,
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width - 16,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                border: Border.all(color: const Color(0xFF475569)),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: HoloOceanPanelWidget(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTutorialButton(bool isSmall) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () {
            if (widget.onTutorialToggle != null) {
              widget.onTutorialToggle!(!widget.showTutorial);
            }
          },
          icon: Icon(Icons.help_outline_rounded, size: isSmall ? 16 : 20),
          color: widget.showTutorial ? Colors.white : const Color(0xFFCBD5E1),
          style: IconButton.styleFrom(
            backgroundColor: widget.showTutorial
                ? Colors.blue[600]
                : const Color(0xFF334155),
            padding: EdgeInsets.all(isSmall ? 4 : 8),
          ),
          tooltip: 'Interactive Tutorial',
        ),
        // Tutorial step indicator
        if (widget.showTutorial && widget.tutorialStep > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.blue[500],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${widget.tutorialStep}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        // First-time user indicator
        if (widget.isFirstTimeUser && !_hasSeenTutorial)
          Positioned(
            top: -4,
            right: -4,
            child: _PulsingDot(color: Colors.yellow[400]!, size: 8),
          ),
      ],
    );
  }

  Widget _buildSettingsButton(bool isSmall) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () {
            setState(() => _showSettings = !_showSettings);
            if (widget.onSettingsClick != null) {
              widget.onSettingsClick!();
            }
          },
          icon: Icon(Icons.settings_rounded, size: isSmall ? 16 : 20),
          color: const Color(0xFFCBD5E1),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF334155),
            padding: EdgeInsets.all(isSmall ? 4 : 8),
          ),
          tooltip: 'Settings',
        ),
        if (_showSettings)
          Positioned(
            top: 50,
            right: 0,
            child: _buildSettingsDropdown(),
          ),
      ],
    );
  }

  Widget _buildSettingsDropdown() {
    final dataSourceInfo = _getDataSourceDisplay();

    return Container(
      width: 256,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border.all(color: const Color(0xFF475569)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'System Settings',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE2E8F0),
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingRow('Data Source:', dataSourceInfo.text, dataSourceInfo.color),
          _buildSettingRow(
            'Connection:',
            widget.connectionStatus[0].toUpperCase() +
                widget.connectionStatus.substring(1),
            widget.connectionStatus == 'connected'
                ? Colors.green[400]!
                : widget.connectionStatus == 'connecting'
                    ? Colors.yellow[400]!
                    : Colors.red[400]!,
          ),
          if (widget.dataQuality != null) ...[
            _buildSettingRow(
              'Stations:',
              '${widget.dataQuality!.stations} Stations',
              const Color(0xFFCBD5E1),
            ),
            _buildSettingRow(
              'Measurements:',
              '${widget.dataQuality!.measurements} Measurements',
              const Color(0xFFCBD5E1),
            ),
            if (widget.dataQuality!.lastUpdate != null)
              _buildSettingRow(
                'Last Update:',
                DateFormat('HH:mm:ss').format(widget.dataQuality!.lastUpdate!),
                const Color(0xFFCBD5E1),
              ),
          ],
          const SizedBox(height: 12),
          Container(
            height: 1,
            color: const Color(0xFF334155),
          ),
          const SizedBox(height: 12),
          _buildQuickAction(
            Icons.explore_rounded,
            _showHoloOceanPanel ? 'Hide HoloOcean Control' : 'Show HoloOcean Control',
            () {
              setState(() {
                _showHoloOceanPanel = !_showHoloOceanPanel;
                _showSettings = false;
              });
            },
          ),
          _buildQuickAction(
            Icons.menu_book_rounded,
            'Start Tutorial',
            () {
              if (widget.onTutorialToggle != null) {
                widget.onTutorialToggle!(true);
              }
              setState(() => _showSettings = false);
            },
          ),
          _buildQuickAction(
            Icons.refresh_rounded,
            'Refresh Data',
            () {
              // Trigger refresh
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, color: valueColor),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Icon(icon, size: 12, color: const Color(0xFFCBD5E1)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadButton(bool isSmall) {
    final os = PlatformDetector.detectOS();
    final osName = PlatformDetector.getOSDisplayName(os);

    // Get appropriate icon based on OS
    IconData icon;
    switch (os) {
      case OperatingSystem.windows:
        icon = Icons.download_rounded;
        break;
      case OperatingSystem.macos:
        icon = Icons.apple;
        break;
      case OperatingSystem.linux:
        icon = Icons.download_rounded;
        break;
      case OperatingSystem.android:
        icon = Icons.android;
        break;
      case OperatingSystem.ios:
        icon = Icons.apple;
        break;
      case OperatingSystem.unknown:
        icon = Icons.download_rounded;
        break;
    }

    return ElevatedButton.icon(
      onPressed: () => _handleDownload(),
      icon: Icon(icon, size: isSmall ? 14 : 16),
      label: Text(
        isSmall ? 'Download' : 'Download App',
        style: TextStyle(
          fontSize: isSmall ? 10 : 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF22C6DA), // cyan gradient color
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 8 : 12,
          vertical: isSmall ? 6 : 8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        elevation: 2,
      ),
    );
  }

  Future<void> _handleDownload() async {
    final os = PlatformDetector.detectOS();

    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Preparing download...'),
            ],
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF334155),
        ),
      );
    }

    // Trigger download
    final result = await DownloadService.downloadInstallerForOS(os);

    // Show result
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.message ?? 'Download started successfully',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        // Show error dialog for iOS or unknown OS
        if (os == OperatingSystem.ios || os == OperatingSystem.unknown) {
          _showDownloadInfoDialog(result.errorMessage ?? result.message ?? 'Download not available');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      result.errorMessage ?? 'Download failed',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red[600],
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      }
    }
  }

  void _showDownloadInfoDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF60A5FA)),
            SizedBox(width: 12),
            Text(
              'Download Information',
              style: TextStyle(color: Color(0xFFE2E8F0)),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF60A5FA)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlueMvmtLogo(bool isSmall) {
  return Image.asset(
    'icons/powered_by_bluemvmt.png',
    height: isSmall ? 24 : 32,
    errorBuilder: (context, error, stackTrace) {
      // Fallback when image is missing
      return Container(
        height: isSmall ? 24 : 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          'Powered by BlueMvmt',
          style: TextStyle(
            fontSize: isSmall ? 10 : 12,
            color: const Color(0xFF64748B),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    },
  );
}
}

// ============================================================================
// MODELS
// ============================================================================

class DataSourceInfo {
  final String text;
  final Color color;
  final IconData icon;

  DataSourceInfo({
    required this.text,
    required this.color,
    required this.icon,
  });
}

class DataQuality {
  final int stations;
  final int measurements;
  final DateTime? lastUpdate;

  DataQuality({
    required this.stations,
    required this.measurements,
    this.lastUpdate,
  });
}

// ============================================================================
// ANIMATED COMPONENTS
// ============================================================================

class _PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const _PulsingDot({required this.color, this.size = 8});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.5 + (_controller.value * 0.5)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

class _PingingDot extends StatefulWidget {
  final Color color;
  final double size;

  const _PingingDot({required this.color, this.size = 8});

  @override
  State<_PingingDot> createState() => _PingingDotState();
}

class _PingingDotState extends State<_PingingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(1 - _controller.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}