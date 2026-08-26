import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { clone } from 'three/addons/utils/SkeletonUtils.js';

const loader = new GLTFLoader();
const cache = new Map();

export function loadGlb(assetUri) {
  if (!assetUri) {
    return Promise.reject(new Error('GLB asset URI is required.'));
  }
  let cached = cache.get(assetUri);
  if (!cached) {
    cached = loader.loadAsync(assetUri);
    cache.set(assetUri, cached);
  }
  return cached.then((gltf) => ({
    ...gltf,
    scene: clone(gltf.scene),
  })).catch((error) => {
    cache.delete(assetUri);
    throw new Error(`GLB 로드 실패 (${assetUri}): ${error.message ?? error}`);
  });
}
