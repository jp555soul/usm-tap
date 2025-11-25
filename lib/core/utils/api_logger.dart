import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class ApiLogger {
  static final ApiLogger _instance = ApiLogger._internal();
  
  factory ApiLogger() {
    return _instance;
  }
  
  ApiLogger._internal();
  
  final List<String> _logs = [];
  
  void logQuery(String query) {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    _logs.add('[$timestamp] $query');
  }
  
  Future<String> saveLogsToFile() async {
    if (_logs.isEmpty) {
      return 'No logs to save.';
    }
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${directory.path}/api_logs_$timestamp.txt');
      
      final content = _logs.join('\n');
      await file.writeAsString(content);
      
      return file.path;
    } catch (e) {
      return 'Error saving logs: $e';
    }
  }
  
  void clearLogs() {
    _logs.clear();
  }
  
  List<String> get logs => List.unmodifiable(_logs);
}
