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

  factory UserEntity.fromJson(Map<String, dynamic> json) {
    return UserEntity(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      picture: json['picture'] as String?,
      sub: json['sub'] as String?,
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      if (name != null) 'name': name,
      if (picture != null) 'picture': picture,
      if (sub != null) 'sub': sub,
      if (accessToken != null) 'accessToken': accessToken,
      if (refreshToken != null) 'refreshToken': refreshToken,
      if (metadata != null) 'metadata': metadata,
    };
  }
}