import 'package:flutter/material.dart';
import '../models/time_filter.dart';

class FilterDropdown extends StatelessWidget {
  const FilterDropdown({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final TimeFilter selected;
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
                f.label,
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
