import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Static room definition. We keep the list of rooms client-side so we always
/// have something to show even before anyone posts.
class ChatRoomDef extends Equatable {
  const ChatRoomDef({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.iconAsset,
    this.allowImages = true,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;

  /// Optional artwork shown instead of [icon] (preferred when present).
  final String? iconAsset;

  final bool allowImages;

  @override
  List<Object?> get props =>
      <Object?>[id, title, description, icon, iconAsset, allowImages];
}

enum ChatMessageType { text, image }

/// Mirror of `chat_rooms/{roomId}/messages/{id}`.
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.type,
    required this.isAdmin,
    required this.deleted,
    required this.edited,
    required this.reactions,
    required this.createdAt,
    this.imageUrl,
    this.storagePath,
    this.profileImageUrl,
    this.senderEmail,
  });

  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String text;
  final ChatMessageType type;
  final bool isAdmin;
  final bool deleted;
  final bool edited;
  final Map<String, List<String>> reactions; // emoji -> list of uids
  final DateTime createdAt;
  final String? imageUrl;
  final String? storagePath;
  final String? profileImageUrl;
  final String? senderEmail;

  bool get hasImage =>
      type == ChatMessageType.image && (imageUrl?.isNotEmpty ?? false);

  factory ChatMessage.fromSnapshot(
    String roomId,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> m = doc.data();
    final String typeStr = (m['type'] as String?) ?? 'text';
    return ChatMessage(
      id: doc.id,
      roomId: roomId,
      senderId: (m['senderId'] ?? '') as String,
      senderName: (m['senderName'] ?? 'Member') as String,
      text: (m['text'] ?? '') as String,
      type: typeStr == 'image' ? ChatMessageType.image : ChatMessageType.text,
      isAdmin: (m['isAdmin'] as bool?) ?? false,
      deleted: (m['deleted'] as bool?) ?? false,
      edited: (m['edited'] as bool?) ?? false,
      reactions: _parseReactions(m['reactions']),
      createdAt: _parseDate(m['createdAt']) ?? DateTime.now(),
      imageUrl: m['imageUrl'] as String?,
      storagePath: m['storagePath'] as String?,
      profileImageUrl: m['profileImageUrl'] as String?,
      senderEmail: m['senderEmail'] as String?,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        roomId,
        senderId,
        senderName,
        text,
        type,
        isAdmin,
        deleted,
        edited,
        reactions,
        createdAt,
        imageUrl,
        storagePath,
        profileImageUrl,
        senderEmail,
      ];
}

Map<String, List<String>> _parseReactions(Object? raw) {
  final Map<String, List<String>> out = <String, List<String>>{};
  if (raw is Map) {
    raw.forEach((Object? key, Object? value) {
      final String emoji = key?.toString() ?? '';
      if (emoji.isEmpty) return;
      if (value is List) {
        out[emoji] =
            value.map((Object? v) => v?.toString() ?? '').toList(growable: false);
      } else {
        out[emoji] = <String>[];
      }
    });
  }
  return out;
}

DateTime? _parseDate(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is Timestamp) return raw.toDate();
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}
