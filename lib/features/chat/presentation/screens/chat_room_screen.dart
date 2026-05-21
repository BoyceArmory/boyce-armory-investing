import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import '../../../../shared/widgets/screen_header.dart';
import '../../data/chat_models.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_message_bubble.dart';

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
  bool _sending = false;
  bool _uploading = false;

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
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
      await ref.read(chatRepositoryProvider).sendText(
            roomId: room.id,
            roomTitle: room.title,
            text: text,
            senderName: _senderName(appUser, fbUser, isAdmin: isAdmin),
            profileImageUrl: appUser?.photoUrl,
            isAdmin: isAdmin,
          );
    } catch (e) {
      if (mounted) context.showSnack('Send failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
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
      final bool ok = await ref.read(chatRepositoryProvider).pickAndSendImage(
            roomId: room.id,
            roomTitle: room.title,
            caption: caption,
            senderName: _senderName(appUser, fbUser, isAdmin: isAdmin),
            profileImageUrl: appUser?.photoUrl,
            isAdmin: isAdmin,
          );
      if (ok) _composer.clear();
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
    final AsyncValue<List<ChatMessage>> async =
        ref.watch(chatMessagesProvider(widget.roomId));
    final User? fbUser = ref.watch(currentFirebaseUserProvider);
    final String currentUid = fbUser?.uid ?? '';

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
          _Composer(
            controller: _composer,
            allowImages: room?.allowImages ?? true,
            sending: _sending,
            uploading: _uploading,
            onSend: _sendText,
            onUpload: _sendImage,
          ),
        ],
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
    required this.allowImages,
    required this.sending,
    required this.uploading,
    required this.onSend,
    required this.onUpload,
  });
  final TextEditingController controller;
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
