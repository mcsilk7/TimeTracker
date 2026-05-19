import 'package:app_usage/app_usage.dart';
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import '../models/time_filter.dart';
import '../utils/usage_utils.dart';
import '../widgets/app_usage_tile.dart';
import 'settings_screen.dart';
import 'achievements_screen.dart';
import 'weekly_activity_screen.dart';
import '../widgets/filter_dropdown.dart';
import '../widgets/total_time_card.dart';

class AppUsageScreen extends StatefulWidget {
  const AppUsageScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<AppUsageScreen> createState() => _AppUsageScreenState();
}

class _AppUsageScreenState extends State<AppUsageScreen> {
  List<Map<String, dynamic>> _displayApps = [];
  Duration _totalTime = Duration.zero;
  bool _isLoading = false;

  final AppUsage _appUsage = AppUsage();
  TimeFilter _selectedFilter = TimeFilter.dzis;
  Map<String, AppInfo>? _appsCache;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      _appsCache ??= await buildAppsCache();

      final result = await fetchUsageStats(
        filter: _selectedFilter,
        appUsage: _appUsage,
        appsCache: _appsCache!,
      );

      if (!mounted) return;
      setState(() {
        _displayApps = result.apps;
        _totalTime = result.totalTime;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Błąd pobierania statystyk: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wymagane uprawnienia'),
        content: const Text(
          'Ta aplikacja potrzebuje dostępu do statystyk użytkowania. '
          'Włącz uprawnienie "Dostęp do danych użytkowania" w Ustawieniach.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _onFilterChanged(TimeFilter newFilter) {
    setState(() => _selectedFilter = newFilter);
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Odśwież',
            onPressed: _loadStats,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Ustawienia',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    themeMode: widget.themeMode,
                    onThemeModeChanged: widget.onThemeModeChanged,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).appBarTheme.backgroundColor,
            child: Wrap(
              runSpacing: 8,
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width > 560 ? 320 : MediaQuery.of(context).size.width - 160,
                  child: FilterDropdown(
                    selected: _selectedFilter,
                    onChanged: _onFilterChanged,
                  ),
                ),
                SizedBox(
                  height: 44,
                  width: 56,
                  child: Tooltip(
                    message: 'Wykres',
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WeeklyActivityScreen(),
                          ),
                        );
                      },
                      child: const Icon(Icons.show_chart, size: 22),
                    ),
                  ),
                ),
                SizedBox(
                  height: 44,
                  width: 56,
                  child: Tooltip(
                    message: 'Osiągnięcia',
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AchievementsScreen(),
                          ),
                        );
                      },
                      child: const Icon(Icons.emoji_events, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _displayApps.isEmpty
                    ? Center(
                        child: Text(
                          'Brak danych dla wybranego okresu.',
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                      )
                    : Column(
                        children: [
                          TotalTimeCard(
                            totalTime: _totalTime,
                            filterLabel: _selectedFilter.label,
                            isDark: widget.themeMode == ThemeMode.dark,
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _displayApps.length,
                              itemBuilder: (context, index) =>
                                  AppUsageTile(app: _displayApps[index]),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
