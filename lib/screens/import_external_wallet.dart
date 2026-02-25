// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:arweave_aoconnect_mobile_template/services/arweavejs.dart';
import 'package:arweave_aoconnect_mobile_template/services/helpers.dart';
import 'package:arweave_aoconnect_mobile_template/services/wallet_vault.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../router.dart';
import '../shared_components/shared.dart';

enum _ImportMethod { file, paste }

class ImportExternalWalletScreen extends StatefulWidget {
  const ImportExternalWalletScreen({super.key});

  @override
  State<ImportExternalWalletScreen> createState() => _ImportExternalWalletScreenState();
}

class _ImportExternalWalletScreenState extends State<ImportExternalWalletScreen> {
  final _jwkTextController = TextEditingController();
  final _pwController = TextEditingController();
  final _confirmPwController = TextEditingController();

  _ImportMethod _method = _ImportMethod.file;
  String? _selectedFileName;
  bool _acknowledgedRisk = false;
  bool _obscurePw = true;
  bool _obscureConfirmPw = true;
  String? _selectedJwkContent;
  Map<String, dynamic>? _selectedJwk;

  @override
  void dispose() {
    _jwkTextController.dispose();
    _pwController.dispose();
    _confirmPwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      title: 'Import External Wallet',
      currentRoute: AppRoutes.importExternalWallet,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.amber.withValues(alpha: 0.12),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This wallet is highly sensitive. Never share your JWK. '
                      'It should only be stored encrypted.',
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
                    'Import method',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<_ImportMethod>(
                    segments: const [
                      ButtonSegment(
                        value: _ImportMethod.file,
                        icon: Icon(Icons.upload_file_outlined),
                        label: Text('Upload keyfile'),
                      ),
                      ButtonSegment(
                        value: _ImportMethod.paste,
                        icon: Icon(Icons.content_paste_outlined),
                        label: Text('Paste JWK JSON'),
                      ),
                    ],
                    selected: {_method},
                    onSelectionChanged: (selection) {
                      setState(() => _method = selection.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_method == _ImportMethod.file) ...[
                    OutlinedButton.icon(
                      onPressed: _pickJwkFile,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Choose jwk file'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Selected file',
                        hintText: 'No file selected',
                        prefixIcon: const Icon(Icons.description_outlined),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      controller: TextEditingController(text: _selectedFileName ?? ''),
                    ),
                  ] else ...[
                    TextField(
                      controller: _jwkTextController,
                      minLines: 8,
                      maxLines: 14,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        labelText: 'Raw JWK JSON',
                        hintText: '{ "kty": "RSA", "n": "...", ... }',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.key_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pwController,
                    obscureText: _obscurePw,
                    decoration: InputDecoration(
                      labelText: 'Set encryption password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscurePw = !_obscurePw),
                        icon: Icon(_obscurePw ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPwController,
                    obscureText: _obscureConfirmPw,
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      prefixIcon: const Icon(Icons.lock_reset_outlined),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscureConfirmPw = !_obscureConfirmPw),
                        icon: Icon(_obscureConfirmPw ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _acknowledgedRisk,
                    onChanged: (v) => setState(() => _acknowledgedRisk = v ?? false),
                    title: const Text('I understand this is sensitive key material'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _acknowledgedRisk ? _onImportPressed : null,
                    icon: const Icon(Icons.save_alt),
                    label: const Text('Encrypt & Save Wallet'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Login'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickJwkFile() async {
    // you can specify what file types you want to allow, but for this template we'll allow all and just validate the file after
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
      allowMultiple: false
    );
    if (result == null || result.files.isEmpty) {
      // user canceled or no file picked
      return;
    }
    final file = result.files.first;
    _selectedJwkContent = String.fromCharCodes(file.bytes!);

    setState(() => _selectedFileName = file.name);
    showSnackBar(context, 'JWK file selected: ${file.name}', duration: const Duration(milliseconds: 1500));
  }

  Future<void> _onImportPressed() async {
    if (!_acknowledgedRisk) {
      showSnackBar(context, 'You must acknowledge the risks to proceed');
      return;
    }
    if (_pwController.text.isEmpty || _confirmPwController.text.isEmpty) {
      showSnackBar(context, 'Password fields cannot be empty');
      return;
    } else if (_pwController.text != _confirmPwController.text) {
      showSnackBar(context, 'Passwords do not match');
      return;
    }

    if (_method == _ImportMethod.file && _selectedJwkContent == null) {
      showSnackBar(context, 'Please select a JWK file to import');
      return;
    }
    if (_method == _ImportMethod.paste) {
      if (_jwkTextController.text.isEmpty) {
        showSnackBar(context, 'Please paste the JWK JSON to import');
        return;
      }
      _selectedJwkContent = _jwkTextController.text;
    }
    

    try {
      _selectedJwk = jsonDecode(_selectedJwkContent!) as Map<String, dynamic>;
    } catch (e) {
      showSnackBar(context, 'Invalid JWK JSON: ${e.toString()}');
      return;
    }

    // attempt to use jwk to sign something to validate it
    try {
      await ArweaveJs.sign(
        jwk: _selectedJwk!,
        messageBytes: utf8.encode('jwk validity test'),
      );
    } catch (e) {
      showSnackBar(context, 'Invalid JWK: ${e.toString()}');
      return;
    }

    showSnackBar(context, 'JWK is valid! Encrypting and saving wallet...', duration: const Duration(milliseconds: 2000));
    
    final vault = WalletVault();
    final originalHash = await vault.loadExportString();
    final encryptedString = await vault.encryptJwkToExportString(jwkJson: _selectedJwkContent!, password: _pwController.text);

    if (encryptedString != originalHash) {
      // hash used to log in is different than the stored on, so this is a different user
      // save the new hash to storage
      await vault.saveExportString(encryptedString);
    }
    await vault.savePassword(_pwController.text);
    showSnackBar(context, 'Wallet imported and saved successfully!');
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }
}
