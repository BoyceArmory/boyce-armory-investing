import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_providers.dart';
import '../../../../core/providers/auth_state_provider.dart';
import '../../data/chat_models.dart';
import '../../data/chat_prefs_service.dart';
import '../../data/chat_repository.dart';
import '../../data/chat_rooms.dart';

final Provider<ChatRepository> chatRepositoryProvider =
    Provider<ChatRepository>((Ref ref) =>
        ChatRepository(apiClient: ref.watch(apiClientProvider)));

final Provider<ChatPrefsService> chatPrefsServiceProvider =
    Provider<ChatPrefsService>((Ref ref) => ChatPrefsService());

/// Streams the current user's chat prefs (lastRead + mutes per room).
/// Empty default when no user is signed in so chat home can still render.
final StreamProvider<ChatPrefs> chatPrefsProvider =
    StreamProvider<ChatPrefs>((Ref ref) {
  final user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return Stream.value(const ChatPrefs());
  return ref.watch(chatPrefsServiceProvider).streamPrefs(user.uid);
});

/// True when this room is muted for the current user.
final ProviderFamily<bool, String> chatRoomMutedProvider =
    Provider.family<bool, String>((Ref ref, String roomId) {
  return ref.watch(chatPrefsProvider).maybeWhen(
        data: (p) => p.isMuted(roomId),
        orElse: () => false,
      );
});

/// Unread message count for [roomId] = number of messages with
/// `createdAt > lastReadAt`. Returns 0 if muted (badges shouldn't yell
/// at the user for muted rooms — they'll see them at their own pace).
/// Hard-capped at 99 client-side so the badge doesn't blow up.
final StreamProviderFamily<int, String> chatRoomUnreadCountProvider =
    StreamProvider.family<int, String>((Ref ref, String roomId) {
  if (ref.watch(chatRoomMutedProvider(roomId))) return Stream.value(0);
  final lastReadAsync = ref.watch(chatPrefsProvider);
  final lastRead = lastReadAsync.maybeWhen(
    data: (p) => p.lastReadFor(roomId),
    orElse: () => null,
  );
  // No lastRead yet — treat as "everything is read" so first-login
  // users don't see fake unreads. The room enter handler stamps it
  // anyway, so the next message will count correctly.
  if (lastRead == null) return Stream.value(0);
  return ref
      .watch(chatRepositoryProvider)
      .streamMessages(roomId, limit: 100)
      .map((messages) {
    final count = messages
        .where((m) => !m.deleted && m.createdAt.isAfter(lastRead))
        .length;
    return count > 99 ? 99 : count;
  });
});

final Provider<List<ChatRoomDef>> chatRoomsProvider =
    Provider<List<ChatRoomDef>>((Ref ref) => chatRooms);

/// Total unread across all configured chat rooms. Used by the bottom-nav
/// Chat tab badge so users see "something is waiting" from anywhere in
/// the app. Sums each room's per-room unread provider and short-circuits
/// at 99 so the badge stays readable.
final Provider<int> chatTotalUnreadProvider = Provider<int>((Ref ref) {
  final rooms = ref.watch(chatRoomsProvider);
  int total = 0;
  for (final r in rooms) {
    final n = ref.watch(chatRoomUnreadCountProvider(r.id)).maybeWhen(
          data: (v) => v,
          orElse: () => 0,
        );
    total += n;
    if (total >= 99) return 99;
  }
  return total;
});

final ProviderFamily<ChatRoomDef?, String> chatRoomByIdProvider =
    Provider.family<ChatRoomDef?, String>((Ref ref, String id) {
  for (final ChatRoomDef r in ref.watch(chatRoomsProvider)) {
    if (r.id == id) return r;
  }
  return null;
});

final StreamProviderFamily<List<ChatMessage>, String> chatMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((Ref ref, String roomId) {
  return ref.watch(chatRepositoryProvider).streamMessages(roomId);
});
