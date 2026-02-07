import 'package:flutter/material.dart';

import '../features/auth/auth_gate.dart';
import '../ui/theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'habit_ai',
      theme: AppTheme.light(),
      home: const AuthGate(),
    );
  }
}
