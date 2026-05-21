import 'package:flutter/material.dart';

String formatDuration(int? seconds) {
  if (seconds == null || seconds <= 0) return '';
  if (seconds < 60) return '${seconds}s';
  final m   = seconds ~/ 60;
  final s   = seconds % 60;
  if (m < 60) return s == 0 ? '${m}m' : '${m}m ${s}s';
  final h   = m ~/ 60;
  final rem = m % 60;
  return rem == 0 ? '${h}h' : '${h}h ${rem}m';
}

String callTypeLabel(String? type) => switch (type) {
      'incoming'     => 'Incoming',
      'outgoing'     => 'Outgoing',
      'missed'       => 'Missed',
      'rejected'     => 'Rejected',
      'blocked'      => 'Blocked',
      'voiceMail'    => 'Voicemail',
      'wifiIncoming' => 'WiFi Incoming',
      'wifiOutgoing' => 'WiFi Outgoing',
      _              => 'Unknown',
    };

(IconData, Color) callTypeStyle(String? type) => switch (type) {
      'incoming'     => (Icons.call_received_rounded, Colors.green),
      'outgoing'     => (Icons.call_made_rounded,     Colors.blue),
      'missed'       => (Icons.call_missed_rounded,   Colors.red),
      'rejected'     => (Icons.call_end_rounded,      Colors.orange),
      'blocked'      => (Icons.block_rounded,         Colors.grey),
      'voiceMail'    => (Icons.voicemail_rounded,     Colors.purple),
      'wifiIncoming' => (Icons.wifi_calling_rounded,  Colors.green),
      'wifiOutgoing' => (Icons.wifi_calling_rounded,  Colors.blue),
      _              => (Icons.call_rounded,          Colors.grey),
    };

String formatTimestamp(int milliseconds) {
  final dt  = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  final now = DateTime.now();
  final hh  = dt.hour.toString().padLeft(2, '0');
  final mm  = dt.minute.toString().padLeft(2, '0');
  final time = '$hh:$mm';

  final today     = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final callDay   = DateTime(dt.year, dt.month, dt.day);

  if (callDay == today)     return 'Today, $time';
  if (callDay == yesterday) return 'Yesterday, $time';

  const months = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
  final datePart = dt.year == now.year
      ? '${dt.day} ${months[dt.month - 1]}'
      : '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  return '$datePart, $time';
}

String formatDate(DateTime d) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String formatRangeLabel(DateTimeRange r) {
  final now       = DateTime.now();
  final today     = DateTime(now.year, now.month, now.day);
  final start     = DateTime(r.start.year, r.start.month, r.start.day);
  final end       = DateTime(r.end.year,   r.end.month,   r.end.day);
  if (start == end) {
    if (start == today) return 'Today';
    if (start == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return formatDate(r.start);
  }
  return '${formatDate(r.start)}  →  ${formatDate(r.end)}';
}

String rangeFileTag(DateTimeRange r) {
  String tag(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}_'
      '${d.month.toString().padLeft(2,'0')}_'
      '${d.year}';
  final s = DateTime(r.start.year, r.start.month, r.start.day);
  final e = DateTime(r.end.year,   r.end.month,   r.end.day);
  return s == e ? tag(r.start) : '${tag(r.start)}_to_${tag(r.end)}';
}
