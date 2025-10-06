import 'package:flutter/material.dart';

/// Connection status indicator for HoloOcean WebSocket
/// Shows visual status with color coding and icons
class ConnectionStatusWidget extends StatelessWidget {
  final bool isConnected;
  final bool isConnecting;
  final int reconnectAttempts;
  final String? error;

  const ConnectionStatusWidget({
    Key? key,
    required this.isConnected,
    required this.isConnecting,
    this.reconnectAttempts = 0,
    this.error,
  }) : super(key: key);

  StatusInfo _getStatusInfo() {
    if (error != null) {
      return StatusInfo(
        status: 'error',
        text: 'Connection Error',
        color: Colors.red.shade400,
        bgColor: Colors.red.shade900.withOpacity(0.2),
        borderColor: Colors.red.shade700.withOpacity(0.3),
        icon: Icons.error_outline,
      );
    }

    if (isConnecting) {
      return StatusInfo(
        status: 'connecting',
        text: reconnectAttempts > 0 
            ? 'Reconnecting ($reconnectAttempts)' 
            : 'Connecting',
        color: Colors.yellow.shade400,
        bgColor: Colors.yellow.shade900.withOpacity(0.2),
        borderColor: Colors.yellow.shade700.withOpacity(0.3),
        icon: Icons.refresh,
      );
    }

    if (isConnected) {
      return StatusInfo(
        status: 'connected',
        text: 'Connected',
        color: Colors.green.shade400,
        bgColor: Colors.green.shade900.withOpacity(0.2),
        borderColor: Colors.green.shade700.withOpacity(0.3),
        icon: Icons.check_circle_outline,
      );
    }

    return StatusInfo(
      status: 'disconnected',
      text: 'Disconnected',
      color: Colors.grey.shade400,
      bgColor: Colors.grey.shade900.withOpacity(0.2),
      borderColor: Colors.grey.shade700.withOpacity(0.3),
      icon: Icons.close,
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusInfo = _getStatusInfo();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusInfo.bgColor,
            border: Border.all(color: statusInfo.borderColor),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                statusInfo.icon,
                size: 16,
                color: statusInfo.color,
              ),
              const SizedBox(width: 8),
              Text(
                statusInfo.text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: statusInfo.color,
                ),
              ),
            ],
          ),
        ),

        // Connection Pulse Indicator
        if (isConnected) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 12,
            height: 12,
            child: Stack(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green.shade500,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green.shade500.withOpacity(0.75),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Error Tooltip
        if (error != null) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: error!,
            child: Icon(
              Icons.info_outline,
              size: 16,
              color: Colors.red.shade400,
            ),
          ),
        ],
      ],
    );
  }
}

class StatusInfo {
  final String status;
  final String text;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final IconData icon;

  StatusInfo({
    required this.status,
    required this.text,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.icon,
  });
}