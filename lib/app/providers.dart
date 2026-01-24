import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/habit_repository_supabase.dart';
import '../domain/repositories/habit_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return HabitRepositorySupabase(client);
});

/// Stream de sessao do Supabase.
/// Importante: isso muda quando voce faz login/logout e nos permite resetar estado do app.
final authSessionProvider = StreamProvider<Session?>((ref) async* {
  final auth = Supabase.instance.client.auth;
  yield auth.currentSession;
  await for (final event in auth.onAuthStateChange) {
    yield event.session;
  }
});

/// Sessao atual (null se deslogado)
final sessionProvider = Provider<Session?>((ref) {
  return ref.watch(authSessionProvider).value;
});

/// userId atual (null se deslogado)
final userIdProvider = Provider<String?>((ref) {
  return ref.watch(sessionProvider)?.user.id;
});

final authUserIdProvider = Provider<String?>((ref) {
  final session = ref.watch(authSessionProvider).value;
  return session?.user.id;
});

final authUserEmailProvider = Provider<String?>((ref) {
  final session = ref.watch(authSessionProvider).value;
  return session?.user.email;
});
