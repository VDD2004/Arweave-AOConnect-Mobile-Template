# AGENTS.md

## App Modification Guidelines

The markdown files in this repo intend to provide full guidance on working with Arweave and AO in a typical web app environment.

1. The `PERMAWEB_SKILLS.md` file provides information on best practices for Arweave uploads/queries, and AO process integrations. 
2. If the user asks to write an AO process, refer to `AO-PROCESS-GUIDE.md` for help on syntax and spec

## Chain App Rules

1. If a user asks to change this app, deploy after the change and include the deployed app link in the response.
2. Keep the current deploy pipeline and protocol. Do not switch uploader implementations unless the user explicitly asks.
3. Prefer the default gateway behavior in `scripts/deploy.mjs` (`https://arweave.net`). Only override with `--gateway` / `ARWEAVE_GATEWAY` when the user explicitly asks.
4. Before deploy, check wallet credentials in this order:
   - `--wallet=/absolute/path/to/wallet.json`
   - `ARWEAVE_WALLET`
   - `wallet.json` in the app root
5. If neither `ARWEAVE_WALLET` nor `wallet.json` exists, generate a new RSA-4096 JWK wallet at `wallet.json` and continue.
6. `npm run wallet:new` is the explicit wallet generation helper for agents/users.
7. Deploy order requirement:
   - Upload the app source code archive first.
   - Archive contents must be the app root itself (no wrapper directory).
   - Exclude only `wallet.json` and `node_modules`.
   - Preserve markdown files (`*.md`), including this `AGENTS.md`.
   - Upload the archive with `Content-Encoding: gzip` and gzip-encoded data.
8. When uploading app assets and the manifest, add tag `code` with the 43-character Arweave ID of the uploaded code archive.
9. Add `forked-from` on upload for the app transactions (code archive, assets, and manifest). Use `--forked-from=<arweave-id>` or `FORKED_FROM` when available.
10. In deployment output, provide both:
   - App URL
   - Code archive transaction ID/link
11. Repeatable command sequence:
   - `npm install`
   - `npm run wallet:new` (only if wallet is missing and you want explicit generation)
   - `npm run deploy:ship -- --wallet=/absolute/path/to/wallet.json --forked-from=<arweave-id>`
