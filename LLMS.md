ARWEAVE AO CONNECT MOBILE TEMPLATE — LLM WORKING SPEC
Version: 1.0
Last Updated: 2026-02-25
Audience: LLM agents, automation tooling, and contributors modifying this repository

======================================================================
0) WHAT THIS FILE IS
======================================================================

This file is the high-signal operational spec for AI/code agents working in this repo.
It is intentionally explicit and conservative.

Primary goals:
- Explain architecture and runtime constraints.
- Define safe edit boundaries and invariants.
- Document critical flows (wallet generation/login/import/AO messaging).
- Prevent security regressions and bridge breakage.

If this file conflicts with implementation:
1) Treat source code as truth.
2) Update this file in the same change set.

======================================================================
1) PROJECT IDENTITY
======================================================================

Project name:
- arweave_aoconnect_mobile_template

Core purpose:
- Flutter mobile template for Arweave wallet auth + AOConnect interactions.
- Uses hidden in-app WebView to run bundled JS bridge code.
- Stores encrypted wallet export string in secure storage.
- Supports account creation, password login, external wallet import, AO message/result demo.

Platforms:
- Android-focused and documented.
- iOS not currently documented/tested here.

Tech stack:
- Flutter + Dart
- flutter_inappwebview
- flutter_secure_storage
- cryptography (PBKDF2 + AES-GCM)
- file_picker
- media_store_plus
- JavaScript bridge bundled with Vite in arweave_bridge/

Dependency source:
- pubspec.yaml
- arweave_bridge package config/build toolchain

======================================================================
2) REPO MAP (HIGH VALUE PATHS)
======================================================================

Root:
- README.md
- notes.md
- pubspec.yaml
- analysis_options.yaml
- LLMS.md (existing markdown variant)
- LLMS.txt (this file)

Flutter app:
- lib/main.dart
- lib/app.dart
- lib/router.dart
- lib/services/
  - arweave_web_host.dart
  - arweavejs.dart
  - aoconnect.dart
  - wallet_vault.dart
  - app_settings_store.dart
  - helpers.dart
- lib/screens/
  - unauthed_screen.dart
  - authed_home_screen.dart
  - create_account_screen.dart
  - login_screen.dart
  - import_external_wallet.dart
  - account_hash_screen.dart
  - settings_screen.dart
  - change_password_screen.dart
  - loading_screen.dart
  - about_screen.dart
- lib/shared_components/
  - app_page_shell.dart
  - nav_drawer.dart
  - page_action_button.dart
  - shared.dart

Bridge + web assets:
- assets/arweave_runner.html
- assets/arweave_bridge.js (generated bundle)
- arweave_bridge/vite.config.js
- arweave_bridge/src/bridge.mjs
- arweave_bridge/src/wallet_shim.mjs
- arweave_bridge/src/aoconnect_bridge.mjs

Android config (important for local HB):
- android/app/src/main/AndroidManifest.xml
- android/app/src/main/res/xml/network_security_config.xml

Low-signal / avoid as context:
- .dart_tool/
- build/
- zips/
- generated caches/artifacts

======================================================================
3) RUNTIME MODEL (CRITICAL)
======================================================================

The app is a hybrid runtime with two cooperating execution environments:

A) Dart/Flutter runtime:
- UI, navigation, storage, user flows.
- Sensitive credential handling and encryption.
- Calls into JS through flutter_inappwebview controller.

B) Hidden WebView JS runtime:
- Loads assets/arweave_runner.html.
- arweave_runner.html loads assets/arweave_bridge.js.
- Bridge injects globals into globalThis:
  - ArweaveBridge
  - arweaveWallet shim
  - AOConnect
  - aoInstance (optional connected instance cache)

Important:
- Do NOT assume Node.js runtime inside the app.
- JS executes in WebView/browser-like context.
- Bridge usage depends on WebView readiness and serializable return values.

======================================================================
4) APP BOOTSTRAP FLOW
======================================================================

Source of truth:
- lib/main.dart
- lib/services/arweave_web_host.dart
- lib/services/arweavejs.dart
- lib/services/aoconnect.dart
- lib/services/wallet_vault.dart

Boot sequence:
1) Flutter app starts _Bootstrap.
2) _Bootstrap mounts hidden ArweaveWebViewHost (1x1, opacity 0, ignore pointer).
3) WebView loads assets/arweave_runner.html.
4) onReady callback initializes:
   - ArweaveJs.init(controller)
   - AOConnectJs.init(controller)
5) Bootstrap waits for:
   - host ready
   - small minimum delay (450ms) to avoid flash
6) Attempts auto-login via WalletVault().attemptLogin().
7) If logged in, calls AOConnectJs.connect(jwk: WalletVault.jwk!).
8) Removes LoadingScreen overlay and shows routed app.

Invariant:
- Any ArweaveJs/AOConnectJs call before init must fail loudly (StateError).
- Keep hidden WebView mounted for session lifetime.

======================================================================
5) NAVIGATION + SCREEN RESPONSIBILITIES
======================================================================

Router:
- lib/router.dart
- AppRoutes + AppRouter.onGenerateRoute

Route behavior:
- "/" returns AuthedHomeScreen when WalletVault.jwk != null, else UnauthedScreen.
- Dedicated routes for create/login/import/account hash/settings/about/change-password.

Shell:
- lib/shared_components/app_page_shell.dart
- Standard app bar, optional drawer, themed glow background.

Drawer:
- lib/shared_components/nav_drawer.dart
- Uses pushReplacementNamed for navigation.

Primary screen intents:
- unauthed_screen.dart: orientation + entry actions.
- create_account_screen.dart: generate/encrypt/store new wallet.
- login_screen.dart: login with encrypted hash (paste/file) + password.
- import_external_wallet.dart: import existing raw JWK, validate, encrypt/store.
- account_hash_screen.dart: re-auth with password, reveal and export encrypted hash.
- settings_screen.dart: auto-lock config + logout + remove account from device.
- change_password_screen.dart: verifies current password, re-encrypts the same wallet with the new password, stores updated export/password, and exposes the new encrypted hash for backup.
- authed_home_screen.dart: AO message/result demo against configured process.
- about_screen.dart: informational.

======================================================================
6) SECURITY MODEL
======================================================================

Source of truth:
- lib/services/wallet_vault.dart
- lib/services/app_settings_store.dart

Storage:
- Uses flutter_secure_storage for encrypted export string + saved password + settings.

Key points:
- Wallet JWK is stored encrypted as portable export string.
- Password may be stored for auto-login convenience (guarded by auto-lock timeout).
- In-memory jwk cache: WalletVault.jwk static.

Crypto scheme:
- KDF: PBKDF2-HMAC-SHA256
- Iterations default: 600,000
- Salt length: 16 bytes
- Key length: 32 bytes (AES-256)
- Cipher: AES-256-GCM
- Nonce length: 12 bytes
- AAD context: "ArweaveAOConnectTemplate/WalletVault/v1"
- Payload version: 1
- Export format: base64url(JSON payload), no padding

Decryption verification:
- Uses AES-GCM authentication; wrong password/corrupt data throws.
- attemptLogin validates decrypted JWK by signing test bytes via ArweaveJs.sign.

Auto-lock:
- app_settings_store.dart stores:
  - auto lock settings (enabled + timeoutSeconds)
  - last unlock timestamp (UTC ISO string)
- WalletVault.attemptLogin enforces timeout when using saved password.

Sensitive behavior constraints:
- Never log raw JWK.
- Never expose decrypted JWK to UI.
- Never weaken KDF/cipher unless migration plan is added.
- Do not remove AAD/version payload fields.

======================================================================
7) WALLET/AUTH FLOWS
======================================================================

7.1 Create account flow
Source:
- create_account_screen.dart
- services/helpers.dart generateAndStoreWallet

Flow:
1) User enters password.
2) ArweaveJs.generateWallet() returns new jwk + address.
3) JWK JSON encrypted via WalletVault.encryptJwkToExportString.
4) Encrypted export saved in secure storage.
5) Password saved.
6) attemptLogin run immediately to hydrate session.
7) AOConnectJs.connect(jwk: WalletVault.jwk!) executed.
8) Account hash shown as copyable UI token.

7.2 Login flow
Source:
- login_screen.dart
- wallet_vault.dart

Flow:
1) User selects input method:
   - paste encrypted string
   - upload encrypted string file
2) User enters password.
3) WalletVault.attemptLogin(encryptedJwk: hashToUse, password: pw).
4) On success:
   - if hash differs from existing stored hash, overwrite stored export
   - save password
   - navigate home

7.3 External wallet import flow
Source:
- import_external_wallet.dart

Flow:
1) User provides JWK (file or pasted JSON).
2) Must acknowledge risk and confirm password.
3) Parse JSON to map.
4) Validate JWK by attempting ArweaveJs.sign() test message.
5) Encrypt JWK JSON with password.
6) Save export string if different from existing.
7) Save password.
8) Navigate home.

7.4 Retrieve account hash flow
Source:
- account_hash_screen.dart

Flow:
1) User enters password.
2) attemptLogin(password) validates.
3) loadExportString() retrieves encrypted export.
4) User can copy string.
5) Optional save as txt via MediaStore to Downloads/AR_AO_Mobile_Template.

7.5 Change password flow
Source:
- change_password_screen.dart

Flow:
1) User enters current password and new password.
2) Existing stored export is decrypted with current password.
3) The same JWK is re-encrypted with new password.
4) Stored encrypted export and saved password are replaced.
5) Re-authentication is performed with the new export/password pair.
6) New encrypted hash is shown for backup/copy.

======================================================================
8) AO CONNECT + BRIDGE ARCHITECTURE
======================================================================

Dart bridge wrappers:
- lib/services/arweavejs.dart
- lib/services/aoconnect.dart

JS bridge sources:
- arweave_bridge/src/bridge.mjs
- arweave_bridge/src/wallet_shim.mjs
- arweave_bridge/src/aoconnect_bridge.mjs

Bundling:
- arweave_bridge/vite.config.js builds to ../assets/arweave_bridge.js

Global APIs exposed:
- globalThis.ArweaveBridge:
  - generateWallet()
  - getAddress(jwk)
  - sign(jwk, messageBytesB64Url)

- globalThis.arweaveWallet shim:
  - getActiveAddress()
  - signMessage(...)
  - signDataItem(...)
  - connect()
  - getPermissions()

- globalThis.AOConnect:
  - connect(jwk, hbUrl, operator)
  - spawn(...)
  - message(...)
  - result(...)

- globalThis.aoInstance:
  - connected AO instance cache when connect() called

AO connect strategy:
- Supports direct method calls with explicit jwk/hbUrl/operator
  OR reuse prior aoInstance created via AOConnect.connect.
- doAction/doMethodAction in aoconnect_bridge.mjs route calls accordingly.

Constants currently in Dart wrapper:
- AOConnectJs.aoPID
- AOConnectJs.hbUrl
- AOConnectJs.operatorId
These are template defaults and should be app-configurable in production.

======================================================================
9) ANDROID / LOCAL HB NETWORKING NOTES
======================================================================

If using local HyperBEAM over HTTP (e.g., 10.0.2.2):
- cleartext traffic must be allowed by network security config.
- see notes.md and AndroidManifest/xml config files.

MediaStore permissions/config:
- required for saving account hash export files.
- already documented in notes.md.

======================================================================
10) KNOWN ISSUES / SHARP EDGES
======================================================================

1) Some TODO text remains in screens/bridge constants. These are for the developer who is using the template to fill to their own needs.
4) AO defaults are hardcoded constants; not user-configurable yet.
5) Auto-lock settings UI currently has in-memory defaults; no initial load path wired in SettingsScreen build/init.

======================================================================
11) LLM EDITING RULES (MANDATORY)
======================================================================

11.1 High-priority invariants
- Do not break hidden WebView bootstrap sequence.
- Do not call ArweaveJs/AOConnectJs before controller init.
- Do not store plaintext JWK in insecure storage.
- Do not remove JWK validation sign-check on auth/import.
- Do not silently alter cryptographic payload semantics without migration path.
- Preserve base64url no-padding behavior for export payload.

11.2 Preferred edit zones
- lib/screens/* for UX and flow updates.
- lib/services/* for business logic and persistence.
- arweave_bridge/src/* for JS bridge behavior.
- README.md / notes.md / LLMS.* for docs.

11.3 Avoid editing unless required
- Generated/cached artifacts in build/, .dart_tool/.
- Large Android Gradle internals not related to target behavior.
- assets/arweave_bridge.js directly (regenerate from source instead).

11.4 If bridge behavior changes
- Update JS source in arweave_bridge/src/.
- Rebuild bridge into assets/.
- Verify Dart wrapper expectations still match return shapes.

======================================================================
12) STANDARD CHANGE PLAYBOOKS
======================================================================

12.1 Add new AO call
1) Add JS method to globalThis.AOConnect in aoconnect_bridge.mjs.
2) Add Dart wrapper in lib/services/aoconnect.dart.
3) Add helper method in lib/services/helpers.dart if needed.
4) Wire UI action in appropriate screen.
5) Handle loading/error states and mounted checks.

12.2 Modify auth behavior
1) Change wallet_vault.dart logic first.
2) Update affected screens/helpers.
3) Re-verify auto-login, manual login, import, and account hash retrieval.
4) Ensure no plaintext secret leakage in logs/UI.

12.3 Add setting
1) Add typed model/key in app_settings_store.dart.
2) Load + save in settings_screen.dart.
3) Apply setting in runtime paths consuming it.
4) Keep bad-data fallback resilient.

======================================================================
13) MINIMUM MANUAL TEST MATRIX
======================================================================

Boot:
- App starts with loading overlay then resolves.
- WebView host initializes once.
- No crash if bridge init delayed slightly.

Create account:
- Can create wallet with password.
- Export string stored.
- Auto-authenticated and reaches authenticated home.
- AO connect executed.

Login (paste):
- Valid hash + password logs in.
- Wrong password fails.
- Invalid hash fails.

Login (file):
- File load works.
- Extracted content used for login.

Import external wallet:
- Valid JWK imports and logs in.
- Invalid JSON rejected.
- Invalid JWK rejected by sign test.
- Password mismatch blocked.

Account hash:
- Requires password.
- Copy works.
- Save txt to Downloads works.

Settings/auto-lock:
- Toggle/timeout save works.
- Expired timeout blocks auto-login and clears saved password.

AO messaging:
- Authenticated home sends message and retrieves result.
- Error path renders clearly when endpoint/pid invalid.

======================================================================
14) COMMAND CHEAT SHEET
======================================================================

Flutter setup/run:
- flutter pub get
- flutter run
- flutter devices
- flutter build apk

Bridge build:
- cd arweave_bridge
- npm install
- npm run build
- cd ..

General:
- Prefer running on Android emulator (documented path).
- For local HB HTTP, ensure Android cleartext config is enabled.

======================================================================
15) SECURITY CHECKLIST FOR PRS
======================================================================

Before merge, verify:
- [ ] No raw JWK printed/logged.
- [ ] No plaintext JWK persisted outside encryption path.
- [ ] WalletVault decrypt/auth errors handled without leaking internals.
- [ ] Auto-lock timestamps updated on password save/unlock events.
- [ ] Password change flow (if touched) re-encrypts existing JWK, no key replacement.
- [ ] Bridge methods validate and serialize return payloads safely.
- [ ] Sensitive actions require explicit user intent.

======================================================================
16) AGENT RESPONSE FORMAT (RECOMMENDED)
======================================================================

When proposing code changes, agents should include:
1) Intent summary (1-3 lines).
2) File-by-file patch plan.
3) Security impact statement.
4) Test steps (manual + automated if available).
5) Follow-up tasks/TODOs if scope-limited.

======================================================================
17) FUTURE IMPROVEMENTS (BACKLOG HINTS)
======================================================================

- Load existing auto-lock settings on Settings screen init.
- Persist/configure AO endpoint/operator/PID via settings.
- Add unit tests around WalletVault payload compatibility.
- Add structured error types for AO bridge failures.
- Add optional biometric gate before using saved password.
- Harden import/login file parsing against whitespace/encoding edge cases.

======================================================================
END OF FILE
======================================================================