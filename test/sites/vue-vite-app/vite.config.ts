import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import { frontmanPlugin } from '@frontman-ai/vite';

export default defineConfig({
  plugins: [
    frontmanPlugin(),
    vue(),
  ],
});
