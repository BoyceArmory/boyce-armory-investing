import 'package:flutter/material.dart';
import '../../../core/constants/asset_paths.dart';
import 'chat_models.dart';

/// The rooms Boyce Armory ships with. Add or rename here.
const List<ChatRoomDef> chatRooms = <ChatRoomDef>[
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
