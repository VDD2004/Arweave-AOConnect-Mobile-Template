import 'package:flutter/material.dart';

import '../router.dart';
import '../shared_components/shared.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppPageShell(
      title: 'About',
      currentRoute: AppRoutes.about,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.bodyMedium!,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mobile AOConnect + Arweave Template',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This repository is an example/template for developers who want to use AOConnect and Arweave from a mobile app.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What this template demonstrates',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 10),
                  const Text('• Mobile wallet generation and local secure storage flow'),
                  const SizedBox(height: 6),
                  const Text('• Password-based encryption/decryption for wallet access'),
                  const SizedBox(height: 6),
                  const Text('• Flutter ↔ JavaScript bridge pattern for AOConnect usage'),
                  const SizedBox(height: 6),
                  const Text('• Example AO message/result calls from an authenticated screen'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Use this as a starting point: swap in your own process IDs, endpoints, and app UX while keeping the bridge/auth patterns.',
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
