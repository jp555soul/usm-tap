import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:usm_tap/core/utils/api_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return '.';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PathProviderPlatform.instance = MockPathProviderPlatform();
    ApiLogger().clearLogs();
  });

  test('ApiLogger logs queries correctly', () {
    final logger = ApiLogger();
    logger.logQuery('test query 1');
    logger.logQuery('test query 2');

    expect(logger.logs.length, 2);
    expect(logger.logs[0], contains('test query 1'));
    expect(logger.logs[1], contains('test query 2'));
  });

  test('ApiLogger saves logs to file', () async {
    final logger = ApiLogger();
    logger.logQuery('test query for file');

    final path = await logger.saveLogsToFile();
    
    expect(path, isNot('No logs to save.'));
    expect(path, isNot(startsWith('Error saving logs:')));
    
    final file = File(path);
    expect(await file.exists(), true);
    
    final content = await file.readAsString();
    expect(content, contains('test query for file'));
    
    // Cleanup
    await file.delete();
  });
  
  test('ApiLogger handles empty logs', () async {
    final logger = ApiLogger();
    final result = await logger.saveLogsToFile();
    expect(result, 'No logs to save.');
  });
}
