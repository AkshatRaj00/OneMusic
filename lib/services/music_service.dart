import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/song_model.dart';
import 'jiosaavn_service.dart';
import 'piped_service.dart';
import 'soundcloud_service.dart';
import 'deezer_service.dart';
import 'jamendo_service.dart';

class MusicService {
  static final Map<String, String> _urlCache  = {};
  static final Set<String>         _failedKeys = {};

  static Future<List<SongModel>> searchSongs(String query) async {
    final results = await Future.wait<List<SongModel>>([
      JioSaavnService.search(query).catchError((_) => <SongModel>[]),
      PipedService.search(query).catchError((_) => <SongModel>[]),
      SoundCloudService.search(query).catchError((_) => <SongModel>[]),
      DeezerService.search(query).catchError((_) => <SongModel>[]),
      JamendoService.search(query).catchError((_) => <SongModel>[]),
    ]);

    final saavnSongs   = results[0];
    final pipedSongs   = results[1];
    final scSongs      = results[2];
    final deezerSongs  = results[3];
    final jamendoSongs = results[4];

    debugPrint(
      '🔍 Search → JioSaavn: ${saavnSongs.length}, '
      'YouTube: ${pipedSongs.length}, '
      'SoundCloud: ${scSongs.length}, '
      'Deezer: ${deezerSongs.length}, '
      'Jamendo: ${jamendoSongs.length}',
    );

    final seenIds    = <String>{};
    final seenTitles = <String>{};
    final merged     = <SongModel>[];

    void addIfUnique(SongModel s) {
      final normTitle = _normalize(s.title);
      if (!seenIds.contains(s.id) && !seenTitles.contains(normTitle)) {
        seenIds.add(s.id);
        seenTitles.add(normTitle);
        merged.add(s);
      }
    }

    // Priority: JioSaavn > Deezer > YouTube > Jamendo > SoundCloud
    for (final s in saavnSongs)   addIfUnique(s);
    for (final s in deezerSongs)  addIfUnique(s);
    for (final s in pipedSongs)   addIfUnique(s);
    for (final s in jamendoSongs) addIfUnique(s);
    for (final s in scSongs)      addIfUnique(s);

    debugPrint('✅ Total merged results: ${merged.length}');
    return merged;
  }

  static Future<List<SongModel>> getSimilarSongs({
    required String artist,
    required String title,
    required String currentId,
  }) async {
    try {
      final results = await searchSongs('$artist best songs');
      return results.where((s) => s.id != currentId).take(10).toList();
    } catch (e) {
      debugPrint('❌ getSimilarSongs error: $e');
      return [];
    }
  }

  static Future<String?> getStreamUrl({
    required String videoId,
    String? saavnId,
    String? saavnUrl,
    String? ytId,
    String? scId,
  }) async {
    final youtubeId = ytId ?? (videoId.length == 11 ? videoId : null);
    final scTrackId = scId ??
        (videoId.startsWith('sc_') ? videoId.replaceFirst('sc_', '') : null);
    final deezerId =
        videoId.startsWith('dz_') ? videoId.replaceFirst('dz_', '') : null;
    final jamendoId =
        videoId.startsWith('jm_') ? videoId.replaceFirst('jm_', '') : null;

    final cacheKey = youtubeId ?? saavnId ?? scTrackId ?? deezerId ?? jamendoId ?? videoId;

    if (_failedKeys.contains(cacheKey)) {
      debugPrint('⛔ Recently failed, skipping: $cacheKey');
      return null;
    }

    final cached = _urlCache[cacheKey];
    if (cached != null && cached.isNotEmpty) {
      debugPrint('⚡ Cache hit: $cacheKey');
      return cached;
    }

    // ── 1. saavnUrl direct ──────────────────────────────────
    if (saavnUrl != null && saavnUrl.isNotEmpty) {
      _urlCache[cacheKey] = saavnUrl;
      debugPrint('✅ Using existing saavnUrl');
      return saavnUrl;
    }

    // ── 2. JioSaavn ─────────────────────────────────────────
    if (saavnId != null && saavnId.isNotEmpty) {
      try {
        debugPrint('🎵 Fetching JioSaavn stream...');
        final url = await JioSaavnService.getStreamUrl(saavnId)
            .timeout(const Duration(seconds: 10), onTimeout: () => null);
        if (_isValidUrl(url)) {
          _urlCache[cacheKey] = url!;
          debugPrint('✅ JioSaavn stream OK');
          return url;
        }
      } catch (e) {
        debugPrint('JioSaavn stream failed: $e');
      }
    }

    // ── 3. Deezer preview ───────────────────────────────────
    if (deezerId != null && deezerId.isNotEmpty) {
      try {
        debugPrint('🎵 Fetching Deezer stream...');
        final url = await DeezerService.getStreamUrl(deezerId)
            .timeout(const Duration(seconds: 10), onTimeout: () => null);
        if (_isValidUrl(url)) {
          _urlCache[cacheKey] = url!;
          debugPrint('✅ Deezer stream OK');
          return url;
        }
      } catch (e) {
        debugPrint('Deezer stream failed: $e');
      }
    }

    // ── 4. Jamendo ──────────────────────────────────────────
    if (jamendoId != null && jamendoId.isNotEmpty) {
      try {
        debugPrint('🎵 Fetching Jamendo stream...');
        final url = await JamendoService.getStreamUrl(jamendoId)
            .timeout(const Duration(seconds: 10), onTimeout: () => null);
        if (_isValidUrl(url)) {
          _urlCache[cacheKey] = url!;
          debugPrint('✅ Jamendo stream OK');
          return url;
        }
      } catch (e) {
        debugPrint('Jamendo stream failed: $e');
      }
    }

    // ── 5. YouTube ──────────────────────────────────────────
    if (youtubeId != null && youtubeId.isNotEmpty) {
      try {
        debugPrint('🎵 Fetching YouTube stream...');
        final url = await PipedService.getStreamUrl(youtubeId)
            .timeout(const Duration(seconds: 25), onTimeout: () => null);
        if (_isValidUrl(url)) {
          _urlCache[cacheKey] = url!;
          debugPrint('✅ YouTube stream OK');
          return url;
        }
      } catch (e) {
        debugPrint('YouTube stream failed: $e');
      }
    }

    // ── 6. SoundCloud ───────────────────────────────────────
    if (scTrackId != null && scTrackId.isNotEmpty) {
      try {
        debugPrint('🎵 Fetching SoundCloud stream...');
        final url = await SoundCloudService.getStreamUrl(scTrackId)
            .timeout(const Duration(seconds: 10), onTimeout: () => null);
        if (_isValidUrl(url)) {
          _urlCache[cacheKey] = url!;
          debugPrint('✅ SoundCloud stream OK');
          return url;
        }
      } catch (e) {
        debugPrint('SoundCloud stream failed: $e');
      }
    }

    _failedKeys.add(cacheKey);
    Future.delayed(const Duration(minutes: 2), () => _failedKeys.remove(cacheKey));

    debugPrint('❌ All sources failed for: $videoId');
    return null;
  }

  static void clearCache([String? videoId]) {
    if (videoId != null) {
      _urlCache.remove(videoId);
      _failedKeys.remove(videoId);
    } else {
      _urlCache.clear();
      _failedKeys.clear();
    }
  }

  static Future<List<SongModel>> search(String query) => searchSongs(query);

  static Future<List<SongModel>> getTrending() =>
      searchSongs('top hindi songs 2025');

  static Future<List<SongModel>> getByGenre(String genre) =>
      searchSongs('$genre songs hits');

  static bool _isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  static String _normalize(String title) =>
      title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
}