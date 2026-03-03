import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import { frontmanPlugin } from '@frontman-ai/vite';

export default defineConfig({
  server: {
    port: 5199,
  },
  optimizeDeps: {
    include: ['react', 'react-dom', 'react/jsx-runtime'],
    exclude: ['@frontman-ai/client'],
  },
  resolve: {
    dedupe: ['react', 'react-dom'],
  },
  plugins: [
    react(),
    tailwindcss(),
    frontmanPlugin({
      isDev: true,
      entrypointUrl: 'http://localhost:3000/frontman',
    }),
  ],
});
