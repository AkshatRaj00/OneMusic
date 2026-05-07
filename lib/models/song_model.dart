import 'package:hive/hive.dart';

part 'song_model.g.dart';

@HiveType(typeId: 0)
class SongModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String artist;

  @HiveField(3)
  final String thumbnail;

  @HiveField(4)
  final String streamUrl;

  @HiveField(5)
  final String album;

  @HiveField(6)
  final int duration;

  @HiveField(7)
  bool isLiked;

  @HiveField(8)
  int? lastPlayedAt;

  @HiveField(9)
  final String? saavnId;

  @HiveField(10)
  final String? saavnUrl;

  @HiveField(11)
  final String? ytId;

  @HiveField(12)
  final String? scId;

  SongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbnail,
    required this.streamUrl,
    required this.album,
    required this.duration,
    this.isLiked = false,
    this.lastPlayedAt,
    this.saavnId,
    this.saavnUrl,
    this.ytId,
    this.scId,
  });

  SongModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? thumbnail,
    String? streamUrl,
    String? album,
    int? duration,
    bool? isLiked,
    int? lastPlayedAt,
    String? saavnId,
    String? saavnUrl,
    String? ytId,
    String? scId,
  }) {
    return SongModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      thumbnail: thumbnail ?? this.thumbnail,
      streamUrl: streamUrl ?? this.streamUrl,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      isLiked: isLiked ?? this.isLiked,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      saavnId: saavnId ?? this.saavnId,
      saavnUrl: saavnUrl ?? this.saavnUrl,
      ytId: ytId ?? this.ytId,
      scId: scId ?? this.scId,
    );
  }

  factory SongModel.fromMap(Map<String, dynamic> m) => SongModel(
        id: (m['id'] ?? '').toString(),
        title: (m['title'] ?? 'Unknown').toString(),
        artist: (m['artist'] ?? 'Unknown').toString(),
        thumbnail: (m['thumbnail'] ?? '').toString(),
        streamUrl: (m['streamUrl'] ?? '').toString(),
        album: (m['album'] ?? '').toString(),
        duration: int.tryParse(m['duration']?.toString() ?? '0') ?? 0,
        isLiked: m['isLiked'] ?? false,
        lastPlayedAt: m['lastPlayedAt'] is int
            ? m['lastPlayedAt'] as int
            : int.tryParse(m['lastPlayedAt']?.toString() ?? ''),
        saavnId: m['saavnId']?.toString(),
        saavnUrl: m['saavnUrl']?.toString(),
        ytId: m['ytId']?.toString(),
        scId: m['scId']?.toString(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'thumbnail': thumbnail,
        'streamUrl': streamUrl,
        'album': album,
        'duration': duration,
        'isLiked': isLiked,
        'lastPlayedAt': lastPlayedAt,
        'saavnId': saavnId,
        'saavnUrl': saavnUrl,
        'ytId': ytId,
        'scId': scId,
      };
}