import 'package:dejapoo/ui/routing/routing.dart';
import 'package:dejapoo/ui/theme/theme.dart';
import 'package:flutter/material.dart';

class DejaPooApp extends StatelessWidget {
  const DejaPooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DejaPoo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
    );
  }
}
