import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song_model.dart';

class PipedService {
  static const List<String> _instances = [
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.in.projectsegfau.lt',
    'https://pipedapi.darkness.services',
    'https://piped-api.privacy.com.de',
    'https://pipedapi.drgns.space',
    'https://yt.artemislena.eu',
    'https://pipedapi.ngn.tf',
  ];

  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
        'Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept': 'application/json',
  };

  static Future<List<SongModel>> search(String query) async {
    final songs = <SongModel>[];

    final youtubeResults = await _searchYoutubeExplode(query);
    songs.addAll(youtubeResults);

    if (songs.length >= 15) {
      return songs.take(15).toList();
    }

    final instances = List<String>.from(_instances)..shuffle();
    for (final inst in instances.take(3)) {
      try {
        final uri = Uri.parse(
          '$inst/search?q=${Uri.encodeQueryComponent(query)}&filter=music_songs',
        );
        final res = await http
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 8));

        if (res.statusCode != 200) continue;

        final json = jsonDecode(res.body);
        if (json is! Map || json['items'] is! List) continue;

        final pipedSongs = (json['items'] as List)
            .whereType<Map>()
            .map((e) => _toSong(Map<String, dynamic>.from(e)))
            .whereType<SongModel>()
            .take(15)
            .toList();

        for (final s in pipedSongs) {
          if (songs.length >= 15) break;
          if (_addUnique(songs, s)) {
            debugPrint('✅ Piped search OK via $inst');
          }
        }
      } catch (e) {
        debugPrint('Piped search failed ($inst): $e');
      }
    }

    debugPrint('✅ Search results: ${songs.length}');
    return songs.take(15).toList();
  }

  static Future<List<SongModel>> _searchYoutubeExplode(String query) async {
    final yt = YoutubeExplode();
    try {
      final results = await yt.search.getVideos(query);
      final songs = <SongModel>[];

      for (final video in results.take(20)) {
        final dur = video.duration?.inSeconds ?? 0;
        if (dur < 60 || dur > 900) continue;
        if (_isJunk(video.title)) continue;

        songs.add(SongModel(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          thumbnail: 'https://i.ytimg.com/vi/${video.id.value}/hqdefault.jpg',
          streamUrl: '',
          album: '',
          duration: dur,
          ytId: video.id.value,
        ));
      }

      debugPrint('✅ YouTube Explode search: ${songs.length} songs');
      return songs;
    } catch (e) {
      debugPrint('YouTube Explode search failed: $e');
      return [];
    } finally {
      yt.close();
    }
  }

  static Future<String?> getStreamUrl(String videoId) async {
    final ytUrl = await _getUrlFromYoutubeExplode(videoId);
    if (ytUrl != null && ytUrl.isNotEmpty) return ytUrl;

    final instances = List<String>.from(_instances)..shuffle();
    for (final inst in instances.take(3)) {
      try {
        final uri = Uri.parse('$inst/streams/$videoId');
        final res = await http
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 8));

        if (res.statusCode != 200) continue;

        final json = jsonDecode(res.body);
        if (json is! Map || json['audioStreams'] is! List) continue;

        final streams = (json['audioStreams'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        if (streams.isEmpty) continue;

        streams.sort((a, b) {
          final ab = int.tryParse(a['bitrate']?.toString() ?? '0') ?? 0;
          final bb = int.tryParse(b['bitrate']?.toString() ?? '0') ?? 0;
          return bb.compareTo(ab);
        });

        final m4aStream = streams.firstWhere(
          (s) => (s['mimeType']?.toString() ?? '').contains('mp4a'),
          orElse: () => streams.first,
        );

        final url = (m4aStream['url'] ?? '').toString();
        if (url.isNotEmpty) {
          debugPrint('✅ Piped stream OK via $inst');
          return url;
        }
      } catch (e) {
        debugPrint('Piped stream failed ($inst): $e');
      }
    }

    debugPrint('❌ All sources failed for: $videoId');
    return null;
  }

  static Future<String?> _getUrlFromYoutubeExplode(String videoId) async {
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streams.getManifest(
        videoId,
        ytClients: [
          YoutubeApiClient.ios,
          YoutubeApiClient.androidVr,
          YoutubeApiClient.android,
          YoutubeApiClient.safari,
        ],
      ).timeout(const Duration(seconds: 18));

      final audioStreams = manifest.audioOnly.sortByBitrate();
      if (audioStreams.isEmpty) return null;

      final m4a = audioStreams
          .where((s) => s.codec.mimeType.contains('mp4a'))
          .toList();

      final best = m4a.isNotEmpty ? m4a.last : audioStreams.last;
      debugPrint(
        '✅ YouTube Explode stream OK: ${best.bitrate.bitsPerSecond ~/ 1000}kbps',
      );
      return best.url.toString();
    } catch (e) {
      debugPrint('YouTube Explode stream failed: $e');
      return null;
    } finally {
      yt.close();
    }
  }

  static SongModel? _toSong(Map<String, dynamic> item) {
    try {
      final rawUrl = (item['url'] ?? '').toString();
      final videoId = _extractVideoId(rawUrl);
      if (videoId == null) return null;

      final title = (item['title'] ?? 'Unknown').toString().trim();
      final uploader = (item['uploaderName'] ?? 'Unknown').toString().trim();
      final thumbnail = (item['thumbnail'] ?? '').toString();
      final duration = _toInt(item['duration']);

      if (title.isEmpty) return null;
      if (duration < 60 || duration > 900) return null;
      if (_isJunk(title)) return null;

      final thumb = thumbnail.isNotEmpty
          ? thumbnail
          : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

      return SongModel(
        id: videoId,
        title: title,
        artist: uploader,
        thumbnail: thumb,
        streamUrl: '',
        album: '',
        duration: duration,
        ytId: videoId,
      );
    } catch (_) {
      return null;
    }
  }

  static String? _extractVideoId(String rawUrl) {
    if (rawUrl.isEmpty) return null;
    try {
      if (rawUrl.startsWith('/watch')) {
        final uri = Uri.parse('https://youtube.com$rawUrl');
        final id = uri.queryParameters['v'];
        if (id != null && id.length == 11) return id;
      }
      if (rawUrl.startsWith('http')) {
        final uri = Uri.parse(rawUrl);
        final id = uri.queryParameters['v'];
        if (id != null && id.length == 11) return id;
      }
      final match = RegExp(r'([A-Za-z0-9_-]{11})').firstMatch(rawUrl);
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }

  static int _toInt(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '0') ?? 0;

  static bool _addUnique(List<SongModel> list, SongModel song) {
    final normTitle = _normalize(song.title);
    final exists = list.any((s) => s.id == song.id || _normalize(s.title) == normTitle);
    if (exists) return false;
    list.add(song);
    return true;
  }

  static String _normalize(String title) =>
      title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();

  static bool _isJunk(String title) {
    final t = title.toLowerCase();
    const blocked = [
      'slowed',
      'reverb',
      '8d audio',
      'bass boosted',
      'ringtone',
      'lofi',
      'nightcore',
    ];
    return blocked.any(t.contains);
  }
}