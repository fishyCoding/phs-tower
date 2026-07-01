import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../widgets/google_form_webview.dart';
import 'letter_to_editor_screen.dart';
import '../debug/typography.dart';

class OutreachScreen extends StatelessWidget {
  final GoogleSignInAccount? user;
  final VoidCallback? onSignIn;

  /// Testing-only: when true the section unlocks without a real sign-in.
  final bool devBypass;

  /// Testing-only: called by the "skip sign-in" button on the gate.
  final VoidCallback? onDevBypass;

  const OutreachScreen({
    super.key,
    this.user,
    this.onSignIn,
    this.devBypass = false,
    this.onDevBypass,
  });

  static const _ink = Color(0xFF072636); // blue accent — icons, bars, fills
  static const _accent = Color(0xFF072636); // blue accent for eyebrow labels

  // "Join the Tower" interest form.
  static const _joinFormUrl =
      'https://docs.google.com/forms/d/e/1FAIpQLSfYkeJynVHL3mKkBoeNiY51_aMv1ViwiSe0fD8Q3LbCo7nngA/viewform';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: (user == null && !devBypass)
            ? _buildSignInGate(context)
            : _buildMenu(context),
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
              style: headline(context, size: 24, color: Colors.black),
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
            // Testing-only shortcut — bypasses Google/Supabase auth entirely.
            const SizedBox(height: 12),
            TextButton(
              onPressed: onDevBypass,
              child: const Text(
                'Skip sign-in (testing)',
                style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Signed-in state: outreach menu ──────────────────────────────────────────

  Widget _buildMenu(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        // ── Section header ──────────────────────────────────────────────
        Text(
          'COMMUNITY OUTREACH',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: _accent,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Get Involved',
          style: headline(context, size: 34, color: Colors.black),
        ),
        const SizedBox(height: 12),
        Container(width: 56, height: 4, color: _ink),
        const SizedBox(height: 28),

        // ── Action cards ────────────────────────────────────────────────
        _OutreachCard(
          icon: Icons.edit_outlined,
          label: 'LETTERS',
          title: 'Letter to the Editor',
          description: 'Submit a letter to The Tower.',
          action: 'Write a Letter',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LetterToEditorScreen()),
          ),
        ),
        const SizedBox(height: 16),
        _OutreachCard(
          icon: Icons.description_outlined,
          label: 'FORMS',
          title: 'Surveys & Forms',
          description: 'Surveys and other Tower forms.',
          action: 'Open Forms',
          onTap: () => _push(
            context,
            'Forms',
            const _ComingSoon(label: 'No forms yet — check back soon.'),
          ),
        ),
        const SizedBox(height: 16),
        _OutreachCard(
          icon: Icons.group_add_outlined,
          label: 'STAFF',
          title: 'Join the Tower',
          description: 'Express interest in joining staff.',
          action: 'Interest Form',
          onTap: () => _push(
            context,
            'Join the Tower',
            const GoogleFormWebView(formUrl: _joinFormUrl),
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
            foregroundColor: Colors.black,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(title,
                style: headline(context, size: 20, color: Colors.black)),
          ),
          body: SafeArea(child: body),
        ),
      ),
    );
  }
}

// ── Action card ───────────────────────────────────────────────────────────────

class _OutreachCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String title;
  final String description;
  final String action;
  final VoidCallback onTap;

  const _OutreachCard({
    required this.icon,
    required this.label,
    required this.title,
    required this.description,
    required this.action,
    required this.onTap,
  });

  static const _ink = Color(0xFF072636);
  static const _accent = Color(0xFF072636);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6E6E6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D002045), // ~5% navy
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: _accent),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: _accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: headline(context, size: 22, color: Colors.black),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    action,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
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
