import 'dart:convert';

class CapturedLead {
  const CapturedLead({
    required this.name,
    required this.phone,
    required this.timestamp,
    this.duration = 0,
  });

  final String name;
  final String phone;
  final int    timestamp; // milliseconds since epoch
  final int    duration;  // the original call's duration, in seconds

  Map<String, dynamic> toJson() => {
    'name':     name,
    'phone':    phone,
    'ts':       timestamp,
    'duration': duration,
  };

  factory CapturedLead.fromJson(Map<String, dynamic> j) => CapturedLead(
    name:      j['name']     as String? ?? 'Unknown',
    phone:     j['phone']    as String,
    timestamp: j['ts']       as int,
    duration:  j['duration'] as int? ?? 0,
  );

  static String encode(CapturedLead l) => jsonEncode(l.toJson());
  static CapturedLead decode(String s)  =>
      CapturedLead.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
