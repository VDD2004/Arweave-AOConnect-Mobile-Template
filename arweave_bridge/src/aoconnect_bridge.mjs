import { createSigner, connect, spawn, message as aoMessage, result as aoResult } from "@permaweb/aoconnect";

/** @type {ReturnType<typeof connect> | null} */
globalThis.aoInstance = null;

/**
 * @typedef {Object} AOConnectionArgs
 * @property {Record<string, any>} jwk
 * @property {string} hbUrl
 * @property {string} operator
 */

/**
 * @typedef {Object} SpawnArgs
 * @property {string} [data]
 * @property {Record<string, any>} [jwk]
 * @property {string} [hbUrl]
 * @property {string} [operator]
 */

/**
 * @typedef {Object} MessageArgs
 * @property {string} process
 * @property {Array<{name: string, value: string}>} [tags]
 * @property {string} [data]
 * @property {Record<string, any>} [jwk]
 * @property {string} [hbUrl]
 * @property {string} [operator]
 */

/**
 * @typedef {Object} ResultArgs
 * @property {string} process
 * @property {string} message
 * @property {Record<string, any>} [jwk]
 * @property {string} [hbUrl]
 * @property {string} [operator]
 */

/**
 * @typedef {Object} DoActionConfig
 * @property {(args: Record<string, any>) => Promise<any>} action
 * @property {(instance: ReturnType<typeof connect>, args: Record<string, any>) => Promise<any>} [aoInstanceAction]
 * @property {Record<string, any>} [jwk]
 * @property {Record<string, any>} [args]
 */

/**
 * @typedef {Object} MethodActionConfig
 * @property {(args: Record<string, any>) => Promise<any>} action
 * @property {"spawn" | "message" | "result"} methodName
 * @property {Record<string, any>} payload
 * @property {Record<string, any>} [jwk]
 * @property {string} [hbUrl]
 * @property {string} [operator]
 */

/**
 * @param {Record<string, any>} jwk
 * @param {string} hbUrl
 * @param {string} operator
 */
function createConnectedInstance(jwk, hbUrl, operator) {
  // Set the JWK for the wallet shim to use
  globalThis.__JWK__ = jwk;

  return connect({
    MODE: "mainnet",
    signer: createSigner(globalThis.arweaveWallet),
    URL: hbUrl,
    SCHEDULER: operator
  });
}

/**
 * @param {Record<string, any>} args
 */
function stripConnectionArgs(args) {
  const { hbUrl: _hbUrl, operator: _operator, ...actionArgs } = args;
  return actionArgs;
}

/**
 * @param {Record<string, any> | undefined} jwk
 * @param {Record<string, any>} args
 */
function hasDirectConnectionArgs(jwk, args) {
  return Boolean(jwk && args.hbUrl && args.operator);
}

/**
 * @param {DoActionConfig} config
 */
async function doAction({ action, aoInstanceAction, jwk, args = {} }) {
  if (hasDirectConnectionArgs(jwk, args) && aoInstanceAction) {
    const tempInstance = createConnectedInstance(jwk, args.hbUrl, args.operator);
    return await aoInstanceAction(tempInstance, args);
  }

  if (globalThis.aoInstance && aoInstanceAction) {
    return await aoInstanceAction(globalThis.aoInstance, args);
  }

  if (hasDirectConnectionArgs(jwk, args)) {
    globalThis.__JWK__ = jwk;
    return await action({ ...args, signer: createSigner(globalThis.arweaveWallet) });
  }

  throw new Error(
    "doAction requires either (jwk, args.hbUrl, args.operator) or a prior AOConnect.connect call"
  );
}

/**
 * @param {MethodActionConfig} config
 */
async function doMethodAction({ action, methodName, payload, jwk, hbUrl, operator }) {
  try {
    return await doAction({
      action,
      aoInstanceAction: async (instance, args) => {
        return await instance[methodName](stripConnectionArgs(args));
      },
      jwk,
      args: { ...payload, hbUrl, operator }
    });
  } catch (error) {
    console.error("doMethodAction error:", error);
    throw error;
  }
}

globalThis.AOConnect = {
  /**
   * @param {Record<string, any>} jwk
   * @param {string} hbUrl
   * @param {string} operator
   */
  async connect(jwk, hbUrl, operator) {
    globalThis.aoInstance = createConnectedInstance(jwk, hbUrl, operator);
    return globalThis.aoInstance;
  },

  /**
   * @param {SpawnArgs} params
   */
  async spawn({ data = "", jwk, hbUrl, operator }) {
    return await doMethodAction({
      action: spawn,
      methodName: "spawn",
      payload: { data },
      jwk,
      hbUrl,
      operator
    });
  },

  /**
   * @param {MessageArgs} params
   */
  async message({ process, tags = [], data = "", jwk, hbUrl, operator }) {
    return await doMethodAction({
      action: aoMessage,
      methodName: "message",
      payload: { process, tags, data },
      jwk,
      hbUrl,
      operator
    });
  },

  /**
   * @param {ResultArgs} params
   */
  async result({ process, message, jwk, hbUrl, operator }) {
    return await doMethodAction({
      action: aoResult,
      methodName: "result",
      payload: { process, message },
      jwk,
      hbUrl,
      operator
    });
  }
};
