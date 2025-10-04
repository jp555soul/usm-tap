import 'package:flutter/material.dart';
import 'dart:math' as math;

// ============================================================================
// STREAMING PROGRESS SCREEN
// ============================================================================

class StreamingProgressScreen extends StatelessWidget {
  final StreamingProgress progress;
  final List<String> errors;
  final VoidCallback? onCancel;
  final DataQuality? dataQuality;

  const StreamingProgressScreen({
    Key? key,
    required this.progress,
    this.errors = const [],
    this.onCancel,
    this.dataQuality,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentFileProgress = progress.estimatedTotalRows != null
        ? math.min(100.0, (progress.processedRows / progress.estimatedTotalRows!) * 100)
        : 0.0;

    final overallProgress = progress.totalFiles > 0
        ? math.min(
            100.0,
            ((progress.currentFileIndex + (currentFileProgress / 100)) / progress.totalFiles) * 100)
        : currentFileProgress;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // slate-900
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 672), // max-w-2xl
            child: Column(
              children: [
                // Header
                _buildHeader(),
                const SizedBox(height: 32),

                // Main Progress Card
                _buildMainProgressCard(currentFileProgress, overallProgress),
                const SizedBox(height: 24),

                // Error Messages
                if (errors.isNotEmpty || progress.errors.isNotEmpty) ...[
                  _buildErrorMessages(),
                  const SizedBox(height: 24),
                ],

                // Action Buttons
                _buildActionButtons(),
                const SizedBox(height: 32),

                // USM/CubeAI Branding
                _buildBranding(),

                // Technical Details
                if (progress.totalProcessedRows > 0) ...[
                  const SizedBox(height: 32),
                  _buildTechnicalDetails(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            children: [
              _PingingCircle(size: 64, color: Colors.blue[400]!.withOpacity(0.3)),
              _PulsingCircle(size: 56, color: Colors.blue[400]!.withOpacity(0.5)),
              Center(
                child: _PulsingIcon(
                  icon: Icons.storage_rounded,
                  color: Colors.blue[400]!,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Streaming Ocean Data',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.blue[300],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _getStatusMessage(),
          style: const TextStyle(
            fontSize: 18,
            color: Color(0xFF94A3B8), // slate-400
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMainProgressCard(double currentFileProgress, double overallProgress) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.8), // slate-800/80
        border: Border.all(color: const Color(0xFF334155).withOpacity(0.5)), // slate-700/50
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          // File Progress Section
          if (progress.currentFile != null) ...[
            _buildFileProgress(currentFileProgress),
            const SizedBox(height: 24),
          ],

          // Overall Progress Section
          _buildOverallProgress(overallProgress),

          // Data Quality Preview
          if (dataQuality != null && progress.totalProcessedRows > 0) ...[
            const SizedBox(height: 24),
            _buildDataQuality(),
          ],
        ],
      ),
    );
  }

  Widget _buildFileProgress(double currentFileProgress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.description_rounded, size: 16, color: Colors.blue[400]),
                const SizedBox(width: 8),
                Text(
                  _getFileProgressText(),
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1), // slate-300
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Text(
              '${_formatNumber(progress.processedRows)} rows',
              style: TextStyle(
                color: Colors.blue[400],
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '📄 ${progress.currentFile}',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF94A3B8), // slate-400
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        // File Progress Bar
        SizedBox(
          height: 8,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF334155), // slate-700
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: currentFileProgress / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue[400],
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
              ),
              if (currentFileProgress > 0)
                Positioned(
                  right: 4,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: _PulsingIndicator(),
                  ),
                ),
            ],
          ),
        ),
        if (currentFileProgress > 0) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${currentFileProgress.toStringAsFixed(1)}% of current file',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOverallProgress(double overallProgress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, size: 16, color: Colors.blue[400]),
                const SizedBox(width: 8),
                const Text(
                  'Overall Progress',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              '${_formatNumber(progress.totalProcessedRows)} total rows',
              style: TextStyle(
                color: Colors.cyan[400],
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Overall Progress Bar
        SizedBox(
          height: 16,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF334155), // slate-700
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: overallProgress / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue[400],
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
              ),
              _AnimatedGradient(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${overallProgress.toStringAsFixed(1)}% complete',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
              ),
            ),
            if (progress.estimatedTotalRows != null)
              Text(
                '~${_formatNumber(progress.estimatedTotalRows!)} estimated rows',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF94A3B8),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDataQuality() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF334155), width: 0.5), // slate-700/50
        ),
      ),
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Data Quality',
                style: TextStyle(color: Color(0xFFCBD5E1)), // slate-300
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dataQuality!.score >= 75
                          ? Colors.green[400]
                          : dataQuality!.score >= 50
                              ? Colors.yellow[400]
                              : Colors.red[400],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dataQuality!.status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${dataQuality!.stations} stations • ${_formatNumber(dataQuality!.measurements)} measurements',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessages() {
    final allErrors = [...errors, ...progress.errors];

    return Container(
      decoration: BoxDecoration(
        color: Colors.red.shade900.withOpacity(0.2),
        border: Border.all(color: Colors.red.shade500.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cancel_rounded, size: 20, color: Colors.red[400]),
              const SizedBox(width: 8),
              Text(
                'Processing Warnings',
                style: TextStyle(
                  color: Colors.red[300],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...allErrors.map((error) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $error',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red[200],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (progress.isComplete) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, size: 20, color: Colors.green[400]),
          const SizedBox(width: 8),
          Text(
            'Ready to explore!',
            style: TextStyle(
              color: Colors.green[400],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    if (onCancel != null) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.cancel_rounded, size: 16),
          label: const Text('Cancel'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF334155), // slate-700
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBranding() {
    return Column(
      children: [
        const Text(
          'University of Southern Mississippi',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 4),
        const Text(
          'Roger F. Wicker Center for Ocean Enterprise',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Color(0xFF64748B),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Powered by CubeAI',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Color(0xFF64748B),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTechnicalDetails() {
    return Theme(
      data: ThemeData(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text(
          'Technical Details',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF94A3B8),
          ),
          textAlign: TextAlign.center,
        ),
        children: [
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTechnicalDetailRow(
                  'Files',
                  '${progress.currentFileIndex + 1}/${progress.totalFiles}',
                ),
                _buildTechnicalDetailRow(
                  'Rows Processed',
                  progress.totalProcessedRows.toString(),
                ),
                _buildTechnicalDetailRow(
                  'Current File Rows',
                  progress.processedRows.toString(),
                ),
                if (progress.estimatedTotalRows != null)
                  _buildTechnicalDetailRow(
                    'Estimated Total',
                    progress.estimatedTotalRows.toString(),
                  ),
                _buildTechnicalDetailRow(
                  'Status',
                  progress.isComplete ? 'Complete' : 'Processing',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }

  String _getStatusMessage() {
    if (progress.isComplete) return 'Streaming complete! Loading final data...';
    if (progress.currentFile != null) return 'Processing ${progress.currentFile}...';
    return 'Initializing data streaming...';
  }

  String _getFileProgressText() {
    if (progress.totalFiles > 1) {
      return 'File ${progress.currentFileIndex + 1} of ${progress.totalFiles}';
    }
    return 'Processing file';
  }

  String _formatNumber(int num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toString();
  }
}

// ============================================================================
// STREAMING PROGRESS MODEL
// ============================================================================

class StreamingProgress {
  final String? currentFile;
  final int currentFileIndex;
  final int totalFiles;
  final int processedRows;
  final int totalProcessedRows;
  final int? estimatedTotalRows;
  final bool isComplete;
  final List<String> errors;

  StreamingProgress({
    this.currentFile,
    required this.currentFileIndex,
    required this.totalFiles,
    required this.processedRows,
    required this.totalProcessedRows,
    this.estimatedTotalRows,
    required this.isComplete,
    this.errors = const [],
  });
}

// ============================================================================
// DATA QUALITY MODEL
// ============================================================================

class DataQuality {
  final int score;
  final String status;
  final int stations;
  final int measurements;

  DataQuality({
    required this.score,
    required this.status,
    required this.stations,
    required this.measurements,
  });
}

// ============================================================================
// ANIMATED COMPONENTS
// ============================================================================

class _PingingCircle extends StatefulWidget {
  final double size;
  final Color color;

  const _PingingCircle({required this.size, required this.color});

  @override
  State<_PingingCircle> createState() => _PingingCircleState();
}

class _PingingCircleState extends State<_PingingCircle>
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
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.color.withOpacity(1 - _controller.value),
              width: 4,
            ),
          ),
        );
      },
    );
  }
}

class _PulsingCircle extends StatefulWidget {
  final double size;
  final Color color;

  const _PulsingCircle({required this.size, required this.color});

  @override
  State<_PulsingCircle> createState() => _PulsingCircleState();
}

class _PulsingCircleState extends State<_PulsingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
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
        return Opacity(
          opacity: 0.3 + (_controller.value * 0.7),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _PulsingIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
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
        return Opacity(
          opacity: 0.4 + (_controller.value * 0.6),
          child: Icon(widget.icon, color: widget.color, size: widget.size),
        );
      },
    );
  }
}

class _PulsingIndicator extends StatefulWidget {
  @override
  State<_PulsingIndicator> createState() => _PulsingIndicatorState();
}

class _PulsingIndicatorState extends State<_PulsingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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
        return Opacity(opacity: 0.3 + (_controller.value * 0.7), child: child);
      },
      child: Container(color: Colors.transparent),
    );
  }
}

class _AnimatedGradient extends StatefulWidget {
  @override
  State<_AnimatedGradient> createState() => _AnimatedGradientState();
}

class _AnimatedGradientState extends State<_AnimatedGradient>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
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
        return Opacity(
          opacity: 0.3 + (_controller.value * 0.4),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.1),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(9999),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// USAGE EXAMPLE
// ============================================================================

/*
StreamingProgressScreen(
  progress: StreamingProgress(
    currentFile: 'ocean_data_2024_01.csv',
    currentFileIndex: 2,
    totalFiles: 5,
    processedRows: 15000,
    totalProcessedRows: 45000,
    estimatedTotalRows: 100000,
    isComplete: false,
    errors: ['Missing data in row 1234'],
  ),
  dataQuality: DataQuality(
    score: 85,
    status: 'Excellent',
    stations: 42,
    measurements: 125000,
  ),
  errors: ['Warning: Some coordinates are out of range'],
  onCancel: () {
    // Cancel streaming
  },
)
*/