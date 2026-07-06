import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../debug/typography.dart';

const _email = 'phstowersenioreditors@gmail.com';
const _red = Color(0xFFA31621);
const _blue = Color(0xFF072636);
const _body = TextStyle(fontSize: 14.5, height: 1.6, color: Color(0xFF333333));

Future<void> _launchEmail() async {
  final uri = Uri(scheme: 'mailto', path: _email);
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

Widget _eyebrow(String text) => Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: _red,
      ),
    );

// ── About ─────────────────────────────────────────────────────────────────────

class AboutBody extends StatelessWidget {
  const AboutBody({super.key});

  Widget _section(BuildContext context, String heading, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(heading, style: headline(context, size: 18, color: Colors.black)),
            const SizedBox(height: 8),
            Text(text, style: _body),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      children: [
        _eyebrow('THE STUDENT NEWSPAPER OF PRINCETON HIGH SCHOOL'),
        const SizedBox(height: 6),
        Text('The Tower',
            style: headline(context, size: 34, color: Colors.black)),
        const SizedBox(height: 12),
        Container(width: 56, height: 4, color: _blue),
        const SizedBox(height: 24),
        _section(
          context,
          'Mission Statement',
          'The Tower serves as a medium of information for the community through '
              'reporting and/or analyzing the inner workings of Princeton High '
              'School, the school district, and cultural and athletic events that '
              'affect the student body; providing a source of general news for '
              'parents, teachers, and peers; voicing various opinions from an '
              'informed group of writers; and maintaining quality in accurate '
              'content and appealing aesthetics, as well as upholding '
              'professionalism and journalistic integrity.',
        ),
        _section(
          context,
          'Editorial Board',
          'The Editorial Board of the Tower consists of a select group of 26 '
              'Tower 2026 staff members. The views of board members are accurately '
              'reflected in the editorial, which is co-written each month by the '
              'Board with primary authorship changing monthly.',
        ),
        _section(
          context,
          'Letter and Submission Policy',
          'All letters and articles are welcome for consideration. Please email '
              'all submissions to $_email. The editors reserve the rights to alter '
              'letters for length and to edit articles. The Editors-in-Chief take '
              'full responsibility for the content of this paper.',
        ),
        _section(
          context,
          'Publication Policy',
          'The newspaper accepts advice from the administration and the advisors '
              'in regard to the newspaper’s content; however, the final '
              'decision to print the content lies with the Editors-in-Chief. The '
              'Tower’s articles do not necessarily represent the views of the '
              'administration, faculty, or staff.',
        ),
        _section(
          context,
          'Corrections',
          'The Tower aims to uphold accuracy in articles and welcomes suggestions '
              'regarding the content of the articles. Corrections and retractions '
              'of articles will be determined on a case-by-case basis; please '
              'email all requests to $_email for consideration.',
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F6F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _eyebrow('GET IN TOUCH'),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _launchEmail,
                child: Row(
                  children: [
                    const Icon(Icons.email_outlined, size: 18, color: _blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _email,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: _blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Follow The Tower on Instagram, Facebook, YouTube, Spotify, '
                'and Apple Podcasts.',
                style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF666666)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Staff ─────────────────────────────────────────────────────────────────────

/// The 2026 masthead — section title → list of (name, role).
const List<(String, List<(String, String)>)> _staff = [
  ('Senior Editors', [
    ('Aritra Ray', 'Editor-in-Chief'),
    ('Harry Dweck', 'Managing Editor'),
    ('Claire Yang', 'Managing Editor'),
  ]),
  ('Online', [
    ('Alexander Sheng', 'Online Co-Editor'),
    ('Aryan Singla', 'Online Co-Editor'),
  ]),
  ('News & Features', [
    ('Joy Chen', 'News & Features Co-Editor'),
    ('Rohan Srivastava', 'News & Features Co-Editor'),
  ]),
  ('Opinions', [
    ('Stephanie Liao', 'Opinions Co-Editor'),
    ('Fangwu Yu', 'Opinions Co-Editor'),
  ]),
  ('Vanguard', [
    ('Samantha Henderson', 'Vanguard Co-Editor'),
    ('Finn Wedmid', 'Vanguard Co-Editor'),
  ]),
  ('Arts & Entertainment', [
    ('Agatha Patten', 'Arts & Entertainment Co-Editor'),
    ('Maeve Walsh', 'Arts & Entertainment Co-Editor'),
  ]),
  ('Sports', [
    ('Joshua Huang', 'Sports Co-Editor'),
    ('Kaelan Patel', 'Sports Co-Editor'),
    ('Michael Yang', 'Sports Co-Editor'),
  ]),
  ('Visuals', [
    ('Katherine Chen', 'Visuals Co-Editor'),
    ('Emily Kim', 'Visuals Co-Editor'),
    ('Luna Xu', 'Visuals Co-Editor'),
  ]),
  ('Copy', [
    ('Jacob Rogart', 'Co-Head Copy Editor'),
    ('Yunsheng Xu', 'Co-Head Copy Editor'),
  ]),
  ('Business', [
    ('Nathan Bansal', 'Business Co-Editor'),
    ('Maxime DeVico', 'Business Co-Editor'),
  ]),
  ('Multimedia', [
    ('Avantika Palayekar', 'Multimedia Co-Editor'),
    ('Aarna Vachrajani', 'Multimedia Co-Editor'),
  ]),
  ('Outreach', [
    ('Alexander Gu', 'Outreach Editor'),
  ]),
  ('Advisors', [
    ('Lauren King', 'Adviser'),
    ('Doug Levandowski', 'Adviser'),
  ]),
  ('App Development', [
    ('Sebastian Balestri', 'Co-Lead Developer'),
    ('Rohan Srivastava', 'Co-Lead Developer'),
  ]),
];

class StaffBody extends StatelessWidget {
  const StaffBody({super.key});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _eyebrow('THE TOWER · 2026'),
      const SizedBox(height: 6),
      Text('Our Staff', style: headline(context, size: 34, color: Colors.black)),
      const SizedBox(height: 12),
      Container(width: 56, height: 4, color: _blue),
      const SizedBox(height: 24),
    ];

    for (final (section, members) in _staff) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          section.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: _red,
          ),
        ),
      ));
      for (final (name, role) in members) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black)),
              const SizedBox(height: 1),
              Text(role,
                  style:
                      const TextStyle(fontSize: 12.5, color: Color(0xFF888888))),
            ],
          ),
        ));
      }
      children.add(const SizedBox(height: 10));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      children: children,
    );
  }
}
