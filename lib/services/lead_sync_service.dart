// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';
import 'package:call_log/call_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/navigator_key.dart';
import '../models/captured_lead.dart';
import '../widgets/lead_confirm_dialog.dart';
import 'api_service.dart';
import 'auth_service.dart';

class LeadSyncService {
  LeadSyncService._();
  static final LeadSyncService instance = LeadSyncService._();

  static const _kEventChannel    = EventChannel('com.leadmantracrm.app/call_log_events');
  static const _kSyncStartedAt   = 'lead_sync_started_at';
  static const _kUploadedIds     = 'lead_uploaded_ids';
  static const _kHandledNumbers  = 'lead_handled_numbers';
  static const _kCapturedLeads   = 'lead_captured_leads';

  final _api = ApiService();

  Set<String> _uploadedIds    = {};
  Set<String> _handledNumbers = {}; // numbers confirmed OR skipped — never prompted again
  DateTime?   _syncStartedAt;

  // Full list of uploaded leads — dashboard card and leads screen both observe this.
  final capturedLeads = ValueNotifier<List<CapturedLead>>([]);

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
    final savedIds = prefs.getStringList(_kUploadedIds) ?? [];
    _uploadedIds = savedIds.toSet();
    print('[SYNC] ${_uploadedIds.length} call(s) already handled');

    // Restore handled numbers — normalize on load so +91/0 prefix variants match.
    final savedNums = prefs.getStringList(_kHandledNumbers) ?? [];
    _handledNumbers = savedNums.map<String>(_normalizePhone).toSet();
    print('[SYNC] ${_handledNumbers.length} number(s) already handled');

    // Restore captured lead details for the leads screen.
    final savedLeads = prefs.getStringList(_kCapturedLeads) ?? [];
    capturedLeads.value = savedLeads.map(CapturedLead.decode).toList();
    print('[SYNC] ${capturedLeads.value.length} lead(s) captured so far');

    _sub ??= _kEventChannel.receiveBroadcastStream().listen(
      (_) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(seconds: 2), syncNow);
      },
      onError: (_) {},
    );
  }

  void stop() {
    _debounce?.cancel();
    _sub?.cancel();
    _sub = null;
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
      final deviceEntries = await CallLog.query(dateTimeFrom: _syncStartedAt);

      // Only incoming and outgoing — missed calls are not leads.
      final relevant = deviceEntries
          .where((e) =>
              e.callType == CallType.incoming ||
              e.callType == CallType.outgoing)
          .toList();

      // ── Pass 1: group calls by phone number ──────────────────────────────
      // Rules:
      //   • No phone number        → silently mark call ID, skip.
      //   • Already in _uploadedIds → Android logged same call twice, skip.
      //   • Already in _handledNumbers → user already confirmed/skipped this
      //     number; silently mark call ID and skip — no dialog.
      //   • Everything else        → collect into phoneToEntries so we show
      //     exactly ONE dialog per unique new number.

      final phoneToEntries = <String, List<CallLogEntry>>{};

      for (final entry in relevant) {
        final id       = _callId(entry);
        final rawPhone = entry.number;

        if (rawPhone == null || rawPhone.isEmpty) {
          _uploadedIds.add(id);
          continue;
        }
        if (_uploadedIds.contains(id)) continue;

        // Normalize so +919876543210, 09876543210, 9876543210 all match.
        final phone = _normalizePhone(rawPhone);

        if (_handledNumbers.contains(phone)) {
          // Already handled — mark the new call ID silently.
          _uploadedIds.add(id);
          continue;
        }

        phoneToEntries.putIfAbsent(phone, () => []).add(entry);
      }

      // Persist any silent marks from Pass 1.
      await _saveUploadedIds();

      print('[SYNC] ${phoneToEntries.length} unique new number(s) to prompt');

      // ── Pass 2: one dialog per unique new phone number ───────────────────
      for (final pe in phoneToEntries.entries) {
        if (!AuthService.instance.isLoggedIn) break;

        final phone   = pe.key;
        final entries = pe.value;
        // Use the first entry (newest call) for name and timestamp.
        final sample  = entries.first;
        final name    = (sample.name?.isNotEmpty == true) ? sample.name! : 'Unknown';

        // Show dialog. Returns null when there is no navigator context
        // (app backgrounded mid-loop) — do NOT mark anything so the number
        // will be prompted again next time the app is opened.
        final dialogResult = await _showConfirmDialog(name, phone);
        if (dialogResult == null) {
          print('[SYNC] No context for $phone — will retry next open');
          continue;
        }

        final (confirmed, resolvedName) = dialogResult;

        // Mark ALL call IDs for this number (handles the "3 calls, 1 dialog" case).
        for (final e in entries) {
          _uploadedIds.add(_callId(e));
        }
        await _saveUploadedIds();

        // Block this number permanently — no future dialogs.
        _handledNumbers.add(phone);
        await _saveHandledNumbers();

        if (!confirmed) {
          print('[SYNC] Lead skipped by user: $phone');
          continue;
        }

        if (!AuthService.instance.isLoggedIn) break;

        // Use the raw phone from the call log entry for the API and display.
        final displayPhone = sample.number ?? phone;
        final result = await _api.captureLead(
          phone:    displayPhone,
          name:     resolvedName,
          duration: sample.duration ?? 0,
        );
        if (result != null) {
          capturedLeads.value = [
            CapturedLead(
              name:      resolvedName,
              phone:     displayPhone,
              timestamp: sample.timestamp ?? DateTime.now().millisecondsSinceEpoch,
            ),
            ...capturedLeads.value,
          ];
          await _saveCapturedLeads();
        }
      }

      print('[SYNC] Done — handled numbers: ${_handledNumbers.length}, captured: ${capturedLeads.value.length}');
    } catch (e) {
      print('[SYNC] Sync error: $e');
    } finally {
      _syncing = false;
    }
  }

  // ── Confirmation dialog ─────────────────────────────────────────────────────

  // Returns null        → no context, dialog not shown — call will retry next app open.
  // Returns (true, name)  → user confirmed; name is whatever was entered (or original).
  // Returns (false, name) → user tapped Skip.
  Future<(bool, String)?> _showConfirmDialog(String name, String phone) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      print('[SYNC] No context — dialog skipped for $phone (will retry next open)');
      return null;
    }
    return showDialog<(bool, String)>(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => LeadConfirmDialog(name: name, phone: phone),
    );
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> _saveUploadedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kUploadedIds, _uploadedIds.toList());
  }

  Future<void> _saveHandledNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kHandledNumbers, _handledNumbers.toList());
  }

  Future<void> _saveCapturedLeads() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kCapturedLeads,
      capturedLeads.value.map(CapturedLead.encode).toList(),
    );
  }

  String _callId(CallLogEntry e) =>
      '${e.timestamp}_${e.number}_${e.callType?.name}';

  /// Strip non-digits and keep last 10 digits so that
  /// +919876543210, 919876543210, 09876543210 and 9876543210
  /// all compare equal in _handledNumbers.
  String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }
}
