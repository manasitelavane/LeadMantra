import 'package:flutter/material.dart';
import 'navigator_key.dart';

/// Set to true to show a snackbar for every API call (useful during testing).
/// Set to false before publishing to Play Store.
const bool kShowApiSnackbar = true;

void showApiSnackbar(String endpoint, int statusCode, {bool success = true}) {
  if (!kShowApiSnackbar) return;
  final ctx = navigatorKey.currentContext;
  if (ctx == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ScaffoldMessenger.of(ctx).clearSnackBars();
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '[$statusCode] $endpoint',
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: success ? const Color(0xFF2E7D32) : Colors.red.shade700,
        behavior:        SnackBarBehavior.floating,
        duration:        const Duration(seconds: 3),
        margin:          const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  });
}
