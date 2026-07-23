import 'dart:async';
import 'dart:io';

/// Quick real-connectivity probe (not just "connected to Wi-Fi/mobile data").
/// A DNS lookup only succeeds if there is an actual working internet path.
Future<bool> hasInternetConnection({
  Duration timeout = const Duration(seconds: 3),
}) async {
  try {
    final result = await InternetAddress.lookup('google.com').timeout(timeout);
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } on SocketException {
    return false;
  } on TimeoutException {
    return false;
  }
}
