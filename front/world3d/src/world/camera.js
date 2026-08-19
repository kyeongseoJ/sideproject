import * as THREE from 'three';

export function createWorldCamera(width, height) {
  const camera = new THREE.PerspectiveCamera(45, width / height, 0.1, 100);
  camera.position.set(6, 5, 8);
  camera.lookAt(0, 0, 0);
  return camera;
}

export function resizeWorldCamera(camera, width, height) {
  camera.aspect = width / height;
  camera.updateProjectionMatrix();
}
