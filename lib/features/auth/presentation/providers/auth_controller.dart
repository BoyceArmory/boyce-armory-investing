import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/service_providers.dart';
import '../../../../core/utils/result.dart';
import '../../data/auth_repository.dart';

/// Repository provider for the auth feature.
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) {
  return AuthRepository(
    authService: ref.watch(authServiceProvider),
    firestoreService: ref.watch(firestoreServiceProvider),
  );
});

/// Imperative auth state used by the sign-in / sign-up screens.
class AuthFormState {
  const AuthFormState({
    this.submitting = false,
    this.error,
  });

  final bool submitting;
  final String? error;

  AuthFormState copyWith({bool? submitting, String? error, bool clearError = false}) {
    return AuthFormState(
      submitting: submitting ?? this.submitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthController extends StateNotifier<AuthFormState> {
  AuthController(this._repo) : super(const AuthFormState());

  final AuthRepository _repo;

  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(submitting: true, clearError: true);
    final Result<User> r =
        await _repo.signIn(email: email, password: password);
    return r.when<bool>(
      success: (_) {
        state = const AuthFormState();
        return true;
      },
      failure: (String msg, _) {
        state = state.copyWith(submitting: false, error: msg);
        return false;
      },
    );
  }

  Future<bool> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = state.copyWith(submitting: true, clearError: true);
    final Result<User> r = await _repo.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
    return r.when<bool>(
      success: (_) {
        state = const AuthFormState();
        return true;
      },
      failure: (String msg, _) {
        state = state.copyWith(submitting: false, error: msg);
        return false;
      },
    );
  }

  Future<bool> sendReset(String email) async {
    state = state.copyWith(submitting: true, clearError: true);
    final Result<void> r = await _repo.sendPasswordReset(email);
    return r.when<bool>(
      success: (_) {
        state = const AuthFormState();
        return true;
      },
      failure: (String msg, _) {
        state = state.copyWith(submitting: false, error: msg);
        return false;
      },
    );
  }

  Future<void> signOut() => _repo.signOut();

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }
}

final StateNotifierProvider<AuthController, AuthFormState>
    authControllerProvider =
    StateNotifierProvider<AuthController, AuthFormState>(
        (Ref ref) => AuthController(ref.watch(authRepositoryProvider)));
