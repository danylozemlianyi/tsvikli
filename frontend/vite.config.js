import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import path from 'path'

export default defineConfig(({ mode }) => ({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: mode === 'development' ? {
    proxy: {
      '/guacamole': {
        target: 'http://localhost:8080',
        changeOrigin: true,
        rewrite: (p) => p.replace(/^\/guacamole/, '/guacamole'),
      }
    }
  } : undefined,
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  },
  base: '/',
}))
