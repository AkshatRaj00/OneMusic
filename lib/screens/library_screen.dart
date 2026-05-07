import 'package:flutter/material.dart';

class LibraryScreen extends StatefulWidget {
  final dynamic theme;
  const LibraryScreen({super.key, required this.theme});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Column(
      children: [
        // Tab Bar
        Container(
          color: theme.background,
          child: TabBar(
            controller: _tabController,
            indicatorColor: theme.accent,
            indicatorWeight: 2,
            labelColor: theme.accent,
            unselectedLabelColor: theme.textMuted,
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Playlists'),
              Tab(text: 'Downloads'),
              Tab(text: 'Liked'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _PlaylistsTab(theme: theme),
              _DownloadsTab(theme: theme),
              _LikedTab(theme: theme),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlaylistsTab extends StatelessWidget {
  final dynamic theme;
  const _PlaylistsTab({required this.theme});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Create Playlist Button
        GestureDetector(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.accent.withOpacity(0.4),
                width: 1,
              ),
              gradient: LinearGradient(
                colors: [
                  theme.accent.withOpacity(0.08),
                  theme.accentSecondary.withOpacity(0.04),
                ],
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.add_circle_outline_rounded,
                    color: theme.accent, size: 26),
                const SizedBox(width: 12),
                Text(
                  'Create New Playlist',
                  style: TextStyle(
                    color: theme.accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Playlist items
        ...List.generate(4, (i) {
          final names = [
            'My Favourites', 'Late Night Vibes',
            'Workout', 'Punjabi Mix'
          ];
          final counts = ['24 songs', '12 songs', '18 songs', '31 songs'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: theme.cardGradient,
                  ),
                  child: Center(
                    child: Icon(Icons.queue_music_rounded,
                        color: Colors.white.withOpacity(0.8), size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(names[i],
                          style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      Text(counts[i],
                          style: TextStyle(
                              color: theme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.more_vert_rounded,
                    color: theme.textMuted, size: 20),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _DownloadsTab extends StatelessWidget {
  final dynamic theme;
  const _DownloadsTab({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.download_done_rounded,
              color: theme.accent, size: 56),
          const SizedBox(height: 16),
          Text('No downloads yet',
              style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Downloaded songs will appear here',
              style: TextStyle(
                  color: theme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _LikedTab extends StatelessWidget {
  final dynamic theme;
  const _LikedTab({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_rounded, color: theme.accent, size: 56),
          const SizedBox(height: 16),
          Text('No liked songs yet',
              style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Like songs to see them here',
              style: TextStyle(
                  color: theme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}