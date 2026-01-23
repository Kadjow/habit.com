import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import 'habit_repository_impl.dart';
import '../../domain/repositories/habit_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return HabitRepositoryImpl(db);
});
