import 'package:flutter/material.dart';

import '../router.dart';
import '../shared_components/shared.dart';

class UnauthedScreen extends StatelessWidget {
  const UnauthedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppPageShell(
      title: 'Arweave Wallet Auth + AOConnect',
      currentRoute: AppRoutes.home,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _HeroHeader(
            title: 'Prototype navigation & UI',
            subtitle: 'This whole system is looking very promising',
          ),
          const SizedBox(height: 16),
          _FlowCard(
            title: 'Account initialization (first-time user)',
            icon: Icons.person_add_alt_1,
            bullets: const [
              'Ask user for a password',
              'Generate a new Arweave wallet',
              'Encrypt wallet keys + store locally',
              'Prompt copy of encrypted hash to password manager, etc.',
              'Account hash can be retrieved later on authenticated device via password',
            ],
          ),
          const SizedBox(height: 12),
          _FlowCard(
            title: 'Login on a new device (existing user)',
            icon: Icons.lock_open,
            bullets: const [
              'Get password + account hash',
              'Use password to decrypt account hash into wallet keys',
              'Instantiate an Arweave wallet',
              'Try to sign test transaction to see if wallet is valid',
              'If success: user is logged in!',
            ],
          ),
          const SizedBox(height: 16),
          _ActionRow(
            onCreate: () =>
                Navigator.pushNamed(context, AppRoutes.createAccount),
            onLogin: () => Navigator.pushNamed(context, AppRoutes.login),
            onSettings: () =>
                Navigator.pushNamed(context, AppRoutes.settings),
          ),
          const SizedBox(height: 8),
          Text(
            'Tip: Use the drawer to jump between screens.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.22),
            cs.secondary.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
            ),
            child: Icon(Icons.shield_outlined, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowCard extends StatelessWidget {
  const _FlowCard({
    required this.title,
    required this.icon,
    required this.bullets,
  });

  final String title;
  final IconData icon;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(
              bullets.length,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _NumberedBullet(index: i + 1, text: bullets[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberedBullet extends StatelessWidget {
  const _NumberedBullet({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
          ),
          child: Text(
            '$index',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: cs.primary),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.onSurface.withValues(alpha: 0.92)),
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.onCreate,
    required this.onLogin,
    required this.onSettings,
  });

  final VoidCallback onCreate;
  final VoidCallback onLogin;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Create account'),
        ),
        OutlinedButton.icon(
          onPressed: onLogin,
          icon: const Icon(Icons.lock_open),
          label: const Text('Login'),
        ),
        TextButton.icon(
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined),
          label: const Text('Settings'),
        ),
      ],
    );
  }
}