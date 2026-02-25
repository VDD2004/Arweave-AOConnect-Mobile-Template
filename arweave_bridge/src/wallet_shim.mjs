import { createData, ArweaveSigner } from "@dha-team/arbundles";
// ---- Wander-style wallet shim for aoconnect browser signer ----
//
// aoconnect browser createSigner expects a window/globalThis.arweaveWallet instance
/**
 * @typedef {Object} ArweaveWallet
 * @property {() => Promise<string>} getActiveAddress - Gets the currently active Arweave wallet address
 * @property {(data: string|Uint8Array|ArrayBuffer, options?: {hashAlgorithm?: string}) => Promise<ArrayBuffer>} signMessage - Signs an arbitrary message using RSA-PSS with optional hash algorithm
 * @property {(dataItem: {data: string|Uint8Array|ArrayBuffer, target?: string, anchor?: string, tags?: Array<{name: string, value: string}>}) => Promise<Uint8Array>} signDataItem - Signs a DataItem for AO mainnet transactions
 * @property {() => Promise<void>} connect - Establishes a connection to the wallet
 * @property {() => Promise<string[]>} getPermissions - Retrieves the list of granted permissions
 */

/**
 * Arweave wallet shim for aoconnect browser signer integration.
 * Provides Wander-style wallet interface compatible with aoconnect's createSigner.
 * Requires globalThis.__JWK__ to be set before signing operations.
 * 
 * @type {ArweaveWallet}
 */
globalThis.arweaveWallet;

globalThis.__JWK__ = null; // will be set by Flutter before calling AO

function requireJwk() {
  if (!globalThis.__JWK__) throw new Error("Missing globalThis.__JWK__ (set it before signing).");
  return globalThis.__JWK__;
}

function toUint8(data) {
  if (data instanceof Uint8Array) return data;
  if (typeof data === "string") return new TextEncoder().encode(data);
  // Allow ArrayBuffer as well
  if (data instanceof ArrayBuffer) return new Uint8Array(data);
  throw new Error("Unsupported data type for DataItem.data (expected string|Uint8Array|ArrayBuffer).");
}

export function injectArweaveWalletShim(arweave) {
  globalThis.arweaveWallet = {
    // aoconnect + many dapps use this to identify the active wallet. :contentReference[oaicite:23]{index=23}
    async getActiveAddress() {
      const jwk = requireJwk();
      return await arweave.wallets.jwkToAddress(jwk);
    },

    async signMessage(data, options) {
      // ignore options.hashAlgorithm for now unless you have a hard need
      const jwk = requireJwk();
      const bytes = toUint8(data);
      const sigBytes = await arweave.crypto.sign(jwk, bytes);
      // return ArrayBuffer or Uint8Array; aoconnect can work with bytes
      return sigBytes.buffer ?? sigBytes;
    },

    // Required for AO mainnet DataItem signing via browser createSigner. :contentReference[oaicite:25]{index=25}
    async signDataItem(dataItem) {
      const jwk = requireJwk();
      const signer = new ArweaveSigner(jwk);

      const signed = createData(toUint8(dataItem.data), signer, {
        target: dataItem.target,
        anchor: dataItem.anchor,
        tags: dataItem.tags ?? [],
      });

      // DataItem.sign exists in @dha-team/arbundles web build. :contentReference[oaicite:26]{index=26}
      await signed.sign(signer);

      // Return raw bytes (Wander returns a buffer of the signed data item). :contentReference[oaicite:27]{index=27}
      const raw = signed.getRaw(); // Buffer
      return new Uint8Array(raw);
    },

    // Optional “wallet UX” methods (safe no-ops for your mobile local wallet)
    async connect() { return; },
    async getPermissions() { return []; },
  };
}