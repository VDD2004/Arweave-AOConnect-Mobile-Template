import 'package:flutter/material.dart';

import 'router.dart';

class ArweaveAOMobileApp extends StatelessWidget {
  const ArweaveAOMobileApp({super.key, this.builder});

  final TransitionBuilder? builder;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF7C4DFF); // deep purple accent
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Arweave & AOConnect, on Mobile',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFF0B0F14),
        cardTheme: CardThemeData(
          color: const Color(0xFF101826),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B0F14),
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0F1724),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
      builder: (context, child) {
        final resolvedChild = child ?? const SizedBox.shrink();
        if (builder != null) return builder!(context, resolvedChild);
        return resolvedChild;
      },
    );
  }
}