import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ThemeMode _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.themeMode;
  }

  void _onChanged(ThemeMode? mode) {
    if (mode == null) return;
    setState(() => _selected = mode);
    widget.onThemeModeChanged(mode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ustawienia')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Motyw'),
            subtitle: Text('Wybierz preferowany motyw aplikacji'),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Systemowy'),
            value: ThemeMode.system,
            groupValue: _selected,
            onChanged: _onChanged,
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Jasny'),
            value: ThemeMode.light,
            groupValue: _selected,
            onChanged: _onChanged,
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Ciemny'),
            value: ThemeMode.dark,
            groupValue: _selected,
            onChanged: _onChanged,
          ),
        ],
      ),
    );
  }
}
