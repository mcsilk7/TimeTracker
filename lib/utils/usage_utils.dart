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
// Zakres dat dla filtra – wszystkie granice zawsze dokładnie o północy
// ---------------------------------------------------------------------------

/// Zwraca DateTime ustawiony na początek (00:00:00.000) podanego dnia.
DateTime _midnight(DateTime date) =>
    DateTime(date.year, date.month, date.day);
(DateTime start, DateTime end) getDateRange(TimeFilter filter) {
  final today = _midnight(DateTime.now());
  final tomorrow = today.add(const Duration(days: 1));

  return switch (filter) {
    // Dokładne zakresy czasowe - zawsze od 00:00 do 00:00 następnego dnia
    TimeFilter.dzis => (today, tomorrow),
    // dzis     → 2024-05-20 00:00 … 2024-05-21 00:00  (cały bieżący dzień)
    
    TimeFilter.wczoraj => (today.subtract(const Duration(days: 1)), today),
    // wczoraj  → 2024-05-19 00:00 … 2024-05-20 00:00  (cały poprzedni dzień)
    
    TimeFilter.tydzien => (today.subtract(const Duration(days: 7)), tomorrow),
    // ostatnie 7 pełnych dni
    
    TimeFilter.miesiac => (today.subtract(const Duration(days: 30)), tomorrow),
    // ostatnie 30 pełnych dni
    
    TimeFilter.rok => (today.subtract(const Duration(days: 365)), tomorrow),
    // ostatnie 365 pełnych dni
    
    TimeFilter.calyCzas => (today.subtract(const Duration(days: 365)), tomorrow),
    // cały dostępny czas (365 dni)
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