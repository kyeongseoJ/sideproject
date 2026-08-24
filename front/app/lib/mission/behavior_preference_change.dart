import 'package:novelty_app/mission/mission_models.dart';

class BehaviorPreferenceChange {
  const BehaviorPreferenceChange({
    required this.indoorOutdoor,
    required this.social,
    required this.activity,
    required this.novelty,
  });

  factory BehaviorPreferenceChange.fromCompletion(
    MissionPersonalityChange change,
  ) => BehaviorPreferenceChange(
    indoorOutdoor: change.currentIndoorOutdoor - change.previousIndoorOutdoor,
    social: change.currentSocialLevel - change.previousSocialLevel,
    activity: change.currentActivityLevel - change.previousActivityLevel,
    novelty: change.currentNoveltyLevel - change.previousNoveltyLevel,
  );

  final int indoorOutdoor;
  final int social;
  final int activity;
  final int novelty;

  List<BehaviorPreferenceDelta> get meaningful => [
    BehaviorPreferenceDelta(
      indoorOutdoor >= 0 ? '실외 경험' : '실내 경험',
      indoorOutdoor.abs(),
    ),
    BehaviorPreferenceDelta(social >= 0 ? '함께하기 경험' : '혼자하기 경험', social.abs()),
    BehaviorPreferenceDelta(
      activity >= 0 ? '활동성 경험' : '차분함 경험',
      activity.abs(),
    ),
    BehaviorPreferenceDelta(novelty >= 0 ? '새로움 경험' : '익숙함 경험', novelty.abs()),
  ].where((change) => change.amount > 0).toList(growable: false);
}

class BehaviorPreferenceDelta {
  const BehaviorPreferenceDelta(this.label, this.amount);

  final String label;
  final int amount;
}
