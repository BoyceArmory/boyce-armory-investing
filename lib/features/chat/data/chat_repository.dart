import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'chat_models.dart';

/// All Firestore + Storage interactions for the chat feature.
class ChatRepository {
  ChatRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
    ImagePicker? imagePicker,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _picker = imagePicker ?? ImagePicker();

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final ImagePicker _picker;

  // -------- references --------

  DocumentReference<Map<String, dynamic>> _roomRef(String roomId) =>
      _db.collection('chat_rooms').doc(roomId);

  CollectionReference<Map<String, dynamic>> _messagesRef(String roomId) =>
      _roomRef(roomId).collection('messages');

  // -------- reads --------

  Stream<List<ChatMessage>> streamMessages(String roomId, {int limit = 100}) {
    return _messagesRef(roomId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                  ChatMessage.fromSnapshot(roomId, d))
              .toList(growable: false),
        );
  }

  // -------- writes --------

  Future<void> sendText({
    required String roomId,
    required String roomTitle,
    required String text,
    required String senderName,
    required String? profileImageUrl,
    required bool isAdmin,
  }) async {
    final User? u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in.');
    final String body = text.trim();
    if (body.isEmpty) return;

    await _messagesRef(roomId).add(<String, dynamic>{
      'type': 'text',
      'text': body,
      'imageUrl': '',
      'storagePath': '',
      'senderName': senderName,
      'profileImageUrl': profileImageUrl ?? '',
      'senderId': u.uid,
      'senderEmail': u.email ?? '',
      'isAdmin': isAdmin,
      'roomId': roomId,
      'deleted': false,
      'edited': false,
      'reactions': <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _bumpRoom(roomId: roomId, roomTitle: roomTitle, lastMessage: body);
  }

  /// Picks an image from the gallery and uploads it. Returns null if the user
  /// cancelled the picker.
  Future<bool> pickAndSendImage({
    required String roomId,
    required String roomTitle,
    required String caption,
    required String senderName,
    required String? profileImageUrl,
    required bool isAdmin,
  }) async {
    final User? u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in.');

    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked == null) return false;

    final String fileName =
        '${roomId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final Reference ref = _storage
        .ref()
        .child('uploads')
        .child(u.uid)
        .child(roomId)
        .child(fileName);

    await ref.putFile(
      File(picked.path),
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: <String, String>{
          'uid': u.uid,
          'roomId': roomId,
          'uploadedFrom': 'chat',
        },
      ),
    );
    final String url = await ref.getDownloadURL();
    final String trimmedCaption = caption.trim();

    await _messagesRef(roomId).add(<String, dynamic>{
      'type': 'image',
      'text': trimmedCaption,
      'imageUrl': url,
      'storagePath': ref.fullPath,
      'senderName': senderName,
      'profileImageUrl': profileImageUrl ?? '',
      'senderId': u.uid,
      'senderEmail': u.email ?? '',
      'isAdmin': isAdmin,
      'roomId': roomId,
      'deleted': false,
      'edited': false,
      'reactions': <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final String summary = trimmedCaption.isNotEmpty
        ? '📸 $trimmedCaption'
        : (roomId == 'gains'
            ? '📸 New gain screenshot posted'
            : '📸 New screenshot posted');
    await _bumpRoom(
        roomId: roomId, roomTitle: roomTitle, lastMessage: summary);
    return true;
  }

  Future<void> editMessage({
    required String roomId,
    required String messageId,
    required String newText,
  }) {
    return _messagesRef(roomId).doc(messageId).update(<String, dynamic>{
      'text': newText,
      'edited': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage({
    required String roomId,
    required String messageId,
  }) {
    return _messagesRef(roomId).doc(messageId).update(<String, dynamic>{
      'deleted': true,
      'text': '',
      'imageUrl': '',
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': _auth.currentUser?.uid ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Removes the image but keeps the text/caption. Used for moderation.
  Future<void> removeImageOnly({
    required String roomId,
    required ChatMessage message,
  }) async {
    final String? path = message.storagePath;
    if (path != null && path.isNotEmpty) {
      try {
        await _storage.ref(path).delete();
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') rethrow;
      }
    }
    final String newText = message.text.trim().isEmpty
        ? 'Image removed'
        : '${message.text}\n\n[Image removed]';
    await _messagesRef(roomId).doc(message.id).update(<String, dynamic>{
      'type': 'text',
      'imageUrl': '',
      'storagePath': '',
      'text': newText,
      'edited': true,
      'imageDeleted': true,
      'imageDeletedAt': FieldValue.serverTimestamp(),
      'imageDeletedBy': _auth.currentUser?.uid ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleReaction({
    required String roomId,
    required ChatMessage message,
    required String emoji,
  }) async {
    final User? u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in.');
    final Map<String, List<String>> next =
        <String, List<String>>{...message.reactions};
    final List<String> users =
        List<String>.from(next[emoji] ?? const <String>[]);

    if (users.contains(u.uid)) {
      users.remove(u.uid);
    } else {
      users.add(u.uid);
    }
    if (users.isEmpty) {
      next.remove(emoji);
    } else {
      next[emoji] = users;
    }
    await _messagesRef(roomId).doc(message.id).update(<String, dynamic>{
      'reactions': next,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _bumpRoom({
    required String roomId,
    required String roomTitle,
    required String lastMessage,
  }) {
    return _roomRef(roomId).set(
      <String, dynamic>{
        'name': roomTitle,
        'lastMessage': lastMessage,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
