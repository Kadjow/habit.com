import 'package:flutter/material.dart';

class HabitStatusChip extends StatelessWidget {
  const HabitStatusChip({super.key, required this.status});

  final int status; // 0 = none, 1 = done, 2 = partial/min

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      1 => 'Feito',
      2 => 'Mínimo',
      _ => 'Pendente',
    };

    final icon = switch (status) {
      1 => Icons.check_circle_outline,
      2 => Icons.bolt_outlined,
      _ => Icons.circle_outlined,
    };

    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
