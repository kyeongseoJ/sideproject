class WorldObjectProgress {
  const WorldObjectProgress({
    required this.objectCode,
    required this.categoryCode,
    required this.displayName,
    required this.level,
    required this.exp,
    required this.nextLevelRequiredExp,
    required this.maxLevel,
  });

  final String objectCode;
  final String categoryCode;
  final String displayName;
  final int level;
  final int exp;
  final int? nextLevelRequiredExp;
  final int maxLevel;

  String get categoryDisplayName => switch (categoryCode) {
    'MOVEMENT' => '움직임',
    'CREATIVE' => '창작',
    'FOOD' => '음식',
    'LEARNING' => '학습',
    'SOCIAL' => '교류',
    'OUTDOOR' => '야외 탐색',
    'ORGANIZING' => '정리',
    'CULTURE' => '문화',
    _ => categoryCode,
  };

  factory WorldObjectProgress.fromJson(Map<String, Object?> json) {
    final objectCode = json['objectCode'];
    final categoryCode = json['categoryCode'];
    final displayName = json['displayName'];
    final level = json['level'];
    final exp = json['exp'];
    final next = json['nextLevelRequiredExp'];
    final maxLevel = json['maxLevel'];
    if (objectCode is! String ||
        objectCode.isEmpty ||
        categoryCode is! String ||
        categoryCode.isEmpty ||
        displayName is! String ||
        displayName.isEmpty ||
        level is! int ||
        level < 1 ||
        level > 5 ||
        exp is! int ||
        exp < 0 ||
        (next != null && next is! int) ||
        maxLevel is! int ||
        maxLevel < level) {
      throw const FormatException('Invalid world object progress.');
    }
    return WorldObjectProgress(
      objectCode: objectCode,
      categoryCode: categoryCode,
      displayName: displayName,
      level: level,
      exp: exp,
      nextLevelRequiredExp: next as int?,
      maxLevel: maxLevel,
    );
  }

  Map<String, Object?> toBridgeJson() => {
    'objectCode': objectCode,
    'categoryCode': categoryCode,
    'displayName': displayName,
    'level': level,
    'exp': exp,
    'nextLevelRequiredExp': nextLevelRequiredExp,
    'maxLevel': maxLevel,
  };
}

class WorldSnapshot {
  WorldSnapshot(List<WorldObjectProgress> objects)
    : objects = List.unmodifiable(objects);
  final List<WorldObjectProgress> objects;

  factory WorldSnapshot.fromJson(Map<String, Object?> json) {
    final raw = json['objects'];
    if (raw is! List<Object?>)
      throw const FormatException('Invalid world snapshot.');
    return WorldSnapshot(
      raw.map((item) {
        if (item is! Map<String, Object?>)
          throw const FormatException('Invalid world object.');
        return WorldObjectProgress.fromJson(item);
      }).toList(),
    );
  }
}

class WorldGrowth {
  const WorldGrowth({
    required this.objectCode,
    required this.categoryCode,
    required this.awardedExp,
    required this.previousLevel,
    required this.currentLevel,
    required this.currentExp,
    required this.nextLevelRequiredExp,
    required this.levelUp,
    required this.rewardApplied,
  });

  final String objectCode;
  final String categoryCode;
  final int awardedExp;
  final int previousLevel;
  final int currentLevel;
  final int currentExp;
  final int? nextLevelRequiredExp;
  final bool levelUp;
  final bool rewardApplied;

  factory WorldGrowth.fromJson(Map<String, Object?> json) {
    final objectCode = json['objectCode'];
    final categoryCode = json['categoryCode'];
    final awardedExp = json['awardedExp'];
    final previousLevel = json['previousLevel'];
    final currentLevel = json['currentLevel'];
    final currentExp = json['currentExp'];
    final next = json['nextLevelRequiredExp'];
    final levelUp = json['levelUp'];
    final applied = json['rewardApplied'];
    if (objectCode is! String ||
        categoryCode is! String ||
        awardedExp is! int ||
        previousLevel is! int ||
        currentLevel is! int ||
        currentExp is! int ||
        (next != null && next is! int) ||
        levelUp is! bool ||
        applied is! bool) {
      throw const FormatException('Invalid world growth.');
    }
    return WorldGrowth(
      objectCode: objectCode,
      categoryCode: categoryCode,
      awardedExp: awardedExp,
      previousLevel: previousLevel,
      currentLevel: currentLevel,
      currentExp: currentExp,
      nextLevelRequiredExp: next as int?,
      levelUp: levelUp,
      rewardApplied: applied,
    );
  }
}
