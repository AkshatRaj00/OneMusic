import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/song_model.dart';

class DeezerService {
  static const _base = 'https://api.deezer.com';

  static Future<List<SongModel>> search(String query) async {
    try {
      final uri = Uri.parse(
        '$_base/search?q=${Uri.encodeComponent(query)}&limit=20',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final items = data['data'] as List? ?? [];
      return items.map((e) => _toSong(e)).whereType<SongModel>().toList();
    } catch (e) {
      debugPrint('Deezer search error: $e');
      return [];
    }
  }

  static Future<String?> getStreamUrl(String deezerId) async {
    // Deezer 30s preview — free & legal
    try {
      final uri = Uri.parse('$_base/track/$deezerId');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      final preview = data['preview'] as String?;
      return (preview != null && preview.isNotEmpty) ? preview : null;
    } catch (e) {
      debugPrint('Deezer stream error: $e');
      return null;
    }
  }

  static SongModel? _toSong(Map<String, dynamic> item) {
    try {
      final id       = item['id']?.toString() ?? '';
      final title    = item['title']            as String? ?? 'Unknown';
      final artist   = item['artist']?['name']  as String? ?? 'Unknown';
      final thumb    = item['album']?['cover_big'] as String? ?? '';
      final preview  = item['preview']          as String? ?? '';
      final duration = item['duration']         as int? ?? 0;

      if (id.isEmpty || preview.isEmpty) return null;
      if (duration < 30) return null;

      return SongModel(
        id:        'dz_$id',
        title:     title,
        artist:    artist,
        thumbnail: thumb,
        streamUrl: preview, // 30s preview direct
        album:     item['album']?['title'] as String? ?? '',
        duration:  duration,
        saavnUrl:  preview, // direct use hoga
      );
    } catch (_) {
      return null;
    }
  }
}