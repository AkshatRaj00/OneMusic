import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';

class MoodSelector extends StatelessWidget {
  const MoodSelector({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context:          context,
      backgroundColor:  Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const MoodSelector(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tp    = context.watch<ThemeProvider>();
    final theme = tp.currentTheme;

    return Container(
      decoration: BoxDecoration(
        color:        theme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border:       Border.all(color: theme.cardBorder),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: theme.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          Text('Choose Your Mood',
            style: TextStyle(
              color:      theme.textPrimary,
              fontSize:   20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text('Theme changes everything',
            style: TextStyle(color: theme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // 2x2 Grid
          GridView.count(
            crossAxisCount:   2,
            shrinkWrap:       true,
            physics:          const NeverScrollableScrollPhysics(),
            mainAxisSpacing:  12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: AppThemeMode.values.map((mode) {
              final t       = AppTheme(mode);
              final isActive = tp.isActive(mode);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  tp.setTheme(mode);
                  Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve:    Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? t.accentGradient
                        : LinearGradient(colors: [t.surface, t.surfaceAlt]),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isActive ? t.accent : t.cardBorder,
                      width: isActive ? 2 : 1,
                    ),
                    boxShadow: isActive ? t.glowShadow : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(t.emoji, style: const TextStyle(fontSize: 32)),
                      const SizedBox(height: 6),
                      Text(t.displayName,
                        style: TextStyle(
                          color:      isActive ? Colors.white : t.textPrimary,
                          fontSize:   16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(t.vibe,
                        style: TextStyle(
                          color:    isActive
                              ? Colors.white70
                              : t.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}