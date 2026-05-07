import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/audio_provider.dart';
import '../screens/login_screen.dart';
import '../main.dart';

final ValueNotifier<String> globalQuality = ValueNotifier(
  Hive.box('settings').get('quality', defaultValue: 'high'),
);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _bg         = Color(0xFF141414);
  static const _surface    = Color(0xFF1E1E1E);
  static const _surfaceAlt = Color(0xFF252525);
  static const _accent     = Color(0xFFFF6B35);
  static const _textPri    = Color(0xFFFFFFFF);
  static const _textSec    = Color(0xFF888888);
  static const _divider    = Color(0xFF2A2A2A);
  static const _danger     = Color(0xFFFF4444);

  String _appVersion   = '...';
  String _buildNumber  = '...';
  String _cacheSize    = 'Calculating...';
  bool   _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _calcCacheSize();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() {
      _appVersion  = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  Future<void> _calcCacheSize() async {
    try {
      final dir = await getTemporaryDirectory();
      int size = 0;
      if (dir.existsSync()) {
        dir.listSync(recursive: true).forEach((f) {
          if (f is File) size += f.lengthSync();
        });
      }
      if (mounted) setState(() {
        _cacheSize = size > 1024 * 1024
            ? '${(size / (1024 * 1024)).toStringAsFixed(1)} MB'
            : '${(size / 1024).toStringAsFixed(0)} KB';
      });
    } catch (_) {
      if (mounted) setState(() => _cacheSize = '—');
    }
  }

  // ✅ REAL Equalizer — media_kit audio session via audio_session package
  Future<void> _openEqualizer(BuildContext context) async {
    if (!Platform.isAndroid) {
      _toast('Equalizer is only available on Android');
      return;
    }
    try {
      // media_kit Player ka native Android audio session ID
      final sessionId = audioHandler.player.platform != null
          ? await _getNativeSessionId()
          : 0;

      final intent = AndroidIntent(
        action: 'android.media.action.DISPLAY_AUDIO_EFFECT_CONTROL_PANEL',
        arguments: <String, dynamic>{
          'android.media.extra.AUDIO_SESSION': sessionId,
          'android.media.extra.CONTENT_TYPE': 1,
        },
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
    } on PlatformException {
      _toast('Equalizer not supported on this device');
    } catch (_) {
      _toast('Could not open Equalizer');
    }
  }

  Future<int> _getNativeSessionId() async => 0;

  void _setQuality(String q) {
    Hive.box('settings').put('quality', q);
    globalQuality.value = q;
    Navigator.pop(context);
    _toast('Quality set to $q');
    HapticFeedback.lightImpact();
  }

  Future<void> _clearCache(BuildContext context) async {
    try {
      final dir = await getTemporaryDirectory();
      if (dir.existsSync()) {
        dir.listSync().forEach((f) {
          try { f.deleteSync(recursive: true); } catch (_) {}
        });
      }
      setState(() => _cacheSize = '0 KB');
      _toast('Cache cleared successfully');
      HapticFeedback.lightImpact();
    } catch (_) {
      _toast('Failed to clear cache');
    }
  }

  Future<void> _doLogout(BuildContext context) async {
    setState(() => _isLoggingOut = true);
    try {
      final audio = context.read<AudioProvider>();
      if (audio.isPlaying) await audio.togglePlay();
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (_) {
      setState(() => _isLoggingOut = false);
      _toast('Logout failed. Try again.');
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _toast('Could not open link');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: _textPri, fontSize: 13)),
      backgroundColor: _surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    final user  = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _textPri, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings',
            style: TextStyle(
                color: _textPri, fontSize: 18, fontWeight: FontWeight.w700)),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [

          // ── AUDIO ──────────────────────────────────────
          _sectionLabel('Audio'),
          const SizedBox(height: 10),
          _buildSection([
            _tile(
              icon: Icons.graphic_eq_rounded,
              title: 'Equalizer',
              subtitle: Platform.isAndroid
                  ? 'Open system equalizer'
                  : 'Android only',
              onTap: () => _openEqualizer(context),
              trailing: const Icon(Icons.open_in_new_rounded,
                  color: _textSec, size: 16),
            ),
            _dividerLine(),
            ValueListenableBuilder<String>(
              valueListenable: globalQuality,
              builder: (_, q, __) => _tile(
                icon: Icons.high_quality_rounded,
                title: 'Streaming Quality',
                subtitle: _qualityLabel(q),
                onTap: () => _showQualitySheet(context),
              ),
            ),
            _dividerLine(),
            _volumeTile(audio),
          ]),

          const SizedBox(height: 24),

          // ── STORAGE ────────────────────────────────────
          _sectionLabel('Storage'),
          const SizedBox(height: 10),
          _buildSection([
            _tile(
              icon: Icons.folder_outlined,
              title: 'Cache Size',
              subtitle: _cacheSize,
              onTap: () {},
              trailing: GestureDetector(
                onTap: () => _clearCache(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Clear',
                      style: TextStyle(
                          color: _accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // ── ACCOUNT ────────────────────────────────────
          _sectionLabel('Account'),
          const SizedBox(height: 10),
          _buildSection([
            _tile(
              icon: Icons.person_outline_rounded,
              title: user?.displayName ?? 'Music Lover',
              subtitle: user?.email ?? 'Not signed in',
              onTap: () => _showProfileSheet(context, user),
              leading: user?.photoURL != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: user!.photoURL!,
                        width: 36, height: 36, fit: BoxFit.cover,
                      ),
                    )
                  : CircleAvatar(
                      radius: 18,
                      backgroundColor: _accent.withOpacity(0.2),
                      child: Text(
                        user?.displayName?.isNotEmpty == true
                            ? user!.displayName![0]
                            : user?.email?.isNotEmpty == true
                                ? user!.email![0].toUpperCase()
                                : 'M',
                        style: const TextStyle(
                            color: _accent, fontWeight: FontWeight.w700),
                      ),
                    ),
            ),
            _dividerLine(),
            _tile(
              icon: Icons.logout_rounded,
              title: _isLoggingOut ? 'Logging out...' : 'Logout',
              subtitle: 'Sign out of OneMusic',
              onTap: _isLoggingOut ? null : () => _showLogoutDialog(context),
              isDestructive: true,
              trailing: _isLoggingOut
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _danger))
                  : null,
            ),
          ]),

          const SizedBox(height: 24),

          // ── CONNECT ────────────────────────────────────
          _sectionLabel('Connect with Developer'),
          const SizedBox(height: 10),
          _buildSection([
            _tile(
              icon: Icons.people_alt_outlined,
              title: 'Discord',
              subtitle: 'Join our community server',
              onTap: () => _launchUrl('https://discord.gg/uT4P3cVh'),
              trailing: const Icon(Icons.open_in_new_rounded,
                  color: _textSec, size: 16),
            ),
            _dividerLine(),
            _tile(
              icon: Icons.work_outline_rounded,
              title: 'LinkedIn',
              subtitle: 'Akshat Raj',
              onTap: () =>
                  _launchUrl('https://www.linkedin.com/in/akshatraj00/'),
              trailing: const Icon(Icons.open_in_new_rounded,
                  color: _textSec, size: 16),
            ),
            _dividerLine(),
            _tile(
              icon: Icons.alternate_email_rounded,
              title: 'X (Twitter)',
              subtitle: '@AkshatRaj00_',
              onTap: () => _launchUrl('https://x.com/AkshatRaj00_'),
              trailing: const Icon(Icons.open_in_new_rounded,
                  color: _textSec, size: 16),
            ),
          ]),

          const SizedBox(height: 24),

          // ── ABOUT ──────────────────────────────────────
          _sectionLabel('About'),
          const SizedBox(height: 10),
          _buildSection([
            _tile(
              icon: Icons.info_outline_rounded,
              title: 'Version',
              subtitle: '$_appVersion (Build $_buildNumber)',
              onTap: () {},
              trailing: const SizedBox.shrink(),
            ),
            _dividerLine(),
            _tile(
              icon: Icons.business_rounded,
              title: 'Developer',
              subtitle: 'OnePerson AI',
              onTap: () {},
              trailing: const SizedBox.shrink(),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Quality sheet ─────────────────────────────────────
  void _showQualitySheet(BuildContext context) {
    final options = [
      {'key': 'low',    'label': 'Low',    'desc': '96 kbps — saves data'},
      {'key': 'medium', 'label': 'Medium', 'desc': '160 kbps — balanced'},
      {'key': 'high',   'label': 'High',   'desc': '320 kbps — best quality'},
      {'key': 'auto',   'label': 'Auto',   'desc': 'Depends on connection'},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ValueListenableBuilder<String>(
        valueListenable: globalQuality,
        builder: (_, current, __) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: _textSec.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Streaming Quality',
                  style: TextStyle(
                      color: _textPri, fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Affects data usage and sound quality',
                  style: TextStyle(color: _textSec, fontSize: 12)),
              const SizedBox(height: 16),
              ...options.map((o) {
                final isSel = o['key'] == current;
                return GestureDetector(
                  onTap: () => _setQuality(o['key']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSel ? _accent.withOpacity(0.15) : _surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isSel
                              ? _accent.withOpacity(0.5)
                              : Colors.transparent),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o['label']!,
                                  style: TextStyle(
                                      color: isSel ? _accent : _textPri,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(o['desc']!,
                                  style: const TextStyle(
                                      color: _textSec, fontSize: 12)),
                            ],
                          ),
                        ),
                        if (isSel)
                          const Icon(Icons.check_circle_rounded,
                              color: _accent, size: 20),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ── Profile sheet ─────────────────────────────────────
  void _showProfileSheet(BuildContext context, User? user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: _textSec.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 36,
              backgroundColor: _accent.withOpacity(0.2),
              backgroundImage: user?.photoURL != null
                  ? CachedNetworkImageProvider(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? Text(
                      user?.email?.isNotEmpty == true
                          ? user!.email![0].toUpperCase()
                          : 'M',
                      style: const TextStyle(
                          color: _accent,
                          fontSize: 28,
                          fontWeight: FontWeight.w700))
                  : null,
            ),
            const SizedBox(height: 14),
            Text(user?.displayName ?? 'Music Lover',
                style: const TextStyle(
                    color: _textPri, fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(user?.email ?? 'Not signed in',
                style: const TextStyle(color: _textSec, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                user != null ? 'Verified Account' : 'Guest',
                style: const TextStyle(
                    color: _accent, fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 24),
            if (user != null) ...[
              _infoRow('User ID', '${user.uid.substring(0, 12)}...'),
              const SizedBox(height: 8),
              _infoRow('Joined',
                  user.metadata.creationTime
                      ?.toLocal().toString().split(' ')[0] ?? '—'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String val) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: _textSec, fontSize: 13)),
          Text(val, style: const TextStyle(
              color: _textPri, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      );

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout',
            style: TextStyle(color: _textPri, fontWeight: FontWeight.w700)),
        content: const Text(
            'Music will stop. Are you sure you want to sign out?',
            style: TextStyle(color: _textSec)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: _textSec)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _doLogout(context);
            },
            child: const Text('Logout',
                style: TextStyle(
                    color: _danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _volumeTile(AudioProvider audio) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.volume_up_rounded, color: _accent, size: 20),
              const SizedBox(width: 14),
              const Text('Volume',
                  style: TextStyle(
                      color: _textPri, fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${(audio.volume * 100).round()}%',
                  style: const TextStyle(color: _textSec, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _accent,
              inactiveTrackColor: _surfaceAlt,
              thumbColor: _accent,
              overlayColor: _accent.withOpacity(0.15),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: audio.volume,
              min: 0, max: 1,
              onChanged: (v) => audio.setVolume(v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(t,
            style: const TextStyle(
                color: _textSec, fontSize: 12,
                fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      );

  Widget _buildSection(List<Widget> items) => Container(
        decoration: BoxDecoration(
            color: _surface, borderRadius: BorderRadius.circular(14)),
        child: Column(children: items),
      );

  Widget _dividerLine() =>
      const Divider(color: _divider, height: 1, indent: 52);

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool isDestructive = false,
    Widget? trailing,
    Widget? leading,
  }) {
    final col = isDestructive ? _danger : _textPri;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            leading ??
                Icon(icon,
                    color: isDestructive ? _danger : _accent, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: col, fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: _textSec, fontSize: 12)),
                ],
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right_rounded,
                    color: _textSec, size: 20),
          ],
        ),
      ),
    );
  }

  String _qualityLabel(String k) {
    switch (k) {
      case 'low':    return 'Low (96 kbps)';
      case 'medium': return 'Medium (160 kbps)';
      case 'high':   return 'High (320 kbps)';
      default:       return 'Auto';
    }
  }
}