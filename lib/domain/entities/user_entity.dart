import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String? name;
  final String? picture;
  final Map<String, dynamic>? metadata;

  const UserEntity({
    required this.id,
    required this.email,
    this.name,
    this.picture,
    this.metadata,
  });

  @override
  List<Object?> get props => [id, email, name, picture, metadata];

  UserEntity copyWith({
    String? id,
    String? email,
    String? name,
    String? picture,
    Map<String, dynamic>? metadata,
  }) {
    return UserEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      picture: picture ?? this.picture,
      metadata: metadata ?? this.metadata,
    );
  }
}