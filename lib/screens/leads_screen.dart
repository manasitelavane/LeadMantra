import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/remote_lead.dart';
import '../services/api_service.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

enum _LoadState { loading, loaded, error }

class _LeadsScreenState extends State<LeadsScreen> {
  final _api             = ApiService();
  final _scrollController = ScrollController();

  final List<RemoteLead> _leads = [];
  RemoteLeadsMeta?        _meta;
  _LoadState              _state       = _LoadState.loading;
  bool                    _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore) return;
    if (_meta == null || !_meta!.hasMore) return;
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 200) {
      return;
    }
    _loadMore();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    final page = await _api.fetchLeads(page: 1);
    if (!mounted) return;
    if (page == null) {
      setState(() => _state = _LoadState.error);
      return;
    }
    setState(() {
      _leads
        ..clear()
        ..addAll(page.leads);
      _meta  = page.meta;
      _state = _LoadState.loaded;
    });
  }

  Future<void> _loadMore() async {
    final nextPage = _meta?.nextPage;
    if (nextPage == null) return;
    setState(() => _loadingMore = true);
    final page = await _api.fetchLeads(page: nextPage);
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      if (page != null) {
        _leads.addAll(page.leads);
        _meta = page.meta;
      }
    });
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date      = DateTime(dt.year, dt.month, dt.day);

    final String dateStr;
    if (date == today) {
      dateStr = 'Today';
    } else if (date == yesterday) {
      dateStr = 'Yesterday';
    } else {
      dateStr = '${dt.day.toString().padLeft(2, '0')}/'
                '${dt.month.toString().padLeft(2, '0')}/'
                '${dt.year}';
    }

    final hour   = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm   = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$dateStr, $hour:$minute $ampm';
  }

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
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());

      case _LoadState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 52, color: Colors.grey.withValues(alpha: 0.35)),
              const SizedBox(height: 14),
              const Text(
                'Couldn\'t load leads',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF555555)),
              ),
              const SizedBox(height: 4),
              Text(
                'Check your connection and try again.',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        );

      case _LoadState.loaded:
        if (_leads.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_add_alt_1_rounded,
                    size: 52, color: Colors.grey.withValues(alpha: 0.35)),
                const SizedBox(height: 14),
                const Text(
                  'No leads captured yet',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF555555)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Confirm a call prompt to send your first lead.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _load,
          child: Column(
            children: [
              Container(
                margin:  const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
                    const Icon(Icons.upload_rounded,
                        size: 14, color: AppTheme.accent),
                    const SizedBox(width: 8),
                    Text(
                      '${_meta?.total ?? _leads.length} lead'
                      '${(_meta?.total ?? _leads.length) == 1 ? '' : 's'} in your CRM',
                      style: const TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color:      AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller:       _scrollController,
                  physics:          const AlwaysScrollableScrollPhysics(),
                  padding:          const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount:        _leads.length + (_loadingMore ? 1 : 0),
                  separatorBuilder: (_, i) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    if (i >= _leads.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    return _LeadTile(
                      lead:          _leads[i],
                      formattedTime: _formatDateTime(_leads[i].createdAt),
                    );
                  },
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _LeadTile extends StatelessWidget {
  const _LeadTile({required this.lead, required this.formattedTime});

  final RemoteLead lead;
  final String     formattedTime;

  Color get _statusColor {
    switch (lead.status.toLowerCase()) {
      case 'converted':
      case 'won':
        return Colors.green;
      case 'contacted':
        return AppTheme.accent;
      case 'lost':
        return Colors.red;
      case 'new':
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          Container(
            width:  44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded,
                color: AppTheme.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lead.name,
                  style: const TextStyle(
                    fontSize:   14,
                    fontWeight: FontWeight.w700,
                    color:      Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lead.phone,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 11, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      formattedTime,
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:        _statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              lead.status,
              style: TextStyle(
                fontSize:   10,
                fontWeight: FontWeight.w600,
                color:      _statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
