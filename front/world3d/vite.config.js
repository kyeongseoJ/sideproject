import { defineConfig } from 'vite';

export default defineConfig({
  base: './',
  build: {
    outDir: '../app/assets/world3d',
    emptyOutDir: true,
  },
});
