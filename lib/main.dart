import 'dart:async';

import 'package:arweave_aoconnect_mobile_template/services/aoconnect.dart';
import 'package:arweave_aoconnect_mobile_template/services/arweave_web_host.dart';
import 'package:arweave_aoconnect_mobile_template/services/arweavejs.dart';
import 'package:arweave_aoconnect_mobile_template/services/wallet_vault.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'screens/loading_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Bootstrap());
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late final ArweaveWebViewHost _arweaveHost;

  final Completer<void> _hostReady = Completer<void>();
  bool _booting = true;

  @override
  void initState() {
    super.initState();

    _arweaveHost = ArweaveWebViewHost(
      onReady: (controller) async {
        await Future.wait([
          ArweaveJs.init(controller),
          AOConnectJs.init(controller),
        ]);
        if (!_hostReady.isCompleted) _hostReady.complete();
      },
    );

    _runBootstrap();
  }

  Future<void> _runBootstrap() async {
    try {
      // Prevent a quick flash if everything is instant.
      await Future.wait([
        _hostReady.future,
        Future<void>.delayed(const Duration(milliseconds: 450)),
      ]);

      final loggedIn = await WalletVault().attemptLogin();
      if (loggedIn) {
        await AOConnectJs.connect(
          jwk: WalletVault.jwk!
        );
      }
      debugPrint('User is ${loggedIn ? '' : 'not '}logged in${loggedIn ? '!' : '.'}');
    } catch (_) {
      // Ignore bootstrap errors for the UI; app still loads.
    } finally {
      if (mounted) {
        setState(() => _booting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ArweaveAOMobileApp(
      builder: (context, child) {
        return Stack(
          alignment: Alignment.topLeft,
          children: [
            child ?? const SizedBox.shrink(),

            // Ensure the WebView actually mounts so it can create a controller.
            // Keep it invisible and non-interactive
            Align(
              alignment: Alignment.bottomLeft,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0,
                  child: SizedBox(
                    width: 1,
                    height: 1,
                    child: _arweaveHost,
                  ),
                ),
              ),
            ),

            // Loading overlay while we attempt initial auto-login.
            if (_booting) const Positioned.fill(child: LoadingScreen()),
          ],
        );
      },
    );
  }
}
