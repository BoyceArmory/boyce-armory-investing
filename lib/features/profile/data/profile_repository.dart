import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/api_client.dart';

/// Profile-related writes for the signed-in user. Routes through the backend
/// `/api/users/me` for fields that need server-side validation; direct
/// Firestore for fields the rules already gate (photoUrl, displayName).
class ProfileRepository {
  ProfileRepository({
    required ApiClient apiClient,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ImagePicker? imagePicker,
  })  : _api = apiClient,
        _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _picker = imagePicker ?? ImagePicker();

  final ApiClient _api;
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  /// Pick an image from the gallery, upload to Storage at
  /// `avatars/{uid}.jpg`, then write the download URL to `users/{uid}.photoUrl`.
  /// Returns the new photoUrl, or null if the user cancelled the picker.
  Future<String?> pickAndUploadAvatar({
    ImageSource source = ImageSource.gallery,
  }) async {
    final User? u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in.');

    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return null;

    final Reference ref = _storage.ref().child('avatars').child('${u.uid}.jpg');
    await ref.putFile(
      File(picked.path),
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: <String, String>{
          'uid': u.uid,
          'uploadedFrom': 'profile',
        },
      ),
    );
    final String url = await ref.getDownloadURL();

    await _db.collection('users').doc(u.uid).set(
      <String, dynamic>{
        'photoUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await u.updatePhotoURL(url);
    return url;
  }

  Future<void> updateDisplayName(String name) async {
    final User? u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in.');
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await u.updateDisplayName(trimmed);
    // Backend writes through the allowlist so disabled/tier/role can never be
    // touched by accident.
    await _api.patchJson('/api/users/me', body: {'displayName': trimmed});
  }

  Future<void> updateNickname(String nickname) async {
    final String trimmed = nickname.trim();
    if (trimmed.isEmpty) return;
    await _api.patchJson('/api/users/me', body: {'nickname': trimmed});
  }

  /// Calls the backend cascade: deactivate device tokens, anonymize users doc,
  /// audit log. After this returns, the local Firebase Auth user should be
  /// deleted (backend does that too); the client should pop back to sign-in.
  Future<void> deleteAccountCascade() async {
    await _api.deleteJson('/api/users/me');
  }
}
