import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 5173,
    strictPort: true,
    allowedHosts: ['nginx', 'docker', 'localhost', '127.0.0.1'],
    hmr: {
      host: 'localhost',
      port: 8088,
      protocol: 'ws',
      clientPort: 8088,
    },
  },
})
