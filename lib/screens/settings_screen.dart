import 'dart:async';

import 'package:arweave_aoconnect_mobile_template/services/app_settings_store.dart';
import 'package:arweave_aoconnect_mobile_template/services/wallet_vault.dart';
import 'package:flutter/material.dart';

import '../router.dart';
import '../shared_components/shared.dart';

enum _AutoLockUnit { minutes, hours, days }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _store = AppSettingsStore();
  final _vault = WalletVault();
  Timer? _saveTimer;
  bool _autoLockEnabled = true;
  _AutoLockUnit _autoLockUnit = _AutoLockUnit.minutes;
  double _autoLockValue = 15;

  Future<void> _logout() async {
    await _vault.deleteSavedPassword();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged out; saved password removed')),
    );
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
  }

  Future<void> _removeAccountFromDevice() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove account from device?'),
        content: const Text(
          'This will remove your account from this device. If you do not have your encrypted account hash and password, you will never be able to access your account again. There is nothing we can do to get it back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove account'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _vault.deleteSavedPassword();
    await _vault.deleteExportString();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account removed from this device.')),
    );
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
  }
  
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () async {
      debugPrint('Saving auto lock at ${_autoLockTimeout.toString()}');
      await _store.saveAutoLockSettings(
        AutoLockSettings(enabled: _autoLockEnabled, timeout: _autoLockTimeout),
      );
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  int get _minAutoLockValue => switch (_autoLockUnit) {
    _AutoLockUnit.minutes => 5,
    _AutoLockUnit.hours => 1,
    _AutoLockUnit.days => 1,
  };

  int get _maxAutoLockValue => switch (_autoLockUnit) {
    _AutoLockUnit.minutes => 59,
    _AutoLockUnit.hours => 23,
    _AutoLockUnit.days => 30,
  };

  Duration get _autoLockTimeout => switch (_autoLockUnit) {
    _AutoLockUnit.minutes => Duration(minutes: _autoLockValue.round()),
    _AutoLockUnit.hours => Duration(hours: _autoLockValue.round()),
    _AutoLockUnit.days => Duration(days: _autoLockValue.round()),
  };

  String get _autoLockTimeoutLabel {
    final v = _autoLockValue.round();
    return switch (_autoLockUnit) {
      _AutoLockUnit.minutes => '$v minute${v == 1 ? '' : 's'}',
      _AutoLockUnit.hours => '$v hour${v == 1 ? '' : 's'}',
      _AutoLockUnit.days => '$v day${v == 1 ? '' : 's'}',
    };
  }


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppPageShell(
      title: 'Settings',
      currentRoute: AppRoutes.settings,
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
                    'Security',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _autoLockEnabled,
                    title: const Text('Auto-lock'),
                    subtitle: const Text('Log out after inactivity'),
                    onChanged: (v) {
                      _scheduleSave();
                      setState(() => _autoLockEnabled = v);
                    }
                  ),
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: _autoLockEnabled ? 1 : 0.5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auto-lock timeout: $_autoLockTimeoutLabel',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<_AutoLockUnit>(
                          initialValue: _autoLockUnit,
                          decoration: const InputDecoration(
                            labelText: 'Timeout unit',
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: _AutoLockUnit.minutes,
                              child: Text('Minutes (5–59)'),
                            ),
                            DropdownMenuItem(
                              value: _AutoLockUnit.hours,
                              child: Text('Hours (1–23)'),
                            ),
                            DropdownMenuItem(
                              value: _AutoLockUnit.days,
                              child: Text('Days (1–30)'),
                            ),
                          ],
                          onChanged: _autoLockEnabled
                              ? (v) {
                                  if (v == null) return;
                                  _scheduleSave();
                                  setState(() {
                                    _autoLockUnit = v;
                                    final min = _minAutoLockValue.toDouble();
                                    final max = _maxAutoLockValue.toDouble();
                                    if (_autoLockValue < min) {
                                      _autoLockValue = min;
                                    }
                                    if (_autoLockValue > max) {
                                      _autoLockValue = max;
                                    }
                                  });
                                }
                              : null,
                        ),
                        Slider(
                          value: _autoLockValue,
                          min: _minAutoLockValue.toDouble(),
                          max: _maxAutoLockValue.toDouble(),
                          divisions: _maxAutoLockValue - _minAutoLockValue,
                          label: _autoLockTimeoutLabel,
                          onChanged: _autoLockEnabled
                              ? (v) => setState(() => _autoLockValue = v)
                              : null,
                          onChangeEnd: (value) => _scheduleSave(),
                        ),
                        Text(
                          'Range: 5 minutes to 30 days',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.key_outlined),
              title: const Text('Get my account hash'),
              subtitle: const Text('Requires password on authenticated device'),
              onTap: () => Navigator.pushReplacementNamed(
                context,
                AppRoutes.accountHash,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.key_outlined),
              title: const Text('Change password'),
              subtitle: const Text(
                'Due to the nature of a new encryption, you will need to save a new hash as well',
              ),
              onTap: () => Navigator.pushReplacementNamed(
                context,
                AppRoutes.changePassword,
              ),
            ),
          ),
          const SizedBox(height: 100),
          FilledButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _removeAccountFromDevice,
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Remove account from device'),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.error,
              side: BorderSide(color: cs.error),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
