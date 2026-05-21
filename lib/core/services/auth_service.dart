import 'package:firebase_auth/firebase_auth.dart';
import '../utils/result.dart';

/// Auth facade. Wraps FirebaseAuth so feature code never imports
/// firebase_auth directly - easier to swap or mock later.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<Result<User>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final User? u = cred.user;
      if (u == null) return const Failure('Unknown sign-in error.');
      return Success(u);
    } on FirebaseAuthException catch (e) {
      return Failure(_friendly(e), e);
    } catch (e) {
      return Failure('Unexpected sign-in error.', e);
    }
  }

  Future<Result<User>> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final User? u = cred.user;
      if (u == null) return const Failure('Unknown sign-up error.');
      if (displayName != null && displayName.isNotEmpty) {
        await u.updateDisplayName(displayName);
      }
      return Success(u);
    } on FirebaseAuthException catch (e) {
      return Failure(_friendly(e), e);
    } catch (e) {
      return Failure('Unexpected sign-up error.', e);
    }
  }

  Future<Result<void>> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return const Success(null);
    } on FirebaseAuthException catch (e) {
      return Failure(_friendly(e), e);
    } catch (e) {
      return Failure('Unable to send reset email.', e);
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<String?> idToken({bool forceRefresh = false}) async {
    final User? u = _auth.currentUser;
    if (u == null) return null;
    return u.getIdToken(forceRefresh);
  }

  String _friendly(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password is too weak. Try at least 8 characters.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }
}
