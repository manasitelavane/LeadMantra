import 'package:flutter/material.dart';
import '../models/stored_call_entry.dart';
import '../utils/call_log_utils.dart';

class CallLogTile extends StatelessWidget {
  const CallLogTile({super.key, required this.entry});

  final StoredCallEntry entry;

  @override
  Widget build(BuildContext context) {
    final hasName     = entry.name != null && entry.name!.isNotEmpty;
    final displayName = hasName ? entry.name! : (entry.number ?? 'Unknown');
    final subtitle    = hasName ? (entry.number ?? '') : '';

    final (icon, color) = callTypeStyle(entry.callType);
    final timeLabel     = formatTimestamp(entry.timestamp);
    final durationLabel = formatDuration(entry.duration);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color:     Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset:    const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        dense:          true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width:  36,
          height: 36,
          decoration: BoxDecoration(
            color:        color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        title: Text(
          displayName,
          style:    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style:    const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Row(
              children: [
                Text(timeLabel,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                if (durationLabel.isNotEmpty)
                  Text('  ·  $durationLabel',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ],
        ),
        isThreeLine: subtitle.isNotEmpty,
      ),
    );
  }
}
