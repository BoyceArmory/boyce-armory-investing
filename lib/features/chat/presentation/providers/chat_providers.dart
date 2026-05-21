import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/chat_models.dart';
import '../../data/chat_repository.dart';
import '../../data/chat_rooms.dart';

final Provider<ChatRepository> chatRepositoryProvider =
    Provider<ChatRepository>((Ref ref) => ChatRepository());

final Provider<List<ChatRoomDef>> chatRoomsProvider =
    Provider<List<ChatRoomDef>>((Ref ref) => chatRooms);

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
