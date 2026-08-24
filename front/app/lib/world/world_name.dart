import 'package:novelty_app/personality/personality_models.dart';

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
