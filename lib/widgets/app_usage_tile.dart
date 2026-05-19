import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../utils/usage_utils.dart';

class AppUsageTile extends StatelessWidget {
  const AppUsageTile({super.key, required this.app});

  final Map<String, dynamic> app;

  @override
  Widget build(BuildContext context) {
    final Uint8List? iconBytes = app['icon'];
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: iconBytes != null && iconBytes.isNotEmpty
            ? Image.memory(iconBytes, width: 40, height: 40, fit: BoxFit.contain)
            : CircleAvatar(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.android,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
        title: Text(
          app['prettyName'] as String,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          app['packageName'] as String,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
        trailing: Text(
          formatDuration(app['usage'] as Duration),
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
