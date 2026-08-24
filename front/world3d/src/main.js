import './style.css';
import { WorldRenderer } from './world/world_renderer.js';
import { installWorldBridge, postBridgeMessage } from './world/world_bridge.js';
import { objectAsset, roomAsset } from './world/world_manifest.js';

const worldRoot = document.querySelector('#world-root');
const worldRenderer = new WorldRenderer(worldRoot);
worldRenderer.start();

async function loadSpikeLevel(level) {
  await worldRenderer.loadLevel({
    objectKey: 'SPIKE_OBJECT',
    assetUri: `./models/spike-object-lv${level}.glb`,
    transform: { position: { x: 0, y: 0, z: 0 } },
  });
}

worldRenderer.onObjectSelected = (objectCode) => postBridgeMessage('objectSelected', { objectCode });
worldRenderer.onObjectHovered = (objectCode) => postBridgeMessage('objectHovered', { objectCode });
worldRenderer.onSceneTapped = () => postBridgeMessage('sceneTapped');

async function updateObjectLevel(objectCode, level) {
  const asset = objectAsset(objectCode, level);
  await worldRenderer.loadLevel(asset);
  postBridgeMessage('objectLevelChanged', { objectCode, level });
}

installWorldBridge(async ({ type, payload }) => {
  if (type === 'setSpikeLevel') {
    await loadSpikeLevel(payload.level);
    postBridgeMessage('objectLevelChanged', { objectCode: 'SPIKE_OBJECT', level: payload.level });
  } else if (type === 'initializeWorld') {
    if (!Array.isArray(payload.objects) || payload.objects.length === 0) {
      throw new Error('World 오브젝트 정보를 불러오지 못했습니다.');
    }
    if (payload.objectCount !== payload.objects.length) {
      throw new Error(`World 오브젝트 개수 검증 실패: ${payload.objects.length}`);
    }
    await Promise.all(payload.objects.map((object) => {
      if (typeof object?.objectCode !== 'string' || !Number.isInteger(object?.level)) {
        throw new Error('World 오브젝트 데이터 형식이 올바르지 않습니다.');
      }
      return updateObjectLevel(object.objectCode, object.level);
    }));
    postBridgeMessage('worldInitialized');
  } else if (type === 'updateObjectLevel') {
    await updateObjectLevel(payload.objectCode, payload.level);
  } else if (type === 'playLevelUp') {
    worldRenderer.playLevelUp(payload.objectCode);
  } else if (type === 'dispose') {
    worldRenderer.destroy();
  }
});

worldRenderer.loadLevel(roomAsset)
  .then(() => postBridgeMessage('rendererReady'))
  .catch((error) => postBridgeMessage('rendererError', { message: error.message }));

addEventListener('pagehide', () => worldRenderer.destroy(), { once: true });
