import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/enums.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/utils/result.dart';

/// Bundles auth + Firestore user-doc creation so feature code only deals with
/// one Result.
class AuthRepository {
  AuthRepository({
    required AuthService authService,
    required FirestoreService firestoreService,
  })  : _auth = authService,
        _fs = firestoreService;

  final AuthService _auth;
  final FirestoreService _fs;

  Future<Result<User>> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmail(email: email, password: password);
  }

  Future<Result<User>> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final Result<User> result = await _auth.registerWithEmail(
      email: email,
      password: password,
      displayName: displayName,
    );
    if (result is Failure<User>) return result;
    final User u = (result as Success<User>).value;
    await _ensureUserDoc(u, displayName: displayName);
    return Success(u);
  }

  Future<Result<void>> sendPasswordReset(String email) =>
      _auth.sendPasswordReset(email);

  Future<void> signOut() => _auth.signOut();

  Future<void> _ensureUserDoc(User u, {String? displayName}) async {
    final DocumentReference<Map<String, dynamic>> ref =
        _fs.users.doc(u.uid);
    final DocumentSnapshot<Map<String, dynamic>> snap = await ref.get();
    if (snap.exists) return;
    await ref.set(<String, dynamic>{
      'uid': u.uid,
      'email': u.email,
      'displayName': displayName ?? u.displayName,
      'role': UserRole.customer.wire,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
