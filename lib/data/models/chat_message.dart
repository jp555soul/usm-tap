import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  final String id;
  final String content;
  final bool isUser;
  final String source;
  final DateTime timestamp;
  final int retryAttempt;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    this.source = '',
    required this.timestamp,
    this.retryAttempt = 0,
  });

  @override
  List<Object?> get props => [id, content, isUser, source, timestamp, retryAttempt];
}