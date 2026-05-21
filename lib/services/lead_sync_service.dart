// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';
import 'package:call_log/call_log.dart';
import 'package:flutter/services.dart';

import 'api_service.dart';
import 'auth_service.dart';

class LeadSyncService {
  LeadSyncService._();
  static final LeadSyncService instance = LeadSyncService._();

  static const _kEventChannel = EventChannel('com.leadmantracrm.app/call_log_events');

  final _api = ApiService();

  // Tracks calls uploaded in this session only (in-memory, not persisted).
  final Set<String> _uploadedIds = {};

  // Only calls made after this moment are eligible for upload.
  DateTime? _syncStartedAt;

  StreamSubscription<dynamic>? _sub;
  Timer?                       _debounce;
  bool                         _syncing = false;

  // ── Start / Stop ────────────────────────────────────────────────────────────

  Future<void> start() async {
    _syncStartedAt ??= DateTime.now();
    _uploadedIds.clear();
    _sub ??= _kEventChannel.receiveBroadcastStream().listen(
      (_) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(seconds: 5), syncNow);
      },
      onError: (_) {},
    );
    print('[SYNC] LeadSyncService started — watching calls from $_syncStartedAt');
  }

  void stop() {
    _debounce?.cancel();
    _sub?.cancel();
    _sub        = null;
    _syncStartedAt = null;
    _uploadedIds.clear();
    print('[SYNC] LeadSyncService stopped');
  }

  // ── Sync ────────────────────────────────────────────────────────────────────

  Future<void> syncNow() async {
    if (_syncing) return;
    if (!AuthService.instance.isLoggedIn) return;
    if (!Platform.isAndroid) return;
    if (_syncStartedAt == null) return;
    _syncing = true;

    try {
      // Only fetch calls that happened after the service started this session.
      final deviceEntries = await CallLog.query(
        dateTimeFrom: _syncStartedAt,
      );

      final newEntries = deviceEntries
          .where((e) => !_uploadedIds.contains(_callId(e)))
          .toList();

      print('[SYNC] ${newEntries.length} new call(s) to upload');

      for (final entry in newEntries) {
        if (!AuthService.instance.isLoggedIn) break;

        final id    = _callId(entry);
        final phone = entry.number;
        if (phone == null || phone.isEmpty) continue;

        await _api.captureLead(
          phone:    phone,
          name:     entry.name,
          duration: entry.duration ?? 0,
        );

        // Mark uploaded only if the session is still valid after the call.
        if (AuthService.instance.isLoggedIn) {
          _uploadedIds.add(id);
        }
      }

      print('[SYNC] Sync complete — uploaded this session: ${_uploadedIds.length}');
    } catch (e) {
      print('[SYNC] Sync error: $e');
    } finally {
      _syncing = false;
    }
  }

  String _callId(CallLogEntry e) =>
      '${e.timestamp}_${e.number}_${e.callType?.name}';
}
