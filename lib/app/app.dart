import 'package:flutter/material.dart';

import '../features/auth/auth_gate.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'habit_ai',
      theme: ThemeData(useMaterial3: true),
      home: const AuthGate(),
    );
  }
}
