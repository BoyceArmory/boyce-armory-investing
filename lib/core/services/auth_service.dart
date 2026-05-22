import 'package:firebase_auth/firebase_auth.dart';
import '../utils/result.dart';

/// Auth facade. Wraps FirebaseAuth so feature code never imports
/// firebase_auth directly — easier to swap or mock later.
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

  // ----- Recent-sign-in-required operations -------------------------------
  // Firebase requires a fresh credential for sensitive actions (delete,
  // change email, change password). The Flutter UI prompts for the current
  // password and we re-auth before the actual operation, so the user gets a
  // useful error instead of "requires-recent-login".

  Future<Result<void>> reauthenticate(String currentPassword) async {
    try {
      final User? u = _auth.currentUser;
      if (u == null || u.email == null) {
        return const Failure('Not signed in or no email on file.');
      }
      final cred = EmailAuthProvider.credential(
        email: u.email!,
        password: currentPassword,
      );
      await u.reauthenticateWithCredential(cred);
      return const Success(null);
    } on FirebaseAuthException catch (e) {
      return Failure(_friendly(e), e);
    } catch (e) {
      return Failure('Re-authentication failed.', e);
    }
  }

  Future<Result<void>> updatePassword(String newPassword) async {
    try {
      final User? u = _auth.currentUser;
      if (u == null) return const Failure('Not signed in.');
      if (newPassword.length < 8) {
        return const Failure('Use at least 8 characters.');
      }
      await u.updatePassword(newPassword);
      return const Success(null);
    } on FirebaseAuthException catch (e) {
      return Failure(_friendly(e), e);
    } catch (e) {
      return Failure('Unable to update password.', e);
    }
  }

  /// Newer Firebase Auth requires verifyBeforeUpdateEmail — sends a
  /// verification link to the new address. The user clicks it, and the email
  /// only switches over once verified.
  Future<Result<void>> updateEmail(String newEmail) async {
    try {
      final User? u = _auth.currentUser;
      if (u == null) return const Failure('Not signed in.');
      final trimmed = newEmail.trim();
      if (!trimmed.contains('@')) return const Failure('Enter a valid email.');
      await u.verifyBeforeUpdateEmail(trimmed);
      return const Success(null);
    } on FirebaseAuthException catch (e) {
      return Failure(_friendly(e), e);
    } catch (e) {
      return Failure('Unable to update email.', e);
    }
  }

  Future<Result<void>> deleteAccount() async {
    try {
      final User? u = _auth.currentUser;
      if (u == null) return const Failure('Not signed in.');
      await u.delete();
      return const Success(null);
    } on FirebaseAuthException catch (e) {
      return Failure(_friendly(e), e);
    } catch (e) {
      return Failure('Unable to delete account.', e);
    }
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
      case 'requires-recent-login':
        return 'Please sign in again to confirm this change.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }
}
