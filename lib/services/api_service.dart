// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_endpoints.dart';
import '../core/app_config.dart';
import 'auth_service.dart';

class ApiService {
  static const _captureLeadUrl = ApiEndpoints.captureCallLead;
  static const _timeout = Duration(seconds: 30);

  final http.Client _client;
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<String?> captureLead({
    required String phone,
    String?        name,
    required int   duration,
  }) async {
    final payload = {
      'caller_phone': phone,
      'caller_name':  name ?? 'Unknown',
      'duration':     duration,
    };
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('[LEAD CAPTURE] Sending to API:');
    print('  caller_phone : $phone');
    print('  caller_name  : ${name ?? "Unknown"}');
    print('  duration     : ${duration}s');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      final res = await _client
          .post(
            Uri.parse(_captureLeadUrl),
            headers: {
              'Content-Type':  'application/json',
              'Authorization': 'Bearer ${AuthService.instance.token ?? ''}',
            },
            body: jsonEncode(payload),
          )
          .timeout(_timeout);

      print('[API] captureLead ← ${res.statusCode} ${res.body}');
      showApiSnackbar('POST /call-lead/capture', res.statusCode,
          success: res.statusCode == 200);

      if (res.statusCode == 401) {
        AuthService.instance.handleExpiredSession(redirect: true);
        return null;
      }

      try {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        return json['message'] as String?;
      } catch (_) {
        return null;
      }
    } catch (e) {
      print('[API] captureLead error: $e');
      return null;
    }
  }
}
