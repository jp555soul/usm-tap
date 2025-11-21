import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import '../../../data/models/chat_message.dart';

class OutputModuleWidget extends StatefulWidget {
  final List<ChatMessage> chatMessages;
  final List<Map<String, dynamic>> timeSeriesData;
  final int currentFrame;
  final String selectedParameter;
  final double selectedDepth;
  final bool showCharts;
  final bool showTables;
  final bool showScrollButton;
  final int maxResponses;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;
  final Function(ChatMessage)? onExportResponse;
  final Function(ChatMessage)? onCopyResponse;
  final Function(ChatMessage)? onShareResponse;
  final bool isTyping;
  final String typingMessage;
  final Map<String, dynamic> currentsGeoJSON;

  const OutputModuleWidget({
    Key? key,
    this.chatMessages = const [],
    this.timeSeriesData = const [],
    this.currentFrame = 0,
    this.selectedParameter = 'Current Speed',
    this.selectedDepth = 0,
    this.showCharts = true,
    this.showTables = true,
    this.showScrollButton = true,
    this.maxResponses = 50,
    this.isCollapsed = true,
    this.onToggleCollapse,
    this.onExportResponse,
    this.onCopyResponse,
    this.onShareResponse,
    this.isTyping = false,
    this.typingMessage = 'Processing...',
    this.currentsGeoJSON = const {},
  }) : super(key: key);

  @override
  State<OutputModuleWidget> createState() => _OutputModuleWidgetState();
}

class _OutputModuleWidgetState extends State<OutputModuleWidget> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;
  String? _expandedResponseId;
  String _responseFilter = 'api';
  ApiMetrics _apiMetrics = ApiMetrics(
    totalApiResponses: 0,
    totalLocalResponses: 0,
    successRate: 0,
    avgResponseTime: 0,
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void didUpdateWidget(OutputModuleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Calculate metrics when messages change
    if (oldWidget.chatMessages.length != widget.chatMessages.length) {
      _calculateApiMetrics();
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    
    final isNearBottom = _scrollController.position.maxScrollExtent - 
        _scrollController.position.pixels < 100;
    
    if (_showScrollToBottom != !isNearBottom) {
      setState(() {
        _showScrollToBottom = !isNearBottom;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _calculateApiMetrics() {
    final aiResponses = widget.chatMessages.where((msg) => !msg.isUser).toList();
    final apiResponses = aiResponses.where((msg) => msg.source == 'api').toList();
    final localResponses = aiResponses.where((msg) => msg.source == 'local').toList();
    
    setState(() {
      _apiMetrics = ApiMetrics(
        totalApiResponses: apiResponses.length,
        totalLocalResponses: localResponses.length,
        successRate: aiResponses.isNotEmpty 
            ? (apiResponses.length / aiResponses.length * 100)
            : 0,
        avgResponseTime: 0,
      );
    });
  }

  List<ChatMessage> _getFilteredResponses() {
    final aiResponses = widget.chatMessages.where((msg) => !msg.isUser).toList();
    
    switch (_responseFilter) {
      case 'api':
        return aiResponses.where((msg) => msg.source == 'api').toList();
      case 'local':
        return aiResponses.where((msg) => msg.source == 'local').toList();
      case 'charts':
        return aiResponses.where((msg) =>
          msg.content.toLowerCase().contains('chart') ||
          msg.content.toLowerCase().contains('trend') ||
          msg.content.toLowerCase().contains('analysis')
        ).toList();
      case 'tables':
        return aiResponses.where((msg) =>
          msg.content.toLowerCase().contains('data') ||
          msg.content.toLowerCase().contains('measurement') ||
          msg.content.toLowerCase().contains('temperature')
        ).toList();
      case 'text':
        return aiResponses.where((msg) =>
          !msg.content.toLowerCase().contains('chart') &&
          !msg.content.toLowerCase().contains('data') &&
          !msg.content.toLowerCase().contains('trend')
        ).toList();
      default:
        return aiResponses;
    }
  }

  ResponseType _getResponseType(String content, String source) {
    final lowerContent = content.toLowerCase();
    
    if (source == 'api') {
      return ResponseType(
        type: 'api',
        icon: Icons.dns,
        color: Colors.green.shade400,
        bgColor: Colors.green.shade900.withOpacity(0.2),
        borderColor: Colors.green.shade500.withOpacity(0.3),
      );
    }
    if (source == 'local') {
      return ResponseType(
        type: 'local',
        icon: Icons.wifi_off,
        color: Colors.yellow.shade400,
        bgColor: Colors.yellow.shade900.withOpacity(0.2),
        borderColor: Colors.yellow.shade500.withOpacity(0.3),
      );
    }
    if (source == 'error') {
      return ResponseType(
        type: 'error',
        icon: Icons.warning,
        color: Colors.red.shade400,
        bgColor: Colors.red.shade900.withOpacity(0.2),
        borderColor: Colors.red.shade500.withOpacity(0.3),
      );
    }
    
    if (lowerContent.contains('chart') || lowerContent.contains('trend') || lowerContent.contains('ssh')) {
      return ResponseType(
        type: 'chart',
        icon: Icons.bar_chart,
        color: Colors.cyan.shade400,
        bgColor: Colors.cyan.shade900.withOpacity(0.2),
        borderColor: Colors.cyan.shade500.withOpacity(0.3),
      );
    }
    if (lowerContent.contains('data') || lowerContent.contains('temperature') || lowerContent.contains('environmental')) {
      return ResponseType(
        type: 'table',
        icon: Icons.table_chart,
        color: Colors.teal.shade400,
        bgColor: Colors.teal.shade900.withOpacity(0.2),
        borderColor: Colors.teal.shade500.withOpacity(0.3),
      );
    }
    if (lowerContent.contains('analysis') || lowerContent.contains('forecast') || lowerContent.contains('predict')) {
      return ResponseType(
        type: 'analysis',
        icon: Icons.trending_up,
        color: Colors.purple.shade400,
        bgColor: Colors.purple.shade900.withOpacity(0.2),
        borderColor: Colors.purple.shade500.withOpacity(0.3),
      );
    }
    
    return ResponseType(
      type: 'text',
      icon: Icons.description,
      color: Colors.grey.shade400,
      bgColor: Colors.grey.shade700.withOpacity(0.2),
      borderColor: Colors.grey.shade500.withOpacity(0.3),
    );
  }

  Widget? _generateResponseChart(ChatMessage response) {
    final lowerContent = response.content.toLowerCase();
    
    if (lowerContent.contains('current') || lowerContent.contains('flow')) {
      final chartData = widget.timeSeriesData.length > 12 
          ? widget.timeSeriesData.sublist(widget.timeSeriesData.length - 12)
          : widget.timeSeriesData;
      
      final spots = chartData.asMap().entries.map((e) {
        final value = (e.value['currentSpeed'] as num?)?.toDouble() ?? 0;
        return FlSpot(e.key.toDouble(), value);
      }).toList();

      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade600.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Speed Analysis',
              style: TextStyle(fontSize: 12, color: Colors.white60),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
                      isCurved: true,
                      color: const Color(0xFF22d3ee),
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    if (lowerContent.contains('ssh') || lowerContent.contains('elevation')) {
      final chartData = widget.timeSeriesData.length > 8
          ? widget.timeSeriesData.sublist(widget.timeSeriesData.length - 8)
          : widget.timeSeriesData;
      
      final barGroups = chartData.asMap().entries.map((e) {
        final value = (e.value['ssh'] as num?)?.toDouble() ?? 0;
        return BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: value,
              color: const Color(0xFF10b981).withOpacity(0.7),
              width: 8,
            ),
          ],
        );
      }).toList();

      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade600.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Surface Elevation (SSH) Trends',
              style: TextStyle(fontSize: 12, color: Colors.white60),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups.isEmpty 
                      ? [BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 0)])]
                      : barGroups,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return null;
  }

  Widget? _generateResponseTable(ChatMessage response) {
    final lowerContent = response.content.toLowerCase();
    
    if ((lowerContent.contains('data') || 
         lowerContent.contains('temperature') || 
         lowerContent.contains('environmental')) && 
        widget.timeSeriesData.isNotEmpty) {
      
      final tableData = widget.timeSeriesData.length > 3
          ? widget.timeSeriesData.sublist(widget.timeSeriesData.length - 3)
          : widget.timeSeriesData;

      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade600.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Environmental Data Table',
              style: TextStyle(fontSize: 12, color: Colors.white60),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                dataTextStyle: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
                columns: const [
                  DataColumn(label: Text('Time')),
                  DataColumn(label: Text('Temp (°F)')),
                  DataColumn(label: Text('Current (m/s)')),
                  DataColumn(label: Text('SSH (m)')),
                ],
                rows: tableData.map((row) {
                  return DataRow(cells: [
                    DataCell(Text(row['time']?.toString() ?? 'N/A')),
                    DataCell(Text(
                      row['temperature'] != null 
                          ? (row['temperature'] as num).toStringAsFixed(1)
                          : 'N/A'
                    )),
                    DataCell(Text(
                      row['currentSpeed'] != null
                          ? (row['currentSpeed'] as num).toStringAsFixed(2)
                          : 'N/A'
                    )),
                    DataCell(Text(
                      row['ssh'] != null
                          ? (row['ssh'] as num).toStringAsFixed(2)
                          : 'N/A'
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      );
    }

    return null;
  }

  Future<void> _handleCopyResponse(ChatMessage response) async {
    try {
      await Clipboard.setData(ClipboardData(text: response.content));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Response copied to clipboard')),
        );
      }
    } catch (e) {
    }
  }

  Future<void> _handleExportResponse(ChatMessage response, int index) async {
    final responseType = _getResponseType(response.content, response.source);
    final exportData = {
      'id': response.id,
      'timestamp': response.timestamp.toIso8601String(),
      'content': response.content,
      'source': response.source,
      'type': responseType.type,
      'frame': widget.currentFrame,
      'parameter': widget.selectedParameter,
      'depth': widget.selectedDepth,
      'retryAttempt': response.retryAttempt,
    };

    try {
      final jsonStr = const JsonEncoder.withIndent('  ').convert(exportData);
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/ocean_analysis_response_${index + 1}_${response.source}.json'
      );
      await file.writeAsString(jsonStr);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Response exported to ${file.path}')),
        );
      }
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredResponses = _getFilteredResponses();
    final displayResponses = filteredResponses.length > widget.maxResponses
        ? filteredResponses.sublist(filteredResponses.length - widget.maxResponses)
        : filteredResponses;

    return Container(
      child: Column(
        children: [
          // Header
          Container(
            padding: widget.isCollapsed 
                ? const EdgeInsets.all(4)
                : const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: widget.isCollapsed ? null : LinearGradient(
                colors: [
                  Colors.yellow.shade900.withOpacity(0.2),
                  Colors.orange.shade900.withOpacity(0.2),
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.yellow.shade500.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.analytics,
                          size: widget.isCollapsed ? 12 : 20,
                          color: Colors.yellow.shade300,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.isCollapsed ? 'Analysis' : 'Analysis Output Module',
                          style: TextStyle(
                            fontSize: widget.isCollapsed ? 12 : 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.yellow.shade300,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'API: ${_apiMetrics.totalApiResponses} • Showing: ${filteredResponses.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (!widget.isCollapsed) ...[
                      Row(
                        children: [
                          Icon(Icons.public, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            '${_apiMetrics.successRate.toStringAsFixed(1)}% API',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _responseFilter,
                        dropdownColor: Colors.grey.shade700,
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                        underline: Container(),
                        items: const [
                          DropdownMenuItem(value: 'api', child: Text('API Responses')),
                          DropdownMenuItem(value: 'all', child: Text('All Responses')),
                          DropdownMenuItem(value: 'charts', child: Text('Charts & Trends')),
                          DropdownMenuItem(value: 'tables', child: Text('Data & Tables')),
                          DropdownMenuItem(value: 'text', child: Text('Text Analysis')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _responseFilter = value ?? 'api';
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton(
                      icon: Icon(
                        widget.isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                        size: 16,
                      ),
                      color: Colors.grey.shade400,
                      onPressed: widget.onToggleCollapse,
                      tooltip: widget.isCollapsed ? 'Expand Panel' : 'Collapse Panel',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Response History
          Expanded(
            child: Container(
              padding: widget.isCollapsed 
                  ? const EdgeInsets.all(4)
                  : const EdgeInsets.all(16),
              child: Stack(
                children: [
                  ListView.builder(
                    controller: _scrollController,
                    itemCount: displayResponses.length + (widget.isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == displayResponses.length && widget.isTyping) {
                        return _buildTypingIndicator();
                      }

                      final response = displayResponses[index];
                      final responseType = _getResponseType(response.content, response.source);
                      final isExpanded = _expandedResponseId == response.id;

                      return _buildResponseItem(
                        response,
                        index,
                        responseType,
                        isExpanded,
                      );
                    },
                  ),
                  
                  // Scroll to bottom button
                  if (!widget.isCollapsed && 
                      widget.showScrollButton && 
                      _showScrollToBottom)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: FloatingActionButton(
                        mini: true,
                        backgroundColor: Colors.yellow.shade500,
                        onPressed: _scrollToBottom,
                        child: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseItem(
    ChatMessage response,
    int index,
    ResponseType responseType,
    bool isExpanded,
  ) {
    return Container(
      margin: EdgeInsets.only(
        bottom: widget.isCollapsed ? 4 : 16,
      ),
      padding: EdgeInsets.only(
        bottom: widget.isCollapsed ? 4 : 12,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade600.withOpacity(0.3),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Response Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: responseType.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!widget.isCollapsed)
                      Icon(
                        responseType.icon,
                        size: 16,
                        color: responseType.color,
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.isCollapsed
                            ? '#${index + 1}'
                            : 'Response #${index + 1} • ${responseType.type[0].toUpperCase()}${responseType.type.substring(1)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: responseType.color,
                        ),
                      ),
                    ),
                    if (!widget.isCollapsed && response.source.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: responseType.bgColor,
                          border: Border.all(color: responseType.borderColor),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          response.source.toUpperCase(),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    if (!widget.isCollapsed)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          TimeOfDay.fromDateTime(response.timestamp).format(context),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!widget.isCollapsed)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy, size: 14),
                      color: Colors.grey.shade400,
                      onPressed: () => _handleCopyResponse(response),
                      tooltip: 'Copy Response',
                    ),
                    IconButton(
                      icon: const Icon(Icons.download, size: 14),
                      color: Colors.grey.shade400,
                      onPressed: () => _handleExportResponse(response, index),
                      tooltip: 'Export Response',
                    ),
                    IconButton(
                      icon: Icon(
                        isExpanded ? Icons.fullscreen_exit : Icons.fullscreen,
                        size: 14,
                      ),
                      color: Colors.grey.shade400,
                      onPressed: () {
                        setState(() {
                          _expandedResponseId = isExpanded ? null : response.id;
                        });
                      },
                      tooltip: isExpanded ? 'Collapse' : 'Expand',
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Response Content
          Container(
            padding: const EdgeInsets.all(8),
            child: MarkdownBody(
              data: response.content,
              extensionSet: md.ExtensionSet.gitHubFlavored,
              styleSheet: MarkdownStyleSheet(
                h1: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.yellow.shade300,
                ),
                h2: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.yellow.shade400,
                ),
                h3: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
                p: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.5,
                ),
                listBullet: const TextStyle(color: Colors.white70),
                code: TextStyle(
                  backgroundColor: Colors.grey.shade600.withOpacity(0.5),
                  color: Colors.cyan.shade300,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                codeblockDecoration: BoxDecoration(
                  color: Colors.grey.shade800.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.shade600.withOpacity(0.3),
                  ),
                ),
                blockquote: TextStyle(
                  color: Colors.grey.shade300,
                  fontStyle: FontStyle.italic,
                ),
                blockquoteDecoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: Colors.yellow.shade400.withOpacity(0.5),
                      width: 4,
                    ),
                  ),
                  color: Colors.grey.shade700.withOpacity(0.3),
                ),
                tableHead: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
                tableBody: const TextStyle(color: Colors.white60),
                a: TextStyle(
                  color: Colors.cyan.shade400,
                  decoration: TextDecoration.underline,
                ),
                strong: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.yellow.shade300,
                ),
                em: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.white70,
                ),
              ),
            ),
          ),

          // Chart
          if (!widget.isCollapsed && 
              widget.showCharts && 
              (isExpanded || responseType.type == 'chart'))
            _generateResponseChart(response) ?? const SizedBox.shrink(),

          // Table
          if (!widget.isCollapsed && 
              widget.showTables && 
              (isExpanded || responseType.type == 'table'))
            _generateResponseTable(response) ?? const SizedBox.shrink(),

          // Metadata
          if (!widget.isCollapsed && isExpanded)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade800.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Response Metadata',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _buildMetadataItem('Source', response.source, responseType.color),
                      _buildMetadataItem('Parameter', widget.selectedParameter, Colors.white70),
                      _buildMetadataItem('Depth', '${widget.selectedDepth}m', Colors.white70),
                      _buildMetadataItem('Frame', '${widget.currentFrame + 1}', Colors.white70),
                      if (response.retryAttempt > 0)
                        _buildMetadataItem('Retries', '${response.retryAttempt}', Colors.yellow.shade400),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetadataItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 12, color: color),
        ),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          ...List.generate(3, (index) {
            return Container(
              margin: EdgeInsets.only(right: 4, left: index == 0 ? 0 : 0),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                shape: BoxShape.circle,
              ),
            );
          }),
          const SizedBox(width: 8),
          Text(
            widget.typingMessage,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}

// Supporting classes
class ApiMetrics {
  final int totalApiResponses;
  final int totalLocalResponses;
  final double successRate;
  final double avgResponseTime;

  ApiMetrics({
    required this.totalApiResponses,
    required this.totalLocalResponses,
    required this.successRate,
    required this.avgResponseTime,
  });
}

class ResponseType {
  final String type;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;

  ResponseType({
    required this.type,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
  });
}