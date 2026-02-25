import "arweave/web"; // side-effect: defines globalThis.Arweave
import { injectArweaveWalletShim } from "./wallet_shim.mjs";

const ArweaveLib = globalThis.Arweave;

if (!ArweaveLib || typeof ArweaveLib.init !== "function") {
  throw new Error("Arweave web bundle did not initialize (globalThis.Arweave.init missing)");
}

const arweave = ArweaveLib.init({
  host: "arweave.net",
  port: 443,
  protocol: "https",
});

// base64url helpers (no padding)
function toBase64Url(bytes) {
  const bin = String.fromCharCode(...bytes);
  const b64 = btoa(bin);
  return b64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function fromBase64Url(b64url) {
  let b64 = b64url.replace(/-/g, "+").replace(/_/g, "/");
  while (b64.length % 4) b64 += "=";
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

// Expose a single global object for Flutter to call.
globalThis.ArweaveBridge = {
  async generateWallet() {
    const jwk = await arweave.wallets.generate();
    const address = await arweave.wallets.jwkToAddress(jwk);
    return { jwk, address };
  },

  async getAddress(jwk) {
    const address = await arweave.wallets.jwkToAddress(jwk);
    return { address };
  },

  // messageBytesB64Url should be raw bytes of your challenge/nonce/message
  async sign(jwk, messageBytesB64Url) {
    const bytes = fromBase64Url(messageBytesB64Url);
    const sigBytes = await arweave.crypto.sign(jwk, bytes);
    return { signatureB64Url: toBase64Url(sigBytes) };
  }
};

injectArweaveWalletShim(arweave);

import "./aoconnect_bridge.mjs";
