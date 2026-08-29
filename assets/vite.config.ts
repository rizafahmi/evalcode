import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import { resolve } from "node:path";

const mixEnv = process.env.MIX_ENV || "dev";

export default defineConfig({
  plugins: [vue()],
  publicDir: false,
  build: {
    outDir: resolve(__dirname, "../priv/static/assets"),
    emptyOutDir: false,
    sourcemap: true,
    commonjsOptions: { include: [/node_modules/, /vendor/] },
    rollupOptions: {
      input: {
        app: resolve(__dirname, "js/app.js"),
        dashboard: resolve(__dirname, "js/dashboard/main.ts"),
      },
      output: {
        entryFileNames: "js/[name].js",
        chunkFileNames: "js/[name].js",
        assetFileNames: "js/[name][extname]",
      },
    },
  },
  resolve: {
    alias: {
      "phoenix-colocated": resolve(
        __dirname,
        `../_build/${mixEnv}/phoenix-colocated`,
      ),
    },
  },
  test: {
    environment: "jsdom",
    include: ["js/**/*.test.ts"],
  },
});
