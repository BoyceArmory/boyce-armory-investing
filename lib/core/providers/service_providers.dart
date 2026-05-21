import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/messaging_service.dart';

/// App-wide Riverpod providers for shared services.
///
/// These are intentionally `Provider` (not `Provider.autoDispose`) because
/// services are singletons for the lifetime of the app.

final Provider<AuthService> authServiceProvider = Provider<AuthService>(
  (Ref ref) => AuthService(),
);

final Provider<FirestoreService> firestoreServiceProvider =
    Provider<FirestoreService>((Ref ref) => FirestoreService());

final Provider<MessagingService> messagingServiceProvider =
    Provider<MessagingService>((Ref ref) => MessagingService());
