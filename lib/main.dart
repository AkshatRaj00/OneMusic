import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';

import 'firebase_options.dart';
import 'models/song_model.dart';
import 'providers/theme_provider.dart';
import 'providers/audio_provider.dart';
import 'services/audio_handler.dart';
import 'screens/splash_screen.dart';
import 'screens/settings_screen.dart';

late OneMusicAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // ✅ Black screen fix

  HttpOverrides.global = _IPv4Override();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor:                    Colors.transparent,
      statusBarIconBrightness:           Brightness.light,
      systemNavigationBarColor:          Color(0xFF141414),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  audioHandler = await AudioService.init(
    builder: () => OneMusicAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId:   'com.onepersonai.onemusic.audio',
      androidNotificationChannelName: 'OneMusic',
      androidNotificationIcon:        'mipmap/ic_launcher',
      androidNotificationOngoing:     false,
      androidStopForegroundOnPause:   true,
      notificationColor:              Color(0xFFFF6B35),
      androidShowNotificationBadge:   true,
      preloadArtwork:                 true,
    ),
  );

  await Hive.initFlutter();
  Hive.registerAdapter(SongModelAdapter());
  await Hive.openBox<SongModel>('recently_played');
  await Hive.openBox<SongModel>('liked_songs');
  await Hive.openBox('settings');

  runApp(const OneMusic());
}

class _IPv4Override extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..connectionTimeout = const Duration(seconds: 15);
  }
}

class OneMusic extends StatelessWidget {
  const OneMusic({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AudioProvider(audioHandler)),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'OneMusic',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.currentTheme.themeData,
            routes: {
              '/settings': (_) => const SettingsScreen(),
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}