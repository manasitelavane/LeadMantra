import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _confirmController = TextEditingController();
  bool _isDeleting = false;
  bool get _canDelete =>
      _confirmController.text.trim().toUpperCase() == 'DELETE';

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text('Are you sure?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'This action is permanent and cannot be undone.\n\n'
          'All your data, call logs, and lead history will be '
          'permanently erased.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteAccount();
            },
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    setState(() => _isDeleting = true);
    final result = await AuthService.instance.deleteAccount();
    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (result.success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deleted successfully.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Failed to delete account.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(
          'assets/images/logo_2 1.png',
          height: 55,
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, st) => const Text('LeadMantraCRM'),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(color: Colors.red, height: 3),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Danger header card ─────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color:        const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade200, width: 1.5),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color:  Colors.red.shade100,
                        shape:  BoxShape.circle,
                      ),
                      child: Icon(Icons.delete_forever_rounded,
                          color: Colors.red.shade700, size: 32),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Delete Your Account',
                      style: TextStyle(
                        fontSize:   20,
                        fontWeight: FontWeight.w800,
                        color:      Colors.red.shade800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This action is permanent and cannot be undone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: Colors.red.shade600),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── What gets deleted ──────────────────────────────────────
              _SectionTitle('What will be deleted'),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color:     Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset:    const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: const [
                    _DeleteItem(
                      icon:  Icons.person_rounded,
                      color: Colors.blue,
                      title: 'Account & Profile',
                      sub:   'Your name, phone number and login details',
                    ),
                    _Divider(),
                    _DeleteItem(
                      icon:  Icons.call_rounded,
                      color: Colors.orange,
                      title: 'Call Logs & Lead Data',
                      sub:   'All captured call records and lead information',
                    ),
                    _Divider(),
                    _DeleteItem(
                      icon:  Icons.history_rounded,
                      color: Colors.purple,
                      title: 'Activity History',
                      sub:   'All follow-ups, notes and synced data',
                    ),
                    _Divider(),
                    _DeleteItem(
                      icon:  Icons.settings_rounded,
                      color: Colors.teal,
                      title: 'App Settings & Preferences',
                      sub:   'Filters, SIM settings and customisations',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── What stays ────────────────────────────────────────────
              _SectionTitle('What will NOT be deleted'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:        const Color(0xFFF1F8E9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    _KeepItem(
                      icon:  Icons.phone_android_rounded,
                      title: 'Calls on your device',
                      sub:   'Your phone\'s call history is unaffected',
                    ),
                    const SizedBox(height: 10),
                    _KeepItem(
                      icon:  Icons.contacts_rounded,
                      title: 'Device contacts',
                      sub:   'No contacts will be modified or removed',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Confirmation input ─────────────────────────────────────
              _SectionTitle('Confirm deletion'),
              const SizedBox(height: 6),
              Text(
                'Type DELETE in the box below to enable the delete button.',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 10),
              TextField(
                controller:   _confirmController,
                textCapitalization: TextCapitalization.characters,
                onChanged:    (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText:  'Type DELETE to confirm',
                  hintStyle: TextStyle(
                      color: Colors.grey[400], fontSize: 13),
                  filled:     true,
                  fillColor:  Colors.white,
                  prefixIcon: Icon(Icons.keyboard_rounded,
                      color: Colors.grey[400], size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:   BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:   BorderSide(
                        color: Colors.red.shade200, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:   BorderSide(
                        color: Colors.red.shade400, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Action buttons ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: AnimatedOpacity(
                  opacity:  _canDelete ? 1.0 : 0.45,
                  duration: const Duration(milliseconds: 200),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color:        Colors.red,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _canDelete
                          ? [
                              BoxShadow(
                                color:     Colors.red.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset:    const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor:     Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _canDelete && !_isDeleting ? _showConfirmDialog : null,
                      icon: _isDeleting
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.delete_forever_rounded,
                              color: Colors.white, size: 18),
                      label: Text(
                        _isDeleting ? 'Deleting...' : 'Delete My Account',
                        style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side:   const BorderSide(color: AppTheme.primary),
                    shape:  RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel — Keep My Account',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize:   13,
          fontWeight: FontWeight.w700,
          color:      Color(0xFF333333),
          letterSpacing: 0.1,
        ),
      );
}

class _DeleteItem extends StatelessWidget {
  const _DeleteItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
  });

  final IconData icon;
  final Color    color;
  final String   title;
  final String   sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:        color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(sub,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          Icon(Icons.remove_circle_outline_rounded,
              color: Colors.red.shade300, size: 18),
        ],
      ),
    );
  }
}

class _KeepItem extends StatelessWidget {
  const _KeepItem({required this.icon, required this.title, required this.sub});

  final IconData icon;
  final String   title;
  final String   sub;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.green.shade600, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              Text(sub,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[600])),
            ],
          ),
        ),
        Icon(Icons.check_circle_rounded,
            color: Colors.green.shade600, size: 18),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Divider(
      height: 1, indent: 56, endIndent: 16, thickness: 0.5);
}
