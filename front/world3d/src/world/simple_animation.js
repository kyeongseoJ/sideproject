import * as THREE from 'three';

export function createSimpleAnimation(object, clips) {
  if (!clips || clips.length === 0) {
    return null;
  }

  const mixer = new THREE.AnimationMixer(object);
  mixer.clipAction(clips[0]).play();
  return mixer;
}
