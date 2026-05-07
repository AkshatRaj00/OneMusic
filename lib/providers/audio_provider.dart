import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:audio_service/audio_service.dart';

import '../models/song_model.dart';
import '../services/audio_handler.dart';
import '../services/music_service.dart';

enum OneMusicRepeatMode { none, repeatAll, repeatOne }

class AudioProvider extends ChangeNotifier {
  final OneMusicAudioHandler _handler;

  late Box<SongModel> _recentBox;
  late Box<SongModel> _likedBox;

  SongModel? currentSong;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool isPlaying = false;
  bool isLoading = false;
  bool isShuffle = false;
  String? error;

  OneMusicRepeatMode _repeatMode = OneMusicRepeatMode.none;
  OneMusicRepeatMode get repeatMode => _repeatMode;

  double _volume = 0.8;
  double get volume => _volume;

  Stream<Duration>  get positionStream => _handler.positionStream;
  Stream<Duration?> get durationStream => _handler.durationStream;

  List<SongModel> _queue = [];
  List<SongModel> get queue => _queue;
  int queueIndex = 0;
  List<SongModel> recentlyPlayed = [];
  List<SongModel> likedSongs = [];

  String? _currentLoadingId;
  bool _advancing = false;
  bool _fetching  = false;

  AudioProvider(this._handler) {
    _setupHive();
    _listenToPlayer();
    _handler.onSongComplete  = _onComplete;
    _handler.onSkipNext      = () => playNext();
    _handler.onSkipPrevious  = () => playPrev();
  }

  // ════════════════════════════════════════════════════
  //  COMPLETION
  // ════════════════════════════════════════════════════

  void _onComplete() {
    // ✅ Manually stopped hai toh auto-advance nahi
    if (!isPlaying && position.inSeconds < 1) return;

    debugPrint('🎵 onComplete repeat=$_repeatMode idx=$queueIndex');
    switch (_repeatMode) {
      case OneMusicRepeatMode.repeatOne:
        _handler.seek(Duration.zero);
        _handler.play();
        break;
      case OneMusicRepeatMode.repeatAll:
        _advance();
        break;
      case OneMusicRepeatMode.none:
        if (queueIndex < _queue.length - 1) {
          _advance();
        } else {
          _autoFillAndPlay();
        }
        break;
    }
  }

  // ════════════════════════════════════════════════════
  //  PLAYER LISTENERS
  // ════════════════════════════════════════════════════

  void _listenToPlayer() {
    _handler.positionStream.listen((p) {
      position = p;
      notifyListeners();
    });

    _handler.durationStream.listen((d) {
      if (d != null && d.inSeconds > 0) {
        duration = d;
        notifyListeners();
      }
    });

    _handler.playbackState.listen((state) {
      isPlaying = state.playing;
      isLoading = state.processingState == AudioProcessingState.loading ||
                  state.processingState == AudioProcessingState.buffering;
      notifyListeners();
    });
  }

  // ════════════════════════════════════════════════════
  //  HIVE
  // ════════════════════════════════════════════════════

  Future<void> _setupHive() async {
    _recentBox = Hive.box<SongModel>('recently_played');
    _likedBox  = Hive.box<SongModel>('liked_songs');
    recentlyPlayed = _recentBox.values.toList().reversed.take(20).toList();
    likedSongs     = _likedBox.values.toList();
    notifyListeners();
  }

  SongModel _copy(SongModel s) => s.copyWith();

  // ════════════════════════════════════════════════════
  //  PLAY SONG
  // ════════════════════════════════════════════════════

  Future<void> playSong(
    SongModel song, {
    List<SongModel>? list,
    int index = 0,
  }) async {
    if (_currentLoadingId == song.id && isLoading) return;

    final loadId      = song.id;
    _currentLoadingId = loadId;
    isLoading         = true;
    error             = null;
    currentSong       = _copy(song);

    if (list != null) {
      _queue     = list.map(_copy).toList();
      queueIndex = index.clamp(0, _queue.length - 1);
    }

    notifyListeners();

    try {
      await _handler.playSongUrl(
        videoId  : song.id,
        title    : song.title,
        artist   : song.artist,
        thumbnail: song.thumbnail,
        album    : song.album,
        duration : Duration(seconds: song.duration),
        saavnId  : song.saavnId,
        saavnUrl : song.saavnUrl,
        ytId     : song.ytId,
        scId     : song.scId,
      );

      if (_currentLoadingId != loadId) return;

      _currentLoadingId = null;
      await _handler.setVolume(_volume);
      _applyRepeat();

      final r = _copy(song).copyWith(
          lastPlayedAt: DateTime.now().millisecondsSinceEpoch);
      await _recentBox.put(r.id, r);
      recentlyPlayed = _recentBox.values.toList().reversed.take(20).toList();

      isLoading = false;
      error     = null;
      notifyListeners();

      _autoFillQueue();

    } catch (e) {
      debugPrint('❌ playSong: $e');
      if (_currentLoadingId != loadId) return;

      _currentLoadingId = null;
      isLoading         = false;
      MusicService.clearCache(song.id);

      if (_queue.isNotEmpty && queueIndex < _queue.length - 1) {
        error = null;
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 300));
        await _advance();
      } else {
        error = '⚠️ Song play nahi hua.';
        notifyListeners();
      }
    }
  }

  // ════════════════════════════════════════════════════
  //  ADVANCE — deadlock free
  // ════════════════════════════════════════════════════

  Future<void> _advance() async {
    if (_queue.isEmpty || _advancing) return;
    _advancing = true;

    try {
      int next;
      if (isShuffle) {
        final others = List.generate(_queue.length, (i) => i)
            .where((i) => i != queueIndex).toList()..shuffle();
        if (others.isEmpty) return;
        next = others.first;
      } else if (_repeatMode == OneMusicRepeatMode.repeatAll) {
        next = (queueIndex + 1) % _queue.length;
      } else {
        if (queueIndex >= _queue.length - 1) return;
        next = queueIndex + 1;
      }

      queueIndex = next;
      final song = _copy(_queue[queueIndex]);
      _advancing = false; // ✅ playSong se pehle release
      await playSong(song, list: _queue, index: queueIndex);

    } catch (e) {
      debugPrint('❌ _advance: $e');
    } finally {
      _advancing = false; // ✅ har case mein reset
    }
  }

  // ════════════════════════════════════════════════════
  //  AUTO FILL — Spotify infinite queue
  // ════════════════════════════════════════════════════

  Future<void> _autoFillQueue() async {
    if (_fetching || currentSong == null) return;
    if (_queue.length - queueIndex - 1 > 5) return;

    _fetching = true;
    try {
      final similar = await MusicService.getSimilarSongs(
        artist   : currentSong!.artist,
        title    : currentSong!.title,
        currentId: currentSong!.id,
      );
      final existing = _queue.map((s) => s.id).toSet();
      final fresh = similar
          .where((s) => !existing.contains(s.id))
          .map(_copy).toList();
      if (fresh.isNotEmpty) {
        _queue.addAll(fresh);
        notifyListeners();
      }
    } catch (_) {
    } finally {
      _fetching = false;
    }
  }

  Future<void> _autoFillAndPlay() async {
    await _autoFillQueue();
    if (queueIndex < _queue.length - 1) {
      await _advance();
    } else {
      isPlaying = false;
      notifyListeners();
    }
  }

  // ════════════════════════════════════════════════════
  //  CONTROLS
  // ════════════════════════════════════════════════════

  Future<void> togglePlay() async =>
      isPlaying ? await _handler.pause() : await _handler.play();

  Future<void> seekTo(Duration d) => _handler.seek(d);

  Future<void> playNext({SongModel? song}) async {
    if (song != null) {
      final at = (queueIndex + 1).clamp(0, _queue.length);
      _queue.insert(at, _copy(song));
      notifyListeners();
      return;
    }
    await _advance();
  }

  Future<void> playPrev() async {
    if (_queue.isEmpty) return;
    if (position.inSeconds > 3) {
      await seekTo(Duration.zero);
      return;
    }
    queueIndex = (queueIndex - 1 + _queue.length) % _queue.length;
    await playSong(_copy(_queue[queueIndex]),
        list: _queue, index: queueIndex);
  }

  void addToQueue(SongModel s) {
    _queue.add(_copy(s));
    notifyListeners();
  }

  void removeFromQueue(int i) {
    if (i < 0 || i >= _queue.length) return;
    _queue.removeAt(i);
    if (_queue.isEmpty) {
      queueIndex = 0;
    } else if (queueIndex >= _queue.length) {
      queueIndex = _queue.length - 1;
    }
    notifyListeners();
  }

  // ════════════════════════════════════════════════════
  //  SHUFFLE & REPEAT
  // ════════════════════════════════════════════════════

  void toggleShuffle() {
    isShuffle = !isShuffle;
    _handler.setShuffleMode(isShuffle
        ? AudioServiceShuffleMode.all
        : AudioServiceShuffleMode.none);
    notifyListeners();
  }

  void toggleRepeat() {
    _repeatMode = {
      OneMusicRepeatMode.none     : OneMusicRepeatMode.repeatAll,
      OneMusicRepeatMode.repeatAll: OneMusicRepeatMode.repeatOne,
      OneMusicRepeatMode.repeatOne: OneMusicRepeatMode.none,
    }[_repeatMode]!;
    _applyRepeat();
    notifyListeners();
  }

  void _applyRepeat() {
    _handler.setRepeatMode({
      OneMusicRepeatMode.none     : AudioServiceRepeatMode.none,
      OneMusicRepeatMode.repeatAll: AudioServiceRepeatMode.all,
      OneMusicRepeatMode.repeatOne: AudioServiceRepeatMode.one,
    }[_repeatMode]!);
  }

  // ════════════════════════════════════════════════════
  //  VOLUME
  // ════════════════════════════════════════════════════

  Future<void> setVolume(double v) async {
    final nv = v.clamp(0.0, 1.0);
    if (nv == _volume) return;
    _volume = nv;
    await _handler.setVolume(_volume);
    notifyListeners();
  }

  // ════════════════════════════════════════════════════
  //  LIKED SONGS
  // ════════════════════════════════════════════════════

  Future<void> toggleLike(SongModel song) async {
    if (_likedBox.containsKey(song.id)) {
      await _likedBox.delete(song.id);
      song.isLiked = false;
    } else {
      await _likedBox.put(song.id, _copy(song).copyWith(isLiked: true));
      song.isLiked = true;
    }
    likedSongs = _likedBox.values.toList();
    if (currentSong?.id == song.id) currentSong = _copy(song);
    notifyListeners();
  }

  bool isLiked(String id) => _likedBox.containsKey(id);
}