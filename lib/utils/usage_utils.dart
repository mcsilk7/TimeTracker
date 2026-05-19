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

(DateTime start, DateTime end) getDateRange(TimeFilter filter) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  return switch (filter) {
    // For a single-day filter we want to cover the full day (00:00 - 24:00)
    // so continuous sessions that span the midnight boundary are counted
    // within that day's interval.
    TimeFilter.dzis => (today, today.add(const Duration(days: 1))),
    TimeFilter.wczoraj => (today.subtract(const Duration(days: 1)), today),
    TimeFilter.tydzien => (now.subtract(const Duration(days: 7)), now),
    TimeFilter.miesiac => (now.subtract(const Duration(days: 30)), now),
    TimeFilter.rok => (now.subtract(const Duration(days: 90)), now),
    TimeFilter.calyCzas => (now.subtract(const Duration(days: 90)), now),
  };
}

// ---------------------------------------------------------------------------
// Filtrowanie aplikacji systemowych
// ---------------------------------------------------------------------------

const _systemAppWhitelist = {
  'com.google.android.youtube',
  'com.android.chrome',
  'com.facebook.katana',
  'com.google.android.apps.maps',
  'com.google.android.gm',
  'com.google.android.apps.photos',
};

const _blockedPrefixes = [
  'com.android.',
  'android.',
  'com.google.android.providers',
  'com.google.android.inputmethod',
];

bool isSystemService(String packageName) {
  if (packageName == 'android') return true;
  return _blockedPrefixes.any((p) => packageName.startsWith(p));
}

bool isWhitelisted(String packageName) =>
    _systemAppWhitelist.contains(packageName);

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
      if (app.packageName != null && app.packageName!.isNotEmpty)
        app.packageName!: app,
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
    if (isSystemService(info.packageName)) continue;

    aggregated[info.packageName] =
        (aggregated[info.packageName] ?? Duration.zero) + info.usage;
  }

  final List<Map<String, dynamic>> result = [];
  Duration totalTime = Duration.zero;

  for (final entry in aggregated.entries) {
    final packageName = entry.key;
    final usage = entry.value;
    final AppInfo? cachedApp = appsCache[packageName];

    // Pomijaj systemowe niewhitelistowane
    if (cachedApp != null &&
        cachedApp.isSystemApp == true &&
        !isWhitelisted(packageName)) {
      continue;
    }

    totalTime += usage;

    result.add({
      'packageName': packageName,
      'prettyName': cachedApp?.name ?? packageName.split('.').last,
      'usage': usage,
      'icon': cachedApp?.icon,
    });
  }

  result.sort(
    (a, b) => (b['usage'] as Duration).inSeconds.compareTo(
          (a['usage'] as Duration).inSeconds,
        ),
  );

  return (apps: result, totalTime: totalTime);
}
