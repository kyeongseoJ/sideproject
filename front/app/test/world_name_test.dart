import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/world/world_name.dart';

void main() {
  test('registers a room asset for every personality type', () {
    expect(personalityWorldRoomAssetCodes, hasLength(9));
    expect(personalityWorldRoomAssetCodes['QUIET_FOCUSER'], 'classroom_2');
    expect(personalityWorldRoomAssetCodes['COZY_EXPLORER'], 'art_gallery_4');
    expect(personalityWorldRoomAssetCodes['WARM_HOST'], 'cafe_5');
    expect(
      personalityWorldRoomAssetCodes['FLEXIBLE_INDEPENDENT'],
      'music_store_20',
    );
    expect(
      personalityWorldRoomAssetCodes['BALANCED_COORDINATOR'],
      'flower_shop_26',
    );
    expect(personalityWorldRoomAssetCodes['OPEN_CONNECTOR'], 'Theatre_32');
    expect(personalityWorldRoomAssetCodes['SOLO_EXPLORER'], 'Gym_25');
    expect(personalityWorldRoomAssetCodes['FREE_PIONEER'], 'bookshop_7');
    expect(personalityWorldRoomAssetCodes['ACTIVE_CONNECTOR'], 'stadium_40');
  });
}
