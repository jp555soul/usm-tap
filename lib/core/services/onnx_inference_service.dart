export 'onnx_web.dart'
    if (dart.library.io) 'onnx_native.dart';

class OnnxModelInfo {
  final String name;
  final String assetPath;
  final String description;

  const OnnxModelInfo({
    required this.name,
    required this.assetPath,
    required this.description,
  });
}

const List<OnnxModelInfo> kAvailableOnnxModels = [
  OnnxModelInfo(
    name: 'Oceanographic Analysis',
    assetPath: 'assets/models/oceanographic_analysis.onnx',
    description: 'General purpose ocean parameter analysis model',
  ),
];
