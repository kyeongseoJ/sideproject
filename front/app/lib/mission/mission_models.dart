import 'package:novelty_app/world/world_models.dart';

enum MissionStatus {
  generated('GENERATED'),
  shown('SHOWN'),
  selected('SELECTED'),
  cancelled('CANCELLED'),
  completed('COMPLETED');

  const MissionStatus(this.code);
  final String code;

  String get label => switch (this) {
    selected => '수행중',
    completed => '완료',
    cancelled => '취소',
    shown => '추천',
    generated => '생성됨',
  };
}

enum MissionCategory {
  movement('MOVEMENT', '운동'),
  creative('CREATIVE', '창작'),
  food('FOOD', '음식'),
  learning('LEARNING', '학습'),
  social('SOCIAL', '사람'),
  outdoor('OUTDOOR', '야외'),
  organizing('ORGANIZING', '정리'),
  culture('CULTURE', '문화');

  const MissionCategory(this.code, this.label);
  final String code;
  final String label;
}

class UserMission {
  const UserMission({
    required this.userMissionId,
    required this.missionId,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.estimatedMinutes,
    required this.indoorOutdoor,
    required this.socialLevel,
    required this.activityLevel,
    required this.noveltyLevel,
    required this.status,
    required this.personalityDistance,
  });

  final int userMissionId;
  final int missionId;
  final String title;
  final String description;
  final MissionCategory category;
  final int difficulty;
  final int estimatedMinutes;
  final int indoorOutdoor;
  final int socialLevel;
  final int activityLevel;
  final int noveltyLevel;
  final MissionStatus status;
  final double personalityDistance;

  factory UserMission.fromJson(Map<String, Object?> json) {
    final userMissionId = json['userMissionId'];
    final missionId = json['missionId'];
    final title = json['title'];
    final description = json['description'];
    final difficulty = json['difficulty'];
    final estimatedMinutes = json['estimatedMinutes'];
    final indoorOutdoor = json['indoorOutdoor'];
    final socialLevel = json['socialLevel'];
    final activityLevel = json['activityLevel'];
    final noveltyLevel = json['noveltyLevel'];
    final distance = json['personalityDistance'];
    if (userMissionId is! int ||
        userMissionId <= 0 ||
        missionId is! int ||
        missionId <= 0 ||
        title is! String ||
        title.trim().isEmpty ||
        description is! String ||
        description.trim().isEmpty ||
        difficulty is! int ||
        difficulty < 1 ||
        difficulty > 3 ||
        estimatedMinutes is! int ||
        estimatedMinutes <= 0 ||
        indoorOutdoor is! int ||
        indoorOutdoor < -1 ||
        indoorOutdoor > 1 ||
        socialLevel is! int ||
        socialLevel < -1 ||
        socialLevel > 1 ||
        activityLevel is! int ||
        activityLevel < 0 ||
        activityLevel > 2 ||
        noveltyLevel is! int ||
        noveltyLevel < 0 ||
        noveltyLevel > 2 ||
        distance is! num ||
        distance < 0 ||
        distance > 1) {
      throw const FormatException('Invalid user mission.');
    }
    return UserMission(
      userMissionId: userMissionId,
      missionId: missionId,
      title: title,
      description: description,
      category: _enumByCode(MissionCategory.values, json['category']),
      difficulty: difficulty,
      estimatedMinutes: estimatedMinutes,
      indoorOutdoor: indoorOutdoor,
      socialLevel: socialLevel,
      activityLevel: activityLevel,
      noveltyLevel: noveltyLevel,
      status: _enumByCode(MissionStatus.values, json['status']),
      personalityDistance: distance.toDouble(),
    );
  }
}

class MissionToday {
  MissionToday({
    required this.serviceDate,
    required this.completedToday,
    required List<UserMission> activeMissions,
    required List<UserMission> candidates,
  }) : activeMissions = List.unmodifiable(activeMissions),
       candidates = List.unmodifiable(candidates);

  final DateTime serviceDate;
  final int completedToday;
  final List<UserMission> activeMissions;
  final List<UserMission> candidates;

  factory MissionToday.fromJson(Map<String, Object?> json) {
    final date = DateTime.tryParse(_string(json, 'serviceDate'));
    final completed = json['completedToday'];
    if (date == null ||
        completed is! int ||
        completed < 0) {
      throw const FormatException('Invalid mission today response.');
    }
    return MissionToday(
      serviceDate: date,
      completedToday: completed,
      activeMissions: _missionList(json['activeMissions']),
      candidates: _missionList(json['candidates']),
    );
  }
}

class MissionCategoryStat {
  const MissionCategoryStat({
    required this.category,
    required this.completedCount,
  });
  final MissionCategory category;
  final int completedCount;

  factory MissionCategoryStat.fromJson(Map<String, Object?> json) {
    final count = json['completedCount'];
    if (count is! int || count < 0)
      throw const FormatException('Invalid stat.');
    return MissionCategoryStat(
      category: _enumByCode(MissionCategory.values, json['category']),
      completedCount: count,
    );
  }
}

class MissionSummary {
  MissionSummary({
    required this.completedMissionCount,
    required this.lastPersonalityAdaptedCount,
    required this.personalityCode,
    required List<MissionCategoryStat> categoryStats,
  }) : categoryStats = List.unmodifiable(categoryStats);

  final int completedMissionCount;
  final int lastPersonalityAdaptedCount;
  final String personalityCode;
  final List<MissionCategoryStat> categoryStats;

  factory MissionSummary.fromJson(Map<String, Object?> json) {
    final completed = json['completedMissionCount'];
    final adapted = json['lastPersonalityAdaptedCount'];
    final stats = json['categoryStats'];
    if (completed is! int ||
        completed < 0 ||
        adapted is! int ||
        adapted < 0 ||
        adapted > completed ||
        stats is! List<Object?>) {
      throw const FormatException('Invalid mission summary.');
    }
    return MissionSummary(
      completedMissionCount: completed,
      lastPersonalityAdaptedCount: adapted,
      personalityCode: _string(json, 'personalityCode'),
      categoryStats: stats.map((item) {
        if (item is! Map<String, Object?>)
          throw const FormatException('Invalid stat.');
        return MissionCategoryStat.fromJson(item);
      }).toList(),
    );
  }
}

class MissionActionResult {
  const MissionActionResult({
    required this.mission,
    required this.today,
    required this.idempotent,
    this.summary,
    this.personalityUpdated = false,
    this.personalityChange,
    this.llmGenerationStatus,
    this.worldGrowth,
  });

  final UserMission mission;
  final MissionToday today;
  final bool idempotent;
  final MissionSummary? summary;
  final bool personalityUpdated;
  final MissionPersonalityChange? personalityChange;
  final String? llmGenerationStatus;
  final WorldGrowth? worldGrowth;

  factory MissionActionResult.fromJson(Map<String, Object?> json) {
    final mission = json['mission'];
    final today = json['today'];
    final idempotent = json['idempotent'];
    final completion = json['completion'];
    if (mission is! Map<String, Object?> ||
        today is! Map<String, Object?> ||
        idempotent is! bool) {
      throw const FormatException('Invalid mission action response.');
    }
    MissionSummary? summary;
    bool updated = false;
    MissionPersonalityChange? personalityChange;
    String? llmStatus;
    WorldGrowth? worldGrowth;
    if (completion != null) {
      if (completion is! Map<String, Object?> ||
          completion['summary'] is! Map<String, Object?> ||
          completion['personalityUpdated'] is! bool ||
          completion['llmGenerationStatus'] is! String ||
          completion['worldGrowth'] is! Map<String, Object?>) {
        throw const FormatException('Invalid completion effect.');
      }
      summary = MissionSummary.fromJson(
        completion['summary'] as Map<String, Object?>,
      );
      updated = completion['personalityUpdated'] as bool;
      final rawPersonalityChange = completion['personalityChange'];
      if (rawPersonalityChange != null) {
        if (rawPersonalityChange is! Map<String, Object?>) {
          throw const FormatException('Invalid personality change.');
        }
        personalityChange = MissionPersonalityChange.fromJson(
          rawPersonalityChange,
        );
      }
      llmStatus = completion['llmGenerationStatus'] as String;
      worldGrowth = WorldGrowth.fromJson(
        completion['worldGrowth'] as Map<String, Object?>,
      );
    }
    return MissionActionResult(
      mission: UserMission.fromJson(mission),
      today: MissionToday.fromJson(today),
      idempotent: idempotent,
      summary: summary,
      personalityUpdated: updated,
      personalityChange: personalityChange,
      llmGenerationStatus: llmStatus,
      worldGrowth: worldGrowth,
    );
  }
}

class MissionPersonalityChange {
  const MissionPersonalityChange({
    required this.previousIndoorOutdoor,
    required this.currentIndoorOutdoor,
    required this.previousSocialLevel,
    required this.currentSocialLevel,
    required this.previousActivityLevel,
    required this.currentActivityLevel,
    required this.previousNoveltyLevel,
    required this.currentNoveltyLevel,
    required this.previousPersonalityCode,
    required this.currentPersonalityCode,
  });

  final int previousIndoorOutdoor;
  final int currentIndoorOutdoor;
  final int previousSocialLevel;
  final int currentSocialLevel;
  final int previousActivityLevel;
  final int currentActivityLevel;
  final int previousNoveltyLevel;
  final int currentNoveltyLevel;
  final String previousPersonalityCode;
  final String currentPersonalityCode;

  factory MissionPersonalityChange.fromJson(Map<String, Object?> json) {
    final values = <Object?>[
      json['previousIndoorOutdoor'],
      json['currentIndoorOutdoor'],
      json['previousSocialLevel'],
      json['currentSocialLevel'],
      json['previousActivityLevel'],
      json['currentActivityLevel'],
      json['previousNoveltyLevel'],
      json['currentNoveltyLevel'],
    ];
    if (values.any((value) => value is! int)) {
      throw const FormatException('Invalid personality change axes.');
    }
    return MissionPersonalityChange(
      previousIndoorOutdoor: values[0] as int,
      currentIndoorOutdoor: values[1] as int,
      previousSocialLevel: values[2] as int,
      currentSocialLevel: values[3] as int,
      previousActivityLevel: values[4] as int,
      currentActivityLevel: values[5] as int,
      previousNoveltyLevel: values[6] as int,
      currentNoveltyLevel: values[7] as int,
      previousPersonalityCode: _string(json, 'previousPersonalityCode'),
      currentPersonalityCode: _string(json, 'currentPersonalityCode'),
    );
  }
}

List<UserMission> _missionList(Object? value) {
  if (value is! List<Object?>)
    throw const FormatException('Invalid mission list.');
  return value.map((item) {
    if (item is! Map<String, Object?>)
      throw const FormatException('Invalid mission.');
    return UserMission.fromJson(item);
  }).toList();
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty)
    throw FormatException('Invalid $key.');
  return value;
}

T _enumByCode<T>(List<T> values, Object? raw) {
  if (raw is! String) throw const FormatException('Invalid enum.');
  for (final value in values) {
    final code = switch (value) {
      MissionStatus item => item.code,
      MissionCategory item => item.code,
      _ => throw StateError('Unsupported mission enum.'),
    };
    if (code == raw) return value;
  }
  throw const FormatException('Invalid enum.');
}
