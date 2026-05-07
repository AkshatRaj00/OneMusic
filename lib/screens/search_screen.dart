import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/audio_provider.dart';
import '../models/song_model.dart';
import '../services/music_service.dart';
import 'player_screen.dart';

// ═══════════════════════════════════════════════
//  APP COLORS — single source of truth
// ═══════════════════════════════════════════════
class _C {
  static const bg           = Color(0xFF141414);
  static const surface      = Color(0xFF1E1E1E);
  static const surfaceAlt   = Color(0xFF252525);
  static const accent       = Color(0xFFFF6B35);
  static const textPrimary  = Color(0xFFFFFFFF);
  static const textSecondary= Color(0xFF888888);
  static const divider      = Color(0xFF2A2A2A);
}

// ═══════════════════════════════════════════════
//  CATEGORY MODEL
// ═══════════════════════════════════════════════
class _Cat {
  final String label;
  final Color  color;
  final Color  color2;
  const _Cat(this.label, this.color, this.color2);
}

// ═══════════════════════════════════════════════
//  SEARCH SCREEN
// ═══════════════════════════════════════════════
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // Controllers
  final _ctrl      = TextEditingController();
  final _focus     = FocusNode();
  final _scrollCtrl= ScrollController();
  late  Box _box;

  // State
  List<SongModel> _results      = [];
  List<SongModel> _liveSugg     = [];   // live API suggestions
  List<String>    _history      = [];
  List<SongModel> _trending     = [];
  bool   _isLoading    = false;
  bool   _hasSearched  = false;
  bool   _loadingTrend = false;
  String _query        = '';
  Timer? _debounce;

  // ── Categories (JioSaavn style colors) ──────
  static const _cats = [
    _Cat('Bollywood',          Color(0xFF8B0000), Color(0xFFFF4444)),
    _Cat('Punjabi',            Color(0xFF1A5C1A), Color(0xFF44BB44)),
    _Cat('Lofi',               Color(0xFF1A2A6C), Color(0xFF4444FF)),
    _Cat('Workout',            Color(0xFF00838F), Color(0xFF00C8D6)),
    _Cat('Sad',                Color(0xFF1A3A3A), Color(0xFF2E8B8B)),
    _Cat('Party',              Color(0xFF7B3F00), Color(0xFFFF8C00)),
    _Cat('Romance',            Color(0xFF6A0040), Color(0xFFFF69B4)),
    _Cat('Study',              Color(0xFF1A1A4A), Color(0xFF5555CC)),
    _Cat('Hip Hop',            Color(0xFF2A1A00), Color(0xFFBB8800)),
    _Cat('Classical',          Color(0xFF2A2A00), Color(0xFF9A9A00)),
    _Cat('Retro 90s',          Color(0xFF5A1060), Color(0xFFCC44CC)),
    _Cat('EDM',                Color(0xFF003366), Color(0xFF0088FF)),
    _Cat('Devotional',         Color(0xFF5A3000), Color(0xFFFF9900)),
    _Cat('Sufi',               Color(0xFF002B5A), Color(0xFF0066CC)),
    _Cat('Dance',              Color(0xFF6A0020), Color(0xFFFF3366)),
    _Cat('Chill',              Color(0xFF003322), Color(0xFF00AA77)),
  ];

  @override
  void initState() {
    super.initState();
    _box = Hive.box('settings');
    _loadHistory();
    _loadTrending();
    _focus.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── History ──────────────────────────────────
  void _loadHistory() {
    final s = _box.get('search_history', defaultValue: <String>[]);
    setState(() => _history = List<String>.from(s));
  }

  void _saveHistory(String q) {
    if (q.trim().isEmpty) return;
    _history.remove(q);
    _history.insert(0, q);
    if (_history.length > 15) _history = _history.take(15).toList();
    _box.put('search_history', _history);
  }

  void _removeHistory(String q) {
    setState(() => _history.remove(q));
    _box.put('search_history', _history);
  }

  void _clearHistory() {
    setState(() => _history.clear());
    _box.put('search_history', []);
    HapticFeedback.lightImpact();
  }

  // ── Trending ─────────────────────────────────
  Future<void> _loadTrending() async {
    setState(() => _loadingTrend = true);
    try {
      // Fetch trending using popular query
      final songs = await MusicService.search('trending hindi 2024');
      if (mounted) setState(() => _trending = songs.take(5).toList());
    } catch (_) {}
    if (mounted) setState(() => _loadingTrend = false);
  }

  // ── Debounced typing ─────────────────────────
  void _onType(String q) {
    setState(() {
      _query      = q;
      _hasSearched= false;
      _results    = [];
    });

    _debounce?.cancel();

    if (q.trim().isEmpty) {
      setState(() => _liveSugg.clear());
      return;
    }

    // Live suggestions after 350ms
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final sugg = await MusicService.search(q.trim());
        if (mounted && _query == q) {
          setState(() => _liveSugg = sugg.take(6).toList());
        }
      } catch (_) {
        // Fallback to history suggestions
        final hist = _history
            .where((h) => h.toLowerCase().contains(q.toLowerCase()))
            .take(5)
            .toList();
        if (mounted) setState(() => _liveSugg = []);
      }
    });
  }

  // ── Search ───────────────────────────────────
  Future<void> _search(String q) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return;

    _debounce?.cancel();
    _focus.unfocus();
    _ctrl.text = trimmed;
    _saveHistory(trimmed);
    HapticFeedback.lightImpact();

    setState(() {
      _isLoading   = true;
      _hasSearched = true;
      _results     = [];
      _liveSugg    = [];
      _query       = trimmed;
    });

    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut);
    }

    try {
      final songs = await MusicService.search(trimmed);
      if (mounted) setState(() { _results = songs; _isLoading = false; });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Search failed. Check connection.');
      }
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    _ctrl.clear();
    setState(() {
      _query = ''; _liveSugg = []; _results = [];
      _hasSearched = false; _isLoading = false;
    });
    _focus.requestFocus();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: _C.textPrimary)),
      backgroundColor: _C.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
    ));
  }

  // ═══════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Column(children: [
          _buildSearchBar(),
          // Live suggestions overlay
          if (_liveSugg.isNotEmpty && !_hasSearched && !_isLoading)
            _buildLiveSuggestions(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _isLoading
                  ? _buildSkeleton()
                  : _hasSearched
                      ? _buildResults(audio)
                      : _buildIdle(),
            ),
          ),
          if (audio.currentSong != null) const SizedBox(height: 80),
        ]),
      ),
    );
  }

  // ── Search Bar (JioSaavn style) ───────────────
  Widget _buildSearchBar() {
    return Container(
      color: _C.bg,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(children: [
        // Back
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                color: _C.textPrimary, size: 20),
          ),
        ),
        // Field
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _focus.hasFocus
                    ? _C.accent.withOpacity(0.5)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              onChanged: _onType,
              onSubmitted: _search,
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: _C.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Songs, artists, albums...',
                hintStyle: const TextStyle(
                    color: _C.textSecondary, fontSize: 15),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: _C.textSecondary, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? GestureDetector(
                        onTap: _clearSearch,
                        child: const Icon(Icons.close_rounded,
                            color: _C.textSecondary, size: 18))
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ),
        // Cancel
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: (_hasSearched || _focus.hasFocus || _query.isNotEmpty)
              ? GestureDetector(
                  key: const ValueKey('c'),
                  onTap: () { _clearSearch(); _focus.unfocus(); },
                  child: const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text('Cancel',
                        style: TextStyle(
                            color: _C.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('e')),
        ),
      ]),
    );
  }

  // ── Live Suggestions Dropdown ─────────────────
  Widget _buildLiveSuggestions() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.divider),
      ),
      child: Column(
        children: _liveSugg.asMap().entries.map((e) {
          final i = e.key; final s = e.value;
          return Column(children: [
            InkWell(
              onTap: () => _search(s.title),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Row(children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: s.thumbnail,
                      width: 40, height: 40, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                          width: 40, height: 40,
                          color: _C.surfaceAlt,
                          child: const Icon(Icons.music_note,
                              color: _C.accent, size: 18)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _C.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      Text(s.artist,
                          maxLines: 1,
                          style: const TextStyle(
                              color: _C.textSecondary, fontSize: 11)),
                    ],
                  )),
                  const Icon(Icons.north_west_rounded,
                      color: _C.textSecondary, size: 13),
                ]),
              ),
            ),
            if (i < _liveSugg.length - 1)
              const Divider(color: _C.divider, height: 1, indent: 64),
          ]);
        }).toList(),
      ),
    );
  }

  // ── IDLE STATE (JioSaavn layout) ──────────────
  Widget _buildIdle() {
    return ListView(
      key: const ValueKey('idle'),
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [

        // ── Recent Searches ──
        if (_history.isNotEmpty) ...[
          _sectionHeader('Recent Search', onClear: _clearHistory),
          const SizedBox(height: 10),
          ..._history.take(5).map((h) => _recentRow(h)),
          const SizedBox(height: 24),
        ],

        // ── Trending ──
        _sectionHeader('Trending', showSeeAll: true),
        const SizedBox(height: 10),
        if (_loadingTrend)
          ...List.generate(3, (_) => _trendingSkeleton())
        else if (_trending.isEmpty)
          _trendingEmpty()
        else
          ..._trending.map((s) => _trendingRow(s)),

        const SizedBox(height: 28),

        // ── Browse by Genre ──
        _sectionHeader('Browse by Genre'),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.65,
          ),
          itemCount: _cats.length,
          itemBuilder: (_, i) => _genreCard(_cats[i]),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title,
      {VoidCallback? onClear, bool showSeeAll = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                color: _C.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        if (onClear != null)
          GestureDetector(
            onTap: onClear,
            child: const Text('Clear all',
                style: TextStyle(color: _C.textSecondary, fontSize: 13)),
          )
        else if (showSeeAll)
          const Text('See All',
              style: TextStyle(
                  color: _C.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
      ],
    );
  }

  // Recent row — thumbnail + title + subtitle + X
  Widget _recentRow(String h) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => _search(h),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: _C.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.history_rounded,
                  color: _C.textSecondary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _C.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const Text('Recent search',
                    style: TextStyle(
                        color: _C.textSecondary, fontSize: 11)),
              ],
            )),
            GestureDetector(
              onTap: () => _removeHistory(h),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.close_rounded,
                    color: _C.textSecondary, size: 16),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // Trending row — thumbnail + title + type tag + arrow
  Widget _trendingRow(SongModel s) {
    return InkWell(
      onTap: () => _search(s.title),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: s.thumbnail,
              width: 52, height: 52, fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                  width: 52, height: 52, color: _C.surfaceAlt,
                  child: const Icon(Icons.music_note,
                      color: _C.accent, size: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _C.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _C.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Song',
                      style: TextStyle(
                          color: _C.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(s.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _C.textSecondary, fontSize: 11)),
                ),
              ]),
            ],
          )),
          const Icon(Icons.chevron_right_rounded,
              color: _C.textSecondary, size: 20),
        ]),
      ),
    );
  }

  Widget _trendingSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(8))),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 13, width: double.infinity,
                decoration: BoxDecoration(
                    color: _C.surface,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 8),
            Container(height: 11, width: 120,
                decoration: BoxDecoration(
                    color: _C.surface,
                    borderRadius: BorderRadius.circular(4))),
          ],
        )),
      ]),
    );
  }

  Widget _trendingEmpty() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Text('No trending right now',
          style: TextStyle(color: _C.textSecondary, fontSize: 13)),
    );
  }

  // Genre card — gradient background (JioSaavn style)
  Widget _genreCard(_Cat cat) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); _search(cat.label); },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cat.color, cat.color2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(cat.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  // ── Loading Skeleton ──────────────────────────
  Widget _buildSkeleton() {
    return ListView.builder(
      key: const ValueKey('skel'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: 8,
      itemBuilder: (_, i) => _SkelTile(delay: i * 60),
    );
  }

  // ── Results ───────────────────────────────────
  Widget _buildResults(AudioProvider audio) {
    if (_results.isEmpty) {
      return Center(
        key: const ValueKey('empty'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded,
                color: _C.textSecondary, size: 64),
            const SizedBox(height: 16),
            Text('No results for "$_query"',
                style: const TextStyle(
                    color: _C.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Try different keywords',
                style: TextStyle(color: _C.textSecondary, fontSize: 13)),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => _search(_query),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.divider),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, color: _C.accent, size: 18),
                    SizedBox(width: 8),
                    Text('Try Again',
                        style: TextStyle(
                            color: _C.textPrimary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      key: const ValueKey('res'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(text: TextSpan(children: [
                TextSpan(text: '${_results.length} ',
                    style: const TextStyle(
                        color: _C.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const TextSpan(text: 'results found',
                    style: TextStyle(color: _C.textSecondary, fontSize: 14)),
              ])),
              GestureDetector(
                onTap: () {
                  if (_results.isNotEmpty) {
                    audio.playSong(_results[0], list: _results, index: 0);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => PlayerScreen()));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: _C.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text('Play All',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            itemCount: _results.length,
            itemBuilder: (_, i) {
              final s = _results[i];
              final isAct = audio.currentSong?.id == s.id;
              return _ResultTile(
                song: s, index: i,
                isPlaying: isAct && audio.isPlaying,
                isActive: isAct,
                onTap: () {
                  HapticFeedback.lightImpact();
                  audio.playSong(s, list: _results, index: i);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => PlayerScreen()));
                },
                onMore: () => _showOptions(audio, s, i),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Song Options Sheet ────────────────────────
  void _showOptions(AudioProvider audio, SongModel s, int i) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              decoration: BoxDecoration(
                  color: _C.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: s.thumbnail,
                width: 48, height: 48, fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                    color: _C.surfaceAlt,
                    child: const Icon(Icons.music_note, color: _C.accent)),
              ),
            ),
            title: Text(s.title, maxLines: 1,
                style: const TextStyle(
                    color: _C.textPrimary, fontWeight: FontWeight.w700)),
            subtitle: Text(s.artist,
                style: const TextStyle(
                    color: _C.textSecondary, fontSize: 12)),
          ),
          const Divider(color: _C.divider, height: 1),
          const SizedBox(height: 8),
          _opt(Icons.play_circle_outline_rounded, 'Play Now', () {
            Navigator.pop(context);
            audio.playSong(s, list: _results, index: i);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => PlayerScreen()));
          }),
          _opt(Icons.queue_music_rounded, 'Add to Queue', () {
            audio.addToQueue(s);
            Navigator.pop(context);
            _snack('${s.title} added to queue');
          }),
          _opt(
            audio.isLiked(s.id)
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            audio.isLiked(s.id) ? 'Unlike' : 'Like',
            () { audio.toggleLike(s); Navigator.pop(context); },
            color: audio.isLiked(s.id) ? Colors.redAccent : _C.textSecondary,
          ),
        ]),
      ),
    );
  }

  Widget _opt(IconData icon, String label, VoidCallback onTap,
      {Color color = _C.textSecondary}) =>
      ListTile(
        leading: Icon(icon, color: color),
        title: Text(label,
            style: const TextStyle(color: _C.textPrimary, fontSize: 15)),
        onTap: onTap,
      );
}

// ═══════════════════════════════════════════════
//  Result Tile
// ═══════════════════════════════════════════════
class _ResultTile extends StatelessWidget {
  final SongModel song;
  final int index;
  final bool isPlaying, isActive;
  final VoidCallback onTap, onMore;

  const _ResultTile({
    required this.song, required this.index,
    required this.isPlaying, required this.isActive,
    required this.onTap, required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final dur = Duration(seconds: song.duration);
    final durStr =
        '${dur.inMinutes}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}';

    return Column(children: [
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            // Thumbnail
            Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: song.thumbnail,
                  width: 52, height: 52, fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                      color: _C.surface, width: 52, height: 52),
                  errorWidget: (_, __, ___) => Container(
                      color: _C.surface, width: 52, height: 52,
                      child: const Icon(Icons.music_note, color: _C.accent)),
                ),
              ),
              if (isPlaying)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      color: Colors.black54,
                      child: const Icon(Icons.equalizer_rounded,
                          color: _C.accent, size: 22),
                    ),
                  ),
                ),
            ]),
            const SizedBox(width: 14),
            // Info
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: isActive ? _C.accent : _C.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _C.textSecondary, fontSize: 12)),
              ],
            )),
            // Duration + more
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(durStr,
                    style: const TextStyle(
                        color: _C.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onMore,
                  child: const Icon(Icons.more_vert_rounded,
                      color: _C.textSecondary, size: 18),
                ),
              ],
            ),
          ]),
        ),
      ),
      const Divider(color: _C.divider, height: 1),
    ]);
  }
}

// ═══════════════════════════════════════════════
//  Skeleton Tile
// ═══════════════════════════════════════════════
class _SkelTile extends StatefulWidget {
  final int delay;
  const _SkelTile({this.delay = 0});
  @override
  State<_SkelTile> createState() => _SkelTileState();
}

class _SkelTileState extends State<_SkelTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _an;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _an = Tween<double>(begin: 0.3, end: 0.7)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay),
        () { if (mounted) _ac.forward(); });
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _an,
        builder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            _b(52, 52, r: 10),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _b(double.infinity, 13, r: 4),
                const SizedBox(height: 8),
                _b(130, 11, r: 4),
              ],
            )),
            const SizedBox(width: 14),
            _b(36, 11, r: 4),
          ]),
        ),
      );

  Widget _b(double w, double h, {required double r}) => Container(
        width: w, height: h,
        decoration: BoxDecoration(
          color: Color.lerp(
              const Color(0xFF1E1E1E), const Color(0xFF2A2A2A), _an.value),
          borderRadius: BorderRadius.circular(r),
        ),
      );
}