import * as THREE from 'three';

export function createWorldLighting() {
  const ambient = new THREE.HemisphereLight(0xffffff, 0xd3e2fc, 1.6);
  const key = new THREE.DirectionalLight(0xffffff, 2.2);
  key.position.set(5, 8, 4);
  return [ambient, key];
}
