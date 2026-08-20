import 'package:flutter/material.dart';
import 'package:novelty_app/novelty_theme.dart';
import 'package:novelty_app/personality/personality_models.dart';

class PersonalityProfileScreen extends StatelessWidget {
  PersonalityProfileScreen({
    super.key,
    required this.user,
    required this.onReanalyze,
    this.onOpenMissions,
  }) : assert(user.personalityCompleted && user.personality != null);

  final UserProfile user;
  final VoidCallback onReanalyze;
  final VoidCallback? onOpenMissions;

  @override
  Widget build(BuildContext context) {
    final profile = user.personality!;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final useCardLayout = constraints.maxWidth >= 720;
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(useCardLayout ? 24 : 0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: useCardLayout
                          ? Border.all(color: NoveltyColors.line)
                          : null,
                      borderRadius: BorderRadius.circular(
                        useCardLayout ? 16 : 0,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _ProfileContent(
                        nickname: user.nickname,
                        profile: profile,
                        onReanalyze: onReanalyze,
                        onOpenMissions: onOpenMissions,
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

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.nickname,
    required this.profile,
    required this.onReanalyze,
    this.onOpenMissions,
  });

  final String nickname;
  final PersonalityProfile profile;
  final VoidCallback onReanalyze;
  final VoidCallback? onOpenMissions;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('personality-profile-content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(nickname, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 12),
        Text('나의 성향 프로필', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: NoveltyColors.primaryFaint,
            border: Border.all(color: NoveltyColors.primarySubtle),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: NoveltyColors.primary,
                size: 32,
              ),
              const SizedBox(height: 16),
              Text(
                profile.typeName,
                key: const Key('personality-profile-type-name'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                profile.summary,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('행동 선호', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _TraitGrid(profile: profile),
        const SizedBox(height: 24),
        Text('관심 분야', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          key: const Key('personality-profile-interests'),
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final interest in profile.interests)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: NoveltyColors.surfaceAlt,
                  border: Border.all(color: NoveltyColors.line),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_interestLabel(interest)),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: NoveltyColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '마지막 분석 ${_seoulDateTime(profile.analyzedAt)}',
                key: const Key('personality-profile-analyzed-at'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '분석 버전 ${profile.analysisVersion}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (onOpenMissions != null) ...[
          FilledButton(
            key: const Key('open-missions-button'),
            onPressed: onOpenMissions,
            child: const Text('오늘의 미션 보기'),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton(
          key: const Key('personality-reanalyze-button'),
          onPressed: onReanalyze,
          child: const Text('성향 분석 다시하기'),
        ),
        const SizedBox(height: 12),
        Text(
          '성향 분석은 여기까지 완료됐어요. 할애 가능 시간과 미션은 다음 기능에서 연결됩니다.',
          key: const Key('personality-profile-boundary'),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: NoveltyColors.gray040),
        ),
      ],
    );
  }
}

class _TraitGrid extends StatelessWidget {
  const _TraitGrid({required this.profile});

  final PersonalityProfile profile;

  @override
  Widget build(BuildContext context) {
    final traits = <(String, String)>[
      ('실내·실외 선호', _indoorOutdoorLabel(profile.indoorOutdoor)),
      ('사회적 활동 선호', _socialLabel(profile.socialLevel)),
      ('신체 활동 강도', _physicalLabel(profile.physicalActivityLevel)),
      ('새로움 수용도', _noveltyLabel(profile.noveltyLevel)),
      ('실행 방식', _executionLabel(profile.executionStyle)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 2 : 1;
        return GridView.builder(
          key: const Key('personality-profile-traits'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: traits.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 88,
          ),
          itemBuilder: (context, index) {
            final (label, value) = traits[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NoveltyColors.surfaceAlt,
                border: Border.all(color: NoveltyColors.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

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
