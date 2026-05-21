import 'package:call_log/call_log.dart';

class StoredCallEntry {
  final int?    id;
  final String? deviceId;
  final String  callId;
  final String? name;
  final String? number;
  final String  callType;
  final int     timestamp;
  final int     duration;
  final int     syncedAt;
  final String? phoneAccountId;
  final String? simDisplayName;

  const StoredCallEntry({
    this.id,
    this.deviceId,
    required this.callId,
    this.name,
    this.number,
    required this.callType,
    required this.timestamp,
    required this.duration,
    required this.syncedAt,
    this.phoneAccountId,
    this.simDisplayName,
  });

  factory StoredCallEntry.fromCallLogEntry(CallLogEntry e, String deviceId) {
    final ts   = e.timestamp ?? DateTime.now().millisecondsSinceEpoch;
    final num  = e.number   ?? 'unknown';
    final type = e.callType?.name ?? 'unknown';
    return StoredCallEntry(
      deviceId:       deviceId,
      callId:         '${ts}_${num}_$type',
      name:           (e.name != null && e.name!.isNotEmpty) ? e.name : null,
      number:         e.number,
      callType:       type,
      timestamp:      ts,
      duration:       e.duration ?? 0,
      syncedAt:       DateTime.now().millisecondsSinceEpoch,
      phoneAccountId: e.phoneAccountId,
      simDisplayName: e.simDisplayName,
    );
  }

  factory StoredCallEntry.fromJson(Map<String, dynamic> json) {
    return StoredCallEntry(
      id:             json['id']               as int?,
      deviceId:       json['device_id']        as String?,
      callId:         json['call_id']          as String?  ?? '',
      name:           json['name']             as String?,
      number:         json['number']           as String?,
      callType:       json['call_type']        as String?  ?? 'unknown',
      timestamp:      (json['timestamp']       as num?)?.toInt() ?? 0,
      duration:       (json['duration']        as num?)?.toInt() ?? 0,
      syncedAt:       (json['synced_at']       as num?)?.toInt() ?? 0,
      phoneAccountId: json['phone_account_id'] as String?,
      simDisplayName: json['sim_display_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'device_id':        deviceId,
        'call_id':          callId,
        'name':             name,
        'number':           number,
        'call_type':        callType,
        'timestamp':        timestamp,
        'duration':         duration,
        'synced_at':        syncedAt,
        'phone_account_id': phoneAccountId,
        'sim_display_name': simDisplayName,
      };
}
