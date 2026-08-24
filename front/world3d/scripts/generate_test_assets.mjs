import { mkdir, writeFile } from 'node:fs/promises';
import * as THREE from 'three';
import { GLTFExporter } from 'three/addons/exporters/GLTFExporter.js';

globalThis.FileReader ??= class FileReader {
  readAsArrayBuffer(blob) {
    blob.arrayBuffer().then((value) => {
      this.result = value;
      this.onloadend?.();
    });
  }

  readAsDataURL(blob) {
    blob.arrayBuffer().then((value) => {
      const base64 = Buffer.from(value).toString('base64');
      this.result = `data:${blob.type};base64,${base64}`;
      this.onloadend?.();
    });
  }
};

const output = new URL('../public/models/', import.meta.url);
await mkdir(output, { recursive: true });

function material(color) {
  return new THREE.MeshStandardMaterial({ color, roughness: 0.8 });
}

function box(name, size, position, color) {
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(...size), material(color));
  mesh.name = name;
  mesh.position.set(...position);
  return mesh;
}

async function exportGlb(name, scene) {
  const exporter = new GLTFExporter();
  const result = await exporter.parseAsync(scene, { binary: true });
  await writeFile(new URL(name, output), Buffer.from(result));
}

const room = new THREE.Group();
room.add(box('Floor', [8, 0.2, 8], [0, -0.1, 0], 0xf2f2f3));
room.add(box('BackWall', [8, 3.5, 0.2], [0, 1.75, -4], 0xffffff));
room.add(box('SideWall', [0.2, 3.5, 8], [-4, 1.75, 0], 0xffffff));
await exportGlb('room.glb', room);

for (const level of [1, 2]) {
  const object = new THREE.Group();
  object.add(box('Base', [1.4, 0.25, 1.1], [0, 0.125, 0], 0x7234e0));
  for (let index = 0; index < level; index += 1) {
    object.add(box(`Growth${index + 1}`, [0.8, 0.45, 0.8], [0, 0.475 + index * 0.45, 0], 0x21ab79));
  }
  await exportGlb(`spike-object-lv${level}.glb`, object);
}

const objectColors = {
  TRAINING_CORNER: 0xf26b5e, ART_EASEL: 0x9b6de3, KITCHEN_TABLE: 0xf2b84b,
  BOOKSHELF: 0x4c7bd9, MESSAGE_BOARD: 0x4fb6a3, INDOOR_GARDEN: 0x68aa55,
  STORAGE_CABINET: 0x9a7654, RECORD_PLAYER: 0xd25f91,
};

for (const [code, color] of Object.entries(objectColors)) {
  for (let level = 1; level <= 5; level += 1) {
    const object = new THREE.Group();
    object.add(box('Base', [1.15, 0.18, 0.9], [0, 0.09, 0], 0xfaf7f2));
    for (let index = 0; index < level; index += 1) {
      const width = 0.74 - index * 0.06;
      object.add(box(`Level${index + 1}`, [width, 0.28, 0.62],
        [0, 0.32 + index * 0.28, 0], color));
    }
    await exportGlb(`${code.toLowerCase()}-lv${level}.glb`, object);
  }
}
