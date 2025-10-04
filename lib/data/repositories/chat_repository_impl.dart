// lib/data/repositories/chat_repository_impl.dart
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/exceptions.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/remote/ai_service_remote_datasource.dart';
import '../datasources/local/encrypted_storage_local_datasource.dart';

class ChatRepositoryImpl implements ChatRepository {
  final AiServiceRemoteDataSource remoteDataSource;
  final EncryptedStorageLocalDataSource localStorage;

  ChatRepositoryImpl({
    required this.remoteDataSource,
    required this.localStorage,
  });

  @override
  Future<Either<Failure, ChatMessage>> sendMessage({
    required String message,
    List<ChatMessage>? history,
    Map<String, dynamic>? context,
  }) async {
    try {
      final response = await remoteDataSource.sendMessage(
        message: message,
        history: history?.map((m) => {
          'content': m.content,
          'isUser': m.isUser,
          'timestamp': m.timestamp.toIso8601String(),
        }).toList(),
        context: context,
      );

      final chatMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: response['message'] ?? response['content'] ?? '',
        isUser: false,
        timestamp: DateTime.now(),
        metadata: response,
      );

      // Store message in local storage
      await _storeMessage(chatMessage);

      return Right(chatMessage);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Stream<String>>> sendMessageStream({
    required String message,
    List<ChatMessage>? history,
    Map<String, dynamic>? context,
  }) async {
    try {
      final stream = await remoteDataSource.sendMessageStream(
        message: message,
        history: history?.map((m) => {
          'content': m.content,
          'isUser': m.isUser,
          'timestamp': m.timestamp.toIso8601String(),
        }).toList(),
        context: context,
      );

      return Right(stream);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<ChatMessage>>> getChatHistory({
    int? limit,
    DateTime? before,
  }) async {
    try {
      final stored = await localStorage.getData('chat_history');
      if (stored == null) {
        return const Right([]);
      }

      final List<dynamic> historyJson = stored as List<dynamic>;
      var messages = historyJson.map((json) => ChatMessage(
        id: json['id'] ?? '',
        content: json['content'] ?? '',
        isUser: json['isUser'] ?? false,
        timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
        metadata: json['metadata'],
      )).toList();

      // Filter by before date if provided
      if (before != null) {
        messages = messages.where((m) => m.timestamp.isBefore(before)).toList();
      }

      // Apply limit if provided
      if (limit != null && messages.length > limit) {
        messages = messages.sublist(messages.length - limit);
      }

      return Right(messages);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure('Failed to get chat history: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> clearChatHistory() async {
    try {
      await localStorage.deleteData('chat_history');
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(CacheFailure('Failed to clear chat history: ${e.toString()}'));
    }
  }

  Future<void> _storeMessage(ChatMessage message) async {
    try {
      final stored = await localStorage.getData('chat_history');
      final List<Map<String, dynamic>> history = stored != null
          ? List<Map<String, dynamic>>.from(stored as List)
          : [];

      history.add({
        'id': message.id,
        'content': message.content,
        'isUser': message.isUser,
        'timestamp': message.timestamp.toIso8601String(),
        'metadata': message.metadata,
      });

      // Keep only last 100 messages
      if (history.length > 100) {
        history.removeRange(0, history.length - 100);
      }

      await localStorage.saveData('chat_history', history);
    } catch (e) {
      // Ignore storage errors for now
      print('Failed to store message: $e');
    }
  }
}