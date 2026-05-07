import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/song_model.dart';

class JamendoService {
  static const _clientId = '2fe5e426'; // Free public client ID
  static const _base     = 'https://api.jamendo.com/v3.0';

  static Future<List<SongModel>> search(String query) async {
    try {
      final uri = Uri.parse(
        '$_base/tracks?client_id=$_clientId'
        '&format=json&limit=20&search=${Uri.encodeComponent(query)}'
        '&audioformat=mp32&include=musicinfo',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final data   = jsonDecode(res.body);
      final items  = data['results'] as List? ?? [];
      return items.map((e) => _toSong(e)).whereType<SongModel>().toList();
    } catch (e) {
      debugPrint('Jamendo search error: $e');
      return [];
    }
  }

  static Future<String?> getStreamUrl(String jamendoId) async {
    try {
      final uri = Uri.parse(
        '$_base/tracks?client_id=$_clientId&format=json&id=$jamendoId&audioformat=mp32',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data  = jsonDecode(res.body);
      final items = data['results'] as List? ?? [];
      if (items.isEmpty) return null;
      return items[0]['audio'] as String?;
    } catch (e) {
      debugPrint('Jamendo stream error: $e');
      return null;
    }
  }

  static SongModel? _toSong(Map<String, dynamic> item) {
    try {
      final id       = item['id']?.toString()    ?? '';
      final title    = item['name']              as String? ?? 'Unknown';
      final artist   = item['artist_name']       as String? ?? 'Unknown';
      final thumb    = item['album_image']       as String? ?? '';
      final audio    = item['audio']             as String? ?? '';
      final duration = int.tryParse(item['duration']?.toString() ?? '0') ?? 0;

      if (id.isEmpty || audio.isEmpty) return null;
      if (duration < 60) return null;

      return SongModel(
        id:        'jm_$id',
        title:     title,
        artist:    artist,
        thumbnail: thumb,
        streamUrl: audio,
        album:     item['album_name'] as String? ?? '',
        duration:  duration,
        saavnUrl:  audio, // direct stream
      );
    } catch (_) {
      return null;
    }
  }
}