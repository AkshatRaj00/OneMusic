import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../models/song_model.dart';
import '../providers/audio_provider.dart';
import '../services/music_service.dart';
import 'player_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SongModel> _trending   = [];
  List<SongModel> _recentFeed = [];
  bool _loadingTrend = true;
  bool _loadingFeed  = true;

  // ── Colors ──────────────────────────────────────────
  static const _bg          = Color(0xFF121212);
  static const _surface     = Color(0xFF1A1A1A);
  static const _card        = Color(0xFF222222);
  static const _accent      = Color(0xFF00C48C); // JioSaavn green
  static const _textPrimary = Color(0xFFFFFFFF);
  static const _textSub     = Color(0xFF9E9E9E);

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    if (h < 21) return 'Good Evening';
    return 'Good Night';
  }

  String get _userName {
    final user = FirebaseAuth.instance.currentUser;
    return user?.displayName?.split(' ').first
        ?? user?.email?.split('@').first
        ?? 'Music Lover';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loadingTrend = true; _loadingFeed = true; });
    final t = await MusicService.getTrending();
    final f = await MusicService.getByGenre('Bollywood');
    if (mounted) setState(() {
      _trending   = t;
      _recentFeed = f;
      _loadingTrend = false;
      _loadingFeed  = false;
    });
  }

  void _openPlayer() => Navigator.push(
    context, MaterialPageRoute(builder: (_) => const PlayerScreen()));

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ─────────────────────────────────
            _topBar(),

            // ── Content ─────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                color: _accent,
                backgroundColor: _surface,
                onRefresh: _load,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // Your Usuals
                    _sectionTitle('Your Usuals'),
                    _yourUsuals(audio),

                    // Recently Played
                    if (audio.recentlyPlayed.isNotEmpty) ...[
                      _sectionTitle('Recently Played'),
                      _horizontalCards(audio.recentlyPlayed, audio),
                    ],

                    // Trending
                    _sectionTitle('Trending Now'),
                    _horizontalCards(_trending, audio),

                    // Song List Feed
                    _sectionTitle('Top Picks'),
                    ..._recentFeed.take(15).toList().asMap().entries.map(
                      (e) => _songTile(e.value, e.key, _recentFeed, audio)),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),

            // ── Mini Player ──────────────────────────────
            if (audio.currentSong != null) _miniPlayer(audio),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  TOP BAR
  // ══════════════════════════════════════════════════════

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting,
                style: const TextStyle(
                  color: _textSub, fontSize: 13, fontWeight: FontWeight.w500)),
              Text(_userName,
                style: const TextStyle(
                  color: _textPrimary, fontSize: 22,
                  fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.search_rounded, color: _textPrimary, size: 26),
          onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SearchScreen())),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: _textPrimary, size: 24),
          onPressed: () => Navigator.pushNamed(context, '/settings'),
        ),
      ],
    ),
  );

  // ══════════════════════════════════════════════════════
  //  YOUR USUALS — 3x2 grid like JioSaavn
  // ══════════════════════════════════════════════════════

  Widget _yourUsuals(AudioProvider audio) {
    final songs = _trending.take(6).toList();
    if (_loadingTrend) return _shimmerGrid();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: songs.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.82,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (_, i) {
          final s = songs[i];
          final isPlaying = audio.currentSong?.id == s.id && audio.isPlaying;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              audio.playSong(s, list: songs, index: i);
              _openPlayer();
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: s.thumbnail,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: _card),
                          errorWidget: (_, __, ___) => Container(
                            color: _card,
                            child: const Icon(Icons.music_note, color: _accent)),
                        ),
                      ),
                      if (isPlaying)
                        Positioned(
                          bottom: 6, right: 6,
                          child: Container(
                            width: 24, height: 24,
                            decoration: const BoxDecoration(
                              color: _accent, shape: BoxShape.circle),
                            child: const Icon(Icons.pause_rounded,
                              color: Colors.white, size: 14),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isPlaying ? _accent : _textPrimary,
                    fontSize: 12, fontWeight: FontWeight.w600)),
                Text(s.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _textSub, fontSize: 11)),
              ],
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  HORIZONTAL CARDS
  // ══════════════════════════════════════════════════════

  Widget _horizontalCards(List<SongModel> songs, AudioProvider audio) {
    if (songs.isEmpty) return const SizedBox(height: 150);
    return SizedBox(
      height: 155,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: songs.length,
        itemBuilder: (_, i) {
          final s = songs[i];
          final isPlaying = audio.currentSong?.id == s.id && audio.isPlaying;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              audio.playSong(s, list: songs, index: i);
              _openPlayer();
            },
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: s.thumbnail,
                          width: 120, height: 110, fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 120, height: 110, color: _card),
                          errorWidget: (_, __, ___) => Container(
                            width: 120, height: 110, color: _card,
                            child: const Icon(Icons.music_note, color: _accent)),
                        ),
                      ),
                      if (isPlaying)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.equalizer_rounded,
                              color: _accent, size: 28),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPlaying ? _accent : _textPrimary,
                      fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(s.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _textSub, fontSize: 11)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  SONG TILE — JioSaavn style list row
  // ══════════════════════════════════════════════════════

  Widget _songTile(
      SongModel s, int i, List<SongModel> list, AudioProvider audio) {
    final isPlaying = audio.currentSong?.id == s.id;
    final dur = Duration(seconds: s.duration);
    final durStr =
        '${dur.inMinutes}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}';

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        audio.playSong(s, list: list, index: i);
        _openPlayer();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: s.thumbnail,
                      width: 52, height: 52, fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(width: 52, height: 52, color: _card),
                      errorWidget: (_, __, ___) => Container(
                        width: 52, height: 52, color: _card,
                        child: const Icon(Icons.music_note, color: _accent)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isPlaying ? _accent : _textPrimary,
                            fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(s.artist,
                          maxLines: 1,
                          style: const TextStyle(
                            color: _textSub, fontSize: 12)),
                      ],
                    ),
                  ),
                  // Duration
                  Text(durStr,
                    style: const TextStyle(color: _textSub, fontSize: 12)),
                  const SizedBox(width: 8),
                  // More
                  GestureDetector(
                    onTap: () => _showOptions(s, audio),
                    child: const Icon(Icons.more_vert,
                      color: _textSub, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF2A2A2A), height: 1),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  MINI PLAYER — JioSaavn style
  // ══════════════════════════════════════════════════════

  Widget _miniPlayer(AudioProvider audio) {
    final song = audio.currentSong!;
    return GestureDetector(
      onTap: _openPlayer,
      child: Container(
        color: _surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            StreamBuilder<Duration>(
              stream: audio.positionStream,
              builder: (_, snap) {
                final pos = snap.data ?? Duration.zero;
                final dur = audio.duration;
                final progress = dur.inMilliseconds > 0
                    ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                    : 0.0;
                return LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(_accent),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  // Art
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: song.thumbnail,
                      width: 44, height: 44, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 44, height: 44, color: _card,
                        child: const Icon(Icons.music_note, color: _accent)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(song.artist,
                          maxLines: 1,
                          style: const TextStyle(
                            color: _textSub, fontSize: 11)),
                      ],
                    ),
                  ),
                  // Like
                  IconButton(
                    icon: Icon(
                      audio.isLiked(song.id)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: audio.isLiked(song.id)
                          ? Colors.redAccent : _textSub,
                      size: 22),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      audio.toggleLike(song);
                    },
                  ),
                  // Prev
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded,
                      color: _textPrimary, size: 28),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      audio.playPrev();
                    },
                  ),
                  // Play/Pause
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      audio.togglePlay();
                    },
                    child: audio.isLoading
                        ? const SizedBox(
                            width: 36, height: 36,
                            child: CircularProgressIndicator(
                              color: _accent, strokeWidth: 2.5))
                        : Icon(
                            audio.isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_filled_rounded,
                            color: _accent, size: 40),
                  ),
                  // Next
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded,
                      color: _textPrimary, size: 28),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      audio.playNext();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  OPTIONS SHEET
  // ══════════════════════════════════════════════════════

  void _showOptions(SongModel song, AudioProvider audio) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: song.thumbnail,
                width: 46, height: 46, fit: BoxFit.cover)),
            title: Text(song.title, maxLines: 1,
              style: const TextStyle(
                color: _textPrimary, fontWeight: FontWeight.w600)),
            subtitle: Text(song.artist,
              style: const TextStyle(color: _textSub)),
          ),
          const Divider(color: Color(0xFF2A2A2A), height: 1),
          _optionTile(Icons.queue_music_rounded, 'Add to Queue', () {
            audio.addToQueue(song);
            Navigator.pop(context);
          }),
          _optionTile(
            audio.isLiked(song.id)
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            audio.isLiked(song.id) ? 'Unlike' : 'Like',
            () { audio.toggleLike(song); Navigator.pop(context); },
            color: audio.isLiked(song.id) ? Colors.redAccent : _textSub,
          ),
          _optionTile(Icons.playlist_play_rounded, 'Play Next', () {
            audio.playNext(song: song);
            Navigator.pop(context);
          }),
          _optionTile(Icons.share_outlined, 'Share', () {
            Navigator.pop(context);
            Share.share('${song.title} by ${song.artist} 🎵');
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _optionTile(IconData icon, String label, VoidCallback onTap,
      {Color color = _textSub}) =>
    ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label,
        style: const TextStyle(color: _textPrimary, fontSize: 14)),
      onTap: onTap,
    );

  // ══════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
    child: Text(title,
      style: const TextStyle(
        color: _textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
  );

  Widget _shimmerGrid() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, childAspectRatio: 0.82,
        crossAxisSpacing: 10, mainAxisSpacing: 10,
      ),
      itemBuilder: (_, __) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(color: _card)),
    ),
  );
}