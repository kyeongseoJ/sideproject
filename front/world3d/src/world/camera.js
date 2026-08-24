import * as THREE from 'three';

export function createWorldCamera(width, height) {
  const aspect = width / Math.max(height, 1);
  const size = 6;
  const camera = new THREE.OrthographicCamera(-size * aspect, size * aspect, size, -size, 0.1, 100);
  camera.userData.viewSize = size;
  camera.position.set(7, 7, 9);
  camera.lookAt(0, 0, 0);
  return camera;
}

export function resizeWorldCamera(camera, width, height) {
  const aspect = width / Math.max(height, 1);
  const size = camera.userData.viewSize ?? 6;
  camera.left = -size * aspect;
  camera.right = size * aspect;
  camera.top = size;
  camera.bottom = -size;
  camera.updateProjectionMatrix();
}
