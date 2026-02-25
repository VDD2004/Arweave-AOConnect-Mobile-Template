import 'package:flutter/material.dart';

import '../router.dart';
import 'nav_drawer.dart';

class AppPageShell extends StatelessWidget {
  const AppPageShell({
    super.key,
    required this.title,
    required this.currentRoute,
    required this.child,
    this.showAboutAction = true,
    this.showDrawer = true,
    this.showGlow = true,
  });

  final String title;
  final String currentRoute;
  final Widget child;
  final bool showAboutAction;
  final bool showDrawer;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (showAboutAction && currentRoute != AppRoutes.about)
            IconButton(
              tooltip: 'About',
              onPressed: () => Navigator.pushNamed(context, AppRoutes.about),
              icon: const Icon(Icons.info_outline),
            ),
        ],
      ),
      drawer: showDrawer ? AppNavDrawer(currentRoute: currentRoute) : null,
      body: SafeArea(
        child: Stack(
          children: [
            if (showGlow)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.9, -0.9),
                        radius: 1.2,
                        colors: [
                          cs.primary.withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}