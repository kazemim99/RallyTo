import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue()],
  server: {
    host: true,
    // AsanRezerve's admin uses 5173; Rallyto's takes the next port so both can run side by side.
    port: 5174,
    strictPort: true,
  },
  build: {
    sourcemap: true,
  },
})
