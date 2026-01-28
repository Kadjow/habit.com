import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'test_app.dart';

import 'package:habit_ai/features/home/home_controller.dart';
import 'package:habit_ai/features/home/habit_details_page.dart';
import 'package:habit_ai/domain/models/habit.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    SharedPreferences.setMockInitialValues(<String, Object>{});

    // Evita: "You must initialize the supabase instance before calling Supabase.instance"
    // URL e key dummy (nao precisamos de rede).
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'anon-key',
    );
  });

  testWidgets('Smoke: Home -> Details (tap) sem exceptions/overflow', (tester) async {
    final habit = Habit(
      id: 'h1',
      title: 'Atividade fisica',
      difficulty: 1,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

    final homeState = HomeState(
      habits: <Habit>[habit],
      checkinsByHabitId: <String, Map<String, int>>{
        'h1': <String, int>{},
      },
      todayStatusByHabitId: <String, int>{
        'h1': 0,
      },
      rhythm14DaysByHabitId: <String, double>{
        'h1': 0.0,
      },
    );

    await tester.pumpWidget(
      buildSmokeTestApp(homeState: homeState),
    );

    // NAO usar pumpAndSettle (tem progress/anim e pode nunca "settle").
    await tester.pump(const Duration(milliseconds: 50));

    // Espera o item aparecer e navega.
    expect(find.text('Atividade fisica'), findsOneWidget);

    final habitTile = find.widgetWithText(InkWell, 'Atividade fisica');
    expect(habitTile, findsOneWidget);
    await tester.tap(habitTile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Detalhes devem abrir apos o tap.
    expect(find.byType(HabitDetailsPage), findsOneWidget);
  });
}
