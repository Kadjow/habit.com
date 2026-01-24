import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://uxslsphasfuvglrsdmbr.supabase.co',
    anonKey: 'sb_publishable_Iv14A3_pJJb7tXl6zgJczg_9wCtwzcv',
  );

  runApp(const ProviderScope(child: App()));
}
