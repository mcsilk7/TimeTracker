import 'package:app_usage/app_usage.dart';
import 'package:flutter/material.dart';

import '../utils/usage_utils.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class _DayUsage {
  const _DayUsage({required this.label, required this.duration, required this.isToday});

  final String label;
  final Duration duration;
  final bool isToday;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class WeeklyActivityScreen extends StatefulWidget {
  const WeeklyActivityScreen({super.key});

  @override
  State<WeeklyActivityScreen> createState() => _WeeklyActivityScreenState();
}

class _WeeklyActivityScreenState extends State<WeeklyActivityScreen>
    with SingleTickerProviderStateMixin {
  final List<_DayUsage> _week = [];
  bool _isLoading = true;
  late AnimationController _animCtrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _loadWeeklyUsage();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWeeklyUsage() async {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final startOfWeek = startOfToday.subtract(Duration(days: today.weekday - 1));
    final appUsage = AppUsage();
    final appsCache = await buildAppsCache();
    final List<_DayUsage> week = [];

    for (int offset = 0; offset < 7; offset++) {
      final dayStart = startOfWeek.add(Duration(days: offset));
      final dayEnd = dayStart.add(const Duration(days: 1));
      final isToday = dayStart == startOfToday;

      try {
        final infos = await appUsage.getAppUsage(dayStart, dayEnd);
        Duration total = Duration.zero;
        for (final info in infos) {
          if (info.usage.inSeconds < 10) continue;
          if (!appsCache.containsKey(info.packageName)) continue;
          total += info.usage;
        }
        week.add(_DayUsage(
          label: _weekdayLabel(dayStart.weekday),
          duration: total,
          isToday: isToday,
        ));
      } catch (_) {
        week.add(_DayUsage(
          label: _weekdayLabel(dayStart.weekday),
          duration: Duration.zero,
          isToday: isToday,
        ));
      }
    }

    if (mounted) {
      setState(() {
        _week
          ..clear()
          ..addAll(week);
        _isLoading = false;
      });
      _animCtrl.forward();
    }
  }

  static String _weekdayLabel(int weekday) {
    const labels = ['Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'Sb', 'Nd'];
    return labels[(weekday - 1) % 7];
  }

  // ── Statystyki pochodne ──────────────────────────────────────────────────

  Duration get _totalTime =>
      _week.fold(Duration.zero, (s, d) => s + d.duration);

  Duration get _avgTime {
    final nonZero = _week.where((d) => d.duration > Duration.zero).toList();
    if (nonZero.isEmpty) return Duration.zero;
    return Duration(
        seconds: nonZero
                .fold<int>(0, (s, d) => s + d.duration.inSeconds) ~/
            nonZero.length);
  }

  _DayUsage get _peakDay => _week.reduce(
      (a, b) => a.duration.inSeconds >= b.duration.inSeconds ? a : b);

  // ────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Aktywność tygodniowa'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedBuilder(
              animation: _anim,
              builder: (context, _) => _Body(
                week: _week,
                anim: _anim.value,
                totalTime: _totalTime,
                avgTime: _avgTime,
                peakDay: _peakDay,
                isDark: isDark,
                primary: primary,
                theme: theme,
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body (stateless dla czystości)
// ---------------------------------------------------------------------------

class _Body extends StatelessWidget {
  const _Body({
    required this.week,
    required this.anim,
    required this.totalTime,
    required this.avgTime,
    required this.peakDay,
    required this.isDark,
    required this.primary,
    required this.theme,
  });

  final List<_DayUsage> week;
  final double anim;
  final Duration totalTime;
  final Duration avgTime;
  final _DayUsage peakDay;
  final bool isDark;
  final Color primary;
  final ThemeData theme;

  int get _maxSeconds =>
      week.fold<int>(1, (m, d) => d.duration.inSeconds > m ? d.duration.inSeconds : m);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        // ── Karta z wykresem ─────────────────────────────────────────────
        _ChartCard(
          week: week,
          anim: anim,
          maxSeconds: _maxSeconds,
          isDark: isDark,
          primary: primary,
          theme: theme,
        ),

        const SizedBox(height: 16),

        // ── Trzy statystyki w rzędzie ─────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Łącznie',
                value: formatDuration(totalTime),
                icon: Icons.timer_outlined,
                color: primary,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Średnio / dzień',
                value: formatDuration(avgTime),
                icon: Icons.show_chart,
                color: Colors.teal,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Rekord dnia',
                value: peakDay.label,
                sublabel: formatDuration(peakDay.duration),
                icon: Icons.emoji_events_outlined,
                color: const Color(0xFFFFB300),
                isDark: isDark,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Pasek dziennego postępu ───────────────────────────────────────
        _DailyProgressSection(
          week: week,
          maxSeconds: _maxSeconds,
          anim: anim,
          primary: primary,
          theme: theme,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Karta z wykresem słupkowym
// ---------------------------------------------------------------------------

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.week,
    required this.anim,
    required this.maxSeconds,
    required this.isDark,
    required this.primary,
    required this.theme,
  });

  final List<_DayUsage> week;
  final double anim;
  final int maxSeconds;
  final bool isDark;
  final Color primary;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Ostatnie 7 dni',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: week.map((day) {
                  final ratio = maxSeconds == 0
                      ? 0.0
                      : day.duration.inSeconds / maxSeconds;
                  final barHeight = (ratio * 120 * anim).clamp(4.0, 120.0);

                  final barColor = day.isToday
                      ? primary
                      : day.duration == Duration.zero
                          ? theme.colorScheme.surfaceContainerHighest
                          : primary.withValues(alpha: 0.45 + ratio * 0.4);

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Czas nad słupkiem
                          if (day.duration > Duration.zero)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                _compact(day.duration),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: day.isToday
                                      ? primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          // Słupek
                          AnimatedContainer(
                            duration: Duration.zero,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: day.isToday
                                  ? [
                                      BoxShadow(
                                        color: primary.withValues(alpha: 0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Etykieta dnia
                          Text(
                            day.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: day.isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: day.isToday
                                  ? primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          // Kropka „dziś"
                          const SizedBox(height: 3),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: day.isToday
                                  ? primary
                                  : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Np. 1h 23m → "1h23" albo 45m → "45m"
  String _compact(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h${(d.inMinutes % 60).toString().padLeft(2, '0')}';
    return '${d.inMinutes}m';
  }
}

// ---------------------------------------------------------------------------
// Karta statystyki
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
    this.sublabel,
  });

  final String label;
  final String value;
  final String? sublabel;
  final IconData icon;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 15,
              ),
            ),
            if (sublabel != null)
              Text(
                sublabel!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sekcja z poziomymi paskami postępu per dzień
// ---------------------------------------------------------------------------

class _DailyProgressSection extends StatelessWidget {
  const _DailyProgressSection({
    required this.week,
    required this.maxSeconds,
    required this.anim,
    required this.primary,
    required this.theme,
  });

  final List<_DayUsage> week;
  final int maxSeconds;
  final double anim;
  final Color primary;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.view_list_rounded,
                    color: theme.colorScheme.onSurfaceVariant, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Szczegóły dni',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...week.map((day) {
              final ratio = maxSeconds == 0
                  ? 0.0
                  : day.duration.inSeconds / maxSeconds;
              return _DayRow(
                day: day,
                ratio: ratio * anim,
                primary: primary,
                theme: theme,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.ratio,
    required this.primary,
    required this.theme,
  });

  final _DayUsage day;
  final double ratio;
  final Color primary;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final barColor = day.isToday ? primary : primary.withValues(alpha: 0.5);
    final emptyColor = theme.colorScheme.surfaceContainerHighest;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Etykieta dnia
          SizedBox(
            width: 28,
            child: Text(
              day.label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight:
                    day.isToday ? FontWeight.bold : FontWeight.normal,
                color: day.isToday
                    ? primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Pasek
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  // Tło
                  Container(height: 8, color: emptyColor),
                  // Wypełnienie
                  FractionallySizedBox(
                    widthFactor: ratio.clamp(0.0, 1.0),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Czas
          SizedBox(
            width: 60,
            child: Text(
              day.duration == Duration.zero
                  ? '—'
                  : formatDuration(day.duration),
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: day.isToday
                    ? primary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}