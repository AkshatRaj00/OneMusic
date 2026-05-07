import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/song_model.dart';

class JioSaavnService {
  static const List<String> _apiHosts = [
    'https://saavn.dev',
    'https://jiosaavn-apix.arcadopredator.workers.dev',
  ];

  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
        'Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept': 'application/json',
  };

  // ─── SEARCH ───────────────────────────────────────────────────────────────
  static Future<List<SongModel>> search(String query) async {
    for (final host in _apiHosts) {
      try {
        final uri = Uri.parse(
          '$host/api/search/songs'
          '?query=${Uri.encodeQueryComponent(query)}&limit=20',
        );
        final res = await http
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 10));

        if (res.statusCode != 200) continue;

        final json = jsonDecode(res.body);
        final list = _extractList(json);
        if (list.isEmpty) continue;

        final songs = list
            .map(_toSong)
            .whereType<SongModel>()
            .where(_isQuality) // ✅ Quality gate
            .toList();

        if (songs.isNotEmpty) {
          debugPrint('✅ JioSaavn[$host]: ${songs.length} songs');
          return songs;
        }
      } catch (e) {
        debugPrint('❌ JioSaavn search ($host): $e');
      }
    }
    return [];
  }

  // ─── SIMILAR SONGS (Spotify-style) ───────────────────────────────────────
  static Future<List<SongModel>> getSimilarSongs(String saavnId) async {
    for (final host in _apiHosts) {
      try {
        // ✅ JioSaavn ka official suggestions endpoint
        final uri = Uri.parse('$host/api/songs/$saavnId/suggestions?limit=10');
        final res = await http
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 10));

        if (res.statusCode != 200) continue;

        final json = jsonDecode(res.body);
        final list = _extractList(json);
        if (list.isEmpty) continue;

        final songs = list
            .map(_toSong)
            .whereType<SongModel>()
            .where(_isQuality)
            .take(10)
            .toList();

        if (songs.isNotEmpty) {
          debugPrint('✅ JioSaavn similar songs: ${songs.length}');
          return songs;
        }
      } catch (e) {
        debugPrint('❌ JioSaavn similar ($host): $e');
      }
    }

    // ✅ Fallback — same song ka album fetch karo
    return await _getAlbumSongs(saavnId);
  }

  // ─── ALBUM SONGS fallback ─────────────────────────────────────────────────
  static Future<List<SongModel>> _getAlbumSongs(String saavnId) async {
    for (final host in _apiHosts) {
      try {
        final songUri = Uri.parse('$host/api/songs/$saavnId');
        final res = await http
            .get(songUri, headers: _headers)
            .timeout(const Duration(seconds: 8));

        if (res.statusCode != 200) continue;

        final json = jsonDecode(res.body);
        final data = json['data'];
        Map<String, dynamic>? songData;

        if (data is List && data.isNotEmpty) {
          songData = Map<String, dynamic>.from(data.first as Map);
        } else if (data is Map) {
          songData = Map<String, dynamic>.from(data);
        }

        if (songData == null) continue;

        final albumId = songData['album']?['id']?.toString();
        final artist  = songData['artists']?['primary']?[0]?['name']?.toString() ?? '';

        // Album songs try karo
        if (albumId != null && albumId.isNotEmpty) {
          final albumUri = Uri.parse('$host/api/albums?id=$albumId');
          final albumRes = await http
              .get(albumUri, headers: _headers)
              .timeout(const Duration(seconds: 8));

          if (albumRes.statusCode == 200) {
            final albumJson = jsonDecode(albumRes.body);
            final songsList = albumJson['data']?['songs'] as List?;
            if (songsList != null && songsList.isNotEmpty) {
              final songs = songsList
                  .whereType<Map>()
                  .map((e) => _toSong(Map<String, dynamic>.from(e)))
                  .whereType<SongModel>()
                  .where((s) => s.id != saavnId && _isQuality(s))
                  .take(10)
                  .toList();
              if (songs.isNotEmpty) {
                debugPrint('✅ Album fallback: ${songs.length} songs');
                return songs;
              }
            }
          }
        }

        // Artist songs last fallback
        if (artist.isNotEmpty) {
          return await search('$artist hits top songs');
        }

      } catch (e) {
        debugPrint('❌ Album fallback ($host): $e');
      }
    }
    return [];
  }

  // ─── STREAM URL ───────────────────────────────────────────────────────────
  static Future<String?> getStreamUrl(String saavnId) async {
    for (final host in _apiHosts) {
      try {
        final uri = Uri.parse('$host/api/songs/$saavnId');
        final res = await http
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 10));

        if (res.statusCode != 200) continue;

        final json = jsonDecode(res.body);
        final url = _extractStreamUrl(json);
        if (url != null && url.isNotEmpty) {
          debugPrint('✅ JioSaavn stream via $host');
          return url;
        }
      } catch (e) {
        debugPrint('❌ JioSaavn stream ($host): $e');
      }
    }
    return null;
  }

  // ─── QUALITY GATE ─────────────────────────────────────────────────────────
  static bool _isQuality(SongModel s) =>
      s.duration >= 90 &&          // ✅ 90 sec se zyada
      s.title.isNotEmpty &&
      s.artist.isNotEmpty &&
      s.artist != 'Unknown' &&
      s.thumbnail.isNotEmpty;      // ✅ thumbnail hona chahiye

  // ─── PARSERS ──────────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> _extractList(dynamic json) {
    try {
      if (json is Map) {
        final data = json['data'];
        if (data is Map && data['results'] is List) {
          return _castList(data['results'] as List);
        }
        if (data is List) return _castList(data);
        if (json['results'] is List) return _castList(json['results'] as List);
        final songs = json['songs'];
        if (songs is Map && songs['data'] is List) {
          return _castList(songs['data'] as List);
        }
      }
    } catch (_) {}
    return [];
  }

  static List<Map<String, dynamic>> _castList(List raw) =>
      raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  static String? _extractStreamUrl(dynamic json) {
    try {
      if (json is! Map) return null;
      final data = json['data'];
      Map<String, dynamic> song;
      if (data is List && data.isNotEmpty) {
        song = Map<String, dynamic>.from(data.first as Map);
      } else if (data is Map) {
        song = Map<String, dynamic>.from(data);
      } else {
        song = Map<String, dynamic>.from(json);
      }
      return _pickStreamUrl(song);
    } catch (_) {
      return null;
    }
  }

  static String? _pickStreamUrl(Map<String, dynamic> song) {
    final downloadUrl = song['downloadUrl'];
    if (downloadUrl is List) {
      final url = _bestQualityUrl(downloadUrl);
      if (url != null) return url;
    }
    final links = song['download_links'];
    if (links is List && links.isNotEmpty) {
      return links.last.toString().replaceFirst('http://', 'https://');
    }
    final mediaUrl = (song['media_url'] ?? song['media_preview_url'] ?? '')
        .toString()
        .replaceFirst('http://', 'https://');
    if (mediaUrl.isNotEmpty) return mediaUrl;
    return null;
  }

  static String? _bestQualityUrl(List urls) {
    final list = urls
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    for (final quality in ['320kbps', '160kbps', '96kbps', '48kbps']) {
      for (final u in list) {
        if (u['quality']?.toString() == quality) {
          final url = (u['url'] ?? u['link'] ?? '')
              .toString()
              .replaceFirst('http://', 'https://');
          if (url.isNotEmpty) return url;
        }
      }
    }
    for (final u in list) {
      final url = (u['url'] ?? u['link'] ?? '')
          .toString()
          .replaceFirst('http://', 'https://');
      if (url.isNotEmpty) return url;
    }
    return null;
  }

  static SongModel? _toSong(Map<String, dynamic> item) {
    try {
      final id = (item['id'] ?? '').toString();
      if (id.isEmpty) return null;

      final title = _decodeHtml(
          (item['name'] ?? item['title'] ?? 'Unknown').toString().trim());
      final album = _decodeHtml(
          (item['album']?['name'] ?? item['album'] ?? '').toString());
      final duration =
          int.tryParse((item['duration'] ?? '0').toString()) ?? 0;

      String artist = 'Unknown';
      final primary = item['artists']?['primary'];
      if (primary is List && primary.isNotEmpty) {
        artist = (primary.first['name'] ?? 'Unknown').toString();
      } else if (item['primaryArtists'] is String) {
        artist = item['primaryArtists'].toString();
      } else if (item['artist'] != null) {
        artist = item['artist'].toString();
      }

      String thumb = '';
      final images = item['image'];
      if (images is List && images.isNotEmpty) {
        thumb = (images.last['url'] ?? images.last['link'] ?? '').toString();
      } else if (images is String) {
        thumb = images;
      }
      thumb = thumb
          .replaceAll('http://', 'https://')
          .replaceAll('50x50', '500x500')
          .replaceAll('150x150', '500x500');

      final streamUrl = _pickStreamUrl(item) ?? '';

      return SongModel(
        id: id,
        title: title,
        artist: artist,
        thumbnail: thumb,
        streamUrl: streamUrl,
        album: album,
        duration: duration,
        saavnId: id,
        saavnUrl: streamUrl.isNotEmpty ? streamUrl : null,
      );
    } catch (e) {
      debugPrint('JioSaavn _toSong error: $e');
      return null;
    }
  }

  static String _decodeHtml(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }
}