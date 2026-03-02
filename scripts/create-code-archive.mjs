#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { createReadStream, existsSync, mkdirSync } from "node:fs";
import path from "node:path";
import process from "node:process";

function parseArgs(argv) {
  const args = {};
  for (const token of argv) {
    if (!token.startsWith("--")) continue;
    const [k, v] = token.slice(2).split("=");
    args[k] = v ?? true;
  }
  return args;
}

function run(cmd, cmdArgs, opts = {}) {
  const res = spawnSync(cmd, cmdArgs, { stdio: "pipe", encoding: "utf8", ...opts });
  if (res.status !== 0) {
    const err = (res.stderr || res.stdout || "").trim();
    throw new Error(`${cmd} ${cmdArgs.join(" ")} failed: ${err}`);
  }
  return (res.stdout || "").trim();
}

async function sha256File(filePath) {
  return await new Promise((resolve, reject) => {
    const hash = createHash("sha256");
    const stream = createReadStream(filePath);
    stream.on("data", (chunk) => hash.update(chunk));
    stream.on("error", reject);
    stream.on("end", () => resolve(hash.digest("hex")));
  });
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const ref = String(args.ref || "HEAD");
  const outDir = path.resolve(String(args.out || "zips"));
  const ts = new Date().toISOString().replace(/[:.]/g, "-");
  const defaultName = `code-archive-${ts}.tar.gz`;
  const outName = String(args.name || defaultName);
  const outPath = path.join(outDir, outName);

  // Ensure we are in repo root context
  const repoRoot = run("git", ["rev-parse", "--show-toplevel"]);
  if (path.resolve(repoRoot) !== process.cwd()) {
    throw new Error(`Run this from repo root:\n  ${repoRoot}`);
  }

  if (!existsSync(outDir)) mkdirSync(outDir, { recursive: true });

  // Source snapshot from tracked files at ref
  run("git", ["archive", "--format=tar.gz", `--output=${outPath}`, ref], {
    cwd: repoRoot,
  });

  const commit = run("git", ["rev-parse", ref], { cwd: repoRoot });
  const digest = await sha256File(outPath);

  console.log("Archive created:");
  console.log(`- file: ${outPath}`);
  console.log(`- ref: ${ref}`);
  console.log(`- commit: ${commit}`);
  console.log(`- sha256: ${digest}`);
}

main().catch((err) => {
  console.error(`[create-code-archive] ${err.message}`);
  process.exit(1);
});