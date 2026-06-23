import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../widgets/google_form_webview.dart';
import 'letter_to_editor_screen.dart';

class OutreachScreen extends StatelessWidget {
  final GoogleSignInAccount? user;
  final VoidCallback? onSignIn;

  const OutreachScreen({super.key, this.user, this.onSignIn});

  static const _ink = Color(0xFF1A1A2E);

  // "Join the Tower" interest form.
  static const _joinFormUrl =
      'https://docs.google.com/forms/d/e/1FAIpQLSfYkeJynVHL3mKkBoeNiY51_aMv1ViwiSe0fD8Q3LbCo7nngA/viewform';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: user == null ? _buildSignInGate(context) : _buildMenu(context),
      ),
    );
  }

  // ── Locked state: prompt the user to sign in ────────────────────────────────

  Widget _buildSignInGate(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: _ink),
            const SizedBox(height: 20),
            Text(
              'Sign in required',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _ink,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'The Outreach section requires login. Sign in with your '
              '@princetonk12.org account to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onSignIn,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  color: _ink,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.network(
                      'https://www.google.com/favicon.ico',
                      width: 16,
                      height: 16,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.login, size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Sign in with Google',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Signed-in state: outreach menu ──────────────────────────────────────────

  Widget _buildMenu(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Text(
            'Outreach',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _ink,
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE0E0E0)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _OutreachTile(
                icon: Icons.description_outlined,
                title: 'Forms',
                subtitle: 'Surveys and other Tower forms',
                onTap: () => _push(
                  context,
                  'Forms',
                  const _ComingSoon(label: 'No forms yet — check back soon.'),
                ),
              ),
              _OutreachTile(
                icon: Icons.edit_outlined,
                title: 'Letter to the Editor',
                subtitle: 'Submit a letter to The Tower',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LetterToEditorScreen()),
                ),
              ),
              _OutreachTile(
                icon: Icons.group_add_outlined,
                title: 'Join the Tower',
                subtitle: 'Express interest in joining staff',
                onTap: () => _push(
                  context,
                  'Join the Tower',
                  const GoogleFormWebView(formUrl: _joinFormUrl),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Pushes a titled sub-page with an app bar + back button.
  void _push(BuildContext context, String title, Widget body) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: _ink,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(title,
                style: GoogleFonts.playfairDisplay(color: _ink)),
          ),
          body: SafeArea(child: body),
        ),
      ),
    );
  }
}

// ── Menu tile ─────────────────────────────────────────────────────────────────

class _OutreachTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OutreachTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  static const _ink = Color(0xFF1A1A2E);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: _ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 12.5, color: Color(0xFF999999)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }
}

// ── Placeholder for sections that will expand ────────────────────────────────

class _ComingSoon extends StatelessWidget {
  final String label;
  const _ComingSoon({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
        ),
      ),
    );
  }
}
