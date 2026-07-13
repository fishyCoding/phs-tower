import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../screens/saved_screen.dart';

/// The shared "The Tower" masthead used across the News feed and Vanguard so
/// every section reads the same: a centered Canterbury wordmark balanced
/// between a bookmark (saved articles) and the sign-in / account control.
/// [subtitle] shows the current section name under the wordmark (uppercased).
class TowerMasthead extends StatelessWidget {
  final GoogleSignInAccount? user;
  final VoidCallback? onSignIn;
  final VoidCallback? onSignOut;
  final String? subtitle;

  const TowerMasthead({
    super.key,
    required this.user,
    required this.onSignIn,
    required this.onSignOut,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Saved articles
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SavedScreen()),
            ),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.bookmark_border,
                  size: 22, color: Color(0xFF072636)),
            ),
          ),
          // Wordmark + section subtitle, balanced between the two buttons
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  // Canterbury blackletter, distinct from the app headline font.
                  child: Text(
                    'The Tower',
                    style: TextStyle(
                      fontFamily: 'Canterbury',
                      fontSize: 40,
                      color: Colors.black,
                    ),
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                      color: Color(0xFF999999),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Sign-in / account
          GestureDetector(
            onTap: user != null ? onSignOut : onSignIn,
            child: user != null
                ? CircleAvatar(
                    radius: 16,
                    backgroundImage: user!.photoUrl != null
                        ? NetworkImage(user!.photoUrl!)
                        : null,
                    backgroundColor: const Color(0xFF072636),
                    child: user!.photoUrl == null
                        ? Text(
                            (user!.displayName ?? user!.email)[0]
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFDDDDDD)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.network(
                          'https://www.google.com/favicon.ico',
                          width: 14,
                          height: 14,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.login,
                            size: 14,
                            color: Color(0xFF072636),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Sign in',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF072636),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
