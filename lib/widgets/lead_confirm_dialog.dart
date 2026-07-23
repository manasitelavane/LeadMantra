import 'dart:async';
import 'package:flutter/material.dart';
import '../core/connectivity_util.dart';
import '../core/theme.dart';

class LeadConfirmDialog extends StatefulWidget {
  const LeadConfirmDialog({
    super.key,
    required this.name,
    required this.phone,
    required this.hasInternet,
  });

  final String name;
  final String phone;
  final bool   hasInternet;

  @override
  State<LeadConfirmDialog> createState() => _LeadConfirmDialogState();
}

class _LeadConfirmDialogState extends State<LeadConfirmDialog> {
  bool _checked = false;
  late bool _hasInternet;
  late final TextEditingController _nameCtrl;
  Timer? _connectivityTimer;

  bool get _isUnknown =>
      widget.name.isEmpty || widget.name == 'Unknown';

  String get _resolvedName {
    if (!_isUnknown) return widget.name;
    final entered = _nameCtrl.text.trim();
    return entered.isNotEmpty ? entered : 'Unknown';
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl     = TextEditingController();
    _hasInternet  = widget.hasInternet;

    // Keep re-checking while the dialog is open so the button enables
    // itself the moment internet/Wi-Fi comes back, without needing to
    // close and reopen the popup.
    _connectivityTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final online = await hasInternetConnection();
      if (mounted && online != _hasInternet) {
        setState(() => _hasInternet = online);
      }
    });
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_add_alt_1_rounded,
                color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 10),
          const Text('New Lead', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Known name — show it prominently
          if (!_isUnknown) ...[
            Text(
              widget.name,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 2),
          ],

          Text(
            widget.phone,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),

          // Unknown name — let user type one
          if (_isUnknown) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Name (optional)',
                hintText: 'Enter customer name',
                prefixIcon: const Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: AppTheme.primary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
          ],

          const SizedBox(height: 16),
          InkWell(
            onTap: () => setState(() => _checked = !_checked),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Checkbox(
                  value: _checked,
                  activeColor: AppTheme.primary,
                  onChanged: (v) =>
                      setState(() => _checked = v ?? false),
                ),
                const Text(
                  'Confirm and send as lead',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (!_hasInternet) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(Icons.cloud_off_rounded,
                      size: 14, color: Colors.red.shade700),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'No internet — lead cannot be sent right now',
                    style: TextStyle(
                        fontSize: 12, color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, (false, widget.name)),
          child: const Text('Skip'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: (_checked && _hasInternet)
              ? () => Navigator.pop(context, (true, _resolvedName))
              : null,
          child: const Text('Send Lead'),
        ),
      ],
    );
  }
}
