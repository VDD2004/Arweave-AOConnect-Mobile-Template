// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';

import 'package:arweave_aoconnect_mobile_template/services/helpers.dart';
import 'package:arweave_aoconnect_mobile_template/services/wallet_vault.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_store_plus/media_store_plus.dart';

import '../router.dart';
import '../shared_components/shared.dart';

class AccountHashScreen extends StatefulWidget {
  const AccountHashScreen({super.key});

  @override
  State<AccountHashScreen> createState() => _AccountHashScreenState();
}

class _AccountHashScreenState extends State<AccountHashScreen> {
  final _pw = TextEditingController();
  String? _hash;
  final WalletVault _vault = WalletVault();

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  void _tryRetrieveAccountHash() async {
    if (_pw.text.isEmpty) {
      showSnackBar(context, 'Enter your password first');
      return;
    }
    showSnackBar(context, 'Retrieving account hash...', duration: const Duration(seconds: 2));
    bool passwordValid = await _vault.attemptLogin(password: _pw.text);
    if (!passwordValid) {
      showSnackBar(context, 'Incorrect password');
      return;
    }
    _hash = await _vault.loadExportString();

    showSnackBar(context, 'Success!');
    setState(() {});
  }

  Future<void> _saveAccountHashAsTxt() async {
    if (_hash == null || _hash!.isEmpty) {
      showSnackBar(context, 'No account hash to save');
      return;
    }

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'account_hash_$stamp.txt';

    Directory? tempDir;
    File? tempFile;

    try {
      showSnackBar(context, 'Saving file...', duration: const Duration(seconds: 1));
      await MediaStore.ensureInitialized();
      // saves to Downloads/AR_AO_Mobile_Template
      MediaStore.appFolder = 'AR_AO_Mobile_Template';
      tempDir = await Directory.systemTemp.createTemp('account_hash_export_');
      tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(utf8.encode(_hash!), flush: true);

      final mediaStore = MediaStore();
      await mediaStore.saveFile(
        tempFilePath: tempFile.path,
        dirType: DirType.download,
        dirName: DirName.download,
      );

      if (!mounted) return;
      showSnackBar(context, 'Saved to Downloads/${MediaStore.appFolder} as $fileName');
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, 'Failed to save file: $e');
    } finally {
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
        if (tempDir != null && await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppPageShell(
      title: 'Get my account hash',
      currentRoute: AppRoutes.accountHash,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Authenticate on this device',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pw,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      hintText: 'Used to unlock local stored keys',
                      prefixIcon: Icon(Icons.password),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _tryRetrieveAccountHash,
                    icon: const Icon(Icons.key_outlined),
                    label: const Text('Retrieve account hash'),
                  ),
                  const SizedBox(height: 14),
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
                    child: Column(
                      children: [
                        TextButton(
                          child: Text(
                            _hash == null
                                ? 'ACCOUNT_HASH_NOT_UNLOCKED'
                                : 'Click To Copy',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          onPressed: () {
                            if (_hash == null) return;
                            Clipboard.setData(ClipboardData(text: _hash!));
                            showSnackBar(context, 'Copied to clipboard');
                          },
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _hash == null ? null : _saveAccountHashAsTxt,
                          icon: const Icon(Icons.save_alt_outlined),
                          label: const Text('Save as .txt'),
                        ),
                      ],
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
