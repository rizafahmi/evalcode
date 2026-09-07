import { fileURLToPath } from "node:url"
import { defineConfig } from "vite"
import vue from "@vitejs/plugin-vue"

// Builds the Vue entry for the authenticated `/app` page straight into
// Phoenix's static assets (`priv/static/assets/vue`), so Phoenix serves the
// bundle in every environment:
//
//   * development — the watcher in config/dev.exs runs `vite build --watch`
//   * test/CI      — `vitest run` compiles the same components via this file
//   * production   — `mix assets.deploy` runs `npm run build` before digest
//
// There is deliberately no Vite dev server and no second OTP app: Phoenix is
// the only server and serves the built files, exactly like esbuild/tailwind.
export default defineConfig(({ mode }) => ({
  plugins: [vue()],

  // Anchor the config to this directory so the outDir below stays
  // repo-relative no matter where npm/vite is invoked from.
  root: fileURLToPath(new URL(".", import.meta.url)),
  base: "/assets/vue/",

  build: {
    outDir: "../priv/static/assets/vue",
    emptyOutDir: true,
    sourcemap: mode === "development",
    rollupOptions: {
      // Bundle the entry directly; there is no index.html in the assets app.
      input: "vue/main.ts",
      output: {
        // Stable names: the /app controller template references /assets/vue/app.js
        // directly (phx.digest fingerprints it for production).
        entryFileNames: "app.js",
        chunkFileNames: "chunks/[name]-[hash].js",
        assetFileNames: "assets/[name][extname]"
      }
    }
  }
}))
