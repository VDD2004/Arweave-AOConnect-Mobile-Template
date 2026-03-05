# NEXT_AGENT_BRIEF

## Mission
Continue converting this Flutter template into a **Permaweb seed-style forkable project**, starting from docs/tooling hardening without breaking wallet/bridge security invariants.

Primary spec:
- [TODO.md](TODO.md)
- [LLMS.md](LLMS.md)

---

## Current state snapshot

- Flutter app + hidden WebView bridge are working architecture.
- Wallet flows are implemented (create/login/import/account hash).
- AO demo flow exists on authenticated home screen.
- Seed-style packaging/deploy pipeline is **not fully added yet** (work in progress).

---

## Immediate priorities

1. Finalize step-by-step seed-style packaging plan from [TODO.md](TODO.md).
2. Add deploy/tooling skeleton (`scripts/`) after confirming desired deploy target.
3. Keep all security invariants in [LLMS.md](LLMS.md) intact.

---

## Non-negotiable constraints

- Preserve [`main._Bootstrap`](lib/main.dart) WebView init ordering.
- Preserve [`services.WalletVault.attemptLogin`](lib/services/wallet_vault.dart) validation behavior.
- Preserve JWK sign-check validation in login/import flows:
  - [lib/screens/login_screen.dart](lib/screens/login_screen.dart)
  - [lib/screens/import_external_wallet.dart](lib/screens/import_external_wallet.dart)
- Do not weaken crypto defaults without migration notes.

---

## Key files to inspect first

- [lib/main.dart](lib/main.dart)
- [lib/services/wallet_vault.dart](lib/services/wallet_vault.dart)
- [lib/services/arweavejs.dart](lib/services/arweavejs.dart)
- [lib/services/aoconnect.dart](lib/services/aoconnect.dart)
- [arweave_bridge/src/bridge.mjs](arweave_bridge/src/bridge.mjs)
- [arweave_bridge/src/aoconnect_bridge.mjs](arweave_bridge/src/aoconnect_bridge.mjs)
- [arweave_bridge/vite.config.js](arweave_bridge/vite.config.js)
- [README.md](README.md)
- [notes.md](notes.md)
- [TODO.md](TODO.md)

---

## Commands

### Run app
- `flutter pub get`
- `flutter run`

### Rebuild JS bridge
- `cd arweave_bridge`
- `npm install`
- `npm run build`
- `cd ..`

### Deploy (canonical)
- `npm run deploy`
- `node scripts/deploy.mjs --wallet=/absolute/path/to/wallet.json --target=both --apk-path=build/app/outputs/apk/release/app-release.apk`
- Use explicit `--key=value` flags for consistency across shells.

---

## Expected deliverable style (seed-like)

When deploy tooling is added, aim to output:
1. App/manifest URL
2. Code archive URL

Keep docs explicit so a new fork can run in ~2 minutes.

---

## Recommended next PR scope

- Add minimal deploy script placeholders + command wiring in package scripts
- Add wallet generation helper script stub and ignore rules
- Update README with “fork + deploy” section
- Keep changes small and reviewable

---

## Handoff rule

If implementation diverges from docs, update docs in same change set:
- [README.md](README.md)
- [notes.md](notes.md)
- [LLMS.md](LLMS.md)
- [AGENT_HANDOFF.md](AGENT_HANDOFF.md)
- [NEXT_AGENT_BRIEF.md](NEXT_AGENT_BRIEF.md)

## Permaweb-style packaging goal (mobile adaptation)

This repo follows the permaweb-os seed pattern **in spirit** for mobile:

- fork/handoff docs included
- upload immutable source archive to Arweave for provenance/distribution
- distribute APK/IPA through release channels (not manifest hosting)

Do **not** add manifest-hosting assumptions for runtime deployment.