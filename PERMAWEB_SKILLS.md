# PERMAWEB_SKILLS

Standalone reference for implementing Permaweb workflows inside a web app.
This document is intentionally self-contained and framework-agnostic.

It teaches by reusable in-app functions, not CLI wrappers.

## Purpose

Use this guide when you need to:
- upload files or a static site to Arweave
- attach ArNS records to uploaded content
- query Arweave data with GraphQL
- spawn and interact with AO processes from a web stack

## Operating Rules

1. Never log wallet JWK content, private keys, or API tokens.
2. Keep signing on trusted infrastructure (server, secure worker, or wallet provider).
3. Return concrete outputs after each operation:
- tx IDs
- process/message IDs
- canonical URLs
- one verification step
4. On failure, return:
- concise root cause
- one concrete recovery action

## Environment Model (Web-First)

This guide assumes:
- a web frontend (React/Vue/Svelte/vanilla)
- a backend API layer (Node runtime or serverless functions)

Recommended split:
- frontend: user input, progress UI, display IDs/URLs
- backend: secret handling, signing, upload execution, AO privileged actions

## Recommended Dependencies

```txt
@permaweb/arx
@ar.io/sdk
@permaweb/aoconnect
```

Optional for browser bundles that need Node polyfills:
```txt
vite-plugin-node-polyfills
```

## Configuration Contract

Use one runtime config object (env-backed on server):

```ts
type PermawebConfig = {
  turboUrl: string; // default: https://turbo.ardrive.io
  gatewayUrl: string; // default: https://arweave.net
  aoUrl: string; // default: https://push.forward.computer
  aoScheduler: string; // default: n_XZJhUnmldNFo4dhajoPZWhBXuJk-OcQr5JQ49c4Zo
  aoMode: "mainnet" | "legacy";
};
```

Mainnet default for AO should be `"mainnet"` unless explicitly overridden.

## Core Functions

Implement these as application services (for example, `/lib/permaweb.ts`).

### 1) Upload File to Arweave

```ts
import { NodeARx } from "@permaweb/arx/node";

export async function uploadFileToArweave(input: {
  filePath: string;
  walletJwk: Record<string, unknown>;
  turboUrl?: string;
  gatewayUrl?: string;
}) {
  const arx = new NodeARx({
    token: "arweave",
    url: input.turboUrl ?? "https://turbo.ardrive.io",
    key: input.walletJwk,
  });

  await arx.ready();
  const result = await arx.uploadFile(input.filePath);
  return {
    txId: result.id,
    url: `${input.gatewayUrl ?? "https://arweave.net"}/${result.id}`,
  };
}
```

### 2) Upload Static Site Folder (Manifest)

```ts
import { NodeARx } from "@permaweb/arx/node";

export async function uploadSiteFolder(input: {
  dirPath: string;
  indexFile?: string;
  walletJwk: Record<string, unknown>;
  turboUrl?: string;
  gatewayUrl?: string;
}) {
  const arx = new NodeARx({
    token: "arweave",
    url: input.turboUrl ?? "https://turbo.ardrive.io",
    key: input.walletJwk,
  });

  await arx.ready();
  const result = await arx.uploadFolder(input.dirPath, {
    indexFile: input.indexFile ?? "index.html",
  });

  return {
    manifestTxId: result.id,
    url: `${input.gatewayUrl ?? "https://arweave.net"}/${result.id}`,
  };
}
```

### 3) Attach ArNS Record to a Transaction

```ts
import {
  ANT,
  ARIO,
  AOProcess,
  ARIO_MAINNET_PROCESS_ID,
  ARIO_TESTNET_PROCESS_ID,
  ArweaveSigner,
} from "@ar.io/sdk/node";
import { connect } from "@permaweb/aoconnect";

export async function attachArnsRecord(input: {
  txId: string;
  name: string; // base name or undername format, e.g. docs_myname or myname
  walletJwk: Record<string, unknown>;
  network?: "mainnet" | "testnet";
  ttlSeconds?: number;
  aoUrl?: string;
  aoScheduler?: string;
}) {
  const raw = input.name.endsWith(".ar.io") ? input.name.slice(0, -6) : input.name;
  const [underMaybe, ...rest] = raw.split("_");
  const hasUndername = rest.length > 0;
  const undername = hasUndername ? underMaybe : "@";
  const baseName = hasUndername ? rest.join("_") : raw;

  const signer = new ArweaveSigner(input.walletJwk);
  const processId =
    (input.network ?? "mainnet") === "testnet"
      ? ARIO_TESTNET_PROCESS_ID
      : ARIO_MAINNET_PROCESS_ID;

  const ao = connect({
    MODE: "mainnet",
    URL: input.aoUrl ?? "https://push.forward.computer",
    SCHEDULER: input.aoScheduler ?? "n_XZJhUnmldNFo4dhajoPZWhBXuJk-OcQr5JQ49c4Zo",
  });

  const ario = ARIO.init({ signer, process: new AOProcess({ processId, ao }) });
  const arnsRecord = await ario.getArNSRecord({ name: baseName });
  if (!arnsRecord) throw new Error(`ArNS name not found: ${baseName}`);

  const ant = ANT.init({
    signer,
    process: new AOProcess({ processId: arnsRecord.processId, ao }),
  });

  await ant.setRecord({
    undername,
    transactionId: input.txId,
    ttlSeconds: input.ttlSeconds ?? 3600,
  });

  return {
    name: input.name,
    baseName,
    undername,
    txId: input.txId,
    url: `https://${baseName}.arweave.net`,
  };
}
```

### 4) Query Arweave GraphQL

```ts
export async function queryArweaveGraphQL<T>(query: string, variables?: Record<string, unknown>) {
  const res = await fetch("https://arweave.net/graphql", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ query, variables }),
  });

  if (!res.ok) {
    throw new Error(`GraphQL request failed: ${res.status} ${res.statusText}`);
  }

  const data = await res.json();
  if (data.errors?.length) throw new Error(data.errors[0].message);
  return data.data as T;
}
```

### 5) AO Client Factory + Operations

```ts
import { connect, createSigner } from "@permaweb/aoconnect";

export function createAoClient(input: {
  walletJwk: Record<string, unknown>;
  mode?: "mainnet" | "legacy";
  aoUrl?: string;
  aoScheduler?: string;
}) {
  return connect({
    MODE: input.mode ?? "mainnet",
    URL: input.aoUrl ?? "https://push.forward.computer",
    SCHEDULER: input.aoScheduler ?? "n_XZJhUnmldNFo4dhajoPZWhBXuJk-OcQr5JQ49c4Zo",
    signer: createSigner(input.walletJwk),
  });
}

export async function aoSpawn(ao: ReturnType<typeof createAoClient>, input: {
  authority: string;
  module: string;
  data?: string;
  tags?: Array<{ name: string; value: string }>;
}) {
  return ao.spawn({
    authority: input.authority,
    module: input.module,
    data: input.data ?? "",
    tags: input.tags ?? [{ name: "App-Action", value: "Spawn" }],
  });
}

export async function aoMessage(ao: ReturnType<typeof createAoClient>, input: {
  process: string;
  data?: string;
  tags?: Array<{ name: string; value: string }>;
}) {
  return ao.message({
    process: input.process,
    data: input.data ?? "",
    tags: input.tags ?? [{ name: "App-Action", value: "Message" }],
  });
}

export async function aoResult(ao: ReturnType<typeof createAoClient>, input: {
  process: string;
  message: string;
}) {
  return ao.result(input);
}

export async function aoDryrun(ao: ReturnType<typeof createAoClient>, input: {
  process: string;
  message: string;
}) {
  return ao.dryrun(input);
}
```

AO tag guidance:
- prefer dash-separated tag names (`App-Action`) over consecutive uppercase styles (`AppAction`)
- keep names stable and explicit for downstream indexing

## Verification Patterns

Use fetch from backend or frontend:

```ts
export async function verifyArweaveTx(txId: string) {
  const res = await fetch(`https://arweave.net/${txId}`, { method: "HEAD" });
  return { ok: res.ok, status: res.status };
}

export async function verifyArns(name: string) {
  const res = await fetch(`https://${name}.arweave.net`, { method: "HEAD" });
  return { ok: res.ok, status: res.status };
}
```

## Agent Execution Checklist

Before action:
1. Confirm required IDs, names, and target network.
2. Confirm signing context is secure (server/wallet provider, not exposed client key).
3. Confirm AO mode is mainnet unless user explicitly requests legacy.

After action:
1. Return transaction/process/message IDs.
2. Return final URLs.
3. Return one verification step.
4. Return one recommended next action.

## Failure Handling Contract

For each failed operation, return:
- `error.code` (machine-readable)
- `error.message` (human-readable)
- `error.recovery` (single best next step)

Examples:
- `ARNS_NAME_NOT_FOUND`: "ArNS name not found: myname" -> "Verify ownership and correct base name."
- `AO_RESULT_TIMEOUT`: "Result not available yet" -> "Poll result again in 2-5 seconds."
- `GRAPHQL_GATEWAY_ERROR`: "Primary gateway unavailable" -> "Retry with alternate gateway."
