import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// IPv4-only YoutubeExplode client
YoutubeExplode createIPv4YoutubeClient() {
  return YoutubeExplode(
    YoutubeHttpClient(
      _IPv4HttpClient(),
    ),
  );
}

class _IPv4HttpClient extends HttpClient {
  _IPv4HttpClient() : super() {
    // Force IPv4 only — IPv6 YouTube CDN Windows MPV pe fail karta hai
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    // IPv6 host ko IPv4 pe resolve karo
    final ipv4Uri = url.replace(
      host: url.host, // Same host — OS level pe IPv4 prefer karenge
    );
    return super.openUrl(method, ipv4Uri);
  }
}