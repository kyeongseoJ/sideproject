import './style.css';
import { WorldRenderer } from './world/world_renderer.js';

const worldRoot = document.querySelector('#world-root');
const worldRenderer = new WorldRenderer(worldRoot);
worldRenderer.start();
