import 'package:flutter/material.dart';
import '../core/theme.dart';

class LeadConfirmDialog extends StatefulWidget {
  const LeadConfirmDialog({
    super.key,
    required this.name,
    required this.phone,
  });

  final String name;
  final String phone;

  @override
  State<LeadConfirmDialog> createState() => _LeadConfirmDialogState();
}

class _LeadConfirmDialogState extends State<LeadConfirmDialog> {
  bool _checked = false;

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
          Text(
            widget.name,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.phone,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => setState(() => _checked = !_checked),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Checkbox(
                  value: _checked,
                  activeColor: AppTheme.primary,
                  onChanged: (v) => setState(() => _checked = v ?? false),
                ),
                const Text(
                  'Confirm and send as lead',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
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
          onPressed: _checked ? () => Navigator.pop(context, true) : null,
          child: const Text('Send Lead'),
        ),
      ],
    );
  }
}
