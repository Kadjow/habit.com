import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/habit_repository_local.dart';
import '../domain/repositories/habit_repository.dart';

/// Instância de SharedPreferences. Sobrescrita no main() (bootstrap).
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider deve ser sobrescrito no main()');
});

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return LocalHabitRepository(ref.watch(sharedPreferencesProvider));
});

/// Usuário logado localmente (null = deslogado). Sem backend.
class LocalUser {
  const LocalUser({required this.id, required this.login});
  final String id;
  final String login;
}

/// Auth 100% local. Login fixo: admin / admin.
class AuthController extends StateNotifier<LocalUser?> {
  AuthController() : super(null);

  static const String login = 'admin';
  static const String password = 'admin';
  static const String _userId = 'local-admin';

  /// Retorna true se as credenciais batem.
  bool signIn(String user, String pass) {
    if (user.trim() == login && pass == password) {
      state = const LocalUser(id: _userId, login: login);
      return true;
    }
    return false;
  }

  void signOut() => state = null;
}

final authControllerProvider =
    StateNotifierProvider<AuthController, LocalUser?>((ref) => AuthController());

/// userId atual (null se deslogado). Recria HomeController no login/logout.
final userIdProvider = Provider<String?>((ref) {
  return ref.watch(authControllerProvider)?.id;
});

final authUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authControllerProvider)?.id;
});

final authUserEmailProvider = Provider<String?>((ref) {
  return ref.watch(authControllerProvider)?.login;
});
