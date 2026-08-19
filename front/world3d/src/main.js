import * as THREE from 'three';
import './style.css';

const scene = new THREE.Scene();
scene.background = new THREE.Color(0xf2f2f3);

const camera = new THREE.PerspectiveCamera(75, innerWidth / innerHeight, 0.1, 1000);
const renderer = new THREE.WebGLRenderer({ antialias: true });
const worldRoot = document.querySelector('#world-root');

renderer.setSize(innerWidth, innerHeight);
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
worldRoot.appendChild(renderer.domElement);
renderer.render(scene, camera);

addEventListener('resize', () => {
  camera.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(innerWidth, innerHeight);
  renderer.render(scene, camera);
});
