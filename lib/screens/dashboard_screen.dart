import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/theme.dart';
import '../models/captured_lead.dart';
import '../models/stored_call_entry.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/lead_sync_service.dart';
import '../widgets/call_log_tile.dart';
import 'call_log_screen.dart';
import 'delete_account_screen.dart';
import 'leads_screen.dart';
import 'login_screen.dart';
import 'privacy_policy_screen.dart';
import 'privacy_web_screen.dart';
import 'skipped_leads_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  static const _kEventChannel =
      EventChannel('com.leadmantracrm.app/call_log_events');

  bool                  _loading  = true;
  List<StoredCallEntry> _allCalls = [];

  // Backend-truth lead count (server total, across all sources/devices) —
  // falls back to the local capturedLeads count while loading or offline.
  int? _leadsCapturedTotal;

  final _api = ApiService();

  StreamSubscription<dynamic>? _callLogSub;
  Timer?                       _refreshDebounce;

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
    _refreshDebounce?.cancel();
    LeadSyncService.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _loadStats();
    LeadSyncService.instance.syncNow();
  }

  Future<void> _init() async {
    final consented = await _hasConsented();
    if (!consented) {
      if (!mounted) return;
      final agreed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const PrivacyPolicyScreen(isConsent: true),
          fullscreenDialog: true,
        ),
      );
      if (agreed != true) {
        if (!mounted) return;
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const LoginScreen()));
        return;
      }
      await _saveConsent();
    }
    await LeadSyncService.instance.start();
    await _loadStats();
    // Catch up on any calls that happened while the app was closed.
    LeadSyncService.instance.syncNow();
    _subscribeToCallLogChanges();
  }

  // Auto-refresh the stat cards live while the Dashboard is open, whenever
  // the device call log changes (new call logged, either end).
  void _subscribeToCallLogChanges() {
    if (!Platform.isAndroid) return;
    _callLogSub ??= _kEventChannel.receiveBroadcastStream().listen(
      (_) {
        _refreshDebounce?.cancel();
        _refreshDebounce = Timer(const Duration(seconds: 2), _loadStats);
      },
      onError: (_) {},
    );
  }

  Future<bool> _hasConsented() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/.consent').existsSync();
  }

  Future<void> _saveConsent() async {
    final dir = await getApplicationDocumentsDirectory();
    await File('${dir.path}/.consent').writeAsString('1');
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => _loading = true);
    unawaited(_loadLeadsTotal());
    try {
      if (!Platform.isAndroid) { setState(() => _loading = false); return; }

      final status = await Permission.phone.status;
      if (status.isDenied || status.isRestricted) {
        await Permission.phone.request();
      }
      final now        = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final raw = await CallLog.query(dateTimeFrom: todayStart);
      final entries = raw
          .map((e) => StoredCallEntry.fromCallLogEntry(e, ''))
          .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (mounted) setState(() => _allCalls = entries);
    } on PlatformException {
      // Permission denied — show empty state gracefully.
    } catch (_) {
      // Ignore other errors silently on dashboard.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Backend is the source of truth for total leads captured (includes leads
  // created via web/other devices, not just this device's local history).
  // meta.total is the full count regardless of how many entries `data` holds
  // for this page, so a plain first-page fetch is enough.
  Future<void> _loadLeadsTotal() async {
    final page = await _api.fetchLeads(page: 1);
    if (mounted && page != null) {
      setState(() => _leadsCapturedTotal = page.meta.total);
    }
  }

  // ── Computed stats (all from today only) ───────────────────────────────────

  int get _totalToday     => _allCalls.length;
  int get _missedToday    => _allCalls.where((e) => e.callType == 'missed').length;
  int get _connectedToday => _allCalls.where(
      (e) => (e.callType == 'incoming' || e.callType == 'outgoing') && e.duration > 0).length;

  int get _pipelineNew       => _missedToday;
  int get _pipelineContacted => _allCalls.where(
      (e) => e.callType == 'incoming' || e.callType == 'outgoing').length;
  int get _pipelineConverted => _allCalls.where(
      (e) => (e.callType == 'incoming' || e.callType == 'outgoing') && e.duration > 60).length;

  // ── Navigation ─────────────────────────────────────────────────────────────

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label, Color? color) {
    return PopupMenuItem<String>(
      value:   value,
      height:  36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color ?? AppTheme.primary),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _openCallLogs() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CallLogScreen()),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
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
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'logout') {
                await AuthService.instance.logout();
                if (!context.mounted) return;
                Navigator.pushReplacement(context, MaterialPageRoute(
                    builder: (_) => const LoginScreen()));
              } else if (v == 'login') {
                Navigator.pushReplacement(context, MaterialPageRoute(
                    builder: (_) => const LoginScreen()));
              } else if (v == 'privacy') {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const PrivacyWebScreen()));
              } else if (v == 'delete') {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const DeleteAccountScreen()));
              }
            },
            itemBuilder: (_) => [
              _menuItem('privacy', Icons.privacy_tip_rounded,    'Privacy Policy', null),
              const PopupMenuDivider(height: 1),
              if (AuthService.instance.isLoggedIn) ...[
                _menuItem('logout', Icons.logout_rounded,         'Logout',         Colors.red.shade400),
              ] else ...[
                _menuItem('login',  Icons.login_rounded,          'Login',          null),
              ],
              const PopupMenuDivider(height: 1),
              _menuItem('delete',  Icons.delete_forever_rounded, 'Delete Account', Colors.red.shade400),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _GreetingCard(),
                  const SizedBox(height: 16),
                  _SectionLabel('Today\'s Overview'),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<List<CapturedLead>>(
                    valueListenable: LeadSyncService.instance.capturedLeads,
                    builder: (_, leads, child) => ValueListenableBuilder<List<CapturedLead>>(
                      valueListenable: LeadSyncService.instance.skippedLeads,
                      builder: (_, skipped, child) => _StatsGrid(
                        totalToday:     _totalToday,
                        capturedLeads:  _leadsCapturedTotal ?? leads.length,
                        skippedLeads:   skipped.length,
                        connectedToday: _connectedToday,
                        onTapTotal:     () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const CallLogScreen())),
                        onTapLeads:     () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const LeadsScreen())),
                        onTapSkipped:   () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const SkippedLeadsScreen())),
                        onTapConnected: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const CallLogScreen(initialFilter: 'connected'))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SectionLabel('Lead Pipeline'),
                  const SizedBox(height: 10),
                  _PipelineCard(
                    newLeads:       _pipelineNew,
                    contacted:      _pipelineContacted,
                    converted:      _pipelineConverted,
                  ),
                  const SizedBox(height: 20),
                  _SectionLabel('Recent Activity'),
                  const SizedBox(height: 10),
                  if (_allCalls.isEmpty)
                    _EmptyActivity()
                  else
                    ..._allCalls.take(5).map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child:   CallLogTile(entry: e),
                        )),
                  const SizedBox(height: 20),
                  _ViewAllButton(onTap: _openCallLogs),
                ],
              ),
            ),
    );
  }
}

// ── Greeting card ─────────────────────────────────────────────────────────────

class _GreetingCard extends StatelessWidget {
  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryVariant],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_greeting! 👋',
                  style: const TextStyle(
                    color:      Colors.white70,
                    fontSize:   13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Never Miss a Lead Again',
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'WhatsApp-First CRM Built for India',
                  style: TextStyle(
                    color:   Colors.white60,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:        Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Image.asset(
              'assets/images/logo_1 1.png',
              height: 44,
              width:  44,
              fit:    BoxFit.contain,
              errorBuilder: (ctx, err, st) => const Icon(
                  Icons.trending_up_rounded, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize:    14,
        fontWeight:  FontWeight.w700,
        color:       AppTheme.primary,
        letterSpacing: 0.2,
      ),
    );
  }
}

// ── 2x2 stats grid ────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.totalToday,
    required this.capturedLeads,
    required this.skippedLeads,
    required this.connectedToday,
    this.onTapTotal,
    this.onTapLeads,
    this.onTapSkipped,
    this.onTapConnected,
  });

  final int totalToday;
  final int capturedLeads;
  final int skippedLeads;
  final int connectedToday;
  final VoidCallback? onTapTotal;
  final VoidCallback? onTapLeads;
  final VoidCallback? onTapSkipped;
  final VoidCallback? onTapConnected;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount:   2,
      crossAxisSpacing: 10,
      mainAxisSpacing:  10,
      childAspectRatio: 1.4,
      shrinkWrap:       true,
      physics:          const NeverScrollableScrollPhysics(),
      children: [
        _StatCard(
          icon:  Icons.call_rounded,
          color: AppTheme.primary,
          label: 'Total Calls',
          value: '$totalToday',
          sub:   'today',
          onTap: onTapTotal,
        ),
        _StatCard(
          icon:  Icons.person_add_alt_1_rounded,
          color: AppTheme.accent,
          label: 'Leads Captured',
          value: '$capturedLeads',
          sub:   'uploaded to CRM',
          onTap: onTapLeads,
        ),
        _StatCard(
          icon:  Icons.person_off_rounded,
          color: Colors.deepOrange,
          label: 'Skipped',
          value: '$skippedLeads',
          sub:   'leads skipped',
          onTap: onTapSkipped,
        ),
        _StatCard(
          icon:  Icons.check_circle_rounded,
          color: Colors.green,
          label: 'Connected',
          value: '$connectedToday',
          sub:   'successful calls',
          onTap: onTapConnected,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.sub,
    this.onTap,
  });

  final IconData      icon;
  final Color         color;
  final String        label;
  final String        value;
  final String        sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:     Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset:    const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color:        color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize:   22,
                fontWeight: FontWeight.w800,
                color:      color,
                height:     1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize:   11,
                fontWeight: FontWeight.w600,
                color:      Color(0xFF333333),
              ),
            ),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    ),   // Container
    );   // GestureDetector
  }
}

// ── Pipeline card ─────────────────────────────────────────────────────────────

class _PipelineCard extends StatelessWidget {
  const _PipelineCard({
    required this.newLeads,
    required this.contacted,
    required this.converted,
  });

  final int newLeads;
  final int contacted;
  final int converted;

  @override
  Widget build(BuildContext context) {
    final total = (newLeads + contacted + converted).clamp(1, double.infinity).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:     Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset:    const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _PipelineStage(
                label: 'New',
                sub:   'missed calls',
                count: newLeads,
                color: Colors.orange,
                icon:  Icons.fiber_new_rounded,
              ),
              _PipelineArrow(),
              _PipelineStage(
                label: 'Contacted',
                sub:   'calls made',
                count: contacted,
                color: AppTheme.primary,
                icon:  Icons.phone_in_talk_rounded,
              ),
              _PipelineArrow(),
              _PipelineStage(
                label: 'Converted',
                sub:   '>1 min call',
                count: converted,
                color: Colors.green,
                icon:  Icons.check_circle_outline_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                _BarSegment(
                    flex: newLeads, total: total, color: Colors.orange),
                _BarSegment(
                    flex: contacted, total: total, color: AppTheme.primary),
                _BarSegment(
                    flex: converted, total: total, color: Colors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PipelineStage extends StatelessWidget {
  const _PipelineStage({
    required this.label,
    required this.sub,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String   label;
  final String   sub;
  final int      count;
  final Color    color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:        color.withValues(alpha: 0.10),
              shape:        BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize:   20,
              fontWeight: FontWeight.w800,
              color:      color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize:   11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            sub,
            style: TextStyle(fontSize: 9, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PipelineArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Icon(
      Icons.chevron_right_rounded, color: Color(0xFFBBBBBB), size: 20);
}

class _BarSegment extends StatelessWidget {
  const _BarSegment({
    required this.flex,
    required this.total,
    required this.color,
  });

  final int   flex;
  final int   total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = flex / total;
    return Expanded(
      flex: (pct * 100).round().clamp(1, 100),
      child: Container(height: 6, color: color),
    );
  }
}

// ── Empty activity ────────────────────────────────────────────────────────────

class _EmptyActivity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(Icons.call_missed_rounded,
              size: 36, color: Colors.grey.withValues(alpha: 0.4)),
          const SizedBox(height: 10),
          Text('No calls recorded yet',
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

// ── View all button ───────────────────────────────────────────────────────────

class _ViewAllButton extends StatelessWidget {
  const _ViewAllButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.accent, Color(0xFFEF6C00)],
            begin:  Alignment.centerLeft,
            end:    Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color:     AppTheme.accent.withValues(alpha: 0.35),
              blurRadius: 12,
              offset:    const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.call_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'View All Call Logs',
              style: TextStyle(
                color:      Colors.white,
                fontSize:   14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}
