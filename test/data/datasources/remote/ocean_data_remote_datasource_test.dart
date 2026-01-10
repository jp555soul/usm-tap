import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:usm_tap/data/datasources/remote/ocean_data_remote_datasource.dart';

// Custom MockAdapter to intercept requests
class MockAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options, dynamic data) handler;

  MockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    // Collect stream if needed, but for json body usually options.data is set if using DioMixin logic,
    // actually Dio converts data to stream for the adapter.
    // However, options.data is usually preserving the original data object before transformation if using default transformer?
    // Let's rely on options.data passed by Dio.
    
    return handler(options, options.data);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late OceanDataRemoteDataSourceImpl dataSource;
  late Dio dio;
  late List<Map<String, dynamic>> capturedRequests;

  setUp(() {
    capturedRequests = [];
    
    dio = Dio();
    dio.httpClientAdapter = MockAdapter((options, data) async {
      capturedRequests.add({
        'path': options.path,
        'method': options.method,
        'data': data,
      });

      // Return empty list as successful response
      return ResponseBody.fromString(
        '[]',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    dataSource = OceanDataRemoteDataSourceImpl(dio);
  });

  test('loadAllData makes valid POST request to staging API', () async {
    // Arrange
    const targetTime = '2025-08-01T12:00:00.000Z';
    final targetDateTime = DateTime.parse(targetTime);
    
    // Act
    await dataSource.loadAllData(
      area: 'USM',
      targetTime: targetDateTime,
    );

    // Assert
    expect(capturedRequests.length, 1);
    final request = capturedRequests[0];
    
    // Check URL
    expect(request['path'], 'https://api-staging.isdata.ai/usmcom/data-proxy/query');
    expect(request['method'], 'POST');
    
    // Check Body
    // data might be a Map or String depending on implementation. 
    // In our code we passed a Map. Dio might have transformed it?
    // Since we didn't specify a transformer, Dio default transformer keeps it as Map if content-type is json?
    // Actually default transformer converts to JSON string before sending to adapter...
    // But options.data usually holds the Payload unless transformed stream is used.
    // Let's check what we get.
    
    // If it's a string, we decode it.
    var sqlData = request['data'];
    if (sqlData is String) {
        try {
            sqlData = jsonDecode(sqlData);
        } catch (_) {}
    }
    
    // It should be a Map now
    expect(sqlData, isA<Map>());
    final sql = sqlData['sql'] as String;
    
    expect(sql, contains('FROM `isdata-staging.3a9c4e48_f978_444f_8340_08e51a9d5dbd.8959e5fc_cec2_4206_8d23_68d215f77796`')); // USM table ID
    expect(sql, contains('SELECT lat, lon, depth'));
    expect(sql, contains("WHERE time = TIMESTAMP('2025-08-01T12:00:00.000Z')"));
  });


  test('fetchAvailableTimestamps makes valid POST request to staging API', () async {
    // Arrange
    final startDate = DateTime.parse('2025-08-01T00:00:00Z');
    final endDate = DateTime.parse('2025-08-08T00:00:00Z');

    // Act
    await dataSource.fetchAvailableTimestamps(
      startDate: startDate,
      endDate: endDate,
      area: 'MBL',
    );

    // Assert
    expect(capturedRequests.length, 1);
    final request = capturedRequests[0];

    // Check URL and Method
    expect(request['path'], 'https://api-staging.isdata.ai/usmcom/data-proxy/query');
    expect(request['method'], 'POST');

    // Check Body
    var sqlData = request['data'];
    if (sqlData is String) {
        try {
            sqlData = jsonDecode(sqlData);
        } catch (_) {}
    }

    expect(sqlData, isA<Map>());
    final sql = sqlData['sql'] as String;

    // Verify SQL Content
    expect(sql, contains('SELECT DISTINCT time'));
    // MBL table ID: 66e00d41_d810_4026_903a_5fc62711d791
    expect(sql, contains('FROM `isdata-staging.3a9c4e48_f978_444f_8340_08e51a9d5dbd.66e00d41_d810_4026_903a_5fc62711d791`'));
    expect(sql, contains("WHERE time BETWEEN TIMESTAMP('2025-08-01T00:00:00.000Z') AND TIMESTAMP('2025-08-08T23:59:59.999Z')"));
  });
}
