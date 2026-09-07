/// <reference types="vitest/config" />
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import path from 'node:path'

export default defineConfig({
  plugins: [vue()],
  define: {
    'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV || 'production')
  },
  build: {
    outDir: path.resolve(import.meta.dirname, '../priv/static/assets/js'),
    emptyOutDir: false,
    lib: {
      entry: path.resolve(import.meta.dirname, 'vue/main.ts'),
      name: 'AlurVue',
      formats: ['iife'],
      fileName: () => 'vue.js'
    }
  },
  test: {
    environment: 'happy-dom'
  }
})
