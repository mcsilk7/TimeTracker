import 'package:flutter/material.dart';
import 'package:app_usage/app_usage.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'dart:typed_data';

enum TimeFilter { dzis, wczoraj, tydzien, miesiac, rok, calyCzas }

// ---------------------------------------------------------------------------
// Główna aplikacja z obsługą Dark Mode
// ---------------------------------------------------------------------------

class AppUsageApp extends StatefulWidget {
  const AppUsageApp({super.key});

  @override
  State<AppUsageApp> createState() => _AppUsageAppState();
}

class _AppUsageAppState extends State<AppUsageApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Czas przed ekranem',
      debugShowCheckedModeBanner: false,

      // ── Light Theme ──
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Colors.blueAccent,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0.5,
        ),
        cardTheme: CardThemeData(
          // ← CardTheme → CardThemeData
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // ── Dark Theme ──
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blueAccent,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0.5,
        ),
        cardTheme: CardThemeData(
          // ← CardTheme → CardThemeData
          color: const Color(0xFF1E1E1E),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      themeMode: _themeMode,

      home: AppUsageScreen(
        isDarkMode: _themeMode == ThemeMode.dark,
        onThemeToggle: _toggleTheme,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ekran statystyk użytkowania
// ---------------------------------------------------------------------------

class AppUsageScreen extends StatefulWidget {
  const AppUsageScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onThemeToggle;

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
    _getUsageStats();
  }

  (DateTime start, DateTime end) _getDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return switch (_selectedFilter) {
      TimeFilter.dzis => (today, now),
      TimeFilter.wczoraj => (today.subtract(const Duration(days: 1)), today),
      TimeFilter.tydzien => (now.subtract(const Duration(days: 7)), now),
      TimeFilter.miesiac => (now.subtract(const Duration(days: 30)), now),
      TimeFilter.rok => (now.subtract(const Duration(days: 90)), now),
      TimeFilter.calyCzas => (now.subtract(const Duration(days: 90)), now),
    };
  }

  static const _systemAppWhitelist = {
    'com.google.android.youtube',
    'com.android.chrome',
    'com.facebook.katana',
    'com.google.android.apps.maps',
    'com.google.android.gm',
    'com.google.android.apps.photos',
  };

  static bool _isSystemService(String packageName) {
    const blockedPrefixes = [
      'com.android.',
      'android.',
      'com.google.android.providers',
      'com.google.android.inputmethod',
    ];
    if (packageName == 'android') return true;
    return blockedPrefixes.any((p) => packageName.startsWith(p));
  }

  Future<void> _getUsageStats() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      _appsCache ??= await _buildAppsCache();

      final (startDate, endDate) = _getDateRange();

      final List<AppUsageInfo> infoList = await _appUsage.getAppUsage(
        startDate,
        endDate,
      );

      final Map<String, Duration> aggregatedUsage = {};
      for (final info in infoList) {
        if (info.usage.inSeconds < 10) continue;
        if (_isSystemService(info.packageName)) continue;

        aggregatedUsage[info.packageName] =
            (aggregatedUsage[info.packageName] ?? Duration.zero) + info.usage;
      }

      final List<Map<String, dynamic>> temporaryList = [];
      Duration calculatedTotalTime = Duration.zero;

      for (final entry in aggregatedUsage.entries) {
        final packageName = entry.key;
        final usage = entry.value;

        final AppInfo? cachedApp = _appsCache![packageName];

        if (cachedApp != null &&
            cachedApp.isSystemApp == true &&
            !_systemAppWhitelist.contains(packageName)) {
          continue;
        }

        final String prettyName =
            cachedApp?.name ?? packageName.split('.').last;

        final Uint8List? iconBytes = cachedApp?.icon;

        calculatedTotalTime += usage;

        temporaryList.add({
          'packageName': packageName,
          'prettyName': prettyName,
          'usage': usage,
          'icon': iconBytes,
        });
      }

      temporaryList.sort(
        (a, b) => (b['usage'] as Duration).inSeconds.compareTo(
          (a['usage'] as Duration).inSeconds,
        ),
      );

      if (!mounted) return;
      setState(() {
        _displayApps = temporaryList;
        _totalTime = calculatedTotalTime;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Błąd pobierania statystyk: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showPermissionDialog();
    }
  }

  Future<Map<String, AppInfo>> _buildAppsCache() async {
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

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    return '${hours}h ${minutes}m';
  }

  String _getFilterName(TimeFilter filter) => switch (filter) {
    TimeFilter.dzis => 'Dziś',
    TimeFilter.wczoraj => 'Wczoraj',
    TimeFilter.tydzien => 'Ostatni tydzień',
    TimeFilter.miesiac => 'Ostatni miesiąc',
    TimeFilter.rok => 'Ostatni rok',
    TimeFilter.calyCzas => 'Cały czas',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Tracker'),
        actions: [
          // ── Dark Mode Switch ──
          _DarkModeSwitch(isDark: isDark, onChanged: widget.onThemeToggle),
          _FilterDropdown(
            selected: _selectedFilter,
            getFilterName: _getFilterName,
            onChanged: (newValue) {
              setState(() => _selectedFilter = newValue);
              _getUsageStats();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Odśwież',
            onPressed: _getUsageStats,
          ),
        ],
      ),
      body: _isLoading
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
                _TotalTimeCard(
                  totalTime: _totalTime,
                  filterName: _getFilterName(_selectedFilter),
                  formatDuration: _formatDuration,
                  isDark: isDark,
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _displayApps.length,
                    itemBuilder: (context, index) => _AppUsageTile(
                      app: _displayApps[index],
                      formatDuration: _formatDuration,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dark Mode Switch Widget
// ---------------------------------------------------------------------------

class _DarkModeSwitch extends StatelessWidget {
  const _DarkModeSwitch({required this.isDark, required this.onChanged});

  final bool isDark;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isDark ? Icons.dark_mode : Icons.light_mode,
          size: 20,
          color: isDark ? Colors.amber : Colors.orange,
        ),
        const SizedBox(width: 4),
        Switch(
          value: isDark,
          onChanged: onChanged,
          activeColor: Colors.blueAccent,
          activeTrackColor: Colors.blueAccent.withOpacity(0.4),
          inactiveThumbColor: Colors.orange,
          inactiveTrackColor: Colors.orange.withOpacity(0.3),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dropdown filtra czasu
// ---------------------------------------------------------------------------

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.selected,
    required this.getFilterName,
    required this.onChanged,
  });

  final TimeFilter selected;
  final String Function(TimeFilter) getFilterName;
  final ValueChanged<TimeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<TimeFilter>(
      value: selected,
      underline: const SizedBox(),
      icon: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      items: TimeFilter.values
          .map(
            (f) => DropdownMenuItem(
              value: f,
              child: Text(
                getFilterName(f),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Karta z łącznym czasem
// ---------------------------------------------------------------------------

class _TotalTimeCard extends StatelessWidget {
  const _TotalTimeCard({
    required this.totalTime,
    required this.filterName,
    required this.formatDuration,
    required this.isDark,
  });

  final Duration totalTime;
  final String filterName;
  final String Function(Duration) formatDuration;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A237E), const Color(0xFF283593)]
              : [Colors.blueAccent, Colors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.4)
                : Colors.blueAccent.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'CZAS ŁĄCZNIE: ${filterName.toUpperCase()}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatDuration(totalTime),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kafelek aplikacji
// ---------------------------------------------------------------------------

class _AppUsageTile extends StatelessWidget {
  const _AppUsageTile({required this.app, required this.formatDuration});

  final Map<String, dynamic> app;
  final String Function(Duration) formatDuration;

  @override
  Widget build(BuildContext context) {
    final Uint8List? iconBytes = app['icon'];
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: iconBytes != null && iconBytes.isNotEmpty
            ? Image.memory(
                iconBytes,
                width: 40,
                height: 40,
                fit: BoxFit.contain,
              )
            : CircleAvatar(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.android,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
        title: Text(
          app['prettyName'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          app['packageName'],
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
        trailing: Text(
          formatDuration(app['usage']),
          style: const TextStyle(
            fontSize: 15,
            color: Colors.blueAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
