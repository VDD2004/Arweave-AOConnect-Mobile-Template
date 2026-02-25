// ignore_for_file: use_build_context_synchronously

import 'package:arweave_aoconnect_mobile_template/services/wallet_vault.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../router.dart';
import '../services/helpers.dart';
import '../shared_components/shared.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final WalletVault _vault = WalletVault();
  final _currentPw = TextEditingController();
  final _newPw = TextEditingController();
  final _confirmPw = TextEditingController();

  String? _newEncryptedHash;

  @override
  void dispose() {
    _currentPw.dispose();
    _newPw.dispose();
    _confirmPw.dispose();
    super.dispose();
  }

  Future<void> _onConfirmChangePressed() async {
    if (_newPw.text != _confirmPw.text) {
      showSnackBar(context, 'New password and confirmation do not match.');
      return;
    }
    if (_newPw.text.isEmpty) {
      showSnackBar(context, 'New password cannot be empty.');
      return;
    }

    showSnackBar(context, 'Validating current password...');
    try {
      final String jwkJson = await _vault.decryptStoredJwk(
        password: _currentPw.text,
      );
      final String newEncryptedHash = await _vault.encryptJwkToExportString(
        password: _newPw.text,
        jwkJson: jwkJson,
      );

      await _vault.saveExportString(newEncryptedHash);
      await _vault.savePassword(_newPw.text);

      final bool reauthenticated = await _vault.attemptLogin(
        encryptedJwk: newEncryptedHash,
        password: _newPw.text,
      );

      if (!reauthenticated) {
        showSnackBar(
          context,
          'Password changed, but re-authentication failed.',
        );
        return;
      }

      setState(() {
        _newEncryptedHash = newEncryptedHash;
      });
      showSnackBar(context, 'Password changed successfully!');
    } catch (_) {
      showSnackBar(
        context,
        'Current password is incorrect or account data is invalid.',
      );
    }
  }

  void _copyNewHash() {
    if (_newEncryptedHash == null || _newEncryptedHash!.isEmpty) {
      showSnackBar(context, 'No new hash to copy yet.');
      return;
    }
    Clipboard.setData(ClipboardData(text: _newEncryptedHash!));
    showSnackBar(context, 'New encrypted hash copied to clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppPageShell(
      title: 'Change password',
      currentRoute: AppRoutes.changePassword,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update credentials',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _currentPw,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _newPw,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                      prefixIcon: Icon(Icons.password),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _confirmPw,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                      prefixIcon: Icon(Icons.password_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _onConfirmChangePressed,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Confirm password change'),
                    ),
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
                  Text(
                    'New encrypted account hash',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1724),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      _newEncryptedHash == null
                          ? 'NEW_HASH_WILL_APPEAR_HERE'
                          : '••••••••${_newEncryptedHash!.substring(_newEncryptedHash!.length - 8)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _copyNewHash,
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy new hash'),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'Note: This keeps the same wallet/account and only updates its encryption with your new password. Save the new encrypted hash somewhere safe.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
