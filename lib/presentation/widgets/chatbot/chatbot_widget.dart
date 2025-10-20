import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/chat/chat_bloc.dart';
import '../../../domain/repositories/chat_repository.dart' as domain;
import '../../../data/models/chat_message.dart' as data_models;

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

  @override
  void initState() {
    super.initState();
    _threadId = _generateThreadId();
    _initializeChat();
    _apiStatusTimer = Timer.periodic(const Duration(minutes: 1), (_) => _updateApiStatus());
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

  void _initializeChat() {
    if (_isInitialized) return;
    
    // Send initial message to get welcome response
    final contextData = _buildContext();
    context.read<ChatBloc>().add(SendChatMessageEvent(
      message: "Generate a welcome message for CubeAI oceanographic analysis platform",
      context: contextData,
    ));
    
    setState(() {
      _isInitialized = true;
      _apiStatus = _apiStatus.copyWith(
        connected: true,
        endpoint: '/api/chat',
        timestamp: DateTime.now(),
        hasApiKey: true,
      );
    });
  }

  void _updateApiStatus() {
    // API status is now derived from ChatBloc state
    final chatState = context.read<ChatBloc>().state;
    setState(() {
      _apiStatus = _apiStatus.copyWith(
        connected: chatState is! ChatError,
        timestamp: DateTime.now(),
      );
    });
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

  void _sendMessage() {
    if (_inputController.text.trim().isEmpty) return;
    
    final messageText = _inputController.text;
    _inputController.clear();

    final contextData = _buildContext();
    context.read<ChatBloc>().add(SendChatMessageEvent(
      message: messageText,
      context: contextData,
    ));

    _scrollToBottom();
  }

  void _retryLastMessage() {
    final chatState = context.read<ChatBloc>().state;
    List<domain.ChatMessage> messages = [];
    
    if (chatState is ChatLoaded) {
      messages = chatState.messages;
    } else if (chatState is ChatError) {
      messages = chatState.messages;
    }
    
    final lastUserMessage = messages.reversed
        .where((msg) => msg.isUser)
        .firstOrNull;
    
    if (lastUserMessage != null) {
      final contextData = _buildContext();
      context.read<ChatBloc>().add(SendChatMessageEvent(
        message: lastUserMessage.content,
        context: contextData,
      ));
    }
  }

  void _handleKeyPress(RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !event.isShiftPressed) {
      _sendMessage();
    }
  }

  SourceIndicator _getSourceIndicator(domain.ChatMessage msg) {
    if (msg.isUser) {
      return SourceIndicator(
        icon: Icons.person,
        color: Colors.blue.shade400,
        label: 'You',
      );
    }
    
    return SourceIndicator(
      icon: Icons.wifi,
      color: Colors.green.shade400,
      label: 'AI API',
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatBloc, ChatState>(
      listener: (context, state) {
        if (state is ChatLoaded || state is ChatMessageStreaming) {
          _scrollToBottom();
          setState(() {
            _apiStatus = _apiStatus.copyWith(
              connected: true,
              timestamp: DateTime.now(),
            );
          });
        } else if (state is ChatError) {
          setState(() {
            _apiStatus = _apiStatus.copyWith(connected: false);
          });
        }
      },
      child: Stack(
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
              child: BlocBuilder<ChatBloc, ChatState>(
                builder: (context, state) {
                  final hasError = state is ChatError;
                  return Stack(
                    children: [
                      const Icon(Icons.message, color: Colors.white),
                      if (hasError)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.red.shade500,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  );
                },
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
                          child: BlocBuilder<ChatBloc, ChatState>(
                            builder: (context, state) {
                              List<domain.ChatMessage> messages = [];
                              bool isLoading = false;
                              String? streamingContent;

                              if (state is ChatLoaded) {
                                messages = state.messages;
                              } else if (state is ChatMessageSending) {
                                messages = state.messages;
                                isLoading = true;
                              } else if (state is ChatMessageStreaming) {
                                messages = state.messages;
                                streamingContent = state.streamingContent;
                              } else if (state is ChatError) {
                                messages = state.messages;
                              }

                              return ListView.builder(
                                controller: _scrollController,
                                itemCount: messages.length + 
                                    (isLoading ? 1 : 0) + 
                                    (streamingContent != null ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (streamingContent != null && index == messages.length) {
                                    return _buildStreamingMessage(streamingContent);
                                  }

                                  if (isLoading && index == messages.length) {
                                    return _buildTypingIndicator();
                                  }

                                  final msg = messages[index];
                                  final sourceInfo = _getSourceIndicator(msg);

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: msg.isUser
                                          ? Colors.blue.shade600.withOpacity(0.2)
                                          : Colors.grey.shade700.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(8),
                                      border: !msg.isUser
                                          ? Border(
                                              left: BorderSide(
                                                color: Colors.green.shade400,
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
                              );
                            },
                          ),
                        ),
                      ),

                      // Input Section
                      BlocBuilder<ChatBloc, ChatState>(
                        builder: (context, state) {
                          final isLoading = state is ChatMessageSending;
                          final hasError = state is ChatError;

                          return Container(
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
                                          enabled: !isLoading,
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
                                          onPressed: isLoading || _inputController.text.trim().isEmpty
                                              ? null
                                              : _sendMessage,
                                          style: IconButton.styleFrom(
                                            backgroundColor: isLoading || _inputController.text.trim().isEmpty
                                                ? Colors.grey.shade600
                                                : Colors.blue.shade600,
                                            disabledBackgroundColor: Colors.grey.shade600,
                                          ),
                                        ),
                                        if (hasError)
                                          IconButton(
                                            icon: const Icon(Icons.refresh, size: 14),
                                            color: Colors.white,
                                            onPressed: isLoading ? null : _retryLastMessage,
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
                                      isLoading,
                                    ),
                                    const SizedBox(width: 4),
                                    _buildQuickAction(
                                      'Waves',
                                      'Analyze wave patterns',
                                      isLoading,
                                    ),
                                    const SizedBox(width: 4),
                                    _buildQuickAction(
                                      'Safety',
                                      'Safety assessment',
                                      isLoading,
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.refresh, size: 12),
                                      color: Colors.grey.shade300,
                                      onPressed: _updateApiStatus,
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
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(String label, String message, bool disabled) {
    return Expanded(
      child: TextButton(
        onPressed: disabled
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
            'Analyzing...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamingMessage(String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade700.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: Colors.green.shade400,
            width: 2,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.wifi,
            size: 12,
            color: Colors.green.shade400,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade200,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.green.shade400),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Streaming...',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade400,
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