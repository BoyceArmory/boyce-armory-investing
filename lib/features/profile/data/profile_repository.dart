import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Profile-related writes: photo upload + display name updates.
class ProfileRepository {
  ProfileRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ImagePicker? imagePicker,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _picker = imagePicker ?? ImagePicker();

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
    await _db.collection('users').doc(u.uid).set(
      <String, dynamic>{
        'displayName': trimmed,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
