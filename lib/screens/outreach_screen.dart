import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OutreachScreen extends StatelessWidget {
  const OutreachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Outreach',
          style: GoogleFonts.playfairDisplay(
              fontSize: 32, fontWeight: FontWeight.bold)),
    );
  }
}