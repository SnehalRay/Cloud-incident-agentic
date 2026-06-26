import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Vite dev server proxies the control-plane API so the browser can stay
// same-origin (relative /api/...). SSE (agent stream) passes through fine.
const CONTROL_PORT = process.env.CONTROL_PORT ?? '7070'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5174,
    strictPort: true,
    proxy: {
      '/api': {
        target: `http://localhost:${CONTROL_PORT}`,
        changeOrigin: true,
      },
    },
  },
})
