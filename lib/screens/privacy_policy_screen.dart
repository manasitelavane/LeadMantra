import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  /// [isConsent] true → first-launch mode with Agree / Decline buttons.
  /// false → read-only mode opened from the menu.
  final bool isConsent;

  const PrivacyPolicyScreen({super.key, this.isConsent = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: isConsent
          ? null
          : AppBar(
              title: const Text('Privacy Policy'),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: Container(color: const Color(0xFFF57C00), height: 3),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Scrollable content ───────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header (only in consent mode)
                    if (isConsent) ...[
                      Center(
                        child: Image.asset(
                          'assets/images/logo_1 1.png',
                          height: 64,
                          fit:    BoxFit.contain,
                          errorBuilder: (ctx, err, st) => Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE3F2FD),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shield_rounded,
                                size: 40, color: Color(0xFF1976D2)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          'Privacy Policy',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          'Please read and agree before continuing',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ── Policy sections ──────────────────────────────────
                    _PolicySection(
                      icon:  Icons.track_changes_rounded,
                      color: Colors.indigo,
                      title: 'Purpose of This App',
                      body:
                          'This app is designed exclusively for business lead '
                          'capture. When someone calls your number, we capture '
                          'their contact details to help you follow up and grow '
                          'your customer base.',
                    ),
                    _PolicySection(
                      icon:  Icons.phone_in_talk_rounded,
                      color: Colors.teal,
                      title: 'Data We Collect',
                      body:
                          'With your permission, we collect the following from '
                          'your call log:\n\n'
                          '  •  Caller\'s phone number\n'
                          '  •  Caller\'s name (if saved in contacts)\n'
                          '  •  Call duration in seconds',
                    ),
                    _PolicySection(
                      icon:  Icons.campaign_rounded,
                      color: Colors.orange,
                      title: 'How We Use Your Data',
                      body:
                          'Collected data is used solely to:\n\n'
                          '  •  Capture new business leads\n'
                          '  •  Send marketing and promotional messages '
                          'to potential customers\n'
                          '  •  Help you manage and follow up with new contacts',
                    ),
                    _PolicySection(
                      icon:  Icons.lock_rounded,
                      color: Colors.green,
                      title: 'Your Permission',
                      body:
                          'We access your call log only after you explicitly '
                          'grant the "Read Call Log" permission. You can revoke '
                          'this permission at any time from your device Settings '
                          '→ Apps → Permissions.',
                    ),
                    _PolicySection(
                      icon:  Icons.storage_rounded,
                      color: Colors.purple,
                      title: 'Data Storage & Security',
                      body:
                          'Lead information is securely transmitted to and '
                          'stored on our servers. We do not sell or share your '
                          'data with any third parties.',
                    ),
                    _PolicySection(
                      icon:  Icons.info_outline_rounded,
                      color: Colors.blueGrey,
                      title: 'No Other Use',
                      body:
                          'This app does not record call audio, access messages, '
                          'location, or any data beyond what is listed above. '
                          'Call log data is only used for lead management.',
                    ),
                  ],
                ),
              ),
            ),

            // ── Consent buttons (first-launch mode only) ─────────────────
            if (isConsent)
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(
                    top: BorderSide(color: cs.outlineVariant),
                  ),
                ),
                child: Column(
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'I Agree & Continue',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Single policy section row ──────────────────────────────────────────────

class _PolicySection extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   title;
  final String   body;

  const _PolicySection({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 1),
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                      color: Colors.grey[600], height: 1.5, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
