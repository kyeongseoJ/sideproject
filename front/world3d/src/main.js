import './style.css';
import { WorldRenderer } from './world/world_renderer.js';
import { installWorldBridge, postBridgeMessage } from './world/world_bridge.js';
import { roomAsset } from './world/world_manifest.js';

const worldRoot = document.querySelector('#world-root');
const worldRenderer = new WorldRenderer(worldRoot);
worldRenderer.start();
let currentRoomAssetCode = 'room';
let currentRoomDecorationLevel = 1;
let pendingInitializationKey = null;
let initializedKey = null;

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
  if (typeof objectCode !== 'string' || !Number.isInteger(level) || level < 1 || level > 5) {
    throw new Error('World 성장 단계 데이터 형식이 올바르지 않습니다.');
  }
  currentRoomDecorationLevel = Math.max(currentRoomDecorationLevel, level);
  await worldRenderer.loadLevel(roomAsset(currentRoomAssetCode, currentRoomDecorationLevel));
  postBridgeMessage('objectLevelChanged', { objectCode, level });
}

async function initializeWorld(payload) {
  if (!Array.isArray(payload.objects) || payload.objects.length === 0) {
    throw new Error('World objects are required.');
  }
  if (payload.objectCount !== payload.objects.length) {
    throw new Error(`World object count mismatch: ${payload.objects.length}`);
  }
  payload.objects.forEach((object) => {
    if (typeof object?.objectCode !== 'string' || !Number.isInteger(object?.level)) {
      throw new Error('Invalid world object data.');
    }
  });

  const roomAssetCode = payload.roomAssetCode ?? 'room';
  const roomDecorationLevel = payload.roomDecorationLevel ?? 1;
  const requestKey = `${roomAssetCode}:${roomDecorationLevel}`;
  if (initializedKey === requestKey || pendingInitializationKey === requestKey) return;

  pendingInitializationKey = requestKey;
  try {
    currentRoomAssetCode = roomAssetCode;
    currentRoomDecorationLevel = roomDecorationLevel;
    await worldRenderer.loadLevel(roomAsset(roomAssetCode, roomDecorationLevel));
    initializedKey = requestKey;
    postBridgeMessage('worldInitialized');
  } finally {
    pendingInitializationKey = null;
  }
}

installWorldBridge(async ({ type, payload }) => {
  if (type === 'setSpikeLevel') {
    await loadSpikeLevel(payload.level);
    postBridgeMessage('objectLevelChanged', { objectCode: 'SPIKE_OBJECT', level: payload.level });
  } else if (type === 'initializeWorld') {
    await initializeWorld(payload);
    /* The renderer no longer preloads a placeholder room. */
  } else if (false) {
    if (!Array.isArray(payload.objects) || payload.objects.length === 0) {
      throw new Error('World 오브젝트 정보를 불러오지 못했습니다.');
    }
    if (payload.objectCount !== payload.objects.length) {
      throw new Error(`World 오브젝트 개수 검증 실패: ${payload.objects.length}`);
    }
    currentRoomAssetCode = payload.roomAssetCode ?? 'room';
    currentRoomDecorationLevel = payload.roomDecorationLevel ?? 1;
    await worldRenderer.loadLevel(roomAsset(
      currentRoomAssetCode,
      currentRoomDecorationLevel,
    ));
    payload.objects.forEach((object) => {
      if (typeof object?.objectCode !== 'string' || !Number.isInteger(object?.level)) {
        throw new Error('World 오브젝트 데이터 형식이 올바르지 않습니다.');
      }
    });
    postBridgeMessage('worldInitialized');
  } else if (type === 'updateObjectLevel') {
    await updateObjectLevel(payload.objectCode, payload.level);
  } else if (type === 'playLevelUp') {
    worldRenderer.playLevelUp(payload.objectCode);
  } else if (type === 'focusGrowthObject') {
    worldRenderer.focusGrowthObject(payload.objectCode, payload.levelUp === true);
  } else if (type === 'dispose') {
    worldRenderer.destroy();
  }
});

postBridgeMessage('rendererReady');

addEventListener('pagehide', () => worldRenderer.destroy(), { once: true });
