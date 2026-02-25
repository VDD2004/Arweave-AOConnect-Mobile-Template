import 'package:arweave_aoconnect_mobile_template/screens/import_external_wallet.dart';
import 'package:flutter/material.dart';

import 'screens/about_screen.dart';
import 'screens/account_hash_screen.dart';
import 'screens/create_account_screen.dart';
import 'screens/unauthed_screen.dart';
import 'screens/login_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/authed_home_screen.dart';
import 'services/wallet_vault.dart';

sealed class AppRoutes {
  static const home = '/';
  static const createAccount = '/create';
  static const login = '/login';
  static const importExternalWallet = '/import-external-wallet';
  static const accountHash = '/account-hash';
  static const settings = '/settings';
  static const about = '/about';
  static const changePassword = '/change-password';
}

sealed class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute(
          builder: (_) => WalletVault.jwk != null
              ? const AuthedHomeScreen()
              : const UnauthedScreen(),
        );
      case AppRoutes.createAccount:
        return MaterialPageRoute(builder: (_) => const CreateAccountScreen());
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case AppRoutes.importExternalWallet:
        return MaterialPageRoute(builder: (_) => const ImportExternalWalletScreen());
      case AppRoutes.accountHash:
        return MaterialPageRoute(builder: (_) => const AccountHashScreen());
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case AppRoutes.about:
        return MaterialPageRoute(builder: (_) => const AboutScreen());
      case AppRoutes.changePassword:
        return MaterialPageRoute(builder: (_) => const ChangePasswordScreen());
      default:
        return MaterialPageRoute(builder: (_) => const UnauthedScreen());
    }
  }
}