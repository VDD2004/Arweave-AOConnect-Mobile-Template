# Arweave AOConnect Mobile Template

Quickstart for running this Flutter app on an Android emulator.

For implementation details and deep explanations, see [notes.md](notes.md).

---

## Quickstart

## 1) Requirements

Install:

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Android Studio (Android SDK + emulator)
- Git
- Node.js + npm (for JS bridge tooling in [arweave_bridge/](arweave_bridge))

Then verify setup:

```bash
flutter doctor
```

### Tested versions

- **Flutter**: 3.38.7 (stable)
- **Dart**: 3.10.7
- **DevTools**: 2.51.1
- **Node.js**: v22.14.0
- **npm**: 11.8.0
- **Android SDK Command-line Tools (`sdkmanager`)**: 19.0

Note: your environment reported duplicate/backup emulator package warnings during `sdkmanager --version`; these do not change the pinned CLI tool version above.

### Platform support

- Tested/documented for Android emulator workflows.
- iOS is not currently documented/tested in this template.

---

## 2) Download project

```bash
git clone https://github.com/VDD2004/Arweave-AOConnect-Mobile-Template.git
cd arweave_aoconnect_mobile_template
```

---

## 3) Install Flutter dependencies

From project root (same folder as [pubspec.yaml](pubspec.yaml)):

```bash
flutter pub get
```

---

## 4) Install/rebuild JS bridge (if needed)

If your setup requires bridge assets different from the current ones in [arweave_bridge/](arweave_bridge):
1. Make desired changes
2. Rebuild the bridge:
    ```bash
    cd arweave_bridge
    npm install
    # build script automatically outputs files in assets/
    npm run build
    cd ..
    ```

---

## 5) Start Android emulator

- Android Studio → Device Manager → start an emulator  
  **or**
- Start emulator via CLI if already configured.

Check connected devices:

```bash
flutter devices
```

### Tested emulator

- Pixel 6a emulator
- Android 16.0 (API 36)

### Local HyperBEAM over HTTP (cleartext)

- Required config is documented in [notes.md → Note for testing with local HyperBEAM instances](notes.md#note-for-tesing-with-local-hyperbeam-instances).
- Config files:
  - [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml)
  - [android/app/src/main/res/xml/network_security_config.xml](android/app/src/main/res/xml/network_security_config.xml)

---

## 6) Run app

From project root:

```bash
flutter run
```

If multiple devices are connected:

```bash
flutter run -d <device-id>
```

---

## 7) Login / wallet flow

- Login screen: [lib/screens/login_screen.dart](lib/screens/login_screen.dart)
- External wallet import screen: [lib/screens/import_external_wallet.dart](lib/screens/import_external_wallet.dart)

You can use **Import external wallet** from the login screen ([`_LoginScreenState.build`](lib/screens/login_screen.dart)) to import an existing wallet using raw JWK JSON (paste mode) or keyfile upload.

Current implementation status in this template:
- Import UI is present ([`ImportExternalWalletScreen`](lib/screens/import_external_wallet.dart)).
- File picker is implemented (`_pickJwkFile`) via `file_picker`.
- Import flow is implemented (`_onImportPressed`):
  - validates acknowledgment + password confirmation
  - parses and validates JWK JSON
  - validates JWK by signing test data
  - encrypts and stores wallet via `WalletVault`
  - saves password and navigates to home on success

### Import requirements

- **Accepted JWK format**: official Arweave wallet JWK (JSON keyfile format).
- **Validation rule**: key must be valid for Arweave signing (validated via signing attempt in wallet flow).
- **Password/encryption requirements**: configurable in app code (vault + settings behavior).

Current post-import behavior: successful import saves the encrypted wallet + password, then routes to home.

---

## 8) Build APK (optional)

```bash
flutter build apk
```

---

If emulator/network/networking issues appear (especially local HyperBEAM over HTTP), see [notes.md](notes.md) and Android config under [android/](android).