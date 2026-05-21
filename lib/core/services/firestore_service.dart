import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';

/// Thin wrapper around FirebaseFirestore with strongly-typed collection
/// references used across features. Centralizes collection names so refactors
/// are mechanical.
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  FirebaseFirestore get db => _db;

  CollectionReference<Map<String, dynamic>> get users =>
      _db.collection(FirestoreCollections.users);
  CollectionReference<Map<String, dynamic>> get scannerResults =>
      _db.collection(FirestoreCollections.scannerResults);
  CollectionReference<Map<String, dynamic>> get scannerAlerts =>
      _db.collection(FirestoreCollections.scannerAlerts);
  CollectionReference<Map<String, dynamic>> get tradeAlerts =>
      _db.collection(FirestoreCollections.tradeAlerts);
  CollectionReference<Map<String, dynamic>> get activeTrades =>
      _db.collection(FirestoreCollections.activeTrades);
  CollectionReference<Map<String, dynamic>> get closedTrades =>
      _db.collection(FirestoreCollections.closedTrades);
  CollectionReference<Map<String, dynamic>> get performanceStats =>
      _db.collection(FirestoreCollections.performanceStats);
  CollectionReference<Map<String, dynamic>> get dailyRecaps =>
      _db.collection(FirestoreCollections.dailyRecaps);
  CollectionReference<Map<String, dynamic>> get notifications =>
      _db.collection(FirestoreCollections.notifications);
  CollectionReference<Map<String, dynamic>> get deviceTokens =>
      _db.collection(FirestoreCollections.deviceTokens);
}
