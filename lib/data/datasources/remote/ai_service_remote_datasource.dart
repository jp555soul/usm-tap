// lib/data/datasources/remote/ai_service_remote_datasource.dart
import '../../services/ai_service.dart';

/// Abstract class for remote AI service data source
/// 
/// Implements the Chat API as documented in docs/doc.md.
abstract class AiServiceRemoteDataSource {
  Future<Map<String, dynamic>> getAIResponse({
    required String message,
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? context,
  });

  Future<bool> testAPIConnection();

  /// Sends a message to the Chat API.
  /// 
  /// Parameters:
  /// - [message]: Required. The question or prompt to send to the AI.
  /// - [llmModel]: Optional. LLM model to use: "blueai" (default) or "gemini-2.5-pro".
  /// - [datasourceUuids]: Optional. List of datasource UUIDs to query against.
  /// - [threadId]: Optional. Thread ID for conversation continuity.
  /// - [additionalInstructions]: Optional. Extra instructions for the LLM.
  Future<dynamic> sendMessage({
    required String message,
    String? llmModel,
    List<String>? datasourceUuids,
    String? threadId,
    String? additionalInstructions,
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? context,
  });
  
  /// Sends a message and returns a streaming response.
  /// [onThreadId] is called when the first SSE event contains thread_id (thread_init).
  Stream<dynamic> sendMessageStream({
    required String message,
    String? llmModel,
    List<String>? datasourceUuids,
    String? threadId,
    String? additionalInstructions,
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? context,
    void Function(String)? onThreadId,
  });

  /// Retrieves all messages from a conversation thread.
  /// 
  /// GET /chat/messages/{thread_id}
  Future<Map<String, dynamic>> getThreadMessages({
    required String threadId,
  });
}

/// Implementation of [AiServiceRemoteDataSource]
class AiServiceRemoteDataSourceImpl implements AiServiceRemoteDataSource {
  final AiService _aiService;

  AiServiceRemoteDataSourceImpl({required AiService aiService})
      : _aiService = aiService;

  @override
  Future<Map<String, dynamic>> getAIResponse({
    required String message,
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? context,
  }) async {
    final response = await _aiService.sendMessage(
      message: message,
      history: history,
      context: context,
    );
    return response;
  }

  @override
  Future<bool> testAPIConnection() async {
    return await _aiService.healthCheck();
  }

  @override
  Future<dynamic> sendMessage({
    required String message,
    String? llmModel,
    List<String>? datasourceUuids,
    String? threadId,
    String? additionalInstructions,
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? context,
  }) async {
    final response = await _aiService.sendMessage(
      message: message,
      llmModel: llmModel,
      datasourceUuids: datasourceUuids,
      threadId: threadId,
      additionalInstructions: additionalInstructions,
      history: history,
      context: context,
    );
    return response;
  }

  @override
  Stream<dynamic> sendMessageStream({
    required String message,
    String? llmModel,
    List<String>? datasourceUuids,
    String? threadId,
    String? additionalInstructions,
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? context,
    void Function(String)? onThreadId,
  }) {
    return _aiService.sendMessageStream(
      message: message,
      llmModel: llmModel,
      datasourceUuids: datasourceUuids,
      threadId: threadId,
      additionalInstructions: additionalInstructions,
      history: history,
      context: context,
      onThreadId: onThreadId,
    );
  }

  @override
  Future<Map<String, dynamic>> getThreadMessages({
    required String threadId,
  }) async {
    return await _aiService.getThreadMessages(threadId: threadId);
  }
}