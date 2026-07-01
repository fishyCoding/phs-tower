import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'screens/news_screen.dart';
import 'screens/games_screen.dart';
import 'screens/outreach_screen.dart';
import 'screens/search_screen.dart';
import 'debug/typography.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://yusjougmsdnhcsksadaw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl1c2pvdWdtc2RuaGNza3NhZGF3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE2NDU1NzI4NzQsImV4cCI6MTk2MTE0ODg3NH0.DHLgiswzK6Y_z5_mXAkRn1xy60zvhdb_iQH5gAyJorg',
  );
  PaintingBinding.instance.imageCache.maximumSize = 200;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024;
  runApp(const PHSTowerApp());
}

class PHSTowerApp extends StatelessWidget {
  const PHSTowerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PHS Tower',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF072636)),
        useMaterial3: true,
      ),
      // Wrap the whole navigator in the typography scope so every screen (and
      // pushed route) rebuilds live when the debug panel changes a setting.
      builder: (context, child) => TypographyScope(
        controller: typography,
        child: Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (kTypographyPanelEnabled) const TypographyDebugPanel(),
          ],
        ),
      ),
      home: const MainScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav height constant — tweak this one value to resize the whole bar
// ─────────────────────────────────────────────────────────────────────────────

const double _kNavHeight = 72.0;

// ─────────────────────────────────────────────────────────────────────────────
// Data model for a nav entry
// ─────────────────────────────────────────────────────────────────────────────

enum _NavKind { topLevel, newsSub }

class _NavEntry {
  final String id;
  final String label;
  final IconData icon;
  final _NavKind kind;

  const _NavEntry(this.id, this.label, this.icon, this.kind);
}

const _topLevelEntries = [
  _NavEntry('news',     'News',     Icons.newspaper_outlined,         _NavKind.topLevel),
  _NavEntry('games',    'Games',    Icons.grid_on_outlined,           _NavKind.topLevel),
  _NavEntry('outreach', 'Outreach', Icons.people_outline,             _NavKind.topLevel),
];

const _newsSubEntries = [
  _NavEntry('all',           'All',      Icons.home_outlined,              _NavKind.newsSub),
  _NavEntry('news-features', 'News-F',   Icons.article_outlined,           _NavKind.newsSub),
  _NavEntry('opinions',      'Opinions', Icons.lightbulb_outline,          _NavKind.newsSub),
  _NavEntry('arts-entertainment', 'Arts', Icons.palette_outlined,         _NavKind.newsSub),
  _NavEntry('sports',        'Sports',   Icons.sports_basketball_outlined, _NavKind.newsSub),
  _NavEntry('search',        'Search',   Icons.search,                     _NavKind.newsSub),
];

// ─────────────────────────────────────────────────────────────────────────────
// MainScreen
// ─────────────────────────────────────────────────────────────────────────────

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {

  String _topPage      = 'news';
  String _newsSubPage  = 'all';
  bool   _newsExpanded = true;

  // Testing-only: lets the Outreach section be opened without a real sign-in.
  bool   _devBypass    = false;

  late final AnimationController _animController;
  late final Animation<double>   _expandAnim;

  final _newsKey   = GlobalKey<NewsScreenState>();
  final _searchKey = GlobalKey<SearchScreenState>();

  // Auth — restricted to the school's Google Workspace domain.
  static const _allowedDomain = 'princetonk12.org';

  // ⚠️ FILL ME IN: the **Web** OAuth client ID from Google Cloud Console
  // (APIs & Services → Credentials → OAuth client of type "Web application").
  // This is used as the audience of the idToken so Supabase can verify it, and
  // the same id must be added under Supabase → Auth → Providers → Google.
  static const _webClientId =
      '452482738574-7dg9bofecv2qvhuo4t6kqcptqf4ugu5g.apps.googleusercontent.com';

  final _googleSignIn = GoogleSignIn(
    scopes: const ['email'],
    // Hints the Google account picker to only offer @princetonk12.org accounts.
    hostedDomain: _allowedDomain,
    // Makes the returned idToken audience = the Web client → lets Supabase
    // verify it via signInWithIdToken.
    serverClientId: _webClientId,
  );
  GoogleSignInAccount? _user;

  /// Exact-match domain check (defence in depth — `hostedDomain` only filters
  /// the picker; we never trust an account whose email isn't on the domain).
  bool _isAllowedDomain(String email) {
    final at = email.lastIndexOf('@');
    if (at < 0) return false;
    return email.substring(at + 1).toLowerCase() == _allowedDomain;
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0, // start expanded
    );
    _expandAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
      reverseCurve: Curves.easeInOut,
    );
    // Restore previous session silently — re-establishing the Supabase session
    // and re-checking the domain.
    _googleSignIn.signInSilently().then((u) async {
      if (u == null) return;
      final ok = await _authorize(u);
      if (!ok) {
        await _googleSignIn.signOut();
        await Supabase.instance.client.auth.signOut();
        return;
      }
      if (mounted) setState(() => _user = u);
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Validates the domain and establishes a Supabase session from the Google
  /// idToken. Returns true on success. On any failure the account is signed out
  /// so we never hold a half-authenticated state.
  Future<bool> _authorize(GoogleSignInAccount account) async {
    if (!_isAllowedDomain(account.email)) return false;

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      debugPrint('Google sign-in: missing idToken (check serverClientId).');
      return false;
    }

    await Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: auth.accessToken,
    );
    return true;
  }

  Future<void> _handleSignIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return; // user cancelled

      final ok = await _authorize(account);
      if (!ok) {
        // Off-domain (or token problem) — reject and clear everything.
        await _googleSignIn.signOut();
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          setState(() => _user = null);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in with your @$_allowedDomain account.'),
            ),
          );
        }
        return;
      }

      if (mounted) setState(() => _user = account);
    } catch (e) {
      debugPrint('Google sign-in error: $e');
    }
  }

  Future<void> _handleSignOut() async {
    await _googleSignIn.signOut();
    await Supabase.instance.client.auth.signOut();
    if (mounted) setState(() => _user = null);
  }

  void _showAccountDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_user!.displayName ?? 'Account'),
        content: Text(_user!.email),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); _handleSignOut(); },
            child: const Text('Sign out'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ── tap handlers ────────────────────────────────────────────────────────────

  void _tapNews() {
    if (_topPage == 'news') {
      if (_newsExpanded) {
        _animController.reverse().then((_) {
          if (mounted) setState(() => _newsExpanded = false);
        });
      } else {
        setState(() => _newsExpanded = true);
        _animController.forward();
      }
    } else {
      // Returning from another top-level page — reset sub to All
      setState(() {
        _topPage      = 'news';
        _newsExpanded = true;
        _newsSubPage  = 'all';
      });
      _newsKey.currentState?.selectCategory('All');
      _animController.forward();
    }
  }

  void _tapSub(String subId) {
    setState(() {
      _topPage     = 'news';
      _newsSubPage = subId;
    });
    if (subId != 'search') {
      final cat = subId == 'all' ? 'All' : subId;
      _newsKey.currentState?.selectCategory(cat);
    }
  }

  void _tapTopLevel(String id) {
    setState(() => _topPage = id);
    _animController.reverse().then((_) {
      if (mounted) setState(() => _newsExpanded = false);
    });
  }

  // ── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: _buildNav(context),
    );
  }

  Widget _buildBody() {
    if (_topPage == 'news') {
      return IndexedStack(
        index: _newsSubPage == 'search' ? 1 : 0,
        children: [
          NewsScreen(
            key: _newsKey,
            user: _user,
            onSignIn: _handleSignIn,
            onSignOut: _handleSignOut,
          ),
          SearchScreen(key: _searchKey),
        ],
      );
    }
    if (_topPage == 'games')    return const GamesScreen();
    if (_topPage == 'outreach') {
      return OutreachScreen(
        user: _user,
        onSignIn: _handleSignIn,
        devBypass: _devBypass,
        onDevBypass: () => setState(() => _devBypass = true),
      );
    }
    return const SizedBox.shrink();
  }

  // ── nav bar ──────────────────────────────────────────────────────────────────
  //
  // Two layers in a Stack, cross-fading via Opacity as _expandAnim runs:
  //   Layer 1 (bottom): centered Row of 3 top-level buttons (visible when collapsed)
  //   Layer 2 (top):    scrollable expanded row (visible when expanded)
  //
  // Each layer is wrapped in IgnorePointer(ignoring: opacity == 0) so that
  // whichever layer is invisible cannot steal taps from the visible one.

  Widget _buildNav(BuildContext context) {
    final bottomPad  = MediaQuery.of(context).padding.bottom;
    final newsActive = _topPage == 'news';

    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
          SizedBox(
            height: _kNavHeight + bottomPad,
            child: AnimatedBuilder(
              animation: _expandAnim,
              builder: (context, _) {
                final t = _expandAnim.value; // 1 = expanded, 0 = collapsed

                return Stack(
                  children: [

                    // ── Layer 1: centered 3-button row (shown when collapsed) ──
                    IgnorePointer(
                      // Ignore taps whenever this layer is not the dominant one
                      ignoring: t > 0.5,
                      child: Opacity(
                        opacity: (1.0 - t).clamp(0.0, 1.0),
                        child: Padding(
                          padding: EdgeInsets.only(bottom: bottomPad),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _NavBtn(
                                label: 'News',
                                icon: Icons.newspaper_outlined,
                                isActive: newsActive,
                                onTap: _tapNews,
                                trailing: newsActive
                                    ? const Icon(
                                        Icons.keyboard_arrow_right,
                                        size: 14,
                                        color: Color(0xFF072636),
                                      )
                                    : null,
                              ),
                              _NavBtn(
                                label: 'Games',
                                icon: Icons.grid_on_outlined,
                                isActive: _topPage == 'games',
                                onTap: () => _tapTopLevel('games'),
                              ),
                              _NavBtn(
                                label: 'Outreach',
                                icon: Icons.people_outline,
                                isActive: _topPage == 'outreach',
                                onTap: () => _tapTopLevel('outreach'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── Layer 2: expanded scrollable row (shown when expanded) ──
                    IgnorePointer(
                      // Ignore taps whenever this layer is not the dominant one
                      ignoring: t <= 0.5,
                      child: Opacity(
                        opacity: t.clamp(0.0, 1.0),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.only(
                            left: 4,
                            right: 4,
                            bottom: bottomPad,
                          ),
                          children: [
                            _NavBtn(
                              label: 'News',
                              icon: Icons.newspaper_outlined,
                              isActive: newsActive,
                              onTap: _tapNews,
                              trailing: newsActive
                                  ? Icon(
                                      _newsExpanded
                                          ? Icons.keyboard_arrow_left
                                          : Icons.keyboard_arrow_right,
                                      size: 14,
                                      color: const Color(0xFF072636),
                                    )
                                  : null,
                            ),
                            // Animated sub-group
                            ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: t,
                                child: _SubGroupWrapper(
                                  children: _newsSubEntries.map((e) {
                                    final isActive =
                                        _topPage == 'news' && _newsSubPage == e.id;
                                    return _NavBtn(
                                      label: e.label,
                                      icon: e.icon,
                                      isActive: isActive,
                                      onTap: () => _tapSub(e.id),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            _NavBtn(
                              label: 'Games',
                              icon: Icons.grid_on_outlined,
                              isActive: _topPage == 'games',
                              onTap: () => _tapTopLevel('games'),
                            ),
                            _NavBtn(
                              label: 'Outreach',
                              icon: Icons.people_outline,
                              isActive: _topPage == 'outreach',
                              onTap: () => _tapTopLevel('outreach'),
                            ),
                          ],
                        ),
                      ),
                    ),

                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-group wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _SubGroupWrapper extends StatelessWidget {
  final List<Widget> children;
  const _SubGroupWrapper({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 0.8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NavBtn
// ─────────────────────────────────────────────────────────────────────────────

class _NavBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final Widget? trailing;

  const _NavBtn({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.trailing,
  });

  static const _active   = Color(0xFF072636);
  static const _inactive = Color(0xFF999999);

  @override
  Widget build(BuildContext context) {
    final color = isActive ? _active : _inactive;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minWidth: 64, maxWidth: 84),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Active indicator line
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 2,
              width: isActive ? 26 : 0,
              margin: const EdgeInsets.only(bottom: 5),
              decoration: BoxDecoration(
                color: _active,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 1),
                  trailing!,
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}