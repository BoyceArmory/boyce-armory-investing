import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/api_client.dart';
import 'chat_models.dart';

/// All Firestore + Storage interactions for the chat feature.
class ChatRepository {
  ChatRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
    ImagePicker? imagePicker,
    required ApiClient apiClient,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _picker = imagePicker ?? ImagePicker(),
        _api = apiClient;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final ImagePicker _picker;
  final ApiClient _api;

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

  Future<ChatSendResult?> sendText({
    required String roomId,
    required String roomTitle,
    required String text,
    required String senderName,
    required String? profileImageUrl,
    required bool isAdmin,
    // Mentions resolved client-side from the picker. uids are the
    // explicit per-user targets; everyone:true triggers an admin-only
    // @everyone broadcast (server enforces the admin gate).
    List<String> mentionedUids = const <String>[],
    bool mentionEveryone = false,
  }) async {
    final User? u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in.');
    final String body = text.trim();
    if (body.isEmpty) return null;

    final DocumentReference<Map<String, dynamic>> doc =
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
      'mentionedUids': mentionedUids,
      'mentionEveryone': mentionEveryone,
      'reactions': <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _bumpRoom(roomId: roomId, roomTitle: roomTitle, lastMessage: body);

    // Fire mention pushes via the backend. Best-effort — if the mention
    // ping fails, the message itself still went through.
    if (mentionedUids.isNotEmpty || mentionEveryone) {
      try {
        await _api.postJson('/api/chat/mentions', body: <String, dynamic>{
          'roomId': roomId,
          'messageId': doc.id,
          'senderName': senderName,
          'preview': body,
          'mentions': <Map<String, dynamic>>[
            if (mentionEveryone) {'everyone': true},
            for (final uid in mentionedUids) {'uid': uid},
          ],
        });
      } catch (e, st) {
        // Chat write succeeded; mention push is a nice-to-have. Log a
        // non-fatal breadcrumb so we can diagnose "@mention didn't
        // notify them" support reports without surfacing an error toast
        // on a successful chat send.
        FirebaseCrashlytics.instance.recordError(
          e, st,
          reason: 'chat.mentions push failed (chat write succeeded)',
          fatal: false,
        );
      }
    }

    return ChatSendResult(
      messageId: doc.id,
      text: body,
      imageUrl: null,
      messageType: ChatMessageType.text,
    );
  }

  /// Typeahead candidates for the @mention picker. Returns up to 12
  /// users whose displayName or email contains [query]. Empty/short
  /// queries return an empty list — caller debounces.
  Future<List<MentionCandidate>> mentionCandidates(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const <MentionCandidate>[];
    try {
      final j = await _api.getJson(
        '/api/chat/users-for-mention?q=${Uri.encodeQueryComponent(q)}',
      );
      final raw = (j['candidates'] as List?) ?? const <dynamic>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(MentionCandidate.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const <MentionCandidate>[];
    }
  }

  /// Picks an image from the gallery and uploads it. Returns
  /// [ChatSendResult.cancelledResult] if the user cancels the picker.
  Future<ChatSendResult> pickAndSendImage({
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
    if (picked == null) return ChatSendResult.cancelledResult;

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

    final DocumentReference<Map<String, dynamic>> doc =
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
        : (roomId == 'admin_buys'
            ? '🚨 New admin trade screenshot'
            : roomId == 'gains'
                ? '📸 New gain screenshot posted'
                : '📸 New screenshot posted');
    await _bumpRoom(
        roomId: roomId, roomTitle: roomTitle, lastMessage: summary);
    return ChatSendResult(
      messageId: doc.id,
      text: trimmedCaption,
      imageUrl: url,
      messageType: ChatMessageType.image,
    );
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

/// A user candidate surfaced by the @mention typeahead. The picker
/// returns these from `ChatRepository.mentionCandidates()`. uid is the
/// value that gets sent to the mentions endpoint when the user picks.
class MentionCandidate {
  const MentionCandidate({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoURL,
  });
  final String uid;
  final String displayName;
  final String email;
  final String photoURL;

  /// What the chat input inserts when this candidate is picked. Spaces
  /// in display names are stripped so the @mention is contiguous and
  /// parseable. Falls back to the email-local-part when displayName is
  /// missing.
  String get insertionToken {
    final src = displayName.isNotEmpty
        ? displayName
        : (email.contains('@') ? email.split('@').first : email);
    return src.replaceAll(' ', '_');
  }

  factory MentionCandidate.fromJson(Map<String, dynamic> j) => MentionCandidate(
        uid: (j['uid'] ?? '').toString(),
        displayName: (j['displayName'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        photoURL: (j['photoURL'] ?? '').toString(),
      );
}
