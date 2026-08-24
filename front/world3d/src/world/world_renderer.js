import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
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
    this.controls = new OrbitControls(this.camera, this.renderer.domElement);
    this.controls.enablePan = false;
    this.controls.minZoom = 0.8;
    this.controls.maxZoom = 1.8;
    this.controls.minPolarAngle = Math.PI / 4;
    this.controls.maxPolarAngle = Math.PI / 2.35;
    this.controls.minAzimuthAngle = -Math.PI / 3;
    this.controls.maxAzimuthAngle = Math.PI / 3;
    this.controls.target.set(0, 0.6, 0);
    this.controls.update();
    this.levelObjects = new Map();
    this.mixers = new Map();
    this.animationFrame = null;
    this.resizeHandler = () => this.resize();
    this.selectionHandler = (event) => this.selectAt(event);
    this.pointerStart = null;
    this.pointerDownHandler = (event) => {
      this.pointerStart = { x: event.clientX, y: event.clientY };
    };
    addEventListener('resize', this.resizeHandler);
    this.renderer.domElement.addEventListener('pointerdown', this.pointerDownHandler);
    this.renderer.domElement.addEventListener('pointerup', this.selectionHandler);
    this.onObjectSelected = null;
    this.onSceneTapped = null;
  }

  async loadLevel({ objectKey, assetUri, transform }) {
    const gltf = await loadGlb(assetUri);
    const nextObject = placeObject(gltf.scene, transform);
    nextObject.userData.objectCode = objectKey;
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

  playLevelUp(objectKey) {
    const object = this.levelObjects.get(objectKey);
    if (!object) return;
    const start = performance.now();
    const animate = (now) => {
      const progress = Math.min((now - start) / 600, 1);
      const scale = 1 + Math.sin(progress * Math.PI) * 0.18;
      object.scale.setScalar(scale);
      if (progress < 1) requestAnimationFrame(animate);
      else object.scale.setScalar(1);
    };
    requestAnimationFrame(animate);
  }

  selectAt(event) {
    const start = this.pointerStart;
    this.pointerStart = null;
    if (!start || Math.hypot(event.clientX - start.x, event.clientY - start.y) > 8) return;
    const rect = this.renderer.domElement.getBoundingClientRect();
    const pointer = new THREE.Vector2(
      ((event.clientX - rect.left) / rect.width) * 2 - 1,
      -((event.clientY - rect.top) / rect.height) * 2 + 1,
    );
    const raycaster = new THREE.Raycaster();
    raycaster.setFromCamera(pointer, this.camera);
    const candidates = [...this.levelObjects.entries()]
      .filter(([key]) => key !== 'ROOM').map(([, object]) => object);
    const hit = raycaster.intersectObjects(candidates, true)[0];
    if (!hit) {
      this.onSceneTapped?.();
      return;
    }
    let root = hit.object;
    while (root.parent && !root.userData.objectCode) root = root.parent;
    if (root.userData.objectCode) this.onObjectSelected?.(root.userData.objectCode);
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
    this.renderer.domElement.removeEventListener('pointerdown', this.pointerDownHandler);
    this.renderer.domElement.removeEventListener('pointerup', this.selectionHandler);
    if (this.animationFrame !== null) {
      cancelAnimationFrame(this.animationFrame);
    }
    for (const object of [...this.levelObjects.values()]) {
      switchLevelModel(this.scene, object, new THREE.Group());
    }
    this.levelObjects.clear();
    this.mixers.clear();
    this.controls.dispose();
    this.renderer.dispose();
    this.renderer.domElement.remove();
  }
}
