import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_ai/features/home/home_controller.dart';
import 'package:habit_ai/domain/models/habit.dart';
import 'package:habit_ai/features/home/habit_details_page.dart';
import 'test_app.dart';

void main() {
  testWidgets(
    'HabitDetailsPage renders without layout exceptions and accepts taps',
    (tester) async {
      // Seu Habit exige campos obrigatorios (pelo erro: createdAt, difficulty, isActive).
      // Ajuste aqui para o construtor REAL do seu Habit.
      // Pelo log, sabemos pelo menos esses 3 existem.
      final habit = Habit(
        id: 'h1',
        title: 'Atividade fisica!',
        createdAt: DateTime.now(),
        difficulty: 1,
        isActive: true,
      );

      final homeState = HomeState(
        habits: [habit],
        todayStatusByHabitId: const {'h1': 1},
        rhythm14DaysByHabitId: const {'h1': 0.5},
        checkinsByHabitId: const {'h1': {}},
      );

      await tester.pumpWidget(
        buildSmokeTestApp(
          homeState: homeState,
          home: HabitDetailsPage(habit: habit),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Dispara alguns taps
      final tiles = find.byType(InkWell);
      expect(tiles, findsWidgets);

      for (var i = 0; i < 6; i++) {
        await tester.tap(tiles.at(i));
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(tester.takeException(), isNull);
    },
  );
}
