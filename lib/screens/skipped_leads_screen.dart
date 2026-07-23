import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/captured_lead.dart';
import '../services/lead_sync_service.dart';

class SkippedLeadsScreen extends StatelessWidget {
  const SkippedLeadsScreen({super.key});

  String _formatDateTime(int ms) {
    final dt  = DateTime.fromMillisecondsSinceEpoch(ms);
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
      body: ValueListenableBuilder<List<CapturedLead>>(
        valueListenable: LeadSyncService.instance.skippedLeads,
        builder: (_, leads, child) {
          if (leads.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block_rounded,
                      size: 52, color: Colors.grey.withValues(alpha: 0.35)),
                  const SizedBox(height: 14),
                  const Text(
                    'No leads skipped yet',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF555555)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Numbers you skip from the call prompt will show up here.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // count banner
              Container(
                margin:  const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(
                    left: BorderSide(color: Colors.deepOrange, width: 3),
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
                    const Icon(Icons.block_rounded,
                        size: 14, color: Colors.deepOrange),
                    const SizedBox(width: 8),
                    Text(
                      '${leads.length} lead${leads.length == 1 ? '' : 's'} skipped',
                      style: const TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color:      Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.separated(
                  padding:          const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount:        leads.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _SkippedLeadTile(
                    lead:            leads[i],
                    formattedTime:   _formatDateTime(leads[i].timestamp),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SkippedLeadTile extends StatelessWidget {
  const _SkippedLeadTile({required this.lead, required this.formattedTime});

  final CapturedLead lead;
  final String       formattedTime;

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
              color: Colors.deepOrange.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_off_rounded,
                color: Colors.deepOrange, size: 22),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:        Colors.deepOrange.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Skipped',
              style: TextStyle(
                fontSize:   10,
                fontWeight: FontWeight.w600,
                color:      Colors.deepOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
