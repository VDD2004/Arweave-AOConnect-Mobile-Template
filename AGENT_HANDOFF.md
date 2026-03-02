# AGENT_HANDOFF

## Project
**Arweave AOConnect Mobile Template** (Flutter, Android-focused)

This repository is a mobile template showing:
- Arweave wallet generation/import/login
- local encrypted wallet storage
- AOConnect interactions from Flutter via hidden WebView bridge

Primary entry points:
- [`main._Bootstrap`](lib/main.dart)
- [`router.AppRouter.onGenerateRoute`](lib/router.dart)
- [`services.WalletVault`](lib/services/wallet_vault.dart)
- [`services.ArweaveJs`](lib/services/arweavejs.dart)
- [`services.AOConnectJs`](lib/services/aoconnect.dart)

---

## Architecture (high signal)

### 1) Hidden WebView bridge runtime
- Flutter mounts a persistent hidden WebView host in [`ArweaveWebViewHost`](lib/services/arweave_web_host.dart).
- It loads [assets/arweave_runner.html](assets/arweave_runner.html), which loads [assets/arweave_bridge.js](assets/arweave_bridge.js).
- JS bridge source lives in:
  - [arweave_bridge/src/bridge.mjs](arweave_bridge/src/bridge.mjs)
  - [arweave_bridge/src/wallet_shim.mjs](arweave_bridge/src/wallet_shim.mjs)
  - [arweave_bridge/src/aoconnect_bridge.mjs](arweave_bridge/src/aoconnect_bridge.mjs)

### 2) Wallet security model
- Secure storage + encrypted export string logic in [`services.WalletVault`](lib/services/wallet_vault.dart).
- JWK is encrypted with PBKDF2 + AES-GCM (see [LLMS.md](LLMS.md), Security Model section).
- Never expose raw JWK to UI/logs.

### 3) AO bridge interaction
- Dart wrappers:
  - [`services.ArweaveJs.init`](lib/services/arweavejs.dart)
  - [`services.AOConnectJs.init`](lib/services/aoconnect.dart)
- JS globals:
  - `globalThis.ArweaveBridge`
  - `globalThis.arweaveWallet`
  - `globalThis.AOConnect`

---

## Core user flows (screen map)

- Create wallet: [`screens.CreateAccountScreen`](lib/screens/create_account_screen.dart)
- Login (paste/file encrypted hash): [`screens.LoginScreen`](lib/screens/login_screen.dart)
- Import raw external JWK: [`screens.ImportExternalWalletScreen`](lib/screens/import_external_wallet.dart)
- Retrieve account hash: [`screens.AccountHashScreen`](lib/screens/account_hash_screen.dart)
- AO message demo: [`screens.AuthedHomeScreen`](lib/screens/authed_home_screen.dart)
- Settings + auto-lock/logout: [`screens.SettingsScreen`](lib/screens/settings_screen.dart)

---

## Guardrails (do not violate)

1. Do **not** call bridge methods before init:
   - initialize bridge in bootstrap first.
2. Do **not** remove auth/import sign-check validation.
3. Do **not** store plaintext JWK in insecure storage.
4. Do **not** break WalletVault payload format/version/AAD without migration.
5. Do **not** edit generated bridge bundle directly:
   - edit [arweave_bridge/src/*](arweave_bridge/src/aoconnect_bridge.mjs), then rebuild.
6. Keep hidden WebView mounted for session lifetime.

Reference: [LLMS.md](LLMS.md)

---

## Local run/build commands

### Flutter app
- `flutter pub get`
- `flutter run`
- `flutter build apk`

### JS bridge (if changed)
- `cd arweave_bridge`
- `npm install`
- `npm run build`
- `cd ..`

---

## Config points to customize per fork

- AO defaults in [`services.AOConnectJs`](lib/services/aoconnect.dart):
  - `aoPID`
  - `hbUrl`
  - `operatorId`
- App routes in [`router.AppRoutes`](lib/router.dart)
- UI/theme in [lib/app.dart](lib/app.dart)

---

## Permaweb-style packaging goal (current direction)

This repo is being adapted to seed-style handoff/deploy pattern:
- handoff docs (`AGENT_HANDOFF.md`, `NEXT_AGENT_BRIEF.md`)
- fork-friendly deploy scripts
- source archive + app artifact publishing linkage

See [TODO.md](TODO.md) for checklist.

---

## Sensitive files / git hygiene

- Never commit deploy wallets (example: `wallet.json` when deploy scripts are added).
- Keep secrets out of source, docs, and logs.
- Review [.gitignore](.gitignore) before adding deploy tooling.

---

## If you change bridge behavior

1. Edit source in [arweave_bridge/src/](arweave_bridge/src/bridge.mjs)
2. Rebuild to [assets/arweave_bridge.js](assets/arweave_bridge.js)
3. Verify Dart wrappers still match expected return shapes:
   - [lib/services/arweavejs.dart](lib/services/arweavejs.dart)
   - [lib/services/aoconnect.dart](lib/services/aoconnect.dart)

---

## First verification checklist after any non-trivial change

- App boots and loading overlay clears
- Wallet create/login/import still works
- Account hash retrieval still works
- AO message/result still works
- No plaintext key leakage

## Expected deliverable style (mobile-only)

When release tooling is used, output:

1. Code archive URL (Arweave)
2. Release URL (GitHub Releases/TestFlight)

No Arweave manifest app URL is expected for this repo.