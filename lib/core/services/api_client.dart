import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/api_config.dart';

/// Thin REST client over the Boyce Armory backend. Automatically attaches
/// the signed-in Firebase user's ID token as `Authorization: Bearer <token>`.
///
/// Throws [ApiException] for non-2xx responses so callers can show useful
/// error UI instead of mystery failures.
class ApiClient {
  ApiClient({FirebaseAuth? auth, http.Client? client})
      : _auth = auth ?? FirebaseAuth.instance,
        _client = client ?? http.Client();

  final FirebaseAuth _auth;
  final http.Client _client;

  // ---------- public ----------

  Future<Map<String, dynamic>> getJson(String path) async {
    final http.Response r = await _send('GET', path);
    return _parseJson(r);
  }

  Future<List<dynamic>> getJsonList(String path) async {
    final http.Response r = await _send('GET', path);
    final dynamic decoded = jsonDecode(r.body);
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic> && decoded['results'] is List) {
      return decoded['results'] as List<dynamic>;
    }
    throw ApiException(r.statusCode, 'Expected list, got: $decoded');
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final http.Response r = await _send('POST', path, body: body);
    return _parseJson(r);
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final http.Response r = await _send('PATCH', path, body: body);
    return _parseJson(r);
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final http.Response r = await _send('DELETE', path, body: body);
    return _parseJson(r);
  }

  // ---------- internals ----------

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    // First attempt with the cached ID token. On 401 we force a token
    // refresh and retry exactly once. This covers the edge case where
    // the cached token JUST expired between our getIdToken() call and
    // the server validating it - happens on long-lived sessions or
    // when the device clock skews. Without this retry the user sees
    // a one-shot ApiException(401) error and has to manually back out
    // and re-tap. Retry once, then give up.
    http.Response r = await _attempt(method, path, body: body, forceRefresh: false);
    if (r.statusCode == 401 && _auth.currentUser != null) {
      r = await _attempt(method, path, body: body, forceRefresh: true);
    }
    return r;
  }

  Future<http.Response> _attempt(
    String method,
    String path, {
    Map<String, dynamic>? body,
    required bool forceRefresh,
  }) async {
    final Uri url = Uri.parse('${ApiConfig.baseUrl}$path');
    final Map<String, String> headers = await _headers(forceRefresh: forceRefresh);
    final String? jsonBody = body == null ? null : jsonEncode(body);

    Future<http.Response> futureRes;
    switch (method) {
      case 'GET':
        futureRes = _client.get(url, headers: headers);
        break;
      case 'POST':
        futureRes = _client.post(url, headers: headers, body: jsonBody);
        break;
      case 'PATCH':
        futureRes = _client.patch(url, headers: headers, body: jsonBody);
        break;
      case 'DELETE':
        futureRes = _client.delete(url, headers: headers, body: jsonBody);
        break;
      default:
        throw StateError('Unsupported method $method');
    }
    return futureRes.timeout(ApiConfig.timeout);
  }

  Future<Map<String, String>> _headers({bool forceRefresh = false}) async {
    final Map<String, String> h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    try {
      // forceRefresh=true on retry asks Firebase to mint a fresh token
      // server-side rather than returning a cached one. Used after a
      // 401 to recover from JUST-expired tokens.
      final String? token = await _auth.currentUser?.getIdToken(forceRefresh);
      if (token != null && token.isNotEmpty) {
        h['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ApiClient token fetch failed: $e');
    }
    return h;
  }

  Map<String, dynamic> _parseJson(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw ApiException(r.statusCode, _readError(r));
    }
    if (r.body.isEmpty) return <String, dynamic>{};
    final dynamic decoded = jsonDecode(r.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{'data': decoded};
  }

  String _readError(http.Response r) {
    try {
      final dynamic decoded = jsonDecode(r.body);
      if (decoded is Map<String, dynamic>) {
        final dynamic m = decoded['message'] ?? decoded['error'];
        if (m != null) return m.toString();
      }
    } catch (_) {
      // body wasn't json - fall through
    }
    return r.body.isNotEmpty ? r.body : 'HTTP ${r.statusCode}';
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
