const placements = {
  TRAINING_CORNER: [-2.5, 0, -2.1], ART_EASEL: [0, 0, -2.6],
  KITCHEN_TABLE: [2.5, 0, -2.1], BOOKSHELF: [-2.7, 0, 0.2],
  MESSAGE_BOARD: [2.7, 0, 0.2], INDOOR_GARDEN: [-2.3, 0, 2.4],
  STORAGE_CABINET: [0, 0, 2.6], RECORD_PLAYER: [2.3, 0, 2.4],
};

export function objectAsset(objectCode, level) {
  if (!placements[objectCode] || !Number.isInteger(level) || level < 1 || level > 5) {
    throw new Error('Unknown World object or level.');
  }
  return {
    objectKey: objectCode,
    assetUri: `./models/${objectCode.toLowerCase()}-lv${level}.glb`,
    transform: { position: { x: placements[objectCode][0], y: 0, z: placements[objectCode][2] } },
  };
}

export const roomAsset = { objectKey: 'ROOM', assetUri: './models/room.glb' };
