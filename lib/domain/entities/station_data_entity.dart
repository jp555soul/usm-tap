import 'package:equatable/equatable.dart';

class StationDataEntity extends Equatable {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? description;
  final String? type;
  final bool isActive;
  final DateTime? lastUpdate;
  final List<String>? availableModels;
  final List<double>? availableDepths;
  final Map<String, dynamic>? metadata;

  const StationDataEntity({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.description,
    this.type,
    this.isActive = true,
    this.lastUpdate,
    this.availableModels,
    this.availableDepths,
    this.metadata,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        latitude,
        longitude,
        description,
        type,
        isActive,
        lastUpdate,
        availableModels,
        availableDepths,
        metadata,
      ];

  StationDataEntity copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    String? description,
    String? type,
    bool? isActive,
    DateTime? lastUpdate,
    List<String>? availableModels,
    List<double>? availableDepths,
    Map<String, dynamic>? metadata,
  }) {
    return StationDataEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: description ?? this.description,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      availableModels: availableModels ?? this.availableModels,
      availableDepths: availableDepths ?? this.availableDepths,
      metadata: metadata ?? this.metadata,
    );
  }
}