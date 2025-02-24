import 'package:hive/hive.dart';

part 'user_profile.g.dart';

@HiveType(typeId: 0)
class UserProfile {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String email;

  @HiveField(2)
  final String address;

  @HiveField(3)
  final String phone;

  @HiveField(4)
  final String role;

  @HiveField(5)
  final String? imagePath;

  @HiveField(6)
  final bool isSynced;

  UserProfile({
    required this.name,
    required this.email,
    required this.address,
    required this.phone,
    required this.role,
    this.imagePath,
    this.isSynced = true,
  });

  UserProfile copyWith({
    String? name,
    String? email,
    String? address,
    String? phone,
    String? role,
    String? imagePath,
    bool? isSynced,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      imagePath: imagePath ?? this.imagePath,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}