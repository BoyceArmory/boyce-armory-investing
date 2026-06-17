import 'package:cloud_firestore/cloud_firestore.dart';

/// Per-user chat prefs that live on `users/{uid}`:
///   - chatLastRead: { roomId: ISO timestamp string }
///   - chatMutes:    { roomId: bool }
///
/// These power:
///   - Unread badges on chat home (count of messages after lastRead)
///   - Per-room push mute (badge suppressed + future push-fan-out skip)
class ChatPrefsService {
  ChatPrefsService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  Stream<ChatPrefs> streamPrefs(String uid) {
    return _userRef(uid).snapshots().map((snap) {
      final data = snap.data() ?? const <String, dynamic>{};
      final lastRead = <String, DateTime>{};
      final lastReadRaw = (data['chatLastRead'] as Map?) ?? const {};
      lastReadRaw.forEach((k, v) {
        final key = k?.toString();
        final ts = v is String ? DateTime.tryParse(v) : null;
        if (key != null && ts != null) lastRead[key] = ts;
      });
      // chatMutes value can be:
      //   - bool (true = muted forever)
      //   - ISO timestamp string (muted until that moment)
      // Past timestamps are dropped here so callers see the room as
      // unmuted without having to re-check expiry each time.
      final mutes = <String, bool>{};
      final muteUntil = <String, DateTime>{};
      final mutesRaw = (data['chatMutes'] as Map?) ?? const {};
      mutesRaw.forEach((k, v) {
        final key = k?.toString();
        if (key == null) return;
        if (v is bool) {
          mutes[key] = v;
        } else if (v is String && v.isNotEmpty) {
          final parsed = DateTime.tryParse(v);
          if (parsed != null && parsed.isAfter(DateTime.now())) {
            muteUntil[key] = parsed;
          }
        }
      });
      return ChatPrefs(
        lastRead: lastRead,
        mutes: mutes,
        muteUntil: muteUntil,
      );
    });
  }

  /// Stamp now as the latest read timestamp for this room. Called on
  /// room enter and again on dispose so badges clear immediately.
  Future<void> markRoomRead(String uid, String roomId) async {
    await _userRef(uid).set({
      'chatLastRead': {roomId: DateTime.now().toUtc().toIso8601String()},
    }, SetOptions(merge: true));
  }

  /// Flip the per-room mute. Suppresses the unread badge and the backend
  /// fan-out pushes for messages in this room. Writes `true` for the
  /// classic "muted forever" binary state.
  Future<void> setRoomMuted(String uid, String roomId, bool muted) async {
    await _userRef(uid).set({
      'chatMutes': {roomId: muted},
    }, SetOptions(merge: true));
  }

  /// Temporarily mute a room until [until]. Stored as an ISO timestamp
  /// the backend can parse. Past timestamps are no-ops on read.
  Future<void> setRoomMutedUntil(
      String uid, String roomId, DateTime until) async {
    await _userRef(uid).set({
      'chatMutes': {roomId: until.toUtc().toIso8601String()},
    }, SetOptions(merge: true));
  }

  /// Stamp lastRead = now across every supplied room in a single write.
  /// Used by the chat-home "Mark all read" affordance so long-absent
  /// users can clear every badge in one tap without opening rooms one
  /// at a time. No-op if [roomIds] is empty.
  Future<void> markAllRoomsRead(String uid, List<String> roomIds) async {
    if (roomIds.isEmpty) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final updates = <String, String>{for (final id in roomIds) id: now};
    await _userRef(uid).set({
      'chatLastRead': updates,
    }, SetOptions(merge: true));
  }

  /// Wipe every per-room mute back to unmuted. Paired with the Settings
  /// "Reset notification prefs" action so users get a clean slate across
  /// both notificationPrefs and chatMutes in one move. Writes an empty
  /// map (effectively replacing chatMutes) — does NOT delete the field
  /// outright to avoid races with concurrent reads.
  Future<void> clearAllMutes(String uid) async {
    await _userRef(uid).set({
      'chatMutes': <String, bool>{},
    }, SetOptions(merge: true));
  }
}

class ChatPrefs {
  const ChatPrefs({
    this.lastRead = const <String, DateTime>{},
    this.mutes = const <String, bool>{},
    this.muteUntil = const <String, DateTime>{},
  });
  final Map<String, DateTime> lastRead;
  // Binary "muted forever" entries. Mutually exclusive with muteUntil:
  // setting one clears the other on the next write.
  final Map<String, bool> mutes;
  // Temporary mute timestamps. Only entries with future timestamps reach
  // this map — past entries are filtered at parse time.
  final Map<String, DateTime> muteUntil;

  DateTime? lastReadFor(String roomId) => lastRead[roomId];
  /// True if [roomId] is muted right now — either forever or within an
  /// active temporary window.
  bool isMuted(String roomId) =>
      mutes[roomId] == true || muteUntil.containsKey(roomId);
  /// Returns the future timestamp the temporary mute expires at, or null
  /// if the room isn't on a temporary mute (binary forever or unmuted).
  DateTime? mutedUntilFor(String roomId) => muteUntil[roomId];
}
