import fs from "node:fs/promises";
import path from "node:path";
import { spawn } from "node:child_process";
import { gzipSync } from "node:zlib";
import process from "node:process";
import Arweave from "arweave";

const root = process.cwd();

function parseArg(name) {
  const raw = process.argv.find((arg) => arg.startsWith(`--${name}=`));
  return raw ? raw.slice(name.length + 3).trim() : "";
}

function runBinary(command, args, cwd = root) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { cwd, stdio: ["ignore", "pipe", "pipe"] });
    const out = [];
    let err = "";

    child.stdout.on("data", (chunk) => out.push(chunk));
    child.stderr.on("data", (chunk) => (err += chunk.toString()));
    child.on("error", reject);
    child.on("close", (code) => {
      if (code !== 0) {
        reject(new Error(`${command} ${args.join(" ")} failed (${code}) ${err.trim()}`));
        return;
      }
      resolve({ stdout: Buffer.concat(out), stderr: err });
    });
  });
}

function buildGatewayConfig(gateway) {
  const u = new URL(gateway);
  return {
    host: u.hostname,
    port: u.port ? Number.parseInt(u.port, 10) : u.protocol === "https:" ? 443 : 80,
    protocol: u.protocol.replace(":", ""),
  };
}

async function loadWallet(walletArg) {
  const chosen = walletArg || process.env.ARWEAVE_WALLET?.trim() || "wallet.json";
  const walletPath = path.resolve(root, chosen);
  const raw = await fs.readFile(walletPath, "utf8");
  return { walletPath, jwk: JSON.parse(raw) };
}

async function createCodeArchive({ ref = "HEAD" } = {}) {
  const commit = (await runBinary("git", ["rev-parse", ref], root)).stdout.toString("utf8").trim();
  const tar = await runBinary("git", ["archive", "--format=tar", ref], root);
  return { commit, data: gzipSync(tar.stdout) };
}

async function uploadTransaction(arweave, jwk, data, tags) {
  const tx = await arweave.createTransaction({ data }, jwk);
  for (const [k, v] of tags) tx.addTag(k, String(v));
  await arweave.transactions.sign(tx, jwk);

  const uploader = await arweave.transactions.getUploader(tx);
  while (!uploader.isComplete) await uploader.uploadChunk();

  return tx.id;
}

async function main() {
  const walletArg = parseArg("wallet");
  const gateway = parseArg("gateway") || process.env.ARWEAVE_GATEWAY || "https://arweave.net";
  const publicGateway = parseArg("public-gateway") || gateway;
  const ref = parseArg("ref") || "HEAD";
  const appName = parseArg("app-name") || process.env.APP_NAME || "Arweave-AOConnect-Mobile-Template";
  const appVersion = parseArg("app-version") || process.env.APP_VERSION || "0.1.0";
  const forkedFrom = (parseArg("forked-from") || process.env.FORKED_FROM || "").trim();

  const { walletPath, jwk } = await loadWallet(walletArg);
  const arweave = Arweave.init({ ...buildGatewayConfig(gateway), timeout: 30_000, logging: false });

  console.log(`Using wallet: ${walletPath}`);
  console.log(`Gateway: ${gateway}`);

  const { commit, data } = await createCodeArchive({ ref });

  const codeArchiveId = await uploadTransaction(arweave, jwk, data, [
    ["Content-Type", "application/gzip"],
    ["Content-Encoding", "gzip"],
    ["App-Name", appName],
    ["App-Version", appVersion],
    ["Type", "code-archive"],
    ["Source-Ref", ref],
    ["Source-Commit", commit],
    ...(forkedFrom ? [["forked-from", forkedFrom]] : []),
  ]);

  const base = publicGateway.replace(/\/+$/, "");
  console.log("");
  console.log(`Code Archive ID: ${codeArchiveId}`);
  console.log(`Code Archive URL: ${base}/${codeArchiveId}`);
  console.log("");
}

main().catch((error) => {
  console.error(error?.message || error);
  process.exitCode = 1;
});