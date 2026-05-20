import 'dart:typed_data';

import 'package:app_usage/app_usage.dart';
import 'package:flutter/material.dart';

import '../models/time_filter.dart';
import '../utils/usage_utils.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class _Achievement {
  const _Achievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.value,
    required this.color,
  });

  final String title;
  final String description;
  final IconData icon;
  final String value;
  final Color color;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  /// Dane z okresu 90 dni – używane do statystyk / osiągnięć
  List<Map<String, dynamic>> _apps = [];
  Duration _totalTime = Duration.zero;

  /// Dane ALL-TIME – używane tylko do podium top 3
  List<Map<String, dynamic>> _allTimeApps = [];

  /// Statystyki dzienne z ostatniego tygodnia
  Duration _maxDailyTime = Duration.zero;
  Duration _minDailyTime = Duration.zero;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _loadDailyStats() async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));
    final appUsage = AppUsage();
    final appsCache = await buildAppsCache();

    Duration maxDaily = Duration.zero;
    Duration minDaily = Duration(days: 365);

    for (int offset = 0; offset < 7; offset++) {
      final dayStart = startOfWeek.add(Duration(days: offset));
      final dayEnd = dayStart.add(const Duration(days: 1));

      try {
        final infos = await appUsage.getAppUsage(dayStart, dayEnd);
        Duration dailyTotal = Duration.zero;
        for (final info in infos) {
          if (info.usage.inSeconds < 10) continue;
          if (!appsCache.containsKey(info.packageName)) continue;
          dailyTotal += info.usage;
        }

        // Max czas dzienia
        if (dailyTotal > maxDaily) maxDaily = dailyTotal;

        // Min czas dzienia (ale nie zero)
        if (dailyTotal > Duration.zero && dailyTotal < minDaily) {
          minDaily = dailyTotal;
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _maxDailyTime = maxDaily;
        _minDailyTime = minDaily == Duration(days: 365) ? Duration.zero : minDaily;
      });
    }
  }

  Future<void> _load() async {
    try {
      final cache = await buildAppsCache();
      final appUsage = AppUsage();

      // Ładujemy równolegle oba zakresy
      final results = await Future.wait([
        fetchUsageStats(
          filter: TimeFilter.calyCzas,
          appUsage: appUsage,
          appsCache: cache,
        ),
        fetchUsageStats(
          filter: TimeFilter.calyCzas, // <-- cały dostępny czas
          appUsage: appUsage,
          appsCache: cache,
        ),
      ]);

      if (mounted) {
        setState(() {
          _apps = results[0].apps;
          _totalTime = results[0].totalTime;
          _allTimeApps = results[1].apps;
          _isLoading = false;
        });
      }

      // Załaduj statystyki dzienne
      await _loadDailyStats();
    } catch (e) {
      debugPrint('Błąd osiągnięć: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<_Achievement> get _achievements {
    return [
      _Achievement(
        title: 'Rekord dnia',
        description: 'Maksymalny czas spędzony na telefonie w ciągu dnia',
        icon: Icons.trending_up,
        value: formatDuration(_maxDailyTime),
        color: Colors.greenAccent,
      ),
      if (_minDailyTime > Duration.zero)
        _Achievement(
          title: 'Najsłabszy dzień',
          description: 'Minimalny czas spędzony na telefonie w ciągu dnia',
          icon: Icons.trending_down,
          value: formatDuration(_minDailyTime),
          color: Colors.lightBlueAccent,
        ),
    ];
  }

  /// Podium zawsze bazuje na danych ALL-TIME
  List<Map<String, dynamic>> get _podiumApps => _allTimeApps.take(3).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Osiągnięcia')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _apps.isEmpty
              ? const Center(child: Text('Brak danych do wyświetlenia.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    // ── Podium top 3 ──────────────────────────────────────
                    if (_podiumApps.isNotEmpty) ...[
                      _SectionHeader(
                        icon: Icons.military_tech,
                        label: 'Najczęściej używane aplikacje (od zawsze)',
                      ),
                      const SizedBox(height: 12),
                      _PodiumCard(apps: _podiumApps),
                      const SizedBox(height: 24),
                    ],

                    // ── Pozostałe osiągnięcia ─────────────────────────────
                    _SectionHeader(
                      icon: Icons.emoji_events_outlined,
                      label: 'Statystyki',
                    ),
                    const SizedBox(height: 12),
                    ..._achievements.map((a) => _AchievementTile(a)),
                  ],
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Podium – trzy miejsca
// ---------------------------------------------------------------------------

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({required this.apps});

  final List<Map<String, dynamic>> apps;

  static const _medals = ['🥇', '🥈', '🥉'];
  static const _medalColors = [
    Color(0xFFFFD700),
    Color(0xFFC0C0C0),
    Color(0xFFCD7F32),
  ];
  static const _podiumHeights = [110.0, 80.0, 60.0];

  // Kolejność wyświetlania: 2, 1, 3 (klasyczne podium)
  List<int> get _order {
    if (apps.length == 1) return [0];
    if (apps.length == 2) return [1, 0];
    return [1, 0, 2];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          children: [
            // Avatary z medalami
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _order.map((i) {
                if (i >= apps.length) return const SizedBox();
                final app = apps[i];
                final height = _podiumHeights[i];
                final color = _medalColors[i];
                final medal = _medals[i];

                return Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(medal, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      _AppIcon(
                        app: app,
                        size: i == 0 ? 52 : 44,
                        borderColor: color,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        app['prettyName'] as String,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: i == 0 ? 13 : 12,
                          fontWeight:
                              i == 0 ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // ── Czas ALL-TIME ─────────────────────────────────
                      Text(
                        formatDuration(app['usage'] as Duration),
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Etykieta "od zawsze"
                      Text(
                        'łącznie',
                        style: TextStyle(
                          fontSize: 10,
                          color: color.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Słupek podium
                      Container(
                        height: height,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: isDark ? 0.25 : 0.18),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                          border: Border(
                            top: BorderSide(color: color, width: 2),
                            left: BorderSide(
                                color: color.withValues(alpha: 0.4), width: 1),
                            right: BorderSide(
                                color: color.withValues(alpha: 0.4), width: 1),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ikona aplikacji (awatar z obwódką)
// ---------------------------------------------------------------------------

class _AppIcon extends StatelessWidget {
  const _AppIcon(
      {required this.app, required this.size, required this.borderColor});

  final Map<String, dynamic> app;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final iconBytes = app['icon'] as dynamic;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2.5),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      padding: const EdgeInsets.all(4),
      child: iconBytes != null && (iconBytes as List).isNotEmpty
          ? ClipOval(
              child: Image.memory(
                iconBytes is Uint8List
                    ? iconBytes
                    : Uint8List.fromList(List<int>.from(iconBytes)),
                fit: BoxFit.contain,
              ),
            )
          : Icon(
              Icons.android,
              size: size * 0.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kafelek osiągnięcia
// ---------------------------------------------------------------------------

class _AchievementTile extends StatelessWidget {
  const _AchievementTile(this.achievement);

  final _Achievement achievement;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: achievement.color.withValues(alpha: 0.15),
          child: Icon(achievement.icon, color: achievement.color),
        ),
        title: Text(
          achievement.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(achievement.description),
        trailing: Text(
          achievement.value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: achievement.color,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nagłówek sekcji
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}