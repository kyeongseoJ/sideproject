import 'package:flutter/material.dart';
import 'package:novelty_app/api/mission_api.dart';
import 'package:novelty_app/api/world_api.dart';
import 'package:novelty_app/mission/behavior_preference_change.dart';
import 'package:novelty_app/mission/mission_experience_screen.dart';
import 'package:novelty_app/mission/mission_models.dart';
import 'package:novelty_app/novelty_theme.dart';
import 'package:novelty_app/personality/personality_models.dart';
import 'package:novelty_app/world/world_models.dart';
import 'package:novelty_app/world/world_name.dart';
import 'package:novelty_app/world/world_preview.dart';

class PersonalityProfileScreen extends StatelessWidget {
  PersonalityProfileScreen({
    super.key,
    required this.user,
    required this.onReanalyze,
    this.onOpenWorld,
    this.missionGateway,
    this.worldGateway,
    this.userKey,
    this.lastPreferenceChange,
    this.onWorldGrowth,
    this.onMissionCompleted,
    this.pendingWorldGrowth,
  }) : assert(user.personalityCompleted && user.personality != null);

  final UserProfile user;
  final VoidCallback onReanalyze;
  final VoidCallback? onOpenWorld;
  final MissionGateway? missionGateway;
  final WorldGateway? worldGateway;
  final String? userKey;
  final BehaviorPreferenceChange? lastPreferenceChange;
  final ValueChanged<WorldGrowth>? onWorldGrowth;
  final ValueChanged<MissionActionResult>? onMissionCompleted;
  final WorldGrowth? pendingWorldGrowth;

  @override
  Widget build(BuildContext context) {
    final profile = user.personality!;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final horizontalPadding = constraints.maxWidth < 360 ? 16.0 : 24.0;
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(wide ? 24 : horizontalPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: NoveltyColors.canvas,
                      border: wide
                          ? Border.all(color: NoveltyColors.line)
                          : null,
                      borderRadius: BorderRadius.circular(
                        wide ? NoveltyRadii.card : 0,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(horizontalPadding),
                      child: Column(
                        key: const Key('personality-profile-content'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _BrandHeader(),
                          const SizedBox(height: 10),
                          _PersonalityTitle(profile: profile),
                          if (missionGateway != null && userKey != null) ...[
                            const SizedBox(height: 20),
                            MissionDashboardSection(
                              gateway: missionGateway!,
                              userKey: userKey!,
                              onWorldGrowth: onWorldGrowth,
                              onMissionCompleted: onMissionCompleted,
                            ),
                          ],
                          const SizedBox(height: 28),
                          Text(
                            '프로필',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          _ProfileSummary(profile: profile),
                          const SizedBox(height: 16),
                          _InterestSection(profile: profile),
                          const SizedBox(height: 16),
                          _BehaviorPreferenceSection(
                            profile: profile,
                            change: lastPreferenceChange,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            key: const Key('personality-reanalyze-button'),
                            onPressed: onReanalyze,
                            child: const Text('성향 분석 다시하기'),
                          ),
                          if (worldGateway != null &&
                              userKey != null &&
                              onOpenWorld != null) ...[
                            const SizedBox(height: 28),
                            Text(
                              '나의 세계',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 10),
                            WorldPreview(
                              gateway: worldGateway!,
                              userKey: userKey!,
                              worldName: profile.typeName,
                              roomAssetCode: personalityWorldRoomAssetCode(profile),
                              baseCategoryCodes: personalityWorldCategories(
                                profile,
                              ),
                              pendingGrowth: pendingWorldGrowth,
                              onOpen: onOpenWorld!,
                            ),
                          ],
                          const SizedBox(height: 40),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Text(
                            '마지막 분석 ${_seoulDateTime(profile.analyzedAt)}\n${profile.analysisVersion}',
                            key: const Key('personality-profile-analyzed-at'),
                            textAlign: TextAlign.left,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: NoveltyColors.gray040),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Image.asset(
        'assets/ui/Novelty_logo_letter.png',
        key: const Key('novelty-wordmark'),
        width: 148,
        height: 25,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
      ),
      Image.asset(
        'assets/ui/Novelty_logo_dark.png',
        key: const Key('novelty-symbol'),
        width: 34,
        height: 34,
        fit: BoxFit.contain,
      ),
    ],
  );
}

class _PersonalityTitle extends StatelessWidget {
  const _PersonalityTitle({required this.profile});
  final PersonalityProfile profile;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    decoration: BoxDecoration(
      color: NoveltyColors.primaryFaint,
      border: Border.all(color: NoveltyColors.primarySubtle),
      borderRadius: BorderRadius.circular(NoveltyRadii.card),
    ),
    child: Column(
      children: [
        Text(
          '나의 성향 분석 결과',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: NoveltyColors.primaryStrong),
        ),
        const SizedBox(height: 4),
        Text(
          profile.typeName,
          key: const Key('personality-profile-type-name'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: NoveltyColors.primaryStrong,
          ),
        ),
      ],
    ),
  );
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profile});
  final PersonalityProfile profile;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('personality-summary-card'),
    padding: const EdgeInsets.all(18),
    decoration: _sectionDecoration(),
    child: Text(profile.summary, style: Theme.of(context).textTheme.bodyLarge),
  );
}

class _InterestSection extends StatelessWidget {
  const _InterestSection({required this.profile});
  final PersonalityProfile profile;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('personality-profile-interests'),
    padding: const EdgeInsets.all(18),
    decoration: _sectionDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('관심 분야', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final interest in profile.interests)
              Chip(label: Text(_interestLabel(interest))),
          ],
        ),
      ],
    ),
  );
}

class _BehaviorPreferenceSection extends StatelessWidget {
  const _BehaviorPreferenceSection({required this.profile, this.change});
  final PersonalityProfile profile;
  final BehaviorPreferenceChange? change;

  @override
  Widget build(BuildContext context) {
    final rows = [
      (
        '실외 활동',
        _normalizedSigned(profile.indoorOutdoorScore),
        _indoorOutdoorLabel(profile.indoorOutdoor),
      ),
      (
        '함께하기',
        _normalizedSigned(profile.socialScore),
        _socialLabel(profile.socialLevel),
      ),
      (
        '활동성',
        _normalizedLevel(profile.physicalActivityScore),
        _physicalLabel(profile.physicalActivityLevel),
      ),
      (
        '새로움',
        _normalizedLevel(profile.noveltyScore),
        _noveltyLabel(profile.noveltyLevel),
      ),
    ];
    final changes = change?.meaningful ?? const <BehaviorPreferenceDelta>[];
    return Container(
      key: const Key('personality-profile-traits'),
      padding: const EdgeInsets.all(18),
      decoration: _sectionDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('행동 선호', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          for (final row in rows) ...[
            Row(
              children: [
                SizedBox(width: 76, child: Text(row.$1)),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: row.$2,
                      backgroundColor: NoveltyColors.line,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${(row.$2 * 100).round()}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        row.$3,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              const Text('실행 방식'),
              const Spacer(),
              Text(_executionLabel(profile.executionStyle)),
            ],
          ),
          if (changes.isNotEmpty) ...[
            const Divider(height: 28),
            Text(
              '성향 변동',
              key: const Key('behavior-preference-change'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in changes)
                  Chip(
                    avatar: const Icon(
                      Icons.swap_vert_rounded,
                      size: 16,
                      color: NoveltyColors.success,
                    ),
                    label: Text('${item.label} +${item.amount}'),
                    backgroundColor: NoveltyColors.successFaint,
                    side: const BorderSide(color: NoveltyColors.success),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

double _normalizedSigned(int score) => (score + 1) / 2;
double _normalizedLevel(int score) => score / 2;

BoxDecoration _sectionDecoration() => BoxDecoration(
  color: NoveltyColors.canvas,
  border: Border.all(color: NoveltyColors.line),
  borderRadius: BorderRadius.circular(NoveltyRadii.card),
);

String _indoorOutdoorLabel(IndoorOutdoor value) => switch (value) {
  IndoorOutdoor.indoor => '실내 중심',
  IndoorOutdoor.mixed => '상황에 따라',
  IndoorOutdoor.outdoor => '실외 중심',
};
String _socialLabel(SocialLevel value) => switch (value) {
  SocialLevel.low => '혼자 하는 편',
  SocialLevel.medium => '상황에 따라',
  SocialLevel.high => '함께하는 편',
};
String _physicalLabel(PhysicalActivityLevel value) => switch (value) {
  PhysicalActivityLevel.low => '정적인 활동',
  PhysicalActivityLevel.medium => '가벼운 움직임',
  PhysicalActivityLevel.high => '활발한 움직임',
};
String _noveltyLabel(NoveltyLevel value) => switch (value) {
  NoveltyLevel.low => '작은 변화',
  NoveltyLevel.medium => '적당한 새로움',
  NoveltyLevel.high => '큰 새로움',
};
String _executionLabel(ExecutionStyle value) => switch (value) {
  ExecutionStyle.planned => '계획 실행형',
  ExecutionStyle.flexible => '유연 실행형',
  ExecutionStyle.spontaneous => '즉흥 실행형',
};
String _interestLabel(PersonalityInterest value) => switch (value) {
  PersonalityInterest.movement => '움직이기',
  PersonalityInterest.creative => '만들기',
  PersonalityInterest.food => '음식',
  PersonalityInterest.learning => '배우기',
  PersonalityInterest.social => '사람',
  PersonalityInterest.outdoor => '바깥',
  PersonalityInterest.organizing => '정리',
  PersonalityInterest.culture => '문화',
};

String _seoulDateTime(DateTime value) {
  final seoul = value.toUtc().add(const Duration(hours: 9));
  String twoDigits(int part) => part.toString().padLeft(2, '0');
  return '${seoul.year}.${twoDigits(seoul.month)}.${twoDigits(seoul.day)} '
      '${twoDigits(seoul.hour)}:${twoDigits(seoul.minute)}';
}
