import 'package:flutter/material.dart';
import 'core/theme/arise_theme.dart';
import 'core/widgets/app_shell.dart';

void main() {
  runApp(const AriseApp());
}

/// A.R.I.S.E. 2.0 — Autonomous Runtime Intelligence & System Engine
class AriseApp extends StatelessWidget {
  const AriseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A.R.I.S.E. 2.0 — Command Console',
      debugShowCheckedModeBanner: false,
      theme: AriseTheme.darkTheme,
      home: const AppShell(),
    );
  }
}
