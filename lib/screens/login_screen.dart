// ignore_for_file: use_build_context_synchronously

import 'package:arweave_aoconnect_mobile_template/services/helpers.dart';
import 'package:arweave_aoconnect_mobile_template/services/wallet_vault.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../router.dart';
import '../shared_components/shared.dart';

enum _LoginInputMethod { paste, file }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final WalletVault _vault = WalletVault();
  final _pw = TextEditingController();
  String? _hash;
  String? _fileInputHash;
  String? _originalHash;
  String? _selectedEncryptedFileName;
  _LoginInputMethod _inputMethod = _LoginInputMethod.file;
  final _hashController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStoredHash();
  }

  Future<void> _loadStoredHash() async {
    final loadedHash = await _vault.loadExportString();
    if (!mounted || loadedHash == null) {
      return;
    }

    setState(() {
      _hash = loadedHash;
      _originalHash = loadedHash;
      _hashController.text = 'Last logged in as:\n${loadedHash.substring(loadedHash.length - 8)}';
    });
  }

  @override
  void dispose() {
    _pw.dispose();
    _hashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      title: 'Login',
      currentRoute: AppRoutes.login,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Enter credentials',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SegmentedButton<_LoginInputMethod>(
                    segments: const [
                      ButtonSegment(
                        value: _LoginInputMethod.file,
                        icon: Icon(Icons.upload_file_outlined),
                        label: Text('Upload file'),
                      ),
                      ButtonSegment(
                        value: _LoginInputMethod.paste,
                        icon: Icon(Icons.content_paste_outlined),
                        label: Text('Paste encrypted string'),
                      ),
                    ],
                    selected: {_inputMethod},
                    onSelectionChanged: (selection) {
                      setState(() => _inputMethod = selection.first);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_inputMethod == _LoginInputMethod.paste) ...[
                    TextField(
                      controller: _hashController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Encrypted Account hash',
                        hintText: 'Paste your saved account hash',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                      onChanged: (String value) {
                        if (value.isNotEmpty && !value.toLowerCase().contains('logged in')) {
                          _hash = value;
                        }
                      },
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: _pickEncryptedStringFile,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Upload encrypted string file'),
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
                      controller: TextEditingController(
                        text: _selectedEncryptedFileName ?? '',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pw,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.password),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _attemptLogin,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Login'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.importExternalWallet,
                    ),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Import external wallet'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _attemptLogin() async {
    if (_inputMethod == _LoginInputMethod.paste && (_hash == null || _hash!.isEmpty)) {
      showSnackBar(context, 'Enter an account hash');
      return;
    } else if (_inputMethod == _LoginInputMethod.file && (_fileInputHash == null || _fileInputHash!.isEmpty)) {
      showSnackBar(context, 'Select an encrypted string file');
      return;
    } else if (_pw.text.isEmpty) {
      showSnackBar(context, 'Enter your password');
      return;
    }
    showSnackBar(context, 'Attempting to login...', duration: const Duration(milliseconds: 2000));
    
    try {
      final String hashToUse = _inputMethod == _LoginInputMethod.paste ? _hash! : _fileInputHash!;
      final loggedIn = await _vault.attemptLogin(encryptedJwk: hashToUse, password: _pw.text);
      if (!loggedIn) {
        throw Exception('Login failed');
      }

      if (hashToUse != _originalHash) {
        // hash used to log in is different than the stored on, so this is a different user
        // save the new hash to storage
        await _vault.saveExportString(hashToUse);
      }
      await _vault.savePassword(_pw.text);
      showSnackBar(context, 'Successfully logged in!');
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } catch (e) {
      showSnackBar(context, 'Failed to login; account hash or password is wrong');
    }
  }

  Future<void> _pickEncryptedStringFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    setState(() => _selectedEncryptedFileName = file.name);
    
    _fileInputHash = String.fromCharCodes(file.bytes!);    
  }
}
