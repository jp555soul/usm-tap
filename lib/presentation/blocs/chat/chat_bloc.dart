// lib/presentation/blocs/chat/chat_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:usm_tap/core/errors/failures.dart';
import '../../../data/models/params.dart';
import '../../../domain/repositories/chat_repository.dart' as domain;
import '../../../domain/usecases/chat/send_message_usecase.dart' as usecase;
import '../../../domain/usecases/chat/get_chat_history_usecase.dart' as history_usecase;

// Events
abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class SendChatMessageEvent extends ChatEvent {
  final String message;
  final Map<String, dynamic>? context;

  const SendChatMessageEvent({
    required this.message,
    this.context,
  });

  @override
  List<Object?> get props => [message, context];
}

class SendChatMessageStreamEvent extends ChatEvent {
  final String message;
  final Map<String, dynamic>? context;

  const SendChatMessageStreamEvent({
    required this.message,
    this.context,
  });

  @override
  List<Object?> get props => [message, context];
}

class LoadChatHistoryEvent extends ChatEvent {
  final int? limit;

  const LoadChatHistoryEvent({this.limit});

  @override
  List<Object?> get props => [limit];
}

class ClearChatHistoryEvent extends ChatEvent {
  const ClearChatHistoryEvent();
}

class AddMessageToChatEvent extends ChatEvent {
  final domain.ChatMessage message;

  const AddMessageToChatEvent(this.message);

  @override
  List<Object?> get props => [message];
}

// States
abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {
  const ChatInitial();
}

class ChatLoading extends ChatState {
  const ChatLoading();
}

class ChatLoaded extends ChatState {
  final List<domain.ChatMessage> messages;

  const ChatLoaded(this.messages);

  @override
  List<Object?> get props => [messages];
}

class ChatMessageSending extends ChatState {
  final List<domain.ChatMessage> messages;

  const ChatMessageSending(this.messages);

  @override
  List<Object?> get props => [messages];
}

class ChatMessageStreaming extends ChatState {
  final List<domain.ChatMessage> messages;
  final String streamingContent;

  const ChatMessageStreaming({
    required this.messages,
    required this.streamingContent,
  });

  @override
  List<Object?> get props => [messages, streamingContent];
}

class ChatError extends ChatState {
  final String message;
  final List<domain.ChatMessage> messages;

  const ChatError({
    required this.message,
    this.messages = const [],
  });

  @override
  List<Object?> get props => [message, messages];
}

// BLoC
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final usecase.SendMessageUseCase _sendMessageUseCase;
  final history_usecase.GetChatHistoryUseCase _getChatHistoryUseCase;
  final domain.ChatRepository _chatRepository;

  List<domain.ChatMessage> _currentMessages = [];
  StreamSubscription? _streamSubscription;

  ChatBloc({
    required usecase.SendMessageUseCase sendMessageUseCase,
    required history_usecase.GetChatHistoryUseCase getChatHistoryUseCase,
    required domain.ChatRepository chatRepository,
  })  : _sendMessageUseCase = sendMessageUseCase,
        _getChatHistoryUseCase = getChatHistoryUseCase,
        _chatRepository = chatRepository,
        super(const ChatInitial()) {
    on<SendChatMessageEvent>(_onSendMessage);
    on<SendChatMessageStreamEvent>(_onSendMessageStream);
    on<LoadChatHistoryEvent>(_onLoadHistory);
    on<ClearChatHistoryEvent>(_onClearHistory);
    on<AddMessageToChatEvent>(_onAddMessage);
  }

  Future<void> _onSendMessage(
    SendChatMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    // Add user message
    final userMessage = domain.ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: event.message,
      isUser: true,
      timestamp: DateTime.now(),
    );

    _currentMessages = [..._currentMessages, userMessage];
    emit(ChatMessageSending(_currentMessages));

    final result = await _sendMessageUseCase(
      usecase.SendMessageParams(
        message: event.message,
        history: _currentMessages,
        context: event.context,
      ),
    );

    result.fold(
      (failure) {
        emit(ChatError(
          message: failure.message,
          messages: _currentMessages,
        ));
      },
      (aiMessage) {
        _currentMessages = [..._currentMessages, aiMessage];
        emit(ChatLoaded(_currentMessages));
      },
    );
  }

  Future<void> _onSendMessageStream(
    SendChatMessageStreamEvent event,
    Emitter<ChatState> emit,
  ) async {
    // Add user message
    final userMessage = domain.ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: event.message,
      isUser: true,
      timestamp: DateTime.now(),
    );

    _currentMessages = [..._currentMessages, userMessage];
    emit(ChatMessageSending(_currentMessages));

    final result = await _sendMessageUseCase.callStream(
      usecase.SendMessageParams(
        message: event.message,
        history: _currentMessages,
        context: event.context,
      ),
    );

    result.fold(
      (failure) {
        emit(ChatError(
          message: failure.message,
          messages: _currentMessages,
        ));
      },
      (stream) {
        String streamingContent = '';

        _streamSubscription?.cancel();
        _streamSubscription = stream.listen(
          (chunk) {
            streamingContent += chunk;
            emit(ChatMessageStreaming(
              messages: _currentMessages,
              streamingContent: streamingContent,
            ));
          },
          onDone: () {
            final aiMessage = domain.ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              content: streamingContent,
              isUser: false,
              timestamp: DateTime.now(),
            );
            _currentMessages = [..._currentMessages, aiMessage];
            emit(ChatLoaded(_currentMessages));
          },
          onError: (error) {
            emit(ChatError(
              message: error.toString(),
              messages: _currentMessages,
            ));
          },
        );
      },
    );
  }

  Future<void> _onLoadHistory(
    LoadChatHistoryEvent event,
    Emitter<ChatState> emit,
  ) async {
    emit(const ChatLoading());

    final result = await _getChatHistoryUseCase(
      history_usecase.GetChatHistoryParams(limit: event.limit),
    );

    result.fold(
      (failure) {
        emit(ChatError(message: failure.message));
      },
      (messages) {
        _currentMessages = messages;
        emit(ChatLoaded(_currentMessages));
      },
    );
  }

  Future<void> _onClearHistory(
    ClearChatHistoryEvent event,
    Emitter<ChatState> emit,
  ) async {
    final result = await _chatRepository.clearChatHistory();

    result.fold(
      (failure) {
        emit(ChatError(
          message: failure.message,
          messages: _currentMessages,
        ));
      },
      (_) {
        _currentMessages = [];
        emit(const ChatLoaded([]));
      },
    );
  }

  void _onAddMessage(
    AddMessageToChatEvent event,
    Emitter<ChatState> emit,
  ) {
    _currentMessages = [..._currentMessages, event.message];
    emit(ChatLoaded(_currentMessages));
  }

  @override
  Future<void> close() {
    _streamSubscription?.cancel();
    return super.close();
  }
}