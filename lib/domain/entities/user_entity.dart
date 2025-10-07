import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String? name;
  final String? picture;
  final String? sub;
  final String? accessToken;
  final String? refreshToken;
  final Map<String, dynamic>? metadata;

  const UserEntity({
    required this.id,
    required this.email,
    this.name,
    this.picture,
    this.sub,
    this.accessToken,
    this.refreshToken,
    this.metadata,
  });

  @override
  List<Object?> get props => [id, email, name, picture, sub, accessToken, refreshToken, metadata];

  UserEntity copyWith({
    String? id,
    String? email,
    String? name,
    String? picture,
    String? sub,
    String? accessToken,
    String? refreshToken,
    Map<String, dynamic>? metadata,
  }) {
    return UserEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      picture: picture ?? this.picture,
      sub: sub ?? this.sub,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      metadata: metadata ?? this.metadata,
    );
  }
}