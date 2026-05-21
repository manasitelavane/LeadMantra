import 'package:flutter/material.dart';

class ActionView extends StatelessWidget {
  const ActionView({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData      icon;
  final Color         iconColor;
  final String        title;
  final String        message;
  final String?       actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: iconColor.withValues(alpha: 0.75)),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey[600], height: 1.5),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                icon:      const Icon(Icons.check_circle_outline_rounded,
                    size: 16),
                label:     Text(actionLabel!,
                    style: const TextStyle(fontSize: 13)),
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
