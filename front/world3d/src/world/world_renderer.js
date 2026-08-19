import * as THREE from 'three';
import { createWorldCamera, resizeWorldCamera } from './camera.js';
import { loadGlb } from './glb_loader.js';
import { createWorldLighting } from './lighting.js';
import { switchLevelModel } from './level_model_switcher.js';
import { placeObject } from './object_placement.js';
import { createSimpleAnimation } from './simple_animation.js';

export class WorldRenderer {
  constructor(root) {
    if (!root) {
      throw new Error('World renderer root element is required.');
    }

    this.root = root;
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0xf2f2f3);
    this.camera = createWorldCamera(innerWidth, innerHeight);
    this.renderer = new THREE.WebGLRenderer({ antialias: true });
    this.renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
    this.renderer.setSize(innerWidth, innerHeight);
    this.root.appendChild(this.renderer.domElement);
    this.scene.add(...createWorldLighting());

    this.clock = new THREE.Clock();
    this.levelObjects = new Map();
    this.mixers = new Map();
    this.animationFrame = null;
    this.resizeHandler = () => this.resize();
    addEventListener('resize', this.resizeHandler);
  }

  async loadLevel({ objectKey, assetUri, transform }) {
    const gltf = await loadGlb(assetUri);
    const nextObject = placeObject(gltf.scene, transform);
    const currentObject = this.levelObjects.get(objectKey);
    this.levelObjects.set(
      objectKey,
      switchLevelModel(this.scene, currentObject, nextObject),
    );

    const mixer = createSimpleAnimation(nextObject, gltf.animations);
    if (mixer) {
      this.mixers.set(objectKey, mixer);
    } else {
      this.mixers.delete(objectKey);
    }
  }

  start() {
    if (this.animationFrame !== null) {
      return;
    }

    const render = () => {
      const delta = this.clock.getDelta();
      for (const mixer of this.mixers.values()) {
        mixer.update(delta);
      }
      this.renderer.render(this.scene, this.camera);
      this.animationFrame = requestAnimationFrame(render);
    };
    render();
  }

  resize() {
    resizeWorldCamera(this.camera, innerWidth, innerHeight);
    this.renderer.setSize(innerWidth, innerHeight);
  }

  destroy() {
    removeEventListener('resize', this.resizeHandler);
    if (this.animationFrame !== null) {
      cancelAnimationFrame(this.animationFrame);
    }
    this.renderer.dispose();
    this.renderer.domElement.remove();
  }
}
