import 'package:flutter/material.dart';
import '../../../core/constants/asset_paths.dart';
import 'chat_models.dart';

/// The rooms Boyce Armory ships with. Add or rename here.
const List<ChatRoomDef> chatRooms = <ChatRoomDef>[
  // Admin-only broadcast room: Jonathan posts screenshots of his real trades
  // and every post fires a push notification to all users in real time.
  // Read-only for everyone else. THIS IS THE PROOF-OF-CONCEPT CHANNEL.
  ChatRoomDef(
    id: 'admin_buys',
    title: 'ADMIN BUYS',
    description:
        'Real-time screenshots of Boyce Armory trades. Every post pushes to your phone.',
    icon: Icons.bolt,
    adminOnly: true,
    broadcastPush: true,
  ),
  ChatRoomDef(
    id: 'general',
    title: 'General Chat',
    description: 'Open community discussion.',
    icon: Icons.forum_outlined,
    iconAsset: AssetPaths.chatRoomGeneral,
  ),
  ChatRoomDef(
    id: 'gains',
    title: 'SHOW THEM GAINS',
    description: 'Post your screenshots. Celebrate the wins.',
    icon: Icons.trending_up,
    iconAsset: AssetPaths.chatRoomGains,
  ),
  ChatRoomDef(
    id: 'questions',
    title: 'Questions',
    description: 'Ask anything. Charts encouraged.',
    icon: Icons.help_outline,
    iconAsset: AssetPaths.chatRoomQuestions,
  ),
  ChatRoomDef(
    id: 'watchlist',
    title: 'Watchlist Talk',
    description: 'What is on your radar this week.',
    icon: Icons.visibility_outlined,
    iconAsset: AssetPaths.chatRoomWatchlist,
  ),
];
