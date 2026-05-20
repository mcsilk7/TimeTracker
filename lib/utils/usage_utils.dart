import 'dart:typed_data';

import 'package:app_usage/app_usage.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import '../models/time_filter.dart';

// ---------------------------------------------------------------------------
// Formatowanie czasu
// ---------------------------------------------------------------------------

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  return '${hours}h ${minutes}m';
}

// ---------------------------------------------------------------------------
// Zakres dat dla filtra
// ---------------------------------------------------------------------------

DateTime _startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

(DateTime start, DateTime end) getDateRange(TimeFilter filter) {
  final now = DateTime.now();
  final today = _startOfDay(now);

  return switch (filter) {
    // For a single-day filter we want to cover the full day (00:00 - 24:00)
    // so continuous sessions that span the midnight boundary are counted
    // within that day's interval.
    TimeFilter.dzis => (today, today.add(const Duration(days: 1))),
    TimeFilter.wczoraj => (today.subtract(const Duration(days: 1)), today),
    // For weekly summaries use full calendar days to avoid partial-day
    // intervals and keep the data aligned to midnight boundaries.
    TimeFilter.tydzien => (today.subtract(const Duration(days: 6)), today.add(const Duration(days: 1))),
    TimeFilter.miesiac => (now.subtract(const Duration(days: 30)), now),
    TimeFilter.rok => (now.subtract(const Duration(days: 90)), now),
    TimeFilter.calyCzas => (now.subtract(const Duration(days: 90)), now),
  };
}

// ---------------------------------------------------------------------------
// Filtrowanie aplikacji systemowych
// ---------------------------------------------------------------------------

bool _hasIcon(AppInfo app) {
  final icon = app.icon;
  return icon is Uint8List && icon.isNotEmpty;
}

// ---------------------------------------------------------------------------
// Cache zainstalowanych aplikacji
// ---------------------------------------------------------------------------

Future<Map<String, AppInfo>> buildAppsCache() async {
  final List<AppInfo> apps = await InstalledApps.getInstalledApps(
    excludeSystemApps: false,
    withIcon: true,
  );
  return {
    for (final app in apps)
      if (app.packageName.isNotEmpty && _hasIcon(app)) app.packageName: app,
  };
}

// ---------------------------------------------------------------------------
// Pobieranie i agregacja statystyk
// ---------------------------------------------------------------------------

Future<({List<Map<String, dynamic>> apps, Duration totalTime})>
    fetchUsageStats({
  required TimeFilter filter,
  required AppUsage appUsage,
  required Map<String, AppInfo> appsCache,
}) async {
  final (startDate, endDate) = getDateRange(filter);

  final List<AppUsageInfo> infoList = await appUsage.getAppUsage(
    startDate,
    endDate,
  );

  // Agregacja po packageName (może być wiele wpisów dla jednej apki)
  final Map<String, Duration> aggregated = {};
  for (final info in infoList) {
    if (info.usage.inSeconds < 10) continue;

    aggregated.update(
      info.packageName,
      (existing) => existing + info.usage,
      ifAbsent: () => info.usage,
    );
  }

  final List<Map<String, dynamic>> result = [];
  Duration totalTime = Duration.zero;

  for (final entry in aggregated.entries) {
    final packageName = entry.key;
    final usage = entry.value;
    final AppInfo? cachedApp = appsCache[packageName];

    // Pomijaj aplikacje, dla których nie mamy ikony.
    if (cachedApp == null) continue;

    totalTime += usage;

    result.add({
      'packageName': packageName,
      'prettyName': cachedApp.name ?? packageName.split('.').last,
      'usage': usage,
      'icon': cachedApp.icon,
    });
  }

  result.sort(
    (a, b) => (b['usage'] as Duration).inSeconds.compareTo(
          (a['usage'] as Duration).inSeconds,
        ),
  );

  return (apps: result, totalTime: totalTime);
}
