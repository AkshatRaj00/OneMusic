import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import '../services/music_service.dart';

class OneMusicAudioHandler extends BaseAudioHandler with SeekHandler {
  final Player _player = Player();

  int _playToken = 0;
  bool _disposed = false;
  bool _stopped = false;
  String? _currentVideoId;

  StreamSubscription? _stateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _completedSub;

  void Function()? onSongComplete;
  void Function()? onSkipNext;
  void Function()? onSkipPrevious;

  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();

  Stream<Duration>  get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;

  // ✅ Settings screen + Equalizer ke liye
  Player get player => _player;

  static const Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
        'AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept': '*/*',
    'Connection': 'keep-alive',
  };

  OneMusicAudioHandler() {
    _attachListeners();
  }

  Future<void> playSongUrl({
    required String videoId,
    required String title,
    required String artist,
    required String thumbnail,
    required String album,
    required Duration duration,
    String? saavnId,
    String? saavnUrl,
    String? ytId,
    String? scId,
  }) async {
    if (_disposed) return;

    final int token = ++_playToken;
    _currentVideoId = videoId;
    _stopped = false;

    debugPrint('🎵 [$token] Playing: $title');

    try {
      await _safeStop();
      if (_stale(token)) return;

      final String? url = await _resolveUrl(
        videoId: videoId, saavnId: saavnId,
        saavnUrl: saavnUrl, ytId: ytId, scId: scId,
      );
      if (_stale(token)) return;

      if (!_validUrl(url)) {
        debugPrint('❌ [$token] No URL: $title');
        _currentVideoId = null;
        return;
      }

      _pushMediaItem(
        videoId: videoId, title: title, artist: artist,
        album: album, thumbnail: thumbnail, duration: duration,
        streamUrl: url,
      );

      await _player.open(
        Media(url!, httpHeaders: _headers),
        play: true,
      );
      if (_stale(token)) return;

      debugPrint('▶️ [$token] Started: $title');

    } catch (e) {
      debugPrint('❌ [$token] Error: $e');
      _currentVideoId = null;
    }
  }

  @override
  Future<void> play() async {
    _stopped = false;
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration pos) => _player.seek(pos);

  @override
  Future<void> skipToNext() async =>
      Future.microtask(() => onSkipNext?.call());

  @override
  Future<void> skipToPrevious() async =>
      Future.microtask(() => onSkipPrevious?.call());

  @override
  Future<void> stop() async {
    _stopped = true;
    _playToken++;
    _currentVideoId = null;
    await _safeStop();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
  }

  Future<void> setVolume(double v) =>
      _player.setVolume(v.clamp(0.0, 1.0) * 100);

  Future<void> setShuffleMode(AudioServiceShuffleMode mode) async {}

  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {
    await _player.setPlaylistMode(
      mode == AudioServiceRepeatMode.one
          ? PlaylistMode.single
          : PlaylistMode.none,
    );
  }

  void _attachListeners() {
    _positionSub = _player.stream.position.listen((pos) {
      _positionController.add(pos);
      playbackState.add(playbackState.value.copyWith(
        updatePosition: pos,
      ));
    });

    _durationSub = _player.stream.duration.listen((dur) {
      _durationController.add(dur);
    });

    _stateSub = _player.stream.playing.listen((playing) {
      _updatePlaybackState(playing: playing);
    });

    _player.stream.buffering.listen((buffering) {
      _updatePlaybackState(buffering: buffering);
    });

    _completedSub = _player.stream.completed.listen((completed) {
      if (!completed) return;
      if (_stopped) return;
      if (_currentVideoId == null) return;
      debugPrint('✅ Song completed: $_currentVideoId');
      _currentVideoId = null;
      Future.microtask(() => onSongComplete?.call());
    });
  }

  void _updatePlaybackState({bool? playing, bool? buffering}) {
    final isPlaying   = playing   ?? _player.state.playing;
    final isBuffering = buffering ?? _player.state.buffering;

    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.play,
        MediaAction.pause,
        MediaAction.seek,
        MediaAction.stop,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: isBuffering
          ? AudioProcessingState.buffering
          : AudioProcessingState.ready,
      playing: isPlaying,
      updatePosition: _player.state.position,
      bufferedPosition: _player.state.position,
      speed: 1.0,
    ));
  }

  bool _stale(int token) => _disposed || token != _playToken;

  Future<String?> _resolveUrl({
    required String videoId,
    String? saavnId, String? saavnUrl,
    String? ytId, String? scId,
  }) async {
    if (_validUrl(saavnUrl)) return saavnUrl;
    try {
      return await MusicService.getStreamUrl(
        videoId: videoId, saavnId: saavnId,
        saavnUrl: saavnUrl, ytId: ytId, scId: scId,
      ).timeout(const Duration(seconds: 15));
    } catch (_) { return null; }
  }

  bool _validUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  void _pushMediaItem({
    required String videoId, required String title,
    required String artist, required String album,
    required String thumbnail, required Duration duration,
    String? streamUrl,
  }) {
    mediaItem.add(MediaItem(
      id: videoId, title: title, artist: artist,
      album: album, duration: duration,
      artUri: thumbnail.isNotEmpty ? Uri.tryParse(thumbnail) : null,
      extras: {'streamUrl': streamUrl},
    ));
  }

  Future<void> _safeStop() async {
    try { await _player.pause(); } catch (_) {}
    try { await _player.seek(Duration.zero); } catch (_) {}
  }

  @override Future<void> onTaskRemoved() => stop();

  @override
  Future<dynamic> customAction(String name,
      [Map<String, dynamic>? extras]) async {
    if (name == 'dispose') await dispose();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _playToken++;
    await _stateSub?.cancel();
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _completedSub?.cancel();
    await _positionController.close();
    await _durationController.close();
    await _player.dispose();
  }
}