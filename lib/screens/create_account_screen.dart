// ignore_for_file: use_build_context_synchronously

import 'package:arweave_aoconnect_mobile_template/services/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../router.dart';
import '../shared_components/shared.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _pw = TextEditingController();
  String? _accountHash;

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppPageShell(
      title: 'Create account',
      currentRoute: AppRoutes.createAccount,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Step 1: Choose a password',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pw,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      hintText: 'Used to encrypt wallet keys',
                      prefixIcon: Icon(Icons.password),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      final res = await generateAndStoreWallet(context, _pw.text);
                      if (res != null) {
                        showSnackBar(context, 'Wallet generated and stored successfully!');
                        setState(() {
                          _accountHash = res;
                        });
                      } else {
                        showSnackBar(context, 'Failed to generate and store wallet');
                      }
                    },
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generate & encrypt'),
                  ),
                ],
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
                  Text('Encrypted Account Hash',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1724),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
                    ),
                    child: TextButton(
                      onPressed: () {
                        if (_accountHash == null) {
                          return;
                        }
                        Clipboard.setData(ClipboardData(text: _accountHash!));
                        showSnackBar(context, 'Account hash copied to clipboard.');
                      },                      
                      child: Text(_accountHash == null ? 'ACCOUNT_HASH_WILL_APPEAR_HERE' : 'Click To Copy', 
                      style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)
                      )
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
