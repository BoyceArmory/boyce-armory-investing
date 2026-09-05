import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/asset_paths.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/auth_state_provider.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/premium_gate.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../../../admin/presentation/providers/admin_providers.dart';
import '../../data/chat_models.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/mention_picker.dart';

const List<String> _kReactionOptions = <String>[
  '🔥', '📈', '💰', '👏', '🚀', '🐻', '✅', '👀',
  '💎', '🫡', '📉', '⚠️', '👎', '❌', '🤔', '😬', '🚫', '🛑',
];

class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({super.key, required this.roomId});
  final String roomId;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final TextEditingController _composer = TextEditingController();
  // FocusNode lets us re-focus the composer after a successful send so
  // users can keep typing without re-tapping the field. Disposed in the
  // dispose() below alongside the controller.
  final FocusNode _composerFocus = FocusNode();
  // Holds the @mentions the picker has resolved for this draft. Cleared
  // after a successful send so the next message starts fresh.
  final MentionState _mentionState = MentionState();
  bool _sending = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    // Stamp "read up to now" on enter so the unread badge clears
    // immediately for this room. We do it via a post-frame callback so
    // ref.read is safe (initState runs before the widget is mounted).
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  @override
  void dispose() {
    // Re-stamp on exit so any messages that arrived while the user was
    // looking at the room are counted as read. Best-effort: we kick off
    // the write but don't await — dispose can't be async.
    final user = ref.read(currentFirebaseUserProvider);
    if (user != null) {
      ref
          .read(chatPrefsServiceProvider)
          .markRoomRead(user.uid, widget.roomId)
          .ignore();
    }
    _composer.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    final user = ref.read(currentFirebaseUserProvider);
    if (user == null) return;
    try {
      await ref
          .read(chatPrefsServiceProvider)
          .markRoomRead(user.uid, widget.roomId);
    } catch (e, st) {
      // Best-effort — the next room-enter will retry. Breadcrumb only —
      // if users report "badge won't clear" we have a trail back to the
      // specific Firestore error without surfacing an error toast on
      // every room enter.
      FirebaseCrashlytics.instance.recordError(
        e, st,
        reason: 'chat.markRoomRead failed (room: ${widget.roomId})',
        fatal: false,
      );
    }
  }

  /// Long-press the bell → choose a duration. Saves `chatMutes: { roomId:
  /// ISO timestamp }`. Backend filter treats future timestamps as muted
  /// and ignores expired ones automatically, so the user doesn't need to
  /// remember to un-mute. Tap (not long-press) still uses the binary
  /// forever-mute toggle from `_toggleMute`.
  Future<void> _pickMuteDuration() async {
    final user = ref.read(currentFirebaseUserProvider);
    if (user == null) {
      context.showSnack('Sign in to change notifications.', isError: true);
      return;
    }
    final picked = await showModalBottomSheet<Duration>(
      context: context,
      backgroundColor: AppColors.obsidian,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext c) {
        const options = <(String, Duration)>[
          ('15 min', Duration(minutes: 15)),
          ('1 hour', Duration(hours: 1)),
          ('4 hours', Duration(hours: 4)),
          ('8 hours', Duration(hours: 8)),
          ('24 hours', Duration(hours: 24)),
        ];
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'MUTE THIS ROOM',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pick a window. Mute auto-clears when the timer expires — no need to come back here.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final (label, dur) in options)
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.pop(c, dur),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    AppColors.gold.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null) return;
    final until = DateTime.now().add(picked);
    try {
      await ref
          .read(chatPrefsServiceProvider)
          .setRoomMutedUntil(user.uid, widget.roomId, until);
      if (mounted) {
        final h = until.toLocal().hour.toString().padLeft(2, '0');
        final m = until.toLocal().minute.toString().padLeft(2, '0');
        context.showSnack('Muted until $h:$m');
      }
    } catch (e) {
      if (mounted) context.showSnack('Failed: $e', isError: true);
    }
  }

  Future<void> _toggleMute() async {
    final user = ref.read(currentFirebaseUserProvider);
    if (user == null) {
      context.showSnack('Sign in to change notifications.', isError: true);
      return;
    }
    final muted = ref.read(chatRoomMutedProvider(widget.roomId));
    try {
      await ref
          .read(chatPrefsServiceProvider)
          .setRoomMuted(user.uid, widget.roomId, !muted);
      if (mounted) {
        context.showSnack(
          !muted ? 'Muted this room' : 'Unmuted this room',
        );
      }
    } catch (e) {
      if (mounted) context.showSnack('Failed: $e', isError: true);
    }
  }

  ChatRoomDef? _resolveRoom() =>
      ref.read(chatRoomByIdProvider(widget.roomId));

  String _senderName(AppUser? appUser, User? fbUser, {required bool isAdmin}) {
    if (isAdmin) return 'Boyce Armory 🏆';
    final String? name = (appUser?.displayName?.trim().isNotEmpty ?? false)
        ? appUser!.displayName
        : fbUser?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final String? email = fbUser?.email?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Boyce Armory Member';
  }

  Future<void> _sendText() async {
    final String text = _composer.text.trim();
    if (text.isEmpty || _sending) return;
    final ChatRoomDef? room = _resolveRoom();
    if (room == null) return;
    final AppUser? appUser = ref.read(appUserProvider).asData?.value;
    final User? fbUser = ref.read(currentFirebaseUserProvider);
    if (fbUser == null) {
      context.showSnack('You must be signed in to chat.', isError: true);
      return;
    }
    final bool isAdmin = ref.read(isAdminProvider);

    setState(() => _sending = true);
    _composer.clear();
    try {
      // Block non-admins in admin-only rooms (defense-in-depth — the
      // composer is already hidden but a fast double-tap could still race).
      if (room.adminOnly && !isAdmin) {
        context.showSnack(
          'Only admins can post in this room.',
          isError: true,
        );
        return;
      }
      // Snapshot mentions BEFORE clearing. The picker state lives across
      // sends so we have to copy out before resetting.
      final mentionedUids =
          _mentionState.mentionedUids.toList(growable: false);
      final mentionEveryone = _mentionState.everyone;
      final ChatSendResult? sent =
          await ref.read(chatRepositoryProvider).sendText(
                roomId: room.id,
                roomTitle: room.title,
                text: text,
                senderName: _senderName(appUser, fbUser, isAdmin: isAdmin),
                profileImageUrl: appUser?.photoUrl,
                isAdmin: isAdmin,
                mentionedUids: mentionedUids,
                mentionEveryone: mentionEveryone,
              );
      if (sent != null) {
        // Successful send — reset the picker state for the next message
        // and re-focus the composer so the keyboard stays up. Without
        // this, every send dismisses the keyboard and the user has to
        // tap the field again to keep going.
        _mentionState.clear();
        if (mounted) _composerFocus.requestFocus();
      }
      if (sent != null && room.broadcastPush && isAdmin) {
        await _broadcastIfBroadcastRoom(room: room, result: sent);
      }
    } catch (e) {
      if (mounted) context.showSnack('Send failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Fires the FCM broadcast for an admin post in a broadcastPush room.
  /// Best-effort: the chat message is already saved in Firestore, so we
  /// don't want a broadcast failure to surface as a "post failed" to the
  /// user. Log a snack on error but don't rethrow.
  Future<void> _broadcastIfBroadcastRoom({
    required ChatRoomDef room,
    required ChatSendResult result,
  }) async {
    try {
      await ref.read(adminRepositoryProvider).broadcastChatMessage(
            roomId: room.id,
            roomTitle: room.title,
            messageId: result.messageId,
            text: result.text,
            messageType:
                result.messageType == ChatMessageType.image ? 'image' : 'text',
            imageUrl: result.imageUrl,
          );
    } catch (e) {
      if (mounted) {
        context.showSnack(
          'Posted, but push broadcast failed: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _sendImage() async {
    if (_uploading) return;
    final ChatRoomDef? room = _resolveRoom();
    if (room == null) return;
    if (!room.allowImages) return;

    final AppUser? appUser = ref.read(appUserProvider).asData?.value;
    final User? fbUser = ref.read(currentFirebaseUserProvider);
    if (fbUser == null) {
      context.showSnack('You must be signed in to upload.', isError: true);
      return;
    }
    final bool isAdmin = ref.read(isAdminProvider);
    final String caption = _composer.text;

    setState(() => _uploading = true);
    try {
      if (room.adminOnly && !isAdmin) {
        context.showSnack(
          'Only admins can post in this room.',
          isError: true,
        );
        return;
      }
      final ChatSendResult sent =
          await ref.read(chatRepositoryProvider).pickAndSendImage(
                roomId: room.id,
                roomTitle: room.title,
                caption: caption,
                senderName: _senderName(appUser, fbUser, isAdmin: isAdmin),
                profileImageUrl: appUser?.photoUrl,
                isAdmin: isAdmin,
              );
      if (sent.cancelled) return;
      _composer.clear();
      if (room.broadcastPush && isAdmin) {
        await _broadcastIfBroadcastRoom(room: room, result: sent);
      }
    } catch (e) {
      if (mounted) context.showSnack('Upload failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  bool _canModify(ChatMessage m) {
    final User? fbUser = ref.read(currentFirebaseUserProvider);
    final bool isAdmin = ref.read(isAdminProvider);
    if (isAdmin) return true;
    return fbUser != null &&
        fbUser.uid.isNotEmpty &&
        fbUser.uid == m.senderId;
  }

  Future<void> _toggleReaction(ChatMessage m, String emoji) async {
    final User? fbUser = ref.read(currentFirebaseUserProvider);
    if (fbUser == null) {
      context.showSnack('You must be signed in to react.', isError: true);
      return;
    }
    try {
      await ref.read(chatRepositoryProvider).toggleReaction(
            roomId: widget.roomId,
            message: m,
            emoji: emoji,
          );
    } catch (e) {
      if (mounted) context.showSnack('Reaction failed: $e', isError: true);
    }
  }

  Future<void> _showActionsSheet(ChatMessage m) async {
    final bool canModify = _canModify(m);
    final bool isImage = m.hasImage;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.carbon,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading:
                      const Icon(Icons.emoji_emotions_outlined, color: AppColors.gold),
                  title: const Text('React',
                      style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showReactionPicker(m);
                  },
                ),
                if (canModify)
                  ListTile(
                    leading: const Icon(Icons.edit, color: AppColors.gold),
                    title: Text(
                      isImage ? 'Edit caption' : 'Edit message',
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _editMessage(m);
                    },
                  ),
                if (canModify && isImage)
                  ListTile(
                    leading: const Icon(Icons.image_not_supported_outlined,
                        color: Colors.orangeAccent),
                    title: const Text(
                      'Remove image only',
                      style: TextStyle(color: Colors.orangeAccent),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _removeImageOnly(m);
                    },
                  ),
                if (canModify)
                  ListTile(
                    leading:
                        const Icon(Icons.delete_forever, color: AppColors.bearish),
                    title: const Text(
                      'Delete message',
                      style: TextStyle(color: AppColors.bearish),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _deleteMessage(m);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showReactionPicker(ChatMessage m) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.carbon,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'React to message',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: _kReactionOptions.map((String e) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _toggleReaction(m, e);
                      },
                      child: Container(
                        width: 54,
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.graphite,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.steel),
                        ),
                        child: Text(
                          e,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editMessage(ChatMessage m) async {
    final TextEditingController c = TextEditingController(text: m.text);
    final String? next = await showDialog<String>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        backgroundColor: AppColors.graphite,
        title: Text(
          m.hasImage ? 'Edit caption' : 'Edit message',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 4,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Message…'),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, c.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    c.dispose();
    if (next == null) return;
    try {
      await ref.read(chatRepositoryProvider).editMessage(
            roomId: widget.roomId,
            messageId: m.id,
            newText: next,
          );
    } catch (e) {
      if (mounted) context.showSnack('Edit failed: $e', isError: true);
    }
  }

  Future<void> _deleteMessage(ChatMessage m) async {
    final bool? ok = await _confirm(
      'Delete message?',
      'This will hide the message from the chat.',
    );
    if (ok != true) return;
    try {
      await ref.read(chatRepositoryProvider).deleteMessage(
            roomId: widget.roomId,
            messageId: m.id,
          );
    } catch (e) {
      if (mounted) context.showSnack('Delete failed: $e', isError: true);
    }
  }

  Future<void> _removeImageOnly(ChatMessage m) async {
    final bool? ok = await _confirm(
      'Remove image?',
      'The image will be removed but the caption will remain.',
    );
    if (ok != true) return;
    try {
      await ref.read(chatRepositoryProvider).removeImageOnly(
            roomId: widget.roomId,
            message: m,
          );
    } catch (e) {
      if (mounted) context.showSnack('Remove failed: $e', isError: true);
    }
  }

  Future<bool?> _confirm(String title, String body) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        backgroundColor: AppColors.graphite,
        title: Text(title,
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(body,
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bearish,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _openImage(String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenImage(url: url),
      ),
    );
  }

  /// Open a bottom-sheet search over the recent messages already in
  /// memory. Client-side filter keeps it cheap — no extra reads against
  /// Firestore. The user can tap a result to dismiss; the bubble for it
  /// is already on screen in the underlying list.
  Future<void> _openSearchSheet(List<ChatMessage> messages) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.carbon,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext c) {
        return _ChatSearchSheet(messages: messages);
      },
    );
  }

  String _emptyText(String roomId) {
    switch (roomId) {
      case 'gains':
        return 'No wins posted yet.\nPost screenshots and celebrate the gains.';
      case 'questions':
        return 'No questions yet.\nAsk anything or upload a chart screenshot.';
      default:
        return 'No messages yet.\nStart the community conversation.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ChatRoomDef? room = _resolveRoom();
    final String title = room?.title ?? 'Chat';

    // Sep 2026: ADMIN BUYS is premium-only (see firestore.rules
    // isPremium()). Gate before ever subscribing to chatMessagesProvider so
    // a free-tier user's client doesn't attempt the now-restricted
    // Firestore read at all — they'd just get permission-denied instead of
    // this friendly lock screen.
    final bool isAdminBuysLocked = widget.roomId == 'admin_buys' &&
        !ref.watch(hasPremiumAccessProvider);
    if (isAdminBuysLocked) {
      return Scaffold(
        backgroundColor: AppColors.obsidian,
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(RoutePaths.chat),
          ),
        ),
        body: const PremiumGate(
          featureName: 'ADMIN BUYS',
          description:
              'Live trade call-out screenshots from the desk are a '
              'premium subscriber benefit.',
          child: SizedBox.shrink(),
        ),
      );
    }

    final AsyncValue<List<ChatMessage>> async =
        ref.watch(chatMessagesProvider(widget.roomId));
    final User? fbUser = ref.watch(currentFirebaseUserProvider);
    final String currentUid = fbUser?.uid ?? '';

    final muted = ref.watch(chatRoomMutedProvider(widget.roomId));

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(RoutePaths.chat),
        ),
        actions: [
          IconButton(
            tooltip: 'Search this room',
            onPressed: () => _openSearchSheet(async.asData?.value ?? const []),
            icon: const Icon(Icons.search, color: AppColors.gold),
          ),
          GestureDetector(
            onLongPress: _pickMuteDuration,
            child: IconButton(
              tooltip: muted
                  ? 'Unmute this room (long-press for timed mute)'
                  : 'Mute this room (long-press for timed mute)',
              onPressed: _toggleMute,
              icon: Icon(
                muted
                    ? Icons.notifications_off
                    : Icons.notifications_active,
                color: muted ? AppColors.textTertiary : AppColors.gold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          const ScreenHeader(asset: AssetPaths.headerChatRoom),
          if (_uploading) const _UploadBanner(),
          Expanded(
            child: async.when(
              loading: () => const LoadingIndicator(label: 'Loading messages'),
              error: (Object e, _) => ErrorState(
                message: 'Failed to load messages.',
                details: e.toString(),
                onRetry: () =>
                    ref.invalidate(chatMessagesProvider(widget.roomId)),
              ),
              data: (List<ChatMessage> messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _emptyText(widget.roomId),
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: messages.length,
                  itemBuilder: (BuildContext c, int i) {
                    final ChatMessage m = messages[i];
                    return ChatMessageBubble(
                      message: m,
                      currentUid: currentUid,
                      onLongPress: () => _showActionsSheet(m),
                      onTapImage: _openImage,
                      onToggleReaction: (String e) => _toggleReaction(m, e),
                    );
                  },
                );
              },
            ),
          ),
          // Hide composer entirely when the room is admin-only and the
          // current user isn't an admin. Replace with a small read-only
          // info banner so users understand why they can't post.
          if ((room?.adminOnly ?? false) && !ref.watch(isAdminProvider))
            const _ReadOnlyBanner()
          else ...[
            // @mention typeahead — listens to the composer and renders
            // candidates above the input when the user types @<query>.
            // The picker also surfaces persistent chips for already-
            // resolved mentions so the sender sees who they're pinging.
            MentionPicker(
              controller: _composer,
              state: _mentionState,
              canMentionEveryone: ref.watch(isAdminProvider),
            ),
            _Composer(
              controller: _composer,
              focusNode: _composerFocus,
              allowImages: room?.allowImages ?? true,
              sending: _sending,
              uploading: _uploading,
              onSend: _sendText,
              onUpload: _sendImage,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: AppColors.carbon,
          border: Border(top: BorderSide(color: AppColors.steel, width: 0.5)),
        ),
        child: const Row(
          children: <Widget>[
            Icon(Icons.lock_outline, size: 16, color: AppColors.gold),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'This room is broadcast-only. Watch for live trade screenshots from Boyce Armory.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadBanner extends StatelessWidget {
  const _UploadBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: AppColors.gold.withValues(alpha: 0.12),
      child: const Row(
        children: <Widget>[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.gold,
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Uploading screenshot…',
            style: TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.allowImages,
    required this.sending,
    required this.uploading,
    required this.onSend,
    required this.onUpload,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool allowImages;
  final bool sending;
  final bool uploading;
  final VoidCallback onSend;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final bool canInteract = !sending && !uploading;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
        decoration: const BoxDecoration(
          color: AppColors.obsidian,
          border: Border(top: BorderSide(color: AppColors.steel)),
        ),
        child: Row(
          children: <Widget>[
            if (allowImages)
              IconButton(
                tooltip: 'Upload screenshot',
                onPressed: canInteract ? onUpload : null,
                icon: Icon(
                  Icons.image_outlined,
                  color: canInteract
                      ? AppColors.gold
                      : AppColors.textTertiary,
                ),
              ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: canInteract,
                style: const TextStyle(color: AppColors.textPrimary),
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: allowImages
                      ? 'Type a message or image caption…'
                      : 'Type a message…',
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: canInteract ? onSend : null,
              child: Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color:
                      canInteract ? AppColors.gold : AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.obsidian,
                        ),
                      )
                    : const Icon(Icons.send_rounded,
                        color: AppColors.obsidian),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lightweight in-memory search over the messages currently streamed
/// into the room view. Highlights are not implemented — we just match
/// case-insensitively against the message text and sender name, then
/// render a tappable preview. Empty/short queries show recent messages
/// so the user can scrub even without typing.
class _ChatSearchSheet extends StatefulWidget {
  const _ChatSearchSheet({required this.messages});
  final List<ChatMessage> messages;

  @override
  State<_ChatSearchSheet> createState() => _ChatSearchSheetState();
}

class _ChatSearchSheetState extends State<_ChatSearchSheet> {
  final TextEditingController _q = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  List<ChatMessage> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) {
      return widget.messages.where((m) => !m.deleted).take(40).toList();
    }
    return widget.messages
        .where((m) =>
            !m.deleted &&
            (m.text.toLowerCase().contains(q) ||
                m.senderName.toLowerCase().contains(q)))
        .take(80)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final results = _filtered;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(Icons.search, color: AppColors.gold),
                  SizedBox(width: 10),
                  Text(
                    'Search this room',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _q,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Find a word, ticker, or sender…',
                  prefixIcon: Icon(Icons.filter_list, color: AppColors.gold),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              if (results.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No matches in the last 100 messages.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: results.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: AppColors.steel, height: 1),
                    itemBuilder: (BuildContext c, int i) {
                      final m = results[i];
                      return ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        title: Text(
                          m.senderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          m.text.isEmpty ? '(image)' : m.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        trailing: Text(
                          _fmtTime(m.createdAt),
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtTime(DateTime t) {
    final local = t.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    if (sameDay) return '$h:$m';
    return '${local.month}/${local.day}';
  }
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Screenshot'),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.7,
          maxScale: 4,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            errorWidget: (_, __, ___) => const EmptyState(
              icon: Icons.broken_image_outlined,
              title: 'Image unavailable',
              message: 'This screenshot could not be loaded.',
            ),
          ),
        ),
      ),
    );
  }
}
