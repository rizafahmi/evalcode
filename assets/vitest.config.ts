import { defineConfig } from "vitest/config"
import vue from "@vitejs/plugin-vue"

// Vitest coverage for the Vue application. jsdom gives us a DOM so the
// components really mount; the fetch stub keeps tests offline and deterministic.
export default defineConfig({
  plugins: [vue()],
  test: {
    environment: "jsdom",
    include: ["vue/**/*.test.ts"]
  }
})
