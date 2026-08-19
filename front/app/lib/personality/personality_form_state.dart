import 'package:novelty_app/personality/personality_models.dart';

class PersonalityFormState {
  IndoorOutdoor? indoorOutdoor;
  SocialLevel? socialLevel;
  PhysicalActivityLevel? physicalActivityLevel;
  NoveltyLevel? noveltyLevel;
  final List<PersonalityInterest> interests = <PersonalityInterest>[];
  ExecutionStyle? executionStyle;

  bool isStepComplete(int step) => switch (step) {
    0 => indoorOutdoor != null,
    1 => socialLevel != null,
    2 => physicalActivityLevel != null,
    3 => noveltyLevel != null,
    4 => interests.isNotEmpty && interests.length <= 3,
    5 => executionStyle != null,
    _ => false,
  };

  bool get isComplete =>
      List<bool>.generate(6, isStepComplete).every((complete) => complete);

  InterestSelectionResult toggleInterest(PersonalityInterest interest) {
    if (interests.remove(interest)) {
      return InterestSelectionResult.removed;
    }
    if (interests.length >= 3) {
      return InterestSelectionResult.limitReached;
    }
    interests.add(interest);
    return InterestSelectionResult.added;
  }

  PersonalityAnswers toAnswers() {
    if (!isComplete) {
      throw StateError('모든 성향 문항에 답해야 합니다.');
    }
    return PersonalityAnswers(
      indoorOutdoor: indoorOutdoor!,
      socialLevel: socialLevel!,
      physicalActivityLevel: physicalActivityLevel!,
      noveltyLevel: noveltyLevel!,
      interests: interests,
      executionStyle: executionStyle!,
    );
  }
}

enum InterestSelectionResult { added, removed, limitReached }
