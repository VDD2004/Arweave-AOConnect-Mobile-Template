# Interacting with AO Processes (on HyperBEAM) from a Mobile Phone
**This documentation is specifically for Android phones, and the implementation was done in Flutter. These same principles will likely apply to Apple phones too, but I have not tested that.**

## Overview
This article will cover the following:
- Steps to get & use an Arweave Wallet in a mobile app
- Steps to get & use AOConnect and ArweaveJS in a mobile app
- Notes, what to do / not to do, and miscellaneous

### Core Logic
Natively, the Arweave Wallet, Arweave, and AOConnect SDKs are designed for `Node.js` or browser environments, not mobile. To get around this, you'll need an in-app WebView (kept invisible/non-interactable), and in Flutter, a Dart <-> JS bridge.<br>
On the JS side, you’ll make a bridge file that exposes the functions you need and implements them in a way that plays well with Dart <-> JS interactions.<br>
On the Dart/Flutter side, you’ll just need an implementation that talks to that JS bridge.

### Dependencies
On the JS side, you'll need:
- `@permaweb/aoconnect` (newest version as of writing is `0.0.93`) 
- `arweave` (newest is `1.15.0`)
- `arbundles` (here I used `@dha-team/arbundles` w/ version `1.0.4`) to implement a minimal Arweave Wallet shim with only what AOConnect needs
- `vite` for bundling the files
  - `vite-plugin-node-polyfills` as well

For the Dart side:
- The bundled JS bridge
- A tiny HTML `bridge_runner` page
- `flutter_inappwebview` (used `6.1.5`)
- `flutter_secure_storage` (used `10.0.0`)
- `cryptography` (used `2.9.0`)
- `convert` (used `3.1.2`)
- `file_picker` (used `10.3.10`)
- `media_store_plus`: (used `0.1.3`)

## Setup
### JS Side
Once you have your dependencies installed, the logic of the bridge is:
- Inject `ArweaveBridge`, `ArweaveWallet`, and `AOConnect` into `globalThis` for the Dart side to use
- Polyfill Node with `vite` when bundling
- Specifically use the `web` distribution of `aoconnect` (see [Why specifically use the web implementation of `aoconnect`?](#why-specifically-use-the-web-implementation-of-aoconnect))
- Create our own `ArweaveWallet` (Wander Wallet-like) shim (see [Why use a custom `ArweaveWallet` shim?](#why-use-a-custom-arweavewallet-shim))

**API Types Overview:**
```typescript
globalThis.ArweaveBridge: {
  generateWallet: () => Promise<{ jwk: object; address: string }>;
  getAddress: (jwk: object) => Promise<string>;
  sign: (jwk: object, messageBytesB64Url: string) => Promise<{ signatureB64Url: string }>;
};

globalThis.ArweaveWallet: {
  getActiveAddress: () => Promise<string>;
  signMessage: (
    data: string | ArrayBuffer | Uint8Array<ArrayBufferLike>,
    options?: { hashAlgorithm?: string }
  ) => Promise<ArrayBuffer>;
  signDataItem: (dataItem: {
    data: string | Uint8Array | ArrayBuffer;
    target?: string;
    anchor?: string;
    tags?: Array<{ name: string; value: string }>;
  }) => Promise<Uint8Array>;
  connect: () => Promise<void>;
  getPermissions: () => Promise<string[]>;
};

globalThis.AOConnect: {
    connect(jwk: Record<string, any>, hbUrl: string, operator: string): Promise<{
        MODE: string;
        spawn: (args: any) => Promise<any>;
        message: (args: any) => Promise<any>;
        result: (args: any) => Promise<{
            Output: any;
            Messages: any;
            Assignments: any;
            Spawns: any;
            Error: any;
        }>;
        results: (args: any) => Promise<{
            edges: {
                cursor: any;
                node: {
                    Output: any;
                    Messages: any;
                    Assignments: any;
                    Spawns: any;
                    Error: any;
                };
            }[];
        }>;
        ... 6 more ...;
        getMessageById: ProcessId;
    }>;
    spawn({ data, jwk, hbUrl, operator }: SpawnArgs): Promise<...>;
    message({ process, tags, data, jwk, hbUrl, operator }: MessageArgs): Promise<...>;
    result({ process, message, jwk, hbUrl, operator }: ResultArgs): Promise<...>;
}

globalThis.aoInstance: {
  MODE: string;
  spawn: (args: any) => Promise<any>;
  message: (args: any) => Promise<any>;
  result: (args: any) => Promise<{
    Output: any;
    Messages: any;
    Assignments: any;
    Spawns: any;
    Error: any;
  }>;
  results: (args: any) => Promise<{
    edges: {
      cursor: any;
      node: {
        Output: any;
        Messages: any;
        Assignments: any;
        Spawns: any;
        Error: any;
      };
    }[];
  }>;
  dryrun: (args: any) => Promise<{
    Output: any;
    Messages: any;
    Assignments: any;
    Spawns: any;
    Error: any;
  }>;
  request: (args: any) => Promise<any>;
  createSigner: any;
  createDataItemSigner: ((wallet: any) => (...args: unknown[]) => unknown) | (() => any);
  getMessages: Messages;
  getLastSlot: ProcessId;
  getMessageById: ProcessId;
};
```
See [this](https://Rs8Dr0I3-qPkiwKikoSjiwom3np1WqEDHolcpR6rjw4) (Arweave TxID: `Rs8Dr0I3-qPkiwKikoSjiwom3np1WqEDHolcpR6rjw4`) zip file of the full bridge implementation

### Dart Side
Purpose: provide a bridge implementation that interacts with the bundled JS WebView side and can be used by the rest of the app.

An `ArweaveWallet` instance is required for any interactions. We create one using the bridge. Once generated, we store it with `flutter_secure_storage`. For an additional layer of security, the wallet key is encrypted, and the user is prompted for a password to encrypt it. This template also implements an external raw jwk + password import for importing wallets that were not generated by the app.

Once we have a wallet, we pass its `jwk` into `globalThis.AOConnect.connect`, where `connect` creates a `signer` using the `ArweaveWallet` shim, then instantiates `globalThis.aoInstance` with the configured `hbUrl` and scheduler (operator ID of the HB node).

At that point, we have a properly configured `AOConnect` instance and can communicate with a HyperBEAM backend.

See [here](https://arweave.net/6CbfQClXwD4_J1Q_pLlXyDxInKRKw6ryaVacqevdDxQ) (TxId: `6CbfQClXwD4_J1Q_pLlXyDxInKRKw6ryaVacqevdDxQ`) for the Dart/Flutter code.

## Extended Explanations

### Why use a custom `ArweaveWallet` shim? 
The web implementation of AOConnect requires an `ArweaveWallet` instance, like what Wander injects into browsers. Our `jwk` is not that; it’s just the raw key file for a wallet. The app’s InAppWebView does not have access to a wallet implementation like Wander, but any custom wallet instance that satisfies the [API](https://www.npmjs.com/package/@permaweb/aoconnect#createsigner) AOConnect expects will work. So we create a custom wallet shim using `arbundles` that does exactly what we need for AOConnect.

Additionally, we can’t just use a wallet from `arweave`, because AOConnect doesn’t want “an Arweave wallet” in the `arweave-js` sense. It wants a signer that can produce signatures for the two formats AO uses, and in the browser build it specifically expects that signer to come from an injected-wallet style API (`globalThis.arweaveWallet`) that can sign `ANS-104` DataItems (and also handle HTTP signing). That’s a different abstraction than `arweave.wallets`.

### Why specifically use the web implementation of `aoconnect`? 
The only reasonable way to do JS <-> Dart communication is through an *InAppWebView*. Because of that, the AOConnect Node implementation doesn’t behave correctly in this setup. I first tried using it (mostly because of the `jwk` issue), but I couldn’t get past `Bad state: AOConnect JS error: Error: Failed to format request for signing`, so I switched back to the web implementation.

### Note for testing with local HyperBEAM instances
If you are testing on a local-ran HyperBEAM instance, you likely won’t be using `https`. If that’s the case, make sure you allow `cleartextTraffic` in your `AndroidManifest.xml`. I made a small rule that only allows it for `10.0.2.2`:
- File in `android/app/src/main/res/xml/network_security_config.xml`:
  ```xml
  <?xml version="1.0" encoding="utf-8"?>
  <network-security-config>
    <domain-config cleartextTrafficPermitted="true">
      <domain includeSubdomains="false">10.0.2.2</domain>
    </domain-config>
  </network-security-config>
  ```
- `AndroidManifest.xml` snippet:
  ```xml
  android:networkSecurityConfig="@xml/network_security_config"
  ```

### How do I set up a local HyperBEAM environment? 
There's documentation on that from the [official HyperBEAM documentation](https://hyperbeam.arweave.net/run/running-a-hyperbeam-node.html). But, from my experience that won't be enough to get you through it within a reasonable amount of time. HB is changing fast and the documentation in often out of date or missing crucial information. I made another tutorial on a fully-local HyperBEAM setup [here](https://arweave.net/J7x294SvLhHLr4UPtDERZ4JmEa7fnVmkszCqjSsKgoA) (TxId `J7x294SvLhHLr4UPtDERZ4JmEa7fnVmkszCqjSsKgoA`), which is relevant as of February 19, 2026


### MediaStore Plus Integration
To enable media store plus (allowing encrypted jwk file saving to device's downloads), this configuration is needed in `AndroidManifest.xml` (already is configured in this template repo):
```xml
<!-- required from API level 33 -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" /> <!-- To read images created by other apps -->
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" /> <!-- To read audios created by other apps -->
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" /> <!-- To read videos created by other apps -->

<uses-permission
    android:name="android.permission.READ_EXTERNAL_STORAGE" <!-- To read all files until API level 32 -->
    android:maxSdkVersion="32" />

<uses-permission
    android:name="android.permission.WRITE_EXTERNAL_STORAGE" <!-- To write all files until API level 29. We will MediaStore from API level 30 -->
    android:maxSdkVersion="29" />

<application
    ---------------------------
    android:requestLegacyExternalStorage="true"> 
    <!-- Need for API level 29. Scoped Storage has some issue in Android 10. So, google recommends to add this. -->
    <!-- Read more from here: https://developer.android.com/training/data-storage/shared/media#access-other-apps-files-->
</application>
