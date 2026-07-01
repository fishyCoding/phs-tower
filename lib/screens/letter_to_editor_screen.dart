import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../debug/typography.dart';

class LetterToEditorScreen extends StatefulWidget {
  const LetterToEditorScreen({super.key});

  @override
  State<LetterToEditorScreen> createState() => _LetterToEditorScreenState();
}

class _LetterToEditorScreenState extends State<LetterToEditorScreen> {
  static const _ink = Color(0xFF072636);

  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) {
      _toast('Please write your letter before submitting.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      await Supabase.instance.client.from('letter').insert({
        'subject': subject,
        'body': body,
        'author_email': user?.email,
        'author_name': user?.userMetadata?['full_name'] ?? user?.userMetadata?['name'],
      });
      if (!mounted) return;
      _subjectCtrl.clear();
      _bodyCtrl.clear();
      _toast('Letter submitted — thank you!');
    } catch (e) {
      if (!mounted) return;
      _toast('Could not submit. Please try again.');
      debugPrint('Letter submit error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Letter to the Editor',
            style: headline(context, size: 20, color: Colors.black)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share your thoughts with The Tower’s editorial board. Your '
                'name and school email are attached automatically.',
                style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF666666)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _subjectCtrl,
                textInputAction: TextInputAction.next,
                decoration: _fieldDecoration('Subject (optional)'),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _bodyCtrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  decoration: _fieldDecoration('Write your letter…'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Submit letter',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
        filled: true,
        fillColor: const Color(0xFFF6F6F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}
