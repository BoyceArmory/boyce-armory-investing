import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/enums.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import 'service_providers.dart';

/// Auth state stream from FirebaseAuth.
final StreamProvider<User?> authStateProvider = StreamProvider<User?>(
  (Ref ref) => ref.watch(authServiceProvider).authStateChanges(),
);

/// Currently signed-in FirebaseAuth user (sync access, null if signed out).
final Provider<User?> currentFirebaseUserProvider = Provider<User?>(
  (Ref ref) => ref.watch(authStateProvider).asData?.value,
);

/// Stream of the Firestore `users/{uid}` doc for the signed-in user, parsed
/// into AppUser. Emits null when signed out.
final StreamProvider<AppUser?> appUserProvider = StreamProvider<AppUser?>(
  (Ref ref) {
    final User? fbUser = ref.watch(currentFirebaseUserProvider);
    if (fbUser == null) {
      return Stream<AppUser?>.value(null);
    }
    final FirestoreService fs = ref.watch(firestoreServiceProvider);
    return fs.users.doc(fbUser.uid).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> snap) {
        if (!snap.exists || snap.data() == null) {
          // No user doc yet - treat as customer with bare info.
          return AppUser(
            uid: fbUser.uid,
            role: UserRole.customer,
            email: fbUser.email,
            displayName: fbUser.displayName,
            photoUrl: fbUser.photoURL,
          );
        }
        return AppUser.fromFirestore(snap.id, snap.data()!);
      },
    );
  },
);

/// True if the current user is an admin.
final Provider<bool> isAdminProvider = Provider<bool>(
  (Ref ref) => ref.watch(appUserProvider).asData?.value?.isAdmin ?? false,
);

/// Safety ceiling: resolves true 1.5s after first read so the splash can
/// never get pinned forever if Firebase is slow or stalled.
final FutureProvider<bool> _bootstrapTimedOutProvider = FutureProvider<bool>(
  (Ref ref) async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    return true;
  },
);

/// True while we're still figuring out auth (showing the splash).
/// Falls back to false after [_bootstrapTimedOutProvider] elapses so the
/// app never hangs on splash if Firebase fails to emit.
final Provider<bool> authBootstrappingProvider = Provider<bool>(
  (Ref ref) {
    final AsyncValue<User?> auth = ref.watch(authStateProvider);
    final bool timedOut =
        ref.watch(_bootstrapTimedOutProvider).asData?.value ?? false;
    return auth.isLoading && !timedOut;
  },
);
