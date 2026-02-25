import 'package:flutter/material.dart';

import '../router.dart';

class AppNavDrawer extends StatelessWidget {
  const AppNavDrawer({super.key, required this.currentRoute});

  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget item({
      required String route,
      required String label,
      required IconData icon,
    }) {
      final selected = currentRoute == route;
      return ListTile(
        selected: selected,
        leading: Icon(icon, color: selected ? cs.primary : null),
        title: Text(label),
        onTap: () {
          Navigator.pop(context);
          if (!selected) {
            Navigator.pushReplacementNamed(context, route);
          }
        },
      );
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      cs.primary.withValues(alpha: 0.22),
                      cs.secondary.withValues(alpha: 0.10),
                    ],
                  ),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Arweave + AOConnect', style: TextStyle(fontSize: 16)),
                    SizedBox(height: 4),
                    Text(
                      'Mobile Arweave Wallet Auth + AOConnect Interactions',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  item(route: AppRoutes.home, label: 'Home', icon: Icons.home),
                  item(
                    route: AppRoutes.createAccount,
                    label: 'Create account',
                    icon: Icons.person_add_alt_1,
                  ),
                  item(
                    route: AppRoutes.login,
                    label: 'Login',
                    icon: Icons.lock_open,
                  ),
                  item(
                    route: AppRoutes.importExternalWallet,
                    label: 'Import External Wallet',
                    icon: Icons.file_upload_outlined,
                  ),
                  item(
                    route: AppRoutes.accountHash,
                    label: 'Get my account hash',
                    icon: Icons.key_outlined,
                  ),
                  item(
                    route: AppRoutes.changePassword,
                    label: 'Change password',
                    icon: Icons.password_outlined,
                  ),
                  const Divider(height: 24),
                  item(
                    route: AppRoutes.settings,
                    label: 'Settings',
                    icon: Icons.settings_outlined,
                  ),
                  item(
                    route: AppRoutes.about,
                    label: 'About',
                    icon: Icons.info_outline,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}