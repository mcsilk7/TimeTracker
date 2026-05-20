import 'package:flutter/material.dart';

class DarkModeSwitch extends StatelessWidget {
  const DarkModeSwitch({
    super.key,
    required this.isDark,
    required this.onChanged,
  });

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
          activeThumbColor: Colors.blueAccent,
          activeTrackColor: Colors.blueAccent.withValues(alpha: 0.4),
          inactiveThumbColor: Colors.orange,
          inactiveTrackColor: Colors.orange.withValues(alpha: 0.3),
        ),
      ],
    );
  }
}
