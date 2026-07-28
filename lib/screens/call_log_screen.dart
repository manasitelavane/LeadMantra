import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/theme.dart';
import '../models/stored_call_entry.dart';
import '../utils/call_log_utils.dart';
import '../widgets/action_view.dart';
import '../widgets/call_log_tile.dart';
import '../widgets/loading_view.dart';
import 'privacy_policy_screen.dart';

enum _ScreenState {
  loading,
  permissionDenied,
  permissionPermanentlyDenied,
  unsupportedPlatform,
  error,
  empty,
  loaded,
}

class CallLogScreen extends StatefulWidget {
  /// Optional call-type filter pre-applied on open.
  /// Accepted values: null (all), 'missed', 'connected'.
  const CallLogScreen({super.key, this.initialFilter});
  final String? initialFilter;

  @override
  State<CallLogScreen> createState() => _CallLogScreenState();
}

class _CallLogScreenState extends State<CallLogScreen>
    with WidgetsBindingObserver {

  static const _kEventChannel =
      EventChannel('com.leadmantracrm.app/call_log_events');
  StreamSubscription<dynamic>? _callLogSub;
  Timer? _syncDebounce;

  _ScreenState          _state        = _ScreenState.loading;
  List<StoredCallEntry> _entries      = [];
  String                _errorMessage = '';
  bool                  _isSyncing    = false;
  bool                  _isLoading    = false;
  late String?          _callTypeFilter = widget.initialFilter;

  final Map<String, StoredCallEntry> _seenEntries = {};

  String? _selectedSimId;

  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    end:   DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
  );

  // ── Computed ──────────────────────────────────────────────────────────────

  List<StoredCallEntry> get _filteredEntries {
    final rangeEnd = DateTime(
        _dateRange.end.year, _dateRange.end.month, _dateRange.end.day + 1);
    return _entries.where((e) {
      final dt = DateTime.fromMillisecondsSinceEpoch(e.timestamp);
      if (dt.isBefore(_dateRange.start) || !dt.isBefore(rangeEnd)) return false;
      if (_selectedSimId != null && e.simDisplayName != _selectedSimId) return false;
      if (_callTypeFilter == 'missed'    && e.callType != 'missed') return false;
      if (_callTypeFilter == 'connected' && !((e.callType == 'incoming' || e.callType == 'outgoing') && e.duration > 0)) return false;
      return true;
    }).toList();
  }

  // Groups by simDisplayName (carrier name) — avoids duplicate chips on single-SIM
  // devices that expose multiple phoneAccountIds (VoIP, WhatsApp, system accounts).
  // Those extra accounts often report a bare numeral (e.g. "3") instead of a real
  // carrier name — real carrier names always contain a letter, so numeral-only
  // labels are dropped rather than shown as a phantom SIM chip.
  static final RegExp _hasLetter = RegExp('[A-Za-z]');

  Map<String, String> get _availableSims {
    final sims = <String, String>{};
    for (final e in _entries) {
      final name = e.simDisplayName;
      if (name == null || name.isEmpty) continue;
      if (!_hasLetter.hasMatch(name)) continue;
      sims[name] = name;
    }
    return sims;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callLogSub?.cancel();
    _syncDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_state == _ScreenState.loaded || _state == _ScreenState.empty) {
      _syncInBackground();
    }
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> _init() async {
    await _loadCallLogs();
    _subscribeToCallLogChanges();
  }

  // ── ContentObserver subscription ──────────────────────────────────────────

  void _subscribeToCallLogChanges() {
    if (!Platform.isAndroid) return;
    _callLogSub = _kEventChannel.receiveBroadcastStream().listen(
      (_) {
        _syncDebounce?.cancel();
        _syncDebounce = Timer(const Duration(seconds: 5), _syncInBackground);
      },
      onError: (_) {},
    );
  }

  // ── Full load ─────────────────────────────────────────────────────────────

  Future<void> _loadCallLogs() async {
    if (_isLoading || !mounted) return;
    _isLoading = true;
    setState(() => _state = _ScreenState.loading);

    try {
      if (!Platform.isAndroid) {
        setState(() => _state = _ScreenState.unsupportedPlatform);
        return;
      }

      final status = await Permission.phone.status;
      if (status.isPermanentlyDenied) {
        setState(() => _state = _ScreenState.permissionPermanentlyDenied);
        return;
      }
      if (status.isDenied || status.isRestricted) {
        final result = await Permission.phone.request();
        if (result.isPermanentlyDenied) {
          setState(() => _state = _ScreenState.permissionPermanentlyDenied);
          return;
        }
        if (!result.isGranted) {
          setState(() => _state = _ScreenState.permissionDenied);
          return;
        }
      }

      final deviceEntries = await CallLog.get();
      final loaded = deviceEntries
          .map((e) => StoredCallEntry.fromCallLogEntry(e, ''))
          .toList();

      for (final e in loaded) {
        _seenEntries.putIfAbsent(e.callId, () => e);
      }

      final display = _seenEntries.values.toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (!mounted) return;
      setState(() {
        _entries = display;
        _state   = _entries.isEmpty ? _ScreenState.empty : _ScreenState.loaded;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      final msg = (e.message ?? '').toLowerCase();
      if (msg.contains('permission') ||
          msg.contains('read_call_log') ||
          msg.contains('securityexception')) {
        setState(() => _state = _ScreenState.permissionPermanentlyDenied);
      } else {
        setState(() {
          _state        = _ScreenState.error;
          _errorMessage = e.message ?? 'A platform error occurred.';
        });
      }
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _state        = _ScreenState.error;
        _errorMessage = 'The call_log plugin is not available on this device.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state        = _ScreenState.error;
        _errorMessage = e.toString();
      });
    } finally {
      _isLoading = false;
    }
  }

  // ── Background sync ───────────────────────────────────────────────────────

  Future<void> _syncInBackground() async {
    if (_isSyncing) return;
    if (_state != _ScreenState.loaded && _state != _ScreenState.empty) return;
    if (mounted) setState(() => _isSyncing = true);

    try {
      final deviceEntries = await CallLog.get();
      for (final e in deviceEntries) {
        final entry = StoredCallEntry.fromCallLogEntry(e, '');
        _seenEntries.putIfAbsent(entry.callId, () => entry);
      }

      final display = _seenEntries.values.toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (!mounted) return;
      setState(() {
        _entries = display;
        _state   = _entries.isEmpty ? _ScreenState.empty : _ScreenState.loaded;
      });
    } catch (_) {
      // Silent — background sync must not interrupt the user.
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _openSettings() async => openAppSettings();

  Future<void> _pickDate() async {
    final now    = DateTime.now();
    final picked = await showDateRangePicker(
      context:          context,
      initialDateRange: _dateRange,
      firstDate:        DateTime(now.year - 5),
      lastDate:         now,
      helpText:         'Select date range',
      saveText:         'APPLY',
    );
    if (picked != null && mounted) setState(() => _dateRange = picked);
  }


  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLoaded = _state == _ScreenState.loaded;
    final filtered = isLoaded ? _filteredEntries : <StoredCallEntry>[];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(
          'assets/images/logo_2 1.png',
          height: 55,
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, st) => const Text('LeadMantraCRM'),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(color: AppTheme.accent, height: 3),
        ),
        actions: [
          if (isLoaded || _state == _ScreenState.empty)
            IconButton(
              icon:      const Icon(Icons.refresh_rounded),
              tooltip:   'Refresh',
              onPressed: _loadCallLogs,
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'privacy') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyScreen()),
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'privacy',
                child: Row(
                  children: [
                    Icon(Icons.privacy_tip_rounded),
                    SizedBox(width: 12),
                    Text('Privacy Policy'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: KeyedSubtree(
          key:   ValueKey(_state),
          child: _buildBody(filtered),
        ),
      ),
    );
  }

  Widget _buildBody(List<StoredCallEntry> filtered) {
    return switch (_state) {
      _ScreenState.loading => const LoadingView(),
      _ScreenState.permissionDenied => ActionView(
          icon:        Icons.phone_locked_rounded,
          iconColor:   Colors.orange,
          title:       'Permission Required',
          message:     'Read Call Log permission is needed to display your call history.',
          actionLabel: 'Grant Permission',
          onAction:    _loadCallLogs,
        ),
      _ScreenState.permissionPermanentlyDenied => ActionView(
          icon:        Icons.settings_rounded,
          iconColor:   Colors.red,
          title:       'Permission Required',
          message:     'On Android 9 and above, "Read Call Log" is a separate '
                       'permission.\n\nGo to App Settings → Permissions → Call logs → Allow.',
          actionLabel: 'Open App Settings',
          onAction:    _openSettings,
        ),
      _ScreenState.unsupportedPlatform => const ActionView(
          icon:        Icons.phone_android_rounded,
          iconColor:   Colors.grey,
          title:       'Android Only',
          message:     'Call log access is only available on Android devices.',
          actionLabel: null,
          onAction:    null,
        ),
      _ScreenState.error => ActionView(
          icon:        Icons.error_outline_rounded,
          iconColor:   Colors.red,
          title:       'Something Went Wrong',
          message:     _errorMessage,
          actionLabel: 'Retry',
          onAction:    _loadCallLogs,
        ),
      _ScreenState.empty => const ActionView(
          icon:        Icons.call_missed_rounded,
          iconColor:   Colors.grey,
          title:       'No Call Logs',
          message:     'Your call history is empty.',
          actionLabel: null,
          onAction:    null,
        ),
      _ScreenState.loaded => _buildLoadedBody(filtered),
    };
  }

  Widget _buildLoadedBody(List<StoredCallEntry> filtered) {
    return Column(
      children: [
        _DateBar(
          range:    _dateRange,
          count:    filtered.length,
          onTap:    _pickDate,
        ),
        if (_availableSims.length > 1)
          _SimFilterBar(
            sims:           _availableSims,
            selectedSimId:  _selectedSimId,
            onSelect: (id) => setState(() =>
                _selectedSimId = _selectedSimId == id ? null : id),
            onClear: ()    => setState(() => _selectedSimId = null),
          ),
        if (_isSyncing)
          LinearProgressIndicator(
            minHeight: 2,
            color:     Theme.of(context).colorScheme.primary,
          ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.call_missed_rounded,
                          size:  40,
                          color: Colors.grey.withValues(alpha: 0.4)),
                      const SizedBox(height: 10),
                      Text(
                        'No calls for ${formatRangeLabel(_dateRange)}',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCallLogs,
                  child: ListView.builder(
                    physics:   const AlwaysScrollableScrollPhysics(),
                    padding:   const EdgeInsets.fromLTRB(12, 6, 12, 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => CallLogTile(entry: filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Date bar ──────────────────────────────────────────────────────────────────

class _DateBar extends StatelessWidget {
  const _DateBar({
    required this.range,
    required this.count,
    required this.onTap,
  });

  final DateTimeRange range;
  final int           count;
  final VoidCallback  onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin:  const EdgeInsets.fromLTRB(12, 10, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: const Border(
            left: BorderSide(color: AppTheme.accent, width: 3),
          ),
          boxShadow: [
            BoxShadow(
              color:     Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset:    const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.date_range_rounded,
                size: 14, color: AppTheme.accent),
            const SizedBox(width: 8),
            Text(
              formatRangeLabel(range),
              style: const TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.w600,
                  color:      AppTheme.primary),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color:        AppTheme.accentLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count call${count == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize:   11,
                    fontWeight: FontWeight.w600,
                    color:      AppTheme.accent),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

// ── SIM filter bar ────────────────────────────────────────────────────────────

class _SimFilterBar extends StatelessWidget {
  const _SimFilterBar({
    required this.sims,
    required this.selectedSimId,
    required this.onSelect,
    required this.onClear,
  });

  final Map<String, String> sims;
  final String?             selectedSimId;
  final ValueChanged<String> onSelect;
  final VoidCallback         onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.sim_card_rounded,
              size: 13, color: AppTheme.primary),
          const SizedBox(width: 6),
          ...sims.entries.map((sim) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label:      Text(sim.value),
              labelStyle: TextStyle(
                color: selectedSimId == sim.key
                    ? Colors.white
                    : AppTheme.accent,
                fontWeight: FontWeight.w600,
              ),
              selected:   selectedSimId == sim.key,
              onSelected: (_) => onSelect(sim.key),
            ),
          )),
          if (selectedSimId != null)
            TextButton(
              style: TextButton.styleFrom(
                padding:        EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onClear,
              child: const Text('All'),
            ),
        ],
      ),
    );
  }
}
