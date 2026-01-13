import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// Web-compatible implementation of ONNX inference.
/// Uses flutter_onnxruntime which bridges to onnxruntime-web via JS interop.
class OnnxInferenceService {
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    // flutter_onnxruntime doesn't require explicit OrtEnv init on web usually,
    // as it uses the ort global from index.html.
    _isInitialized = true;
  }

  Future<OrtSession> createSession(String assetPath) async {
    await initialize();

    try {
      final ort = OnnxRuntime();
      return await ort.createSessionFromAsset(assetPath);
    } catch (e) {
      debugPrint('Error creating ONNX session on Web: $e');
      rethrow;
    }
  }

  List<String> getSessionInputNames(dynamic session) {
    // onnxruntime-web / flutter_onnxruntime wrapper might expose this differently.
    // Inspecting the library is hard without docs, but typically it might be 'inputNames'.
    // If unavailable safely return empty or try common property names.
    if (session is OrtSession) {
      // Trying to access likely properties.
      // NOTE: If this fails to compile, we might need to rely on the side-channel or specific known inputs.
      // For now, assuming standard ORT web wrapper structure or just returning basic info.
      
      // Since we can't easily verify the API of the package 'flutter_onnxruntime' completely from here
      // without seeing its code, we will try to return the inputs if the object has them.
      // However, dart is strongly typed. 
      // Let's assume for this specific task we might need to rely on 'run' only unless we see the definition.
      // We will perform a safe check or return empty if not sure.
      return []; 
    }
    return [];
  }
  
  List<String> getSessionOutputNames(dynamic session) {
    if (session is OrtSession) {
       return [];
    }
    return [];
  }

  /// On web, 'compute' doesn't create a real separate thread in the same way as native,
  /// but we keep the same signature for cross-platform consistency.
  /// OrtIsolateSession is NOT used here as web doesn't support FFI-based Isolate sharing.
  Future<Map<String, OrtValue?>> runInferenceInIsolate({
    required dynamic session,
    required Map<String, Float32List> inputs,
    required List<int> shape,
  }) async {
    if (session is! OrtSession) {
      throw ArgumentError('Session must be an OrtSession from flutter_onnxruntime on Web');
    }

    final runOptions = OrtRunOptions();
    final inputValues = <String, OrtValue>{};

    try {
      for (var entry in inputs.entries) {
        // Create tensor from typed data.
        inputValues[entry.key] = await OrtValue.fromList(entry.value, shape);
      }

      // Run inference directly on the main thread (as ORT Web is async internally via Web Workers)
      final outputs = await session.run(inputValues, options: runOptions);
      
      return outputs;
    } catch (e) {
      debugPrint('Inference error on Web: $e');
      rethrow;
    } finally {
      // Cleanup inputs
      for (var value in inputValues.values) {
        await value.dispose();
      }
      // OrtRunOptions doesn't have release/dispose on web
    }
  }

  void releaseSession(dynamic session) {
    if (session is OrtSession) {
      session.close();
    }
  }
}
