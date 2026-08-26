const roomDefinitions = {
  room: { assetUri: './models/room.glb' },
  classroom_2: { assetUri: './models/Classroom_2.glb' },
  art_gallery_4: { assetUri: './models/Art_Galery_4.glb' },
  cafe_5: { assetUri: './models/Cafe_5.glb' },
  music_store_20: { assetUri: './models/Music_Store_20.glb' },
  flower_shop_26: { assetUri: './models/Flower_Shop_26.glb' },
  Theatre_32: { assetUri: './models/Theatre_32.glb' },
  Gym_25: { assetUri: './models/Gym_25.glb' },
  bookshop_7: { assetUri: './models/Book_Shop_7.glb' },
  stadium_40: { assetUri: './models/Stadium_40.glb' },
};

export function roomAsset(roomAssetCode = 'room', decorationLevel = 1) {
  const definition = roomDefinitions[roomAssetCode];
  if (!definition || !Number.isInteger(decorationLevel) || decorationLevel < 1 || decorationLevel > 5) {
    throw new Error('Unknown World room or decoration level.');
  }
  return {
    objectKey: 'ROOM',
    assetUri: definition.assetUri,
    decorationLevel,
  };
}
