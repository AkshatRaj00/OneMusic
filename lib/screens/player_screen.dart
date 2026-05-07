import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/audio_provider.dart';
import '../models/song_model.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  // ── Design tokens ──────────────────────────────────────
  static const _bg         = Color(0xFF141414);
  static const _surface    = Color(0xFF1E1E1E);
  static const _surfaceAlt = Color(0xFF252525);
  static const _accent     = Color(0xFFFF6B35);
  static const _textPrimary   = Color(0xFFFFFFFF);
  static const _textSecondary = Color(0xFF888888);
  static const _divider    = Color(0xFF2A2A2A);

  Color _accentColor = _accent;
  String? _lastThumb;

  late AnimationController _artController;
  late Animation<double> _artAnim;

  @override
  void initState() {
    super.initState();
    _artController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _artAnim = CurvedAnimation(
        parent: _artController, curve: Curves.easeOutBack);
    _artController.forward();
  }

  @override
  void dispose() {
    _artController.dispose();
    super.dispose();
  }

  Future<void> _extractColor(String url) async {
    if (url == _lastThumb || url.isEmpty) return;
    _lastThumb = url;
    try {
      final pg = await PaletteGenerator.fromImageProvider(
          CachedNetworkImageProvider(url),
          size: const Size(150, 150));
      if (mounted) {
        setState(() {
          _accentColor = pg.vibrantColor?.color ??
              pg.dominantColor?.color ?? _accent;
        });
        _artController.reset();
        _artController.forward();
      }
    } catch (_) {}
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
      '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    final song  = audio.currentSong;
    if (song != null) _extractColor(song.thumbnail);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: _textPrimary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Now Playing',
                            style: TextStyle(
                                color: _textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5)),
                        if (song?.album.isNotEmpty == true)
                          Text(song!.album,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz_rounded,
                        color: _textPrimary, size: 24),
                    onPressed: () => _showOptions(context, audio, song),
                  ),
                ],
              ),
            ),

            // ── Album Art ───────────────────────────────
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                child: ScaleTransition(
                  scale: _artAnim,
                  child: AnimatedScale(
                    scale: audio.isPlaying ? 1.0 : 0.92,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _accentColor.withOpacity(0.35),
                            blurRadius: 60,
                            spreadRadius: 5,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: song?.thumbnail.isNotEmpty == true
                            ? CachedNetworkImage(
                                imageUrl: song!.thumbnail,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                placeholder: (_, __) => _artPlaceholder(),
                                errorWidget: (_, __, ___) => _artPlaceholder(),
                              )
                            : _artPlaceholder(),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Song Info ───────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song?.title ?? 'Not Playing',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          song?.artist ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      if (song != null) {
                        HapticFeedback.mediumImpact();
                        audio.toggleLike(song);
                      }
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        audio.isLiked(song?.id ?? '')
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        key: ValueKey(audio.isLiked(song?.id ?? '')),
                        color: audio.isLiked(song?.id ?? '')
                            ? Colors.redAccent
                            : _textSecondary,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Progress Bar ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16),
                      activeTrackColor: _accent,
                      inactiveTrackColor: _surface,
                      thumbColor: _accent,
                      overlayColor: _accent.withOpacity(0.2),
                    ),
                    child: Slider(
                      value: audio.duration.inMilliseconds > 0
                          ? audio.position.inMilliseconds
                              .toDouble()
                              .clamp(0, audio.duration.inMilliseconds.toDouble())
                          : 0,
                      max: audio.duration.inMilliseconds > 0
                          ? audio.duration.inMilliseconds.toDouble()
                          : 1,
                      onChanged: (v) =>
                          audio.seekTo(Duration(milliseconds: v.toInt())),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(audio.position),
                            style: const TextStyle(
                                color: _textSecondary, fontSize: 12)),
                        Text(_fmt(audio.duration),
                            style: const TextStyle(
                                color: _textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Controls ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Shuffle
                  _ctrlBtn(
                    icon: Icons.shuffle_rounded,
                    color: audio.isShuffle ? _accent : _textSecondary,
                    size: 22,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      audio.toggleShuffle();
                    },
                  ),

                  // Previous
                  _ctrlBtn(
                    icon: Icons.skip_previous_rounded,
                    color: _textPrimary,
                    size: 36,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      audio.playPrev();
                    },
                  ),

                  // Play / Pause — orange circle (signature)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      audio.togglePlay();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: _accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _accent.withOpacity(0.4),
                            blurRadius: 24,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: audio.isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(18),
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : Icon(
                              audio.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 34),
                    ),
                  ),

                  // Next
                  _ctrlBtn(
                    icon: Icons.skip_next_rounded,
                    color: _textPrimary,
                    size: 36,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      audio.playNext();
                    },
                  ),

                  // Repeat
                  _ctrlBtn(
                    icon: audio.repeatMode == OneMusicRepeatMode.repeatOne
                        ? Icons.repeat_one_rounded
                        : Icons.repeat_rounded,
                    color: audio.repeatMode != OneMusicRepeatMode.none
                        ? _accent
                        : _textSecondary,
                    size: 22,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      audio.toggleRepeat();
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Bottom Row: Volume + Queue ───────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Volume
                  Row(
                    children: [
                      Icon(
                        audio.volume < 0.05
                            ? Icons.volume_off_rounded
                            : audio.volume < 0.5
                                ? Icons.volume_down_rounded
                                : Icons.volume_up_rounded,
                        color: _textSecondary, size: 18),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 100,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 5),
                            activeTrackColor: _textSecondary,
                            inactiveTrackColor: _surface,
                            thumbColor: _textSecondary,
                            overlayShape: SliderComponentShape.noOverlay,
                          ),
                          child: Slider(
                            value: audio.volume,
                            min: 0.0, max: 1.0,
                            onChanged: (v) => audio.setVolume(v),
                          ),
                        ),
                      ),
                      Icon(Icons.volume_up_rounded,
                          color: _textSecondary, size: 18),
                    ],
                  ),
                  // Queue
                  IconButton(
                    icon: const Icon(Icons.queue_music_rounded,
                        color: _textSecondary, size: 22),
                    onPressed: () => _showQueue(context, audio),
                  ),
                ],
              ),
            ),

            // Branding
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('OnePersonAI',
                  style: TextStyle(
                      color: Color(0xFF2A2A2A),
                      fontSize: 10,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════

  Widget _artPlaceholder() => Container(
    color: _surface,
    child: const Icon(Icons.music_note_rounded,
        size: 80, color: _textSecondary),
  );

  Widget _ctrlBtn({
    required IconData icon,
    required Color color,
    required double size,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color, size: size),
        ),
      );

  // ── Options Sheet ──────────────────────────────────────
  void _showOptions(BuildContext ctx, AudioProvider audio, SongModel? song) {
    if (song == null) return;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(
                    color: _textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                    imageUrl: song.thumbnail,
                    width: 48, height: 48, fit: BoxFit.cover),
              ),
              title: Text(song.title, maxLines: 1,
                  style: const TextStyle(
                      color: _textPrimary, fontWeight: FontWeight.w700)),
              subtitle: Text(song.artist,
                  style: const TextStyle(color: _textSecondary)),
            ),
            const Divider(color: _divider, height: 1),
            const SizedBox(height: 8),
            _sheetTile(Icons.share_rounded, 'Share', () {
              Navigator.pop(ctx);
              Share.share('${song.title} by ${song.artist}');
            }),
            _sheetTile(Icons.queue_music_rounded, 'Add to Queue', () {
              audio.addToQueue(song);
              Navigator.pop(ctx);
            }),
            _sheetTile(
              audio.isLiked(song.id)
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              audio.isLiked(song.id) ? 'Unlike' : 'Like',
              () { audio.toggleLike(song); Navigator.pop(ctx); },
              color: audio.isLiked(song.id) ? Colors.redAccent : _textSecondary,
            ),
            _sheetTile(Icons.timer_outlined, 'Sleep Timer', () {
              Navigator.pop(ctx);
              _showSleepTimer(ctx, audio);
            }),
          ],
        ),
      ),
    );
  }

  // ── Queue Sheet ────────────────────────────────────────
  void _showQueue(BuildContext ctx, AudioProvider audio) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: _surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Up Next',
                      style: TextStyle(
                          color: _textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  Text('${audio.queue.length} songs',
                      style: const TextStyle(
                          color: _textSecondary, fontSize: 13)),
                ],
              ),
            ),
            const Divider(color: _divider, height: 1),
            Expanded(
              child: audio.queue.isEmpty
                  ? const Center(
                      child: Text('Queue is empty',
                          style: TextStyle(color: _textSecondary)))
                  : ListView.builder(
                      controller: sc,
                      itemCount: audio.queue.length,
                      itemBuilder: (_, i) {
                        final s = audio.queue[i];
                        final current = i == audio.queueIndex;
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CachedNetworkImage(
                                imageUrl: s.thumbnail,
                                width: 44, height: 44, fit: BoxFit.cover),
                          ),
                          title: Text(s.title, maxLines: 1,
                              style: TextStyle(
                                  color: current ? _accent : _textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          subtitle: Text(s.artist,
                              style: const TextStyle(
                                  color: _textSecondary, fontSize: 12)),
                          trailing: current
                              ? Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(
                                      color: _accent, shape: BoxShape.circle))
                              : IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      color: _textSecondary, size: 18),
                                  onPressed: () => audio.removeFromQueue(i)),
                          onTap: () {
                            Navigator.pop(ctx);
                            audio.playSong(s, list: audio.queue, index: i);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sleep Timer ────────────────────────────────────────
  void _showSleepTimer(BuildContext ctx, AudioProvider audio) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sleep Timer',
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: [5, 10, 15, 30, 45, 60].map((min) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    Future.delayed(Duration(minutes: min), () {
                      if (audio.isPlaying) audio.togglePlay();
                    });
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text('Music stops in $min minutes'),
                        backgroundColor: _surface,
                        behavior: SnackBarBehavior.floating));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _divider),
                    ),
                    child: Text('$min min',
                        style: const TextStyle(
                            color: _textPrimary, fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sheetTile(IconData icon, String label, VoidCallback onTap,
      {Color color = _textSecondary}) =>
      ListTile(
        leading: Icon(icon, color: color),
        title: Text(label,
            style: const TextStyle(color: _textPrimary, fontSize: 15)),
        onTap: onTap,
      );
}