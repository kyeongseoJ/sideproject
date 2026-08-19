enum IndoorOutdoor {
  indoor('INDOOR'),
  mixed('MIXED'),
  outdoor('OUTDOOR');

  const IndoorOutdoor(this.code);
  final String code;
}

enum SocialLevel {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH');

  const SocialLevel(this.code);
  final String code;
}

enum PhysicalActivityLevel {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH');

  const PhysicalActivityLevel(this.code);
  final String code;
}

enum NoveltyLevel {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH');

  const NoveltyLevel(this.code);
  final String code;
}

enum PersonalityInterest {
  movement('MOVEMENT'),
  creative('CREATIVE'),
  food('FOOD'),
  learning('LEARNING'),
  social('SOCIAL'),
  outdoor('OUTDOOR'),
  organizing('ORGANIZING'),
  culture('CULTURE');

  const PersonalityInterest(this.code);
  final String code;
}

enum ExecutionStyle {
  planned('PLANNED'),
  flexible('FLEXIBLE'),
  spontaneous('SPONTANEOUS');

  const ExecutionStyle(this.code);
  final String code;
}

enum AnalysisMode {
  initial('INITIAL'),
  reanalysis('REANALYSIS');

  const AnalysisMode(this.code);
  final String code;
}

class PersonalityAnswers {
  PersonalityAnswers({
    required this.indoorOutdoor,
    required this.socialLevel,
    required this.physicalActivityLevel,
    required this.noveltyLevel,
    required List<PersonalityInterest> interests,
    required this.executionStyle,
  }) : interests = List<PersonalityInterest>.unmodifiable(interests) {
    if (interests.isEmpty || interests.length > 3) {
      throw ArgumentError.value(
        interests,
        'interests',
        '관심 분야는 1개 이상 3개 이하이어야 합니다.',
      );
    }
    if (interests.toSet().length != interests.length) {
      throw ArgumentError.value(
        interests,
        'interests',
        '관심 분야를 중복해서 선택할 수 없습니다.',
      );
    }
  }

  final IndoorOutdoor indoorOutdoor;
  final SocialLevel socialLevel;
  final PhysicalActivityLevel physicalActivityLevel;
  final NoveltyLevel noveltyLevel;
  final List<PersonalityInterest> interests;
  final ExecutionStyle executionStyle;

  Map<String, Object> toJson() => <String, Object>{
    'indoorOutdoor': indoorOutdoor.code,
    'socialLevel': socialLevel.code,
    'physicalActivityLevel': physicalActivityLevel.code,
    'noveltyLevel': noveltyLevel.code,
    'interests': interests.map((interest) => interest.code).toList(),
    'executionStyle': executionStyle.code,
  };
}

class PersonalityAnalysisRequest {
  const PersonalityAnalysisRequest({
    required this.submissionKey,
    required this.analysisMode,
    required this.answers,
  });

  final String submissionKey;
  final AnalysisMode analysisMode;
  final PersonalityAnswers answers;

  Map<String, Object> toJson() => <String, Object>{
    'submissionKey': submissionKey,
    'analysisMode': analysisMode.code,
    ...answers.toJson(),
  };
}

class PersonalityProfile {
  PersonalityProfile({
    required this.typeCode,
    required this.typeName,
    required this.summary,
    required this.indoorOutdoor,
    required this.indoorOutdoorScore,
    required this.socialLevel,
    required this.socialScore,
    required this.physicalActivityLevel,
    required this.physicalActivityScore,
    required this.noveltyLevel,
    required this.noveltyScore,
    required this.executionStyle,
    required List<PersonalityInterest> interests,
    required this.analysisVersion,
    required this.analyzedAt,
  }) : interests = List<PersonalityInterest>.unmodifiable(interests);

  final String typeCode;
  final String typeName;
  final String summary;
  final IndoorOutdoor indoorOutdoor;
  final int indoorOutdoorScore;
  final SocialLevel socialLevel;
  final int socialScore;
  final PhysicalActivityLevel physicalActivityLevel;
  final int physicalActivityScore;
  final NoveltyLevel noveltyLevel;
  final int noveltyScore;
  final ExecutionStyle executionStyle;
  final List<PersonalityInterest> interests;
  final String analysisVersion;
  final DateTime analyzedAt;

  factory PersonalityProfile.fromJson(Map<String, Object?> json) {
    final typeCode = _requiredString(json, 'typeCode');
    final typeName = _requiredString(json, 'typeName');
    final summary = _requiredString(json, 'summary');
    final indoorOutdoorScore = _requiredInt(json, 'indoorOutdoorScore');
    final socialScore = _requiredInt(json, 'socialScore');
    final physicalActivityScore = _requiredInt(json, 'physicalActivityScore');
    final noveltyScore = _requiredInt(json, 'noveltyScore');
    final analysisVersion = _requiredString(json, 'analysisVersion');
    final analyzedAt = DateTime.tryParse(_requiredString(json, 'analyzedAt'));
    final rawInterests = json['interests'];

    if (analyzedAt == null ||
        analysisVersion != 'PERSONALITY_V2' ||
        rawInterests is! List<Object?>) {
      throw const FormatException('Invalid personality profile.');
    }

    final interests = rawInterests
        .map(
          (value) =>
              _enumByCode(PersonalityInterest.values, value, 'interests'),
        )
        .toList();
    if (interests.isEmpty ||
        interests.length > 3 ||
        interests.toSet().length != interests.length) {
      throw const FormatException('Invalid personality interests.');
    }

    return PersonalityProfile(
      typeCode: typeCode,
      typeName: typeName,
      summary: summary,
      indoorOutdoor: _enumByCode(
        IndoorOutdoor.values,
        json['indoorOutdoor'],
        'indoorOutdoor',
      ),
      indoorOutdoorScore: indoorOutdoorScore,
      socialLevel: _enumByCode(
        SocialLevel.values,
        json['socialLevel'],
        'socialLevel',
      ),
      socialScore: socialScore,
      physicalActivityLevel: _enumByCode(
        PhysicalActivityLevel.values,
        json['physicalActivityLevel'],
        'physicalActivityLevel',
      ),
      physicalActivityScore: physicalActivityScore,
      noveltyLevel: _enumByCode(
        NoveltyLevel.values,
        json['noveltyLevel'],
        'noveltyLevel',
      ),
      noveltyScore: noveltyScore,
      executionStyle: _enumByCode(
        ExecutionStyle.values,
        json['executionStyle'],
        'executionStyle',
      ),
      interests: interests,
      analysisVersion: analysisVersion,
      analyzedAt: analyzedAt,
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.nickname,
    required this.personalityCompleted,
    required this.personality,
  });

  final int userId;
  final String nickname;
  final bool personalityCompleted;
  final PersonalityProfile? personality;

  factory UserProfile.fromJson(Map<String, Object?> json) {
    final userId = json['userId'];
    final nickname = json['nickname'];
    final personalityCompleted = json['personalityCompleted'];
    final personalityJson = json['personality'];

    if (userId is! int ||
        userId <= 0 ||
        nickname is! String ||
        nickname.trim().isEmpty ||
        personalityCompleted is! bool) {
      throw const FormatException('Invalid user profile.');
    }

    final PersonalityProfile? personality;
    if (personalityCompleted) {
      if (personalityJson is! Map<String, Object?>) {
        throw const FormatException('Missing personality profile.');
      }
      personality = PersonalityProfile.fromJson(personalityJson);
    } else {
      if (personalityJson != null) {
        throw const FormatException('Unexpected personality profile.');
      }
      personality = null;
    }

    return UserProfile(
      userId: userId,
      nickname: nickname,
      personalityCompleted: personalityCompleted,
      personality: personality,
    );
  }
}

class AnonymousUser {
  const AnonymousUser({
    required this.userId,
    required this.userKey,
    required this.nickname,
  });

  final int userId;
  final String userKey;
  final String nickname;

  factory AnonymousUser.fromJson(Map<String, Object?> json) {
    final userId = json['userId'];
    final userKey = json['userKey'];
    final nickname = json['nickname'];
    final personalityCompleted = json['personalityCompleted'];
    if (userId is! int ||
        userId <= 0 ||
        userKey is! String ||
        userKey.trim().isEmpty ||
        nickname is! String ||
        nickname.trim().isEmpty ||
        personalityCompleted != false) {
      throw const FormatException('Invalid anonymous user response.');
    }
    return AnonymousUser(userId: userId, userKey: userKey, nickname: nickname);
  }

  UserProfile toProfile() => UserProfile(
    userId: userId,
    nickname: nickname,
    personalityCompleted: false,
    personality: null,
  );
}

class PersonalityAnalysisResult {
  const PersonalityAnalysisResult({
    required this.analysisId,
    required this.status,
    required this.personality,
  });

  final int analysisId;
  final String status;
  final PersonalityProfile personality;

  factory PersonalityAnalysisResult.fromJson(Map<String, Object?> json) {
    final analysisId = json['analysisId'];
    final status = json['status'];
    final personality = json['personality'];
    if (analysisId is! int ||
        analysisId <= 0 ||
        status != 'ANALYZED' ||
        personality is! Map<String, Object?>) {
      throw const FormatException('Invalid personality analysis response.');
    }
    return PersonalityAnalysisResult(
      analysisId: analysisId,
      status: status as String,
      personality: PersonalityProfile.fromJson(personality),
    );
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

T _enumByCode<T>(List<T> values, Object? rawValue, String key) {
  if (rawValue is! String) {
    throw FormatException('Invalid $key.');
  }
  for (final value in values) {
    final code = switch (value) {
      IndoorOutdoor item => item.code,
      SocialLevel item => item.code,
      PhysicalActivityLevel item => item.code,
      NoveltyLevel item => item.code,
      PersonalityInterest item => item.code,
      ExecutionStyle item => item.code,
      AnalysisMode item => item.code,
      _ => throw StateError('Unsupported enum type.'),
    };
    if (code == rawValue) {
      return value;
    }
  }
  throw FormatException('Invalid $key.');
}
