import { defineConfig } from "vite";
import { nodePolyfills } from "vite-plugin-node-polyfills";

export default defineConfig({
  build: {
    outDir: "../assets",
    emptyOutDir: false,
    rollupOptions: {
      input: "src/bridge.mjs",
      output: {
        entryFileNames: "arweave_bridge.js",
      },
    },
  },
  plugins: [
    nodePolyfills({
      protocolImports: true,
    }),
  ],
  define: {
    global: "globalThis",
  },
});