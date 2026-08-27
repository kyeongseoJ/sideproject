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
    this.defaultCameraPosition = this.camera.position.clone();
    this.defaultCameraTarget = this.controls.target.clone();
    this.levelObjects = new Map();
    this.mixers = new Map();
    this.growthEffects = [];
    this.growthFocus = null;
    this.raycaster = new THREE.Raycaster();
    this.pointer = new THREE.Vector2();
    this.hoveredObjectCode = null;
    this.animationFrame = null;
    this.resizeHandler = () => this.resize();
    this.selectionHandler = (event) => this.selectAt(event);
    this.hoverHandler = (event) => this.hoverAt(event);
    this.pointerLeaveHandler = () => this.setHoveredObject(null);
    this.pointerStart = null;
    this.pointerDownHandler = (event) => {
      this.pointerStart = { x: event.clientX, y: event.clientY };
    };
    addEventListener('resize', this.resizeHandler);
    this.renderer.domElement.addEventListener('pointerdown', this.pointerDownHandler);
    this.renderer.domElement.addEventListener('pointerup', this.selectionHandler);
    this.renderer.domElement.addEventListener('pointermove', this.hoverHandler);
    this.renderer.domElement.addEventListener('pointerleave', this.pointerLeaveHandler);
    this.onObjectSelected = null;
    this.onObjectHovered = null;
    this.onSceneTapped = null;
  }

  async loadLevel({ objectKey, assetUri, transform, decorationLevel }) {
    const gltf = await loadGlb(assetUri);
    if (objectKey === 'ROOM') {
      applyRoomDecorationLevel(gltf.scene, decorationLevel ?? 1);
    }
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
    // Room GLBs contain the actual decor, so a category code resolves to ROOM.
    const object = this.levelObjects.get(objectKey) ?? this.levelObjects.get('ROOM');
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

  focusGrowthObject(objectKey, levelUp) {
    const object = this.levelObjects.get(objectKey) ?? this.levelObjects.get('ROOM');
    if (!object) return;

    const bounds = new THREE.Box3().setFromObject(object);
    if (bounds.isEmpty()) return;

    const center = bounds.getCenter(new THREE.Vector3());
    const size = bounds.getSize(new THREE.Vector3());
    const radius = Math.max(size.x, size.z, 1.4) * 0.34;
    const reducedMotion = globalThis.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
    const target = center.clone();
    target.y = Math.max(target.y, 0.5);
    const cameraOffset = this.defaultCameraPosition
      .clone()
      .sub(this.defaultCameraTarget)
      .multiplyScalar(0.84);
    const focusPosition = target.clone().add(cameraOffset);

    this.clearGrowthEffects();
    if (reducedMotion) {
      this.camera.position.copy(focusPosition);
      this.controls.target.copy(target);
      this.camera.zoom = 1.18;
      this.camera.updateProjectionMatrix();
      this.controls.update();
      return;
    }

    this.growthFocus = {
      start: performance.now(),
      duration: levelUp ? 2400 : 1900,
      startPosition: this.camera.position.clone(),
      startTarget: this.controls.target.clone(),
      startZoom: this.camera.zoom,
      focusPosition,
      target,
    };
    this.createGrowthEffect(center, bounds.min.y + 0.04, radius, levelUp);
  }

  createGrowthEffect(center, groundY, radius, levelUp) {
    const group = new THREE.Group();
    const ringMaterial = new THREE.MeshBasicMaterial({
      color: 0x7234e0,
      transparent: true,
      opacity: 0.72,
      side: THREE.DoubleSide,
      depthWrite: false,
    });
    const ring = new THREE.Mesh(
      new THREE.RingGeometry(radius * 0.45, radius * 0.54, 48),
      ringMaterial,
    );
    ring.rotation.x = -Math.PI / 2;
    ring.position.set(center.x, groundY, center.z);
    group.add(ring);

    const particleCount = levelUp ? 34 : 22;
    const positions = new Float32Array(particleCount * 3);
    for (let index = 0; index < particleCount; index += 1) {
      const angle = index * 2.399963;
      const distance = radius * (0.25 + ((index * 17) % 100) / 100);
      positions[index * 3] = center.x + Math.cos(angle) * distance;
      positions[index * 3 + 1] = groundY + ((index * 13) % 100) / 100 * radius * 1.45;
      positions[index * 3 + 2] = center.z + Math.sin(angle) * distance;
    }
    const particleGeometry = new THREE.BufferGeometry();
    particleGeometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    const particleMaterial = new THREE.PointsMaterial({
      color: 0x8f5bf0,
      size: levelUp ? 0.11 : 0.08,
      transparent: true,
      opacity: 0.9,
      depthWrite: false,
    });
    const particles = new THREE.Points(particleGeometry, particleMaterial);
    group.add(particles);

    const light = new THREE.PointLight(0x8f5bf0, levelUp ? 3.4 : 2.2, radius * 6);
    light.position.copy(center);
    light.position.y += radius * 1.4;
    group.add(light);
    this.scene.add(group);
    this.growthEffects.push({
      group,
      start: performance.now(),
      duration: levelUp ? 1800 : 1300,
      update: (progress) => {
        const eased = 1 - (1 - progress) ** 3;
        ring.scale.setScalar(1 + eased * 2.8);
        ringMaterial.opacity = (1 - eased) * 0.72;
        particles.rotation.y = progress * 0.55;
        particleMaterial.opacity = (1 - eased) * 0.9;
        light.intensity = (1 - eased) * (levelUp ? 3.4 : 2.2);
      },
    });
  }

  updateGrowthPresentation(now) {
    const focus = this.growthFocus;
    if (focus) {
      const progress = Math.min((now - focus.start) / focus.duration, 1);
      const focusWeight = progress < 0.38
        ? easeOutCubic(progress / 0.38)
        : progress < 0.72
          ? 1
          : 1 - easeOutCubic((progress - 0.72) / 0.28);
      this.camera.position.lerpVectors(focus.startPosition, focus.focusPosition, focusWeight);
      this.controls.target.lerpVectors(focus.startTarget, focus.target, focusWeight);
      this.camera.zoom = focus.startZoom + 0.22 * focusWeight;
      this.camera.updateProjectionMatrix();
      this.controls.update();
      if (progress >= 1) {
        this.camera.position.copy(focus.startPosition);
        this.controls.target.copy(focus.startTarget);
        this.camera.zoom = focus.startZoom;
        this.camera.updateProjectionMatrix();
        this.controls.update();
        this.growthFocus = null;
      }
    }

    this.growthEffects = this.growthEffects.filter((effect) => {
      const progress = Math.min((now - effect.start) / effect.duration, 1);
      effect.update(progress);
      if (progress < 1) return true;
      disposeObject(effect.group);
      this.scene.remove(effect.group);
      return false;
    });
  }

  clearGrowthEffects() {
    for (const effect of this.growthEffects) {
      disposeObject(effect.group);
      this.scene.remove(effect.group);
    }
    this.growthEffects = [];
  }

  objectCodeAt(event) {
    const rect = this.renderer.domElement.getBoundingClientRect();
    this.pointer.set(
      ((event.clientX - rect.left) / rect.width) * 2 - 1,
      -((event.clientY - rect.top) / rect.height) * 2 + 1,
    );
    this.raycaster.setFromCamera(this.pointer, this.camera);
    const candidates = [...this.levelObjects.entries()]
      .filter(([key]) => key !== 'ROOM').map(([, object]) => object);
    const hit = this.raycaster.intersectObjects(candidates, true)[0];
    if (!hit) return null;
    let root = hit.object;
    while (root.parent && !root.userData.objectCode) root = root.parent;
    return root.userData.objectCode ?? null;
  }

  setHoveredObject(objectCode) {
    if (this.hoveredObjectCode === objectCode) return;
    this.hoveredObjectCode = objectCode;
    this.renderer.domElement.style.cursor = objectCode ? 'pointer' : 'grab';
    this.onObjectHovered?.(objectCode);
  }

  hoverAt(event) {
    if (event.pointerType !== 'mouse' && event.pointerType !== 'pen') return;
    this.setHoveredObject(this.objectCodeAt(event));
  }

  selectAt(event) {
    const start = this.pointerStart;
    this.pointerStart = null;
    if (!start || Math.hypot(event.clientX - start.x, event.clientY - start.y) > 8) return;
    const objectCode = this.objectCodeAt(event);
    if (!objectCode) {
      this.setHoveredObject(null);
      this.onSceneTapped?.();
      return;
    }
    this.onObjectSelected?.(objectCode);
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
      this.updateGrowthPresentation(performance.now());
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
    this.renderer.domElement.removeEventListener('pointermove', this.hoverHandler);
    this.renderer.domElement.removeEventListener('pointerleave', this.pointerLeaveHandler);
    if (this.animationFrame !== null) {
      cancelAnimationFrame(this.animationFrame);
    }
    for (const object of [...this.levelObjects.values()]) {
      switchLevelModel(this.scene, object, new THREE.Group());
    }
    this.levelObjects.clear();
    this.mixers.clear();
    this.clearGrowthEffects();
    this.controls.dispose();
    this.renderer.dispose();
    this.renderer.domElement.remove();
  }
}

function easeOutCubic(value) {
  return 1 - (1 - value) ** 3;
}

function disposeObject(root) {
  root.traverse((node) => {
    if (node.geometry) node.geometry.dispose();
    if (node.material) {
      const materials = Array.isArray(node.material) ? node.material : [node.material];
      materials.forEach((material) => material.dispose());
    }
  });
}

function applyRoomDecorationLevel(room, level) {
  const decorations = [];
  room.traverse((node) => {
    if (!node.isMesh || !node.name || /floor|wall/i.test(node.name)) return;
    decorations.push(node);
  });

  const visibleCount = decorations.length === 0
    ? 0
    : Math.max(1, Math.ceil(decorations.length * (level - 1) / 4));
  decorations.forEach((node, index) => {
    node.visible = index < visibleCount;
  });
}
