import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

const loader = new GLTFLoader();

export function loadGlb(assetUri) {
  if (!assetUri) {
    return Promise.reject(new Error('GLB asset URI is required.'));
  }
  return loader.loadAsync(assetUri).catch((error) => {
    throw new Error(`GLB 로드 실패 (${assetUri}): ${error.message ?? error}`);
  });
}
