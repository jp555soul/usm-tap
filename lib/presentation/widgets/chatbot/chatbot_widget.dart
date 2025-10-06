import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatbotWidget extends StatefulWidget {
  final List<Map<String, dynamic>> timeSeriesData;
  final List<dynamic> data;
  final String dataSource;
  final double selectedDepth;
  final List<double> availableDepths;
  final String selectedArea;
  final String selectedModel;
  final String selectedParameter;
  final double playbackSpeed;
  final int currentFrame;
  final Map<String, double> holoOceanPOV;
  final Map<String, dynamic> envData;
  final String timeZone;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(ChatMessage)? onAddMessage;

  const ChatbotWidget({
    Key? key,
    this.timeSeriesData = const [],
    this.data = const [],
    this.dataSource = 'simulated',
    this.selectedDepth = 0,
    this.availableDepths = const [],
    this.selectedArea = '',
    this.selectedModel = 'NGOSF2',
    this.selectedParameter = 'Current Speed',
    this.playbackSpeed = 1,
    this.currentFrame = 0,
    this.holoOceanPOV = const {'x': 0, 'y': 0, 'depth': 0},
    this.envData = const {},
    this.timeZone = 'UTC',
    this.startDate,
    this.endDate,
    this.onAddMessage,
  }) : super(key: key);

  @override
  State<ChatbotWidget> createState() => _ChatbotWidgetState();
}

class _ChatbotWidgetState extends State<ChatbotWidget> {
  bool _chatOpen = false;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  
  final List<ChatMessage> _chatMessages = [];
  bool _isTyping = false;
  int _retryCount = 0;
  bool _isInitialized = false;
  String _threadId = '';
  
  ApiStatus _apiStatus = ApiStatus(
    connected: false,
    endpoint: '',
    timestamp: null,
    hasApiKey: false,
  );
  bool _showApiStatus = false;
  
  Timer? _apiStatusTimer;
  static const int maxRetries = 2;

  @override
  void initState() {
    super.initState();
    _threadId = _generateThreadId();
    _initializeChat();
    _checkAPIStatus();
    _apiStatusTimer = Timer.periodic(const Duration(minutes: 1), (_) => _checkAPIStatus());
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    _apiStatusTimer?.cancel();
    super.dispose();
  }

  String _generateThreadId() {
    return 'thread_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _initializeChat() async {
    if (_isInitialized || _chatMessages.isNotEmpty) return;
    
    try {
      final context = _buildContext();
      final welcomeResponse = await _getAIResponse(
        "Generate a welcome message for CubeAI oceanographic analysis platform",
        context,
      );
      
      if (welcomeResponse != null && !welcomeResponse.contains('[Local Response')) {
        _addAIResponse(welcomeResponse, 'api');
      } else {
        throw Exception('API not available');
      }
    } catch (error) {
      debugPrint('Failed to get API welcome message: $error');
      _addAIResponse(
        "Unable to connect to CubeAI services. Please check your connection and try again.",
        'error',
      );
      setState(() {
        _apiStatus = _apiStatus.copyWith(connected: false);
      });
    }
    
    setState(() {
      _isInitialized = true;
    });
  }

  Future<void> _checkAPIStatus() async {
    try {
      final status = await _getAPIStatus();
      if (mounted) {
        setState(() {
          _apiStatus = status;
        });
      }
    } catch (error) {
      debugPrint('Failed to check API status: $error');
      if (mounted) {
        setState(() {
          _apiStatus = _apiStatus.copyWith(connected: false);
        });
      }
    }
  }

  Map<String, dynamic> _buildContext() {
    return {
      'currentData': widget.timeSeriesData.isNotEmpty 
          ? widget.timeSeriesData.last 
          : null,
      'timeSeriesData': widget.timeSeriesData,
      'dataSource': widget.dataSource,
      'selectedDepth': widget.selectedDepth,
      'selectedModel': widget.selectedModel,
      'selectedParameter': widget.selectedParameter,
      'selectedArea': widget.selectedArea,
      'playbackSpeed': widget.playbackSpeed,
      'holoOceanPOV': widget.holoOceanPOV,
      'currentFrame': widget.currentFrame,
      'totalFrames': widget.data.length > 0 ? widget.data.length : 24,
      'startDate': widget.startDate?.toIso8601String(),
      'endDate': widget.endDate?.toIso8601String(),
      'envData': widget.envData,
    };
  }

  void _addUserMessage(String content) {
    final message = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      content: content,
      isUser: true,
      source: 'user',
      timestamp: DateTime.now(),
      retryAttempt: 0,
    );
    
    setState(() {
      _chatMessages.add(message);
    });
    
    _scrollToBottom();
  }

  void _addAIResponse(String content, String source, {int retryAttempt = 0}) {
    final message = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      content: content,
      isUser: false,
      source: source,
      timestamp: DateTime.now(),
      retryAttempt: retryAttempt,
    );
    
    setState(() {
      _chatMessages.add(message);
    });
    
    widget.onAddMessage?.call(message);
    _scrollToBottom();
  }

  void _startTyping() {
    setState(() {
      _isTyping = true;
    });
  }

  void _stopTyping() {
    setState(() {
      _isTyping = false;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_inputController.text.trim().isEmpty) return;
    
    final currentInput = _inputController.text;
    _addUserMessage(currentInput);
    _inputController.clear();
    _startTyping();
    setState(() {
      _retryCount = 0;
    });

    try {
      await _processAIResponse(currentInput);
    } catch (error) {
      debugPrint('Failed to process AI response: $error');
      _addAIResponse(
        'Sorry, I encountered an error processing your request. Please try again.',
        'error',
      );
    } finally {
      _stopTyping();
    }
  }

  Future<void> _processAIResponse(String message, [int retryAttempt = 0]) async {
    try {
      final context = _buildContext();
      final aiResponse = await _getAIResponse(message, context);
      
      if (aiResponse == null || aiResponse.contains('[Local Response')) {
        throw Exception('API not available');
      }
      
      _addAIResponse(aiResponse, 'api', retryAttempt: retryAttempt);
      setState(() {
        _retryCount = 0;
        _apiStatus = _apiStatus.copyWith(
          connected: true,
          timestamp: DateTime.now(),
        );
      });
    } catch (error) {
      debugPrint('AI response attempt ${retryAttempt + 1} failed: $error');
      
      if (retryAttempt < maxRetries) {
        setState(() {
          _retryCount = retryAttempt + 1;
        });
        
        final delay = Duration(milliseconds: (1 << retryAttempt) * 1000);
        await Future.delayed(delay);
        
        if (mounted) {
          await _processAIResponse(message, retryAttempt + 1);
        }
      } else {
        _addAIResponse(
          'Unable to connect to CubeAI services. Please check your connection and try again.',
          'error',
        );
        setState(() {
          _apiStatus = _apiStatus.copyWith(connected: false);
        });
      }
    }
  }

  void _retryLastMessage() {
    final lastUserMessage = _chatMessages.reversed
        .firstWhere((msg) => msg.isUser, orElse: () => ChatMessage.empty());
    
    if (lastUserMessage.id.isNotEmpty) {
      _startTyping();
      _processAIResponse(lastUserMessage.content).then((_) => _stopTyping());
    }
  }

  void _handleKeyPress(RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !event.isShiftPressed) {
      _sendMessage();
    }
  }

  String _getMessageStyle(ChatMessage msg) {
    if (msg.isUser) return 'user';
    return msg.source;
  }

  SourceIndicator _getSourceIndicator(String source) {
    switch (source) {
      case 'api':
        return SourceIndicator(
          icon: Icons.wifi,
          color: Colors.green.shade400,
          label: 'AI API',
        );
      case 'error':
        return SourceIndicator(
          icon: Icons.warning,
          color: Colors.red.shade400,
          label: 'Error',
        );
      default:
        return SourceIndicator(
          icon: Icons.message,
          color: Colors.blue.shade400,
          label: 'System',
        );
    }
  }

  // Mock API methods - replace with actual service calls
  Future<String?> _getAIResponse(String message, Map<String, dynamic> context) async {
    // TODO: Replace with actual AI service call
    await Future.delayed(const Duration(seconds: 1));
    return "This is a mock AI response to: $message";
  }

  Future<ApiStatus> _getAPIStatus() async {
    // TODO: Replace with actual API status check
    await Future.delayed(const Duration(milliseconds: 500));
    return ApiStatus(
      connected: true,
      endpoint: '/api/v1/chat',
      timestamp: DateTime.now(),
      hasApiKey: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Chat Toggle Button
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: () {
              setState(() {
                _chatOpen = !_chatOpen;
              });
            },
            backgroundColor: Colors.blue.shade500,
            child: Stack(
              children: [
                const Icon(Icons.message, color: Colors.white),
                if (_retryCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade500,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Chat Window
        if (_chatOpen)
          Positioned(
            bottom: 80,
            right: 16,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade800.withOpacity(0.9),
              child: Container(
                width: 320,
                constraints: const BoxConstraints(maxHeight: 500),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.shade500.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade900.withOpacity(0.2),
                            Colors.cyan.shade900.withOpacity(0.2),
                          ],
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.blue.shade500.withOpacity(0.2),
                          ),
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _apiStatus.connected
                                  ? Colors.green.shade400
                                  : Colors.red.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'CubeAI Assistant',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              _apiStatus.connected ? Icons.wifi : Icons.wifi_off,
                              size: 14,
                              color: Colors.grey.shade400,
                            ),
                            onPressed: () {
                              setState(() {
                                _showApiStatus = !_showApiStatus;
                              });
                            },
                            tooltip: 'API Status',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            color: Colors.grey.shade400,
                            onPressed: () {
                              setState(() {
                                _chatOpen = false;
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    // API Status Panel
                    if (_showApiStatus)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade700.withOpacity(0.5),
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade600),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'API Status:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  _apiStatus.connected ? 'Connected' : 'Disconnected',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _apiStatus.connected
                                        ? Colors.green.shade400
                                        : Colors.red.shade400,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Endpoint: ${_apiStatus.endpoint.isNotEmpty ? _apiStatus.endpoint : 'N/A'}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            if (_apiStatus.timestamp != null)
                              Text(
                                'Last check: ${TimeOfDay.fromDateTime(_apiStatus.timestamp!).format(context)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                          ],
                        ),
                      ),

                    // Messages
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 300),
                        padding: const EdgeInsets.all(12),
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: _chatMessages.length + (_isTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _chatMessages.length && _isTyping) {
                              return _buildTypingIndicator();
                            }

                            final msg = _chatMessages[index];
                            final sourceInfo = _getSourceIndicator(msg.source);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: msg.isUser
                                    ? Colors.blue.shade600.withOpacity(0.2)
                                    : msg.source == 'error'
                                        ? Colors.red.shade900.withOpacity(0.3)
                                        : Colors.grey.shade700.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                                border: !msg.isUser && msg.source == 'api'
                                    ? Border(
                                        left: BorderSide(
                                          color: Colors.green.shade400,
                                          width: 2,
                                        ),
                                      )
                                    : !msg.isUser && msg.source == 'error'
                                        ? Border(
                                            left: BorderSide(
                                              color: Colors.red.shade500,
                                              width: 2,
                                            ),
                                          )
                                        : null,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!msg.isUser)
                                    Icon(
                                      sourceInfo.icon,
                                      size: 12,
                                      color: sourceInfo.color,
                                    ),
                                  if (!msg.isUser) const SizedBox(width: 4),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          msg.content,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: msg.isUser
                                                ? Colors.blue.shade100
                                                : msg.source == 'error'
                                                    ? Colors.red.shade200
                                                    : Colors.grey.shade200,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              TimeOfDay.fromDateTime(msg.timestamp)
                                                  .format(context),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade400,
                                              ),
                                            ),
                                            if (!msg.isUser)
                                              Text(
                                                sourceInfo.label,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: sourceInfo.color,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Input Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.blue.shade500.withOpacity(0.2),
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: RawKeyboardListener(
                                  focusNode: FocusNode(),
                                  onKey: _handleKeyPress,
                                  child: TextField(
                                    controller: _inputController,
                                    focusNode: _inputFocus,
                                    maxLines: 2,
                                    enabled: !_isTyping,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Ask about currents, waves, temperature...',
                                      hintStyle: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade400,
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade700,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      contentPadding: const EdgeInsets.all(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.send, size: 16),
                                    color: Colors.white,
                                    onPressed: _isTyping || _inputController.text.trim().isEmpty
                                        ? null
                                        : _sendMessage,
                                    style: IconButton.styleFrom(
                                      backgroundColor: _isTyping || _inputController.text.trim().isEmpty
                                          ? Colors.grey.shade600
                                          : Colors.blue.shade600,
                                      disabledBackgroundColor: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (_retryCount > 0)
                                    IconButton(
                                      icon: const Icon(Icons.refresh, size: 14),
                                      color: Colors.white,
                                      onPressed: _isTyping ? null : _retryLastMessage,
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.yellow.shade600,
                                        padding: const EdgeInsets.all(8),
                                        minimumSize: const Size(32, 32),
                                      ),
                                      tooltip: 'Retry last message',
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Quick Actions
                          Row(
                            children: [
                              _buildQuickAction(
                                'Conditions',
                                'What are the current conditions?',
                              ),
                              const SizedBox(width: 4),
                              _buildQuickAction(
                                'Waves',
                                'Analyze wave patterns',
                              ),
                              const SizedBox(width: 4),
                              _buildQuickAction(
                                'Safety',
                                'Safety assessment',
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.refresh, size: 12),
                                color: Colors.grey.shade300,
                                onPressed: _checkAPIStatus,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.grey.shade700,
                                  padding: const EdgeInsets.all(8),
                                  minimumSize: const Size(32, 32),
                                ),
                                tooltip: 'Refresh API status',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickAction(String label, String message) {
    return Expanded(
      child: TextButton(
        onPressed: _isTyping
            ? null
            : () {
                _inputController.text = message;
              },
        style: TextButton.styleFrom(
          backgroundColor: Colors.grey.shade700,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: const Size(0, 28),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade700.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          ...List.generate(3, (index) {
            return Container(
              margin: const EdgeInsets.only(right: 4),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                shape: BoxShape.circle,
              ),
            );
          }),
          const SizedBox(width: 8),
          Text(
            _retryCount > 0
                ? 'Retrying ($_retryCount/$maxRetries)...'
                : 'Analyzing...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
          ),
          if (_retryCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.yellow.shade400),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Supporting classes
class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final String source;
  final DateTime timestamp;
  final int retryAttempt;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.source,
    required this.timestamp,
    required this.retryAttempt,
  });

  factory ChatMessage.empty() {
    return ChatMessage(
      id: '',
      content: '',
      isUser: false,
      source: '',
      timestamp: DateTime.now(),
      retryAttempt: 0,
    );
  }
}

class ApiStatus {
  final bool connected;
  final String endpoint;
  final DateTime? timestamp;
  final bool hasApiKey;

  ApiStatus({
    required this.connected,
    required this.endpoint,
    this.timestamp,
    required this.hasApiKey,
  });

  ApiStatus copyWith({
    bool? connected,
    String? endpoint,
    DateTime? timestamp,
    bool? hasApiKey,
  }) {
    return ApiStatus(
      connected: connected ?? this.connected,
      endpoint: endpoint ?? this.endpoint,
      timestamp: timestamp ?? this.timestamp,
      hasApiKey: hasApiKey ?? this.hasApiKey,
    );
  }
}

class SourceIndicator {
  final IconData icon;
  final Color color;
  final String label;

  SourceIndicator({
    required this.icon,
    required this.color,
    required this.label,
  });
}