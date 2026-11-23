import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'backup.dart';

const _websiteOrigin = String.fromEnvironment(
  'EVENTPULSE_ORIGIN',
  defaultValue: 'https://eventmanager-5dsz.vercel.app',
);

/// Public website origin used for links shared from the Android app.
const String eventPulseWebsiteOrigin = _websiteOrigin;
const _googleServerClientId =
    '691672067449-77t974d2qnje89n7cd5bci1og45jujfa.apps.googleusercontent.com';
const _secureStorage = MethodChannel('eventpulse/secure_storage');

class BackendException extends HttpException {
  const BackendException(super.message, this.statusCode);
  final int statusCode;
}

class MobileAccount {
  const MobileAccount({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.googleAvatarUrl,
    this.workspaceRole = 'member',
  });

  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String? googleAvatarUrl;
  final String workspaceRole;

  String get displayName => name;
  String? get photoUrl => avatarUrl;

  factory MobileAccount.fromJson(Map<String, dynamic> json) => MobileAccount(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'EventPulse user',
    email: json['email'] as String? ?? '',
    avatarUrl: json['avatarUrl'] as String?,
    googleAvatarUrl: json['googleAvatarUrl'] as String?,
    workspaceRole: json['workspaceRole'] as String? ?? 'member',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'avatarUrl': avatarUrl,
    'googleAvatarUrl': googleAvatarUrl,
    'workspaceRole': workspaceRole,
  };
}

class MobileSyncBatch {
  const MobileSyncBatch({
    required this.snapshot,
    required this.events,
    required this.changes,
    required this.sharedEvents,
    required this.invitations,
    required this.members,
    required this.notifications,
    required this.preferences,
    required this.profile,
  });

  final bool snapshot;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> changes;
  final List<Map<String, dynamic>> sharedEvents;
  final List<Map<String, dynamic>> invitations;
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> notifications;
  final Map<String, dynamic> preferences;
  final Map<String, dynamic> profile;
}

abstract class MobileBackendService {
  Future<MobileAccount?> restoreSession();
  Future<MobileAccount> signInWithGoogle();
  Future<MobileAccount> signInWithPassword(
    String email,
    String password,
  ) async => throw const HttpException('Password sign-in is unavailable.');
  Future<MobileAccount> registerAccount(
    String name,
    String email,
    String password,
  ) async => throw const HttpException('Account registration is unavailable.');
  Future<void> requestPasswordReset(String email) async =>
      throw const HttpException('Password reset is unavailable.');
  Future<MobileSyncBatch> pull();
  Future<void> respondToInvitation(String invitationId, String response);
  Future<Map<String, dynamic>> sendWorkspaceInvitation(String email) async =>
      {};
  Future<Map<String, dynamic>> pullWork() async => {};
  Future<void> saveWorkItem(String kind, Map<String, dynamic> entity) async {}
  Future<void> deleteWorkItem(String kind, String eventId, String id) async {}
  Future<void> uploadEventFile(
    String eventId,
    String name,
    String mimeType,
    List<int> bytes,
  ) async {}
  Future<List<int>> downloadEventFile(
    String fileId,
    String updatedAt,
    int sizeBytes,
  ) async => [];
  Future<List<Map<String, dynamic>>> eventActivity(String eventId) async => [];
  Future<Map<String, dynamic>> eventMembers(String eventId) async => {};
  Future<Map<String, dynamic>> manageEventMembers(
    String eventId,
    String action, {
    String? userId,
    String? memberId,
    String? inviteId,
    String? email,
    String? role,
  }) async => {};
  Future<void> leaveEvent(String eventId) async {}
  Future<Map<String, dynamic>> manageWorkspaceUsers(
    String action, {
    String? userId,
    String? name,
    String? email,
    String? password,
    String? role,
  }) async => {};
  Future<MobileAccount?> updateProfileName(String name) async => null;
  Future<MobileAccount?> updateProfileAvatar(
    String action, {
    String? mimeType,
    String? dataBase64,
  }) async => null;
  Future<void> updatePreferences(Map<String, dynamic> preferences) async {}
  Future<void> markNotificationRead({
    String? notificationId,
    bool markAll = false,
  }) async {}
  Future<String> getCalendarFeed({bool rotate = false}) async => '';
  Future<Map<String, dynamic>> createBackup() async => {};
  Future<void> restoreBackup(Map<String, dynamic> backup) async {}
  Future<Map<String, dynamic>> updateEvent(Map<String, dynamic> event) async =>
      event;
  Future<void> deleteEvent(String eventId) async {}
  Future<List<Map<String, dynamic>>> listTemplates() async => [];
  Future<Map<String, dynamic>> saveTemplate(
    Map<String, dynamic> template,
  ) async => template;
  Future<Map<String, dynamic>> createEvent({
    required String title,
    required String description,
    required String category,
    required String venue,
    required DateTime startsAt,
    int? capacity,
    String visibility = 'private',
  });
  Future<void> signOut({bool revokeDevice = true});
  Future<void> startBackgroundSync() async {}
}

class MobileBackend extends MobileBackendService {
  MobileBackend._();
  static final instance = MobileBackend._();

  final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);
  String? _token;
  String? _deviceId;
  int _cursor = 0;
  bool _googleInitialized = false;

  /// Work-item changes made while offline, retried on the next work pull.
  final List<Map<String, dynamic>> _pendingWork = [];
  bool _pendingWorkLoaded = false;

  /// False until the UI has rendered a complete snapshot in this app session.
  /// The very first [pull] of a session splices the latest changes into the
  /// stored snapshot and returns a full snapshot, so a cold start never shows
  /// a workspace made of deltas alone.
  bool _sessionSeeded = false;

  Future<String?> _readSecret(String key) =>
      _secureStorage.invokeMethod<String>('read', {'key': key});

  Future<void> _writeSecret(String key, String value) =>
      _secureStorage.invokeMethod<void>('write', {'key': key, 'value': value});

  Future<void> _deleteSecrets() => _secureStorage.invokeMethod<void>('clear');

  Future<void> _deleteSecret(String key) =>
      _secureStorage.invokeMethod<void>('delete', {'key': key});

  /// Drops every cached batch so a new sign-in can never inherit another
  /// session's data or sync cursor.
  Future<void> _clearSyncCaches() async {
    _pendingWork.clear();
    _pendingWorkLoaded = true;
    await _deleteSecret('background-sync-batch');
    await _deleteSecret('background-work-batch');
    await _deleteSecret('last-sync-cache');
    await _deleteSecret('last-work-cache');
    await _deleteSecret('pending-work');
    await _deleteSecret('sync-cursor');
  }

  Future<void> _loadPendingWork() async {
    if (_pendingWorkLoaded) return;
    _pendingWorkLoaded = true;
    try {
      final saved = await _readSecret('pending-work');
      if (saved == null) return;
      final decoded = jsonDecode(saved);
      if (decoded is List) {
        _pendingWork.addAll(
          decoded.whereType<Map>().map(
            (entry) => Map<String, dynamic>.from(entry),
          ),
        );
      }
    } on Object {
      // A corrupt queue must never block sign-in or a normal pull.
    }
  }

  Future<void> _savePendingWork() async {
    if (_pendingWork.isEmpty) {
      await _deleteSecret('pending-work');
      return;
    }
    await _writeSecret('pending-work', jsonEncode(_pendingWork));
  }

  String _workEntityId(Map<String, dynamic> entity) =>
      entity['id']?.toString() ?? '';

  Future<void> _enqueueWork(
    String kind,
    String action,
    Map<String, dynamic> entity,
  ) async {
    await _loadPendingWork();
    final id = _workEntityId(entity);
    _pendingWork.removeWhere(
      (change) =>
          change['kind'] == kind &&
          _workEntityId(
                Map<String, dynamic>.from(change['entity'] as Map? ?? const {}),
              ) ==
              id,
    );
    _pendingWork.add({'kind': kind, 'action': action, 'entity': entity});
    await _savePendingWork();
  }

  Future<void> _removePendingWork(
    String kind,
    Map<String, dynamic> entity,
  ) async {
    await _loadPendingWork();
    final id = _workEntityId(entity);
    final before = _pendingWork.length;
    _pendingWork.removeWhere(
      (change) =>
          change['kind'] == kind &&
          _workEntityId(
                Map<String, dynamic>.from(change['entity'] as Map? ?? const {}),
              ) ==
              id,
    );
    if (_pendingWork.length != before) await _savePendingWork();
  }

  Map<String, dynamic> _applyPendingWork(
    Map<String, dynamic> result, {
    List<Map<String, dynamic>>? changes,
  }) {
    final pending = changes ?? _pendingWork;
    if (pending.isEmpty) return result;
    final copy = Map<String, dynamic>.from(result);
    for (final change in pending) {
      final kind = change['kind']?.toString() ?? '';
      final key = switch (kind) {
        'task' => 'tasks',
        'agenda' => 'agenda',
        'file' => 'files',
        _ => '',
      };
      if (key.isEmpty) continue;
      final entity = Map<String, dynamic>.from(
        change['entity'] as Map? ?? const {},
      );
      final id = _workEntityId(entity);
      if (id.isEmpty) continue;
      final items = List<Map<String, dynamic>>.from(
        (copy[key] as List? ?? const []).whereType<Map>().map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );
      items.removeWhere((item) => item['id']?.toString() == id);
      if (change['action'] != 'delete') items.add(entity);
      copy[key] = items;
    }
    return copy;
  }

  Future<void> _flushPendingWork() async {
    await _loadPendingWork();
    if (_pendingWork.isEmpty || _token == null) return;
    final remaining = <Map<String, dynamic>>[];
    var offline = false;
    for (final change in _pendingWork) {
      if (offline) {
        remaining.add(change);
        continue;
      }
      final kind = change['kind']?.toString() ?? '';
      final action = change['action'] == 'delete' ? 'delete' : 'upsert';
      final entity = Map<String, dynamic>.from(
        change['entity'] as Map? ?? const {},
      );
      if (kind.isEmpty || _workEntityId(entity).isEmpty) continue;
      try {
        await _pushWorkRemote(kind, action, entity);
      } on BackendException catch (error) {
        if (error.statusCode == 401 || error.statusCode == 403) {
          // Keep the change until the session or permission is restored.
          offline = true;
          remaining.add(change);
          continue;
        }
        if (error.statusCode >= 400 && error.statusCode < 500) {
          // The server rejected this change permanently; drop it so it does
          // not block every future sync.
          continue;
        }
        offline = true;
        remaining.add(change);
      } on HttpException {
        offline = true;
        remaining.add(change);
      } on Object {
        offline = true;
        remaining.add(change);
      }
    }
    _pendingWork
      ..clear()
      ..addAll(remaining);
    await _savePendingWork();
  }

  Future<void> _pushWorkRemote(
    String kind,
    String action,
    Map<String, dynamic> entity,
  ) async {
    final result = await _request(
      'POST',
      '/api/sync/work',
      token: _requireToken('save event work'),
      body: {
        'action': 'push',
        'changes': [
          {'kind': kind, 'action': action, 'entity': entity},
        ],
      },
    );
    if ((result['accepted'] as num? ?? 0) < 1) {
      throw const BackendException('The server did not save this change.', 409);
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
    String? pairingSecret,
  }) async {
    final uri = Uri.parse('$_websiteOrigin$path');
    final request = await _http
        .openUrl(method, uri)
        .timeout(const Duration(seconds: 20));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (_deviceId != null) {
      request.headers.set('X-Device-Id', _deviceId!);
    }
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    if (pairingSecret != null) {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Pairing $pairingSecret',
      );
    }
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }

    final response = await request.close().timeout(const Duration(seconds: 20));
    final responseText = await utf8.decoder.bind(response).join();
    final contentType = response.headers.contentType?.mimeType ?? '';
    Map<String, dynamic>? result;
    if (responseText.isNotEmpty && contentType.contains('json')) {
      try {
        final decoded = jsonDecode(responseText);
        if (decoded is Map) result = Map<String, dynamic>.from(decoded);
      } on FormatException {
        result = null;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (result == null) {
        throw BackendException(
          'EventPulse sign-in API returned HTTP ${response.statusCode} instead of JSON. '
          'The latest backend may need to be deployed.',
          response.statusCode,
        );
      }
      throw BackendException(
        result['error'] as String? ??
            'EventPulse request failed (${response.statusCode}).',
        response.statusCode,
      );
    }
    if (responseText.isNotEmpty && result == null) {
      throw BackendException(
        'EventPulse returned a non-JSON response (HTTP ${response.statusCode}, ${contentType.isEmpty ? 'unknown content type' : contentType}). '
        'The Google sign-in API may not be deployed yet.',
        response.statusCode,
      );
    }
    return result ?? <String, dynamic>{};
  }

  /// Restores the saved sign-in instantly from encrypted storage, so a user
  /// who has signed in before never sees the login page on app reopen — even
  /// offline or while the server is slow. The token is still confirmed by the
  /// server in the background ([_verifySessionInBackground]); only a genuine
  /// 401 (revoked or expired token) signs the device out.
  @override
  Future<MobileAccount?> restoreSession() async {
    final token = await _readSecret('device-token');
    final savedUser = await _readSecret('account');
    final deviceId = await _readSecret('device-id');
    if (token == null || savedUser == null || deviceId == null) return null;

    // Hydrate from storage first so the app opens instantly, even offline.
    _token = token;
    _deviceId = deviceId;
    _cursor = int.tryParse(await _readSecret('sync-cursor') ?? '') ?? 0;

    final account = _cachedSessionAccount(savedUser);
    if (account == null) {
      // The cached account is unreadable: drop the stale credentials so the
      // user gets a clean login instead of a broken session.
      await signOut(revokeDevice: false);
      return null;
    }

    // Never block the UI on network calls here; confirm the token quietly.
    unawaited(_verifySessionInBackground());

    // Background sync scheduling is a platform-channel roundtrip; don't make
    // the dashboard wait for it.
    unawaited(startBackgroundSync());
    return account;
  }

  /// Confirms the restored token is still accepted by the server. Network
  /// errors and server outages never log the user out; a 401 means the token
  /// is genuinely revoked or expired and the device signs itself out.
  Future<void> _verifySessionInBackground() async {
    try {
      final verified = await _request(
        'POST',
        '/api/sync/verify',
        token: _token,
      );
      var account = MobileAccount(id: '', name: '', email: '');
      final user = verified['user'];
      if (user is Map) {
        account = MobileAccount.fromJson(Map<String, dynamic>.from(user));
      }
      try {
        final profileResult = await _request(
          'GET',
          '/api/sync/profile',
          token: _token,
        );
        if (profileResult['profile'] is Map) {
          account = MobileAccount.fromJson(
            Map<String, dynamic>.from(profileResult['profile'] as Map),
          );
        }
      } on Object {
        // Keep the verified account when the profile refresh fails.
      }
      if (account.id.isNotEmpty) {
        await _writeSecret('account', jsonEncode(account.toJson()));
      }
    } on BackendException catch (error) {
      if (error.statusCode == 401) await signOut(revokeDevice: false);
    } on Object {
      // Offline or server error: keep the user signed in.
    }
  }

  MobileAccount? _cachedSessionAccount(String savedUser) {
    try {
      final account = MobileAccount.fromJson(
        Map<String, dynamic>.from(jsonDecode(savedUser) as Map),
      );
      if (account.id.isEmpty) return null;
      startBackgroundSync();
      return account;
    } on Object {
      return null;
    }
  }

  Future<MobileAccount> _createPasswordSession({
    required String action,
    required String email,
    required String password,
    String? name,
  }) async {
    final result = await _request(
      'POST',
      '/api/mobile/auth',
      body: {
        'action': action,
        'email': email.trim(),
        'password': password,
        if (name != null) 'name': name.trim(),
      },
    );
    final account = MobileAccount.fromJson(
      Map<String, dynamic>.from(result['user'] as Map),
    );
    final device = Map<String, dynamic>.from(result['device'] as Map);
    final token = result['token'] as String?;
    final deviceId = device['id'] as String?;
    if (token == null || deviceId == null || account.id.isEmpty) {
      throw const HttpException(
        'The EventPulse server returned incomplete account details.',
      );
    }
    _token = token;
    _deviceId = deviceId;
    _cursor = 0;
    // Clear leftover batches BEFORE the new device id schedules background
    // sync, so the first pull is always a fresh snapshot for this session.
    await _clearSyncCaches();
    await _writeSecret('device-token', token);
    await _writeSecret('device-id', deviceId);
    await _writeSecret('account', jsonEncode(account.toJson()));
    await _writeSecret('sync-cursor', '0');
    await startBackgroundSync();
    return account;
  }

  @override
  Future<MobileAccount> signInWithPassword(String email, String password) =>
      _createPasswordSession(action: 'login', email: email, password: password);

  @override
  Future<MobileAccount> registerAccount(
    String name,
    String email,
    String password,
  ) => _createPasswordSession(
    action: 'register',
    name: name,
    email: email,
    password: password,
  );

  @override
  Future<void> requestPasswordReset(String email) async {
    await _request(
      'POST',
      '/api/auth/password-reset',
      body: {'email': email.trim()},
    );
  }

  @override
  Future<void> uploadEventFile(
    String eventId,
    String name,
    String mimeType,
    List<int> bytes,
  ) async {
    if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
      throw const HttpException('Choose a file between 1 byte and 20 MB.');
    }
    final id = _uuidV4();
    final now = DateTime.now().toUtc().toIso8601String();
    final change = {
      'kind': 'file',
      'action': 'upsert',
      'entity': {
        'id': id,
        'eventId': eventId,
        'name': name,
        'mimeType': mimeType,
        'sizeBytes': bytes.length,
        'uploadBytes': true,
        'createdAt': now,
        'updatedAt': now,
      },
    };
    final result = await _request(
      'POST',
      '/api/sync/work',
      token: _requireToken('upload files'),
      body: {
        'action': 'push',
        'changes': [change],
      },
    );
    if ((result['accepted'] as num? ?? 0) < 1) {
      throw const HttpException('The server did not accept this file.');
    }
    final pending = _asMapList(result['pendingUploads']);
    if (pending.isEmpty) {
      throw const HttpException(
        'The file was queued but upload could not start. Try again.',
      );
    }
    final timestamp = pending.first['updatedAt']?.toString() ?? now;
    final chunks = (bytes.length + 256 * 1024 - 1) ~/ (256 * 1024);
    for (var index = 0; index < chunks; index++) {
      final start = index * 256 * 1024;
      final end = min(start + 256 * 1024, bytes.length);
      final request = await _http.openUrl(
        'PUT',
        Uri.parse(
          '$_websiteOrigin/api/sync/work/files/$id?eventId=${Uri.encodeQueryComponent(eventId)}&index=$index&count=$chunks&sizeBytes=${bytes.length}&updatedAt=${Uri.encodeQueryComponent(timestamp)}',
        ),
      );
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${_requireToken('upload files')}',
      );
      if (_deviceId != null) request.headers.set('X-Device-Id', _deviceId!);
      request.add(bytes.sublist(start, end));
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw BackendException(
          'File upload failed (HTTP ${response.statusCode}): $body',
          response.statusCode,
        );
      }
    }
  }

  @override
  Future<List<int>> downloadEventFile(
    String fileId,
    String updatedAt,
    int sizeBytes,
  ) async {
    final output = <int>[];
    final chunks = (sizeBytes + 256 * 1024 - 1) ~/ (256 * 1024);
    for (var index = 0; index < chunks; index++) {
      final response = await _http.getUrl(
        Uri.parse(
          '$_websiteOrigin/api/sync/work/files/$fileId?index=$index&updatedAt=${Uri.encodeQueryComponent(updatedAt)}',
        ),
      );
      response.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${_requireToken('download files')}',
      );
      if (_deviceId != null) response.headers.set('X-Device-Id', _deviceId!);
      final result = await response.close();
      final part = await result.fold<List<int>>(
        <int>[],
        (all, data) => all..addAll(data),
      );
      if (result.statusCode < 200 || result.statusCode >= 300) {
        throw BackendException(
          'File download failed (HTTP ${result.statusCode}).',
          result.statusCode,
        );
      }
      output.addAll(part);
    }
    if (output.length != sizeBytes) {
      throw const HttpException('Downloaded file size did not match.');
    }
    return output;
  }

  @override
  Future<MobileAccount> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    if (!_googleInitialized) {
      await google.initialize(serverClientId: _googleServerClientId);
      _googleInitialized = true;
    }

    final googleAccount = await google.authenticate();
    final idToken = googleAccount.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const HttpException(
        'Google sign-in did not return an identity token. Check the app OAuth configuration.',
      );
    }

    final result = await _request(
      'POST',
      '/api/mobile/google-auth',
      body: {'idToken': idToken, 'deviceName': 'EventPulse Android'},
    );
    final account = MobileAccount.fromJson(
      Map<String, dynamic>.from(result['user'] as Map),
    );
    final device = Map<String, dynamic>.from(result['device'] as Map);
    final token = result['token'] as String?;
    final deviceId = device['id'] as String?;
    if (token == null || deviceId == null || account.id.isEmpty) {
      throw const HttpException(
        'The EventPulse server returned incomplete account details.',
      );
    }

    _token = token;
    _deviceId = deviceId;
    _cursor = 0;
    // Clear leftover batches BEFORE the new device id schedules background
    // sync, so the first pull is always a fresh snapshot for this session.
    await _clearSyncCaches();
    await _writeSecret('device-token', token);
    await _writeSecret('device-id', deviceId);
    await _writeSecret('account', jsonEncode(account.toJson()));
    await _writeSecret('sync-cursor', '0');
    await startBackgroundSync();
    return account;
  }

  @override
  Future<MobileSyncBatch> pull() async {
    final backgroundBatch = await _readSecret('background-sync-batch');
    if (backgroundBatch != null) {
      try {
        final cached = Map<String, dynamic>.from(
          jsonDecode(backgroundBatch) as Map,
        );
        final cursor = cached['cursor'];
        if (cursor is int) {
          _cursor = cursor;
          await _writeSecret('sync-cursor', '$cursor');
        }
        final batch = _syncBatchFromJson(cached);
        final merged = await _applyBatchToSnapshotBase(batch);
        await _deleteSecret('background-sync-batch');
        return merged;
      } on Object {
        // Fall back to a live API pull when the cache is incomplete.
      }
    }
    final token = _token;
    if (token == null) {
      throw const HttpException('Sign in to sync your events.');
    }
    try {
      // Without a stored snapshot there is no base to apply deltas onto, so
      // request cursor 0 to force the server to send a full snapshot.
      final hasSnapshotBase = await _readSecret('last-sync-cache') != null;
      final result = await _request(
        'POST',
        '/api/sync/pull',
        token: token,
        body: {'cursor': hasSnapshotBase ? _cursor : 0},
      );
      final cursor = result['cursor'];
      if (cursor is int) {
        _cursor = cursor;
        await _writeSecret('sync-cursor', '$cursor');
      }
      return await _applyBatchToSnapshotBase(_syncBatchFromJson(result));
    } on BackendException catch (error) {
      if (error.statusCode == 401) rethrow;
      return _cachedSnapshotFallback();
    } on Object {
      // Offline or server error: serve the cached snapshot so users reopen
      // their data instead of an empty workspace.
      return _cachedSnapshotFallback();
    }
  }

  /// Keeps the on-disk snapshot in lockstep with everything the app renders:
  /// server changes AND this device's own edits (which the server change feed
  /// deliberately excludes for this device). Returns the batch the UI should
  /// render: a full merged snapshot before the session is seeded, otherwise
  /// the change batch as-is.
  Future<MobileSyncBatch> _applyBatchToSnapshotBase(
    MobileSyncBatch batch,
  ) async {
    if (batch.snapshot) {
      await _writeSecret(
        'last-sync-cache',
        jsonEncode({
          'mode': 'snapshot',
          'cursor': _cursor,
          'events': batch.events,
          'sharedEvents': batch.sharedEvents,
          'members': batch.members,
          'invitations': batch.invitations,
          'notifications': batch.notifications,
          'preferences': batch.preferences,
          'profile': batch.profile,
        }),
      );
      _sessionSeeded = true;
      return batch;
    }
    final cached = await _readSecret('last-sync-cache');
    if (cached == null) {
      _sessionSeeded = true;
      return batch;
    }
    try {
      final snapshot = Map<String, dynamic>.from(jsonDecode(cached) as Map);
      final events = _asMapList(snapshot['events']);
      for (final change in batch.changes) {
        final id = change['entityId']?.toString() ?? '';
        final index = events.indexWhere((event) => event['id'] == id);
        if (change['action'] == 'delete') {
          if (index >= 0) events.removeAt(index);
        } else if (change['event'] is Map) {
          final event = Map<String, dynamic>.from(change['event'] as Map);
          if (index >= 0) {
            events[index] = event;
          } else {
            events.add(event);
          }
        }
      }
      snapshot
        ..['cursor'] = _cursor
        ..['events'] = events
        // Change responses always carry the full reference lists.
        ..['sharedEvents'] = batch.sharedEvents
        ..['members'] = batch.members
        ..['invitations'] = batch.invitations
        ..['notifications'] = batch.notifications
        ..['preferences'] = batch.preferences
        ..['profile'] = batch.profile;
      await _writeSecret('last-sync-cache', jsonEncode(snapshot));
      if (!_sessionSeeded) {
        _sessionSeeded = true;
        return _syncBatchFromJson(snapshot);
      }
    } on Object {
      // A damaged cache is replaced by the next full snapshot.
    }
    return batch;
  }

  /// Applies one of this device's own event edits to the stored snapshot so a
  /// restart cannot visually revert it (the server never echoes this device's
  /// changes back to it).
  Future<void> _mutateCachedEvent(
    String id, {
    Map<String, dynamic>? event,
  }) async {
    final cached = await _readSecret('last-sync-cache');
    if (cached == null) return;
    try {
      final snapshot = Map<String, dynamic>.from(jsonDecode(cached) as Map);
      final events = _asMapList(snapshot['events']);
      final index = events.indexWhere((item) => item['id']?.toString() == id);
      if (event == null) {
        if (index >= 0) events.removeAt(index);
      } else if (index >= 0) {
        events[index] = event;
      } else {
        events.add(event);
      }
      snapshot['events'] = events;
      await _writeSecret('last-sync-cache', jsonEncode(snapshot));
    } on Object {
      // A damaged cache is replaced by the next full snapshot.
    }
  }

  Future<MobileSyncBatch> _cachedSnapshotFallback() async {
    final cached = await _readSecret('last-sync-cache');
    if (cached == null) {
      throw const HttpException(
        'Could not reach EventPulse to sync your events.',
      );
    }
    try {
      final cachedBatch = Map<String, dynamic>.from(jsonDecode(cached) as Map);
      final cursor = cachedBatch['cursor'];
      if (cursor is int) _cursor = cursor;
      _sessionSeeded = true;
      return _syncBatchFromJson(cachedBatch);
    } on Object {
      throw const HttpException('Cached EventPulse data is unreadable.');
    }
  }

  static MobileSyncBatch _syncBatchFromJson(Map<String, dynamic> result) =>
      MobileSyncBatch(
        snapshot: result['mode'] == 'snapshot',
        events: _asMapList(result['events']),
        changes: _asMapList(result['changes']),
        sharedEvents: _asMapList(result['sharedEvents']),
        invitations: _asMapList(result['invitations']),
        members: _asMapList(result['members']),
        notifications: _asMapList(result['notifications']),
        preferences: result['preferences'] is Map
            ? Map<String, dynamic>.from(result['preferences'] as Map)
            : <String, dynamic>{},
        profile: result['profile'] is Map
            ? Map<String, dynamic>.from(result['profile'] as Map)
            : <String, dynamic>{},
      );

  @override
  Future<void> respondToInvitation(String invitationId, String response) async {
    final token = _token;
    if (token == null) {
      throw const HttpException('Sign in to respond to invitations.');
    }
    await _request(
      'POST',
      '/api/sync/invitations/respond',
      token: token,
      body: {'invitationId': invitationId, 'response': response},
    );
  }

  @override
  Future<Map<String, dynamic>> sendWorkspaceInvitation(String email) =>
      _request(
        'POST',
        '/api/sync/workspace-invitations/send',
        token: _requireToken('send invitations'),
        body: {'email': email.trim()},
      );

  @override
  Future<Map<String, dynamic>> pullWork() async {
    await _loadPendingWork();
    final pending = List<Map<String, dynamic>>.from(_pendingWork);
    final cached = await _readSecret('background-work-batch');
    if (cached != null) {
      await _deleteSecret('background-work-batch');
      try {
        return _applyPendingWork(
          Map<String, dynamic>.from(jsonDecode(cached) as Map),
          changes: pending,
        );
      } on Object {
        // Continue with a live work pull when the cache is invalid.
      }
    }
    try {
      final result = await _request(
        'POST',
        '/api/sync/work',
        token: _requireToken('sync work'),
        body: {'action': 'pull'},
      );
      final merged = _applyPendingWork(result, changes: pending);
      if (pending.isNotEmpty) await _flushPendingWork();
      await _writeSecret('last-work-cache', jsonEncode(merged));
      return merged;
    } on BackendException catch (error) {
      if (error.statusCode == 401) rethrow;
      return _applyPendingWork(await _cachedWorkFallback(), changes: pending);
    } on Object {
      // Offline or server error: fall back to the last cached work batch.
      return _applyPendingWork(await _cachedWorkFallback(), changes: pending);
    }
  }

  Future<Map<String, dynamic>> _cachedWorkFallback() async {
    final fallback = await _readSecret('last-work-cache');
    if (fallback == null) {
      throw const HttpException('Could not reach EventPulse to sync work.');
    }
    try {
      return Map<String, dynamic>.from(jsonDecode(fallback) as Map);
    } on Object {
      throw const HttpException('Cached EventPulse work data is unreadable.');
    }
  }

  @override
  Future<void> saveWorkItem(String kind, Map<String, dynamic> entity) =>
      pushWork(kind, 'upsert', entity);

  @override
  Future<void> deleteWorkItem(String kind, String eventId, String id) =>
      pushWork(kind, 'delete', {
        'id': id,
        'eventId': eventId,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });

  @override
  Future<List<Map<String, dynamic>>> eventActivity(String eventId) async {
    final result = await _request(
      'GET',
      '/api/sync/events/activity?eventId=${Uri.encodeQueryComponent(eventId)}',
      token: _requireToken('load activity'),
    );
    return _asMapList(result['activity']);
  }

  @override
  Future<Map<String, dynamic>> eventMembers(String eventId) => _request(
    'POST',
    '/api/sync/events/members',
    token: _requireToken('load members'),
    body: {'action': 'details', 'eventId': eventId},
  );

  @override
  Future<Map<String, dynamic>> manageEventMembers(
    String eventId,
    String action, {
    String? userId,
    String? memberId,
    String? inviteId,
    String? email,
    String? role,
  }) => _request(
    'POST',
    '/api/sync/events/members',
    token: _requireToken('manage event members'),
    body: {
      'action': action,
      'eventId': eventId,
      'userId': ?userId,
      'memberId': ?memberId,
      'inviteId': ?inviteId,
      'email': ?email,
      'role': ?role,
    },
  );

  @override
  Future<void> leaveEvent(String eventId) => _request(
    'POST',
    '/api/sync/events/members',
    token: _requireToken('leave this event'),
    body: {'action': 'leave', 'eventId': eventId},
  );

  @override
  Future<Map<String, dynamic>> manageWorkspaceUsers(
    String action, {
    String? userId,
    String? name,
    String? email,
    String? password,
    String? role,
  }) => _request(
    'POST',
    '/api/sync/users',
    token: _requireToken('manage workspace users'),
    body: {
      'action': action,
      'userId': ?userId,
      'name': ?name,
      'email': ?email,
      'password': ?password,
      'role': ?role,
    },
  );

  @override
  Future<MobileAccount?> updateProfileName(String name) async {
    final result = await _request(
      'POST',
      '/api/sync/profile',
      token: _requireToken('update profile'),
      body: {'action': 'update-name', 'name': name},
    );
    final profile = result['profile'];
    if (profile is Map) {
      final account = MobileAccount.fromJson(
        Map<String, dynamic>.from(profile),
      );
      await _writeSecret('account', jsonEncode(account.toJson()));
      return account;
    }
    return null;
  }

  @override
  Future<MobileAccount?> updateProfileAvatar(
    String action, {
    String? mimeType,
    String? dataBase64,
  }) async {
    if (action != 'google-avatar' &&
        action != 'remove-avatar' &&
        action != 'upload-avatar') {
      throw const HttpException('Choose a valid profile photo action.');
    }
    final result = await _request(
      'POST',
      '/api/sync/profile',
      token: _requireToken('update profile photo'),
      body: {
        'action': action,
        'mimeType': ?mimeType,
        'dataBase64': ?dataBase64,
      },
    );
    final profile = result['profile'];
    if (profile is! Map) return null;
    final account = MobileAccount.fromJson(Map<String, dynamic>.from(profile));
    await _writeSecret('account', jsonEncode(account.toJson()));
    return account;
  }

  @override
  Future<void> updatePreferences(Map<String, dynamic> preferences) async {
    await _request(
      'POST',
      '/api/sync/preferences',
      token: _requireToken('update preferences'),
      body: preferences,
    );
  }

  @override
  Future<void> markNotificationRead({
    String? notificationId,
    bool markAll = false,
  }) async {
    await _request(
      'POST',
      '/api/sync/notifications/read',
      token: _requireToken('update notifications'),
      body: {'markAll': markAll, 'notificationId': ?notificationId},
    );
  }

  @override
  Future<String> getCalendarFeed({bool rotate = false}) async {
    final result = await _request(
      'GET',
      '/api/sync/calendar-feed${rotate ? '?rotate=1' : ''}',
      token: _requireToken('load calendar feed'),
    );
    final path = result['feedUrl'] as String?;
    if (path == null) {
      throw const HttpException('Calendar feed URL is unavailable.');
    }
    return path.startsWith('http') ? path : '$_websiteOrigin$path';
  }

  @override
  Future<Map<String, dynamic>> createBackup() async {
    final backup = await _request(
      'GET',
      '/api/mobile/backup',
      token: _requireToken('create a backup'),
    );
    validateEventPulseBackup(backup);
    final templates = await listTemplates();
    if (templates.isNotEmpty) {
      backup['localSettings'] = {'android:templates': jsonEncode(templates)};
    }
    return backup;
  }

  @override
  Future<void> restoreBackup(Map<String, dynamic> backup) async {
    validateEventPulseBackup(backup);
    final restoreId = _uuidV4();
    final files = _asMapList(backup['files']);
    final lengths = <String, int>{};
    for (final file in files) {
      final key = file['key']?.toString() ?? '';
      final data = file['data']?.toString() ?? '';
      if (key.isEmpty || data.isEmpty) continue;
      lengths[key] = data.length;
      final count = (data.length + 399999) ~/ 400000;
      for (var index = 0; index < count; index++) {
        final result = await _request(
          'POST',
          '/api/mobile/backup',
          token: _requireToken('restore a backup'),
          body: {
            'action': 'stage',
            'restoreId': restoreId,
            'key': key,
            'index': index,
            'count': count,
            'data': data.substring(
              index * 400000,
              min(index * 400000 + 400000, data.length),
            ),
          },
        );
        if (result['success'] != true) {
          throw const HttpException('Could not stage a backup attachment.');
        }
      }
      file['data'] = '';
    }
    await _request(
      'POST',
      '/api/mobile/backup',
      token: _requireToken('restore a backup'),
      body: {
        'action': 'restore',
        'restoreId': restoreId,
        'attachmentLengths': lengths,
        'backup': backup,
      },
    );
    // The restored workspace replaces the server tables and may have a
    // different sync sequence. Drop local caches and request a fresh snapshot.
    _cursor = 0;
    _sessionSeeded = false;
    await _clearSyncCaches();
    await _restoreLocalBackupSettings(backup);
  }

  Future<void> _restoreLocalBackupSettings(Map<String, dynamic> backup) async {
    final settings = backup['localSettings'];
    if (settings is! Map) return;
    final raw = settings['android:templates'];
    if (raw is! String || raw.trim().isEmpty) return;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) return;
      await _writeSecret('local-templates', jsonEncode(_asMapList(parsed)));
    } on Object {
      // Local settings are optional and must not invalidate a workspace restore.
    }
  }

  @override
  Future<Map<String, dynamic>> updateEvent(Map<String, dynamic> event) async {
    final result = await _request(
      'POST',
      '/api/sync/push',
      token: _requireToken('update event'),
      body: {
        'changes': [
          {'id': _uuidV4(), 'action': 'upsert', 'event': event},
        ],
      },
    );
    if ((result['accepted'] as num? ?? 0) < 1) {
      throw const HttpException('The server did not save this event.');
    }
    await _mutateCachedEvent(event['id']?.toString() ?? '', event: event);
    return event;
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    final result = await _request(
      'POST',
      '/api/sync/push',
      token: _requireToken('delete event'),
      body: {
        'changes': [
          {
            'id': _uuidV4(),
            'action': 'delete',
            'event': {'id': eventId},
          },
        ],
      },
    );
    if ((result['accepted'] as num? ?? 0) < 1) {
      throw const HttpException('The server did not delete this event.');
    }
    await _mutateCachedEvent(eventId);
  }

  @override
  Future<List<Map<String, dynamic>>> listTemplates() async {
    final encoded = await _readSecret('local-templates');
    if (encoded == null) return [];
    try {
      return _asMapList(jsonDecode(encoded));
    } on Object {
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> saveTemplate(
    Map<String, dynamic> template,
  ) async {
    final templates = await listTemplates();
    final id = template['id']?.toString() ?? _uuidV4();
    final saved = {...template, 'id': id};
    final index = templates.indexWhere((item) => item['id'] == id);
    if (index < 0) {
      templates.add(saved);
    } else {
      templates[index] = saved;
    }
    await _writeSecret('local-templates', jsonEncode(templates));
    return saved;
  }

  /// Best-effort owner id for locally created events, read from the cached
  /// account so a restart renders the event in the correct workspace section.
  Future<String?> _cachedAccountId() async {
    try {
      final saved = await _readSecret('account');
      if (saved == null) return null;
      final account = Map<String, dynamic>.from(jsonDecode(saved) as Map);
      final id = account['id']?.toString();
      return (id == null || id.isEmpty) ? null : id;
    } on Object {
      return null;
    }
  }

  Future<void> pushWork(
    String kind,
    String action,
    Map<String, dynamic> entity,
  ) async {
    try {
      await _pushWorkRemote(kind, action, entity);
    } on BackendException catch (error) {
      if (error.statusCode == 401 ||
          (error.statusCode >= 400 && error.statusCode < 500)) {
        rethrow;
      }
      await _enqueueWork(kind, action, entity);
      return;
    } on HttpException {
      rethrow;
    } on Object {
      await _enqueueWork(kind, action, entity);
      return;
    }
    await _removePendingWork(kind, entity);
  }

  String _requireToken(String action) {
    final token = _token;
    if (token == null) throw HttpException('Sign in to $action.');
    return token;
  }

  @override
  Future<Map<String, dynamic>> createEvent({
    required String title,
    required String description,
    required String category,
    required String venue,
    required DateTime startsAt,
    int? capacity,
    String visibility = 'private',
  }) async {
    final token = _token;
    if (token == null) {
      throw const HttpException('Sign in to create events.');
    }
    final id = _uuidV4();
    final now = DateTime.now().toUtc().toIso8601String();
    final event = <String, dynamic>{
      'id': id,
      'title': title.trim(),
      'description': description,
      'category': category,
      'venue': venue,
      'startsAt': startsAt.toUtc().toIso8601String(),
      'capacity': capacity,
      'visibility': visibility,
      'createdAt': now,
      'ownerId': await _cachedAccountId(),
    };
    final result = await _request(
      'POST',
      '/api/sync/push',
      token: token,
      body: {
        'changes': [
          {'id': _uuidV4(), 'action': 'upsert', 'event': event},
        ],
      },
    );
    if ((result['accepted'] as num? ?? 0) < 1) {
      throw const HttpException(
        'The server did not save this event. Please try again.',
      );
    }
    await _mutateCachedEvent(id, event: event);
    return event;
  }

  @override
  Future<void> startBackgroundSync() async {
    await _secureStorage.invokeMethod<void>('schedule-background-sync');
  }

  @override
  Future<void> signOut({bool revokeDevice = true}) async {
    final token = _token;
    if (revokeDevice && token != null) {
      try {
        await _request('DELETE', '/api/sync/device', token: token);
      } on Object {
        // Always clear local credentials, even while offline.
      }
    }
    if (_googleInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } on Object {
        // Clear the EventPulse session even if Google sign-out is unavailable.
      }
    }
    _token = null;
    _deviceId = null;
    _cursor = 0;
    await _deleteSecrets();
    // Defensive second sweep: drop any batch a background worker may have
    // written while the old session was still valid.
    await _clearSyncCaches();
  }

  static List<Map<String, dynamic>> _asMapList(Object? value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : <Map<String, dynamic>>[];

  static String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
