// lib/data/datasources/remote/ai_service_remote_datasource.dart
import '../../services/ai_service.dart';

/// Abstract class for remote AI service data source
abstract class AiServiceRemoteDataSource {
  Future<Map<String, dynamic>> getAIResponse({
    required String message,
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? context,
  });

  Future<bool> testAPIConnection();

  Future<dynamic> sendMessage({required Map<String, dynamic> params});
  Stream<dynamic> sendMessageStream({required Map<String, dynamic> params});
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
    // Note: The original implementation returned a String, but the repository layer
    // expects a Map. This adapts the new service to the existing repository.
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
  Future<dynamic> sendMessage({required Map<String, dynamic> params}) async {
    // This is a placeholder implementation.
    // In a real scenario, this would call the AI service.
    return Future.value({
      'response': 'This is a mock response to your message: ${params['message']}'
    });
  }

  @override
  Stream<dynamic> sendMessageStream({required Map<String, dynamic> params}) {
    // This is a placeholder implementation for a streaming response.
    return Stream.fromIterable([
      {'chunk': 'This '},
      {'chunk': 'is a '},
      {'chunk': 'streamed '},
      {'chunk': 'response.'},
    ]);
  }
}