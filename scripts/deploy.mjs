import fs from "node:fs/promises";
import path from "node:path";
import { spawn } from "node:child_process";
import { gzipSync } from "node:zlib";
import process from "node:process";
import Arweave from "arweave";

const root = process.cwd();

function parseArg(name) {
  const eqPrefix = `--${name}=`;
  const exact = `--${name}`;
  for (let i = 0; i < process.argv.length; i += 1) {
    const arg = process.argv[i];
    if (arg.startsWith(eqPrefix)) return arg.slice(eqPrefix.length).trim();
    if (arg === exact) return (process.argv[i + 1] || "").trim();
  }
  return "";
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

async function resolveCommit(ref = "HEAD") {
  return (await runBinary("git", ["rev-parse", ref], root)).stdout.toString("utf8").trim();
}

async function createCodeArchive({ ref = "HEAD" } = {}) {
  const commit = await resolveCommit(ref);
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

  const targetRaw = (parseArg("target") || "code").toLowerCase();
  const target = targetRaw === "archive" ? "code" : targetRaw;
  if (!["code", "apk", "both"].includes(target)) {
    throw new Error(`Invalid --target value "${targetRaw}". Use one of: code, apk, both`);
  }

  const apkPathArg = parseArg("apk-path") || "build/app/outputs/apk/release/app-release.apk";
  const apkPath = path.resolve(root, apkPathArg);
  const explicitCodeId = parseArg("code-id");

  const { walletPath, jwk } = await loadWallet(walletArg);
  const arweave = Arweave.init({ ...buildGatewayConfig(gateway), timeout: 30_000, logging: false });

  console.log(`Using wallet: ${walletPath}`);
  console.log(`Gateway: ${gateway}`);
  console.log(`Target: ${target}`);

  const base = publicGateway.replace(/\/+$/, "");

  const shouldUploadCode = target === "code" || target === "both";
  const shouldUploadApk = target === "apk" || target === "both";

  let commit = "";
  let codeArchiveId = "";

  if (shouldUploadCode) {
    const archive = await createCodeArchive({ ref });
    commit = archive.commit;

    codeArchiveId = await uploadTransaction(arweave, jwk, archive.data, [
      ["Content-Type", "application/gzip"],
      ["Content-Encoding", "gzip"],
      ["App-Name", appName],
      ["App-Version", appVersion],
      ["Type", "code-archive"],
      ["Source-Ref", ref],
      ["Source-Commit", commit],
      ...(forkedFrom ? [["forked-from", forkedFrom]] : []),
    ]);

    console.log("");
    console.log(`Code Archive ID: ${codeArchiveId}`);
    console.log(`Code Archive URL: ${base}/${codeArchiveId}`);
  }

  if (shouldUploadApk) {
    const apkData = await fs.readFile(apkPath);
    if (!commit) commit = await resolveCommit(ref);

    const codeRef = codeArchiveId || explicitCodeId;
    const apkId = await uploadTransaction(arweave, jwk, apkData, [
      ["Content-Type", "application/vnd.android.package-archive"],
      ["App-Name", appName],
      ["App-Version", appVersion],
      ["Type", "release-apk"],
      ["File-Name", path.basename(apkPath)],
      ["Source-Ref", ref],
      ["Source-Commit", commit],
      ...(codeRef ? [["code", codeRef]] : []),
      ...(forkedFrom ? [["forked-from", forkedFrom]] : []),
    ]);

    console.log("");
    console.log(`APK Path: ${apkPath}`);
    console.log(`APK ID: ${apkId}`);
    console.log(`APK URL: ${base}/${apkId}`);
  }

  console.log("");
}

main().catch((error) => {
  console.error(error?.message || error);
  process.exitCode = 1;
});