import 'package:novelty_app/personality/personality_models.dart';

// Personality-specific room asset codes are resolved by the Three.js manifest.
const Map<String, String> personalityWorldRoomAssetCodes = {
  'QUIET_FOCUSER': 'classroom_2',
  'COZY_EXPLORER': 'art_gallery_4',
  'WARM_HOST': 'cafe_5',
  'FLEXIBLE_INDEPENDENT': 'music_store_20',
  'BALANCED_COORDINATOR': 'flower_shop_26',
  'OPEN_CONNECTOR': 'Theatre_32',
  'SOLO_EXPLORER': 'Gym_25',
  'FREE_PIONEER': 'bookshop_7',
  'ACTIVE_CONNECTOR': 'stadium_40',
};

String personalityWorldRoomAssetCode(PersonalityProfile profile) =>
    personalityWorldRoomAssetCodes[profile.typeCode] ?? 'room';

String personalityWorldName(PersonalityProfile profile) =>
    switch (profile.typeCode) {
      'QUIET_FOCUSER' => '고요한 몰입 작업실',
      'COZY_EXPLORER' => '아늑한 발견의 방',
      'WARM_HOST' => '온기가 머무는 아지트',
      'FLEXIBLE_INDEPENDENT' => '나만의 리듬 스튜디오',
      'BALANCED_COORDINATOR' => '균형의 라운지',
      'OPEN_CONNECTOR' => '열린 연결의 방',
      'SOLO_EXPLORER' => '독립 탐험 베이스',
      'FREE_PIONEER' => '자유 개척 캠프',
      'ACTIVE_CONNECTOR' => '활력 연결 스튜디오',
      _ => '${profile.typeName}의 공간',
    };

Set<String> personalityWorldCategories(PersonalityProfile profile) =>
    profile.interests.map((interest) => interest.code).toSet();
