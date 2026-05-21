// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';
import 'package:call_log/call_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/navigator_key.dart';
import '../widgets/lead_confirm_dialog.dart';
import 'api_service.dart';
import 'auth_service.dart';

class LeadSyncService {
  LeadSyncService._();
  static final LeadSyncService instance = LeadSyncService._();

  static const _kEventChannel  = EventChannel('com.leadmantracrm.app/call_log_events');
  static const _kSyncStartedAt = 'lead_sync_started_at';
  static const _kUploadedIds   = 'lead_uploaded_ids';

  final _api = ApiService();

  Set<String> _uploadedIds   = {};
  DateTime?   _syncStartedAt;

  StreamSubscription<dynamic>? _sub;
  Timer?                       _debounce;
  bool                         _syncing = false;

  // ── Start / Stop ────────────────────────────────────────────────────────────

  Future<void> start() async {
    final prefs = await SharedPreferences.getInstance();

    // Set once on first install/login — never overwritten across restarts.
    final savedMs = prefs.getInt(_kSyncStartedAt);
    if (savedMs == null) {
      _syncStartedAt = DateTime.now();
      await prefs.setInt(_kSyncStartedAt, _syncStartedAt!.millisecondsSinceEpoch);
      print('[SYNC] First start — tracking calls from $_syncStartedAt');
    } else {
      _syncStartedAt = DateTime.fromMillisecondsSinceEpoch(savedMs);
      print('[SYNC] Resumed — tracking calls from $_syncStartedAt');
    }

    // Restore uploaded IDs so already-sent calls are never re-prompted.
    final saved = prefs.getStringList(_kUploadedIds) ?? [];
    _uploadedIds = saved.toSet();
    print('[SYNC] ${_uploadedIds.length} call(s) already handled');

    _sub ??= _kEventChannel.receiveBroadcastStream().listen(
      (_) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(seconds: 5), syncNow);
      },
      onError: (_) {},
    );
  }

  void stop() {
    _debounce?.cancel();
    _sub?.cancel();
    _sub = null;
    // Do NOT clear _syncStartedAt or _uploadedIds — persisted across restarts.
    print('[SYNC] LeadSyncService paused');
  }

  // ── Sync ────────────────────────────────────────────────────────────────────

  Future<void> syncNow() async {
    if (_syncing) return;
    if (!AuthService.instance.isLoggedIn) return;
    if (!Platform.isAndroid) return;
    if (_syncStartedAt == null) return;
    _syncing = true;

    try {
      final deviceEntries = await CallLog.query(
        dateTimeFrom: _syncStartedAt,
      );

      // Only incoming and outgoing calls — missed calls are not leads.
      final newEntries = deviceEntries
          .where((e) =>
              e.callType == CallType.incoming ||
              e.callType == CallType.outgoing)
          .where((e) => !_uploadedIds.contains(_callId(e)))
          .toList();

      print('[SYNC] ${newEntries.length} new lead call(s) pending confirmation');

      bool anyHandled = false;
      for (final entry in newEntries) {
        if (!AuthService.instance.isLoggedIn) break;

        final id    = _callId(entry);
        final phone = entry.number;
        if (phone == null || phone.isEmpty) {
          _uploadedIds.add(id);
          anyHandled = true;
          continue;
        }

        final name = (entry.name?.isNotEmpty == true) ? entry.name! : 'Unknown';

        // Show confirmation dialog — user must check the box and tap Send Lead.
        final confirmed = await _showConfirmDialog(name, phone);

        // Always mark as handled after showing dialog (no re-prompting).
        _uploadedIds.add(id);
        anyHandled = true;

        if (!confirmed) {
          print('[SYNC] Lead skipped by user: $phone');
          continue;
        }

        if (!AuthService.instance.isLoggedIn) break;

        await _api.captureLead(
          phone:    phone,
          name:     entry.name,
          duration: entry.duration ?? 0,
        );
      }

      if (anyHandled) await _saveUploadedIds();
      print('[SYNC] Done — total handled since install: ${_uploadedIds.length}');
    } catch (e) {
      print('[SYNC] Sync error: $e');
    } finally {
      _syncing = false;
    }
  }

  // ── Confirmation dialog ─────────────────────────────────────────────────────

  Future<bool> _showConfirmDialog(String name, String phone) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      print('[SYNC] No context — dialog skipped for $phone (will retry next open)');
      return false;
    }
    final result = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => LeadConfirmDialog(name: name, phone: phone),
    );
    return result ?? false;
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> _saveUploadedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kUploadedIds, _uploadedIds.toList());
  }

  String _callId(CallLogEntry e) =>
      '${e.timestamp}_${e.number}_${e.callType?.name}';
}
