import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

/// Native-specific implementation of ONNX inference.
class OnnxInferenceService {
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    OrtEnv.instance.init();
    _isInitialized = true;
  }

  Future<OrtSession> createSession(String assetPath) async {
    await initialize();

    final byteData = await rootBundle.load(assetPath);
    final buffer = byteData.buffer.asUint8List();

    final sessionOptions = OrtSessionOptions();
    
    if (Platform.isIOS || Platform.isMacOS) {
      sessionOptions.appendCoreMLProvider(CoreMLFlags.useNone);
    } else if (Platform.isAndroid) {
      sessionOptions.appendNnapiProvider(NnapiFlags.useNone);
    }
    
    sessionOptions.setIntraOpNumThreads(2); 

    try {
      return OrtSession.fromBuffer(buffer, sessionOptions);
    } catch (e) {
      debugPrint('Error creating ONNX session: $e');
      rethrow;
    }
  }

  Future<Map<String, OrtValue?>> runInferenceInIsolate({
    required dynamic session,
    required Map<String, Float32List> inputs,
    required List<int> shape,
  }) async {
    if (session is! OrtSession) {
      throw ArgumentError('Session must be an OrtSession on native platforms');
    }
    
    final sessionAddress = session.address;

    return await compute(_performInference, {
      'sessionAddress': sessionAddress,
      'inputs': inputs,
      'shape': shape,
    });
  }

  static Future<Map<String, OrtValue?>> _performInference(Map<String, dynamic> params) async {
    final int sessionAddress = params['sessionAddress'];
    final Map<String, Float32List> inputs = params['inputs'];
    final List<int> shape = params['shape'];

    final session = OrtSession.fromAddress(sessionAddress);
    final runOptions = OrtRunOptions();
    final inputValues = <String, OrtValue>{};

    try {
      for (var entry in inputs.entries) {
        inputValues[entry.key] = OrtValueTensor.createTensorWithDataList(entry.value, shape);
      }
      
      final outputs = session.run(runOptions, inputValues);
      
      // Map outputs back to their names
      final resultMap = <String, OrtValue?>{};
      for (var i = 0; i < outputs.length; i++) {
        if (i < session.outputNames.length) {
          resultMap[session.outputNames[i]] = outputs[i];
        }
      }
      return resultMap;
    } finally {
      for (var value in inputValues.values) {
        value.release();
      }
      runOptions.release();
    }
  }

  void releaseSession(dynamic session) {
    if (session is OrtSession) {
      session.release();
    }
  }
}
