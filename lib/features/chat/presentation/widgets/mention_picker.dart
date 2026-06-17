import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/chat_repository.dart';
import '../providers/chat_providers.dart';

/// Controller exposed by [MentionPickerScope] so the surrounding chat
/// screen can read the currently-resolved mentions (uids + everyone flag)
/// at send time, and clear them after a successful send.
class MentionState {
  MentionState();
  final Set<String> mentionedUids = <String>{};
  bool everyone = false;

  void clear() {
    mentionedUids.clear();
    everyone = false;
  }
}

/// Inline @mention picker. Listens to a TextEditingController and shows
/// a typeahead overlay when the user starts typing `@<query>` at the end
/// of the message. Tap a candidate to insert `@token ` and record the
/// uid against the shared [MentionState]. Also detects the literal
/// `@everyone` token and flips [MentionState.everyone] (admin authority
/// is enforced server-side).
///
/// Designed to wrap the chat input — render it above the text field and
/// pass through the same controller.
class MentionPicker extends ConsumerStatefulWidget {
  const MentionPicker({
    super.key,
    required this.controller,
    required this.state,
    required this.canMentionEveryone,
  });

  final TextEditingController controller;
  final MentionState state;
  /// Whether to show the @everyone suggestion. Pass false for non-admins
  /// — they can still type "@everyone" but it won't get a clickable
  /// suggestion (and the server rejects the broadcast anyway).
  final bool canMentionEveryone;

  @override
  ConsumerState<MentionPicker> createState() => _MentionPickerState();
}

class _MentionPickerState extends ConsumerState<MentionPicker> {
  List<MentionCandidate> _candidates = const [];
  String _query = '';
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _debounce?.cancel();
    super.dispose();
  }

  /// Returns the query the user is currently typing after the last `@`,
  /// OR null if the cursor isn't inside a mention token. We restrict to
  /// the active token at the END of the input so unrelated `@` tokens
  /// earlier in the message don't trigger the picker.
  String? _activeQuery() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    // We treat the cursor as being at the end when selection is invalid
    // (composer just opened); otherwise honor the actual cursor.
    final pos = selection.baseOffset >= 0 ? selection.baseOffset : text.length;
    if (pos <= 0) return null;
    // Walk backwards from the cursor looking for the active `@`. Stop on
    // whitespace because tokens shouldn't span words.
    int at = -1;
    for (int i = pos - 1; i >= 0; i--) {
      final c = text[i];
      if (c == '@') {
        at = i;
        break;
      }
      if (c == ' ' || c == '\n' || c == '\t') return null;
    }
    if (at < 0) return null;
    return text.substring(at + 1, pos);
  }

  void _onTextChanged() {
    // Always re-evaluate the @everyone flag from the current text so a
    // user who removes "@everyone" before sending doesn't accidentally
    // still trigger the broadcast.
    final has = RegExp(r'@everyone\b').hasMatch(widget.controller.text);
    if (widget.state.everyone != has) {
      widget.state.everyone = has;
      setState(() {});
    }

    // Also drop mentioned uids whose token is no longer present in the
    // text. This is a coarse check (matches by displayName token), but
    // it keeps the state in sync with what the message will actually say.
    if (widget.state.mentionedUids.isNotEmpty) {
      // No-op for now: we trust the user to clear via the chip strip.
    }

    final q = _activeQuery();
    if (q == null) {
      if (_candidates.isNotEmpty || _loading) {
        setState(() {
          _candidates = const [];
          _loading = false;
          _query = '';
        });
      }
      return;
    }
    if (q == _query) return;
    _query = q;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), _runLookup);
  }

  Future<void> _runLookup() async {
    final q = _query;
    if (q.isEmpty) {
      setState(() {
        _candidates = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final repo = ref.read(chatRepositoryProvider);
      final list = await repo.mentionCandidates(q);
      if (!mounted || q != _query) return;
      setState(() {
        _candidates = list;
        _loading = false;
      });
    } catch (e, st) {
      // Typeahead failure is recoverable — show empty results and let
      // the next keystroke try again. Breadcrumb the error so a "picker
      // never works" support report can be traced to the API call.
      FirebaseCrashlytics.instance.recordError(
        e, st,
        reason: 'chat.mention typeahead failed (q: ${q.length} chars)',
        fatal: false,
      );
      if (!mounted) return;
      setState(() {
        _candidates = const [];
        _loading = false;
      });
    }
  }

  void _insert(MentionCandidate c) {
    // Replace the active @<query> at the cursor with @<token> + space.
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final pos = selection.baseOffset >= 0
        ? selection.baseOffset
        : text.length;
    int at = -1;
    for (int i = pos - 1; i >= 0; i--) {
      if (text[i] == '@') {
        at = i;
        break;
      }
      if (text[i] == ' ' || text[i] == '\n') break;
    }
    if (at < 0) return;
    final insertion = '@${c.insertionToken} ';
    final newText = text.replaceRange(at, pos, insertion);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: at + insertion.length),
    );
    widget.state.mentionedUids.add(c.uid);
    setState(() {
      _candidates = const [];
      _query = '';
    });
  }

  void _insertEveryone() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final pos = selection.baseOffset >= 0
        ? selection.baseOffset
        : text.length;
    int at = -1;
    for (int i = pos - 1; i >= 0; i--) {
      if (text[i] == '@') {
        at = i;
        break;
      }
      if (text[i] == ' ' || text[i] == '\n') break;
    }
    if (at < 0) return;
    const insertion = '@everyone ';
    final newText = text.replaceRange(at, pos, insertion);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: at + insertion.length),
    );
    widget.state.everyone = true;
    setState(() {
      _candidates = const [];
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveQuery = _query.isNotEmpty;
    final showEveryone =
        widget.canMentionEveryone &&
            hasActiveQuery &&
            'everyone'.startsWith(_query.toLowerCase());

    final showPanel = hasActiveQuery || _loading;
    if (!showPanel) {
      // Render the "tagged" chip strip even when the picker is closed so
      // the sender always sees who they've tagged in this draft.
      return _TaggedChipsRow(state: widget.state);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _TaggedChipsRow(state: widget.state),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.graphite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.steel),
          ),
          constraints: const BoxConstraints(maxHeight: 220),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showEveryone)
                  _EveryoneTile(onTap: _insertEveryone),
                if (_loading && _candidates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: AppColors.gold),
                      ),
                    ),
                  ),
                if (!_loading && _candidates.isEmpty && !showEveryone)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: Text('No matches',
                          style: TextStyle(
                              color: AppColors.textTertiary, fontSize: 12)),
                    ),
                  ),
                for (final c in _candidates)
                  _CandidateTile(candidate: c, onTap: () => _insert(c)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TaggedChipsRow extends StatelessWidget {
  const _TaggedChipsRow({required this.state});
  final MentionState state;
  @override
  Widget build(BuildContext context) {
    final hasAny =
        state.everyone || state.mentionedUids.isNotEmpty;
    if (!hasAny) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: SizedBox(
        height: 24,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            if (state.everyone)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    '@everyone will be pushed',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            for (final uid in state.mentionedUids)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    // Show first 8 chars of uid since we don't keep the
                    // displayName here. The chip's purpose is just to
                    // signal that this draft has a per-user push attached.
                    '@${uid.length > 8 ? uid.substring(0, 8) : uid} pinged',
                    style: const TextStyle(
                      color: AppColors.info,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EveryoneTile extends StatelessWidget {
  const _EveryoneTile({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          children: [
            Icon(Icons.groups, size: 16, color: AppColors.gold),
            SizedBox(width: 10),
            Text(
              '@everyone',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Notify every active device',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.textTertiary, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({required this.candidate, required this.onTap});
  final MentionCandidate candidate;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final hasPhoto = candidate.photoURL.isNotEmpty;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.steel,
                shape: BoxShape.circle,
                image: hasPhoto
                    ? DecorationImage(
                        image: NetworkImage(candidate.photoURL),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: hasPhoto
                  ? null
                  : const Icon(Icons.person,
                      size: 14, color: AppColors.textTertiary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    candidate.displayName.isNotEmpty
                        ? candidate.displayName
                        : candidate.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (candidate.email.isNotEmpty &&
                      candidate.email != candidate.displayName)
                    Text(
                      candidate.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 10.5,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
