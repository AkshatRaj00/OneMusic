import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/song_model.dart';

class SoundCloudService {
  // Public client_id — works for read-only public tracks
  static const _clientId = 'iZIs9mchVcX5lhVRyQGGAYlNPVldzAoX';
  static const _base     = 'https://api.soundcloud.com';
  static const _headers  = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13) Chrome/120.0.0.0',
  };

  // ─── SEARCH ───────────────────────────────
  static Future<List<SongModel>> search(String query) async {
    try {
      final uri = Uri.parse(
        '$_base/tracks?q=${Uri.encodeComponent(query)}'
        '&client_id=$_clientId&limit=10&streamable=true',
      );
      final res = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return [];
      final items = jsonDecode(res.body) as List? ?? [];
      return items
          .map((e) => _toSong(e))
          .whereType<SongModel>()
          .toList();
    } catch (e) {
      debugPrint('SoundCloud search error: $e');
      return [];
    }
  }

  // ─── STREAM URL ───────────────────────────
  static Future<String?> getStreamUrl(String scId) async {
    try {
      final streamUri =
          '$_base/tracks/$scId/stream?client_id=$_clientId';
      final res = await http.get(Uri.parse(streamUri), headers: _headers)
          .timeout(const Duration(seconds: 8));
      // SoundCloud redirects to actual stream
      if (res.statusCode == 302 || res.statusCode == 200) {
        return res.headers['location'] ?? streamUri;
      }
      return null;
    } catch (e) {
      debugPrint('SoundCloud stream error: $e');
      return null;
    }
  }

  // ─── HELPERS ──────────────────────────────
  static SongModel? _toSong(Map<String, dynamic> item) {
    try {
      final id       = item['id']?.toString() ?? '';
      final title    = item['title']          as String? ?? 'Unknown';
      final user     = item['user']?['username'] as String? ?? 'Unknown';
      final thumb    = item['artwork_url']    as String? ?? '';
      final duration = ((item['duration'] as int? ?? 0) / 1000).round();
      final stream   = item['stream_url']     as String? ?? '';

      if (id.isEmpty || !(item['streamable'] as bool? ?? false)) return null;
      if (duration < 60 || duration > 900) return null;

      return SongModel(
        id:        'sc_$id',
        title:     title,
        artist:    user,
        thumbnail: thumb.replaceAll('large', 't500x500'),
        streamUrl: '',
        album:     '',
        duration:  duration,
        scId:      id,
      );
    } catch (_) { return null; }
  }
}