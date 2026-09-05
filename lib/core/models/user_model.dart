import 'package:equatable/equatable.dart';
import 'enums.dart';

/// Mirror of the `users/{uid}` Firestore doc.
class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.role,
    this.tier = UserTier.free,
    this.email,
    this.displayName,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final UserRole role;
  final UserTier tier;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isAdmin => role == UserRole.admin;

  /// True for admins and premium customers — the audience for Scanner,
  /// ADMIN BUYS, and Learn. Admins always pass regardless of tier so the
  /// team never locks itself out of its own premium surfaces.
  bool get hasPremiumAccess => isAdmin || tier == UserTier.premium;

  factory AppUser.fromFirestore(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      role: UserRoleX.fromWire(data['role'] as String?),
      tier: UserTierX.fromWire(data['tier'] as String?),
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      photoUrl: data['photoUrl'] as String?,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'role': role.wire,
        'tier': tier.wire,
        if (email != null) 'email': email,
        if (displayName != null) 'displayName': displayName,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

  AppUser copyWith({
    UserRole? role,
    UserTier? tier,
    String? email,
    String? displayName,
    String? photoUrl,
  }) {
    return AppUser(
      uid: uid,
      role: role ?? this.role,
      tier: tier ?? this.tier,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props =>
      [uid, role, tier, email, displayName, photoUrl, createdAt, updatedAt];
}

DateTime? _parseDate(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  // Firestore Timestamp objects expose toDate(); duck-type to avoid import.
  try {
    final dynamic d = raw;
    final DateTime? v = d.toDate() as DateTime?;
    return v;
  } catch (_) {
    return null;
  }
}
