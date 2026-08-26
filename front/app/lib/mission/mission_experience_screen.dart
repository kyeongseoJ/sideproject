import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:novelty_app/api/mission_api.dart';
import 'package:novelty_app/mission/mission_models.dart';
import 'package:novelty_app/novelty_theme.dart';
import 'package:novelty_app/world/world_models.dart';

class MissionDashboardSection extends StatefulWidget {
  const MissionDashboardSection({
    super.key,
    required this.gateway,
    required this.userKey,
    this.onWorldGrowth,
    this.onMissionCompleted,
  });

  final MissionGateway gateway;
  final String userKey;
  final ValueChanged<WorldGrowth>? onWorldGrowth;
  final ValueChanged<MissionActionResult>? onMissionCompleted;

  @override
  State<MissionDashboardSection> createState() =>
      _MissionDashboardSectionState();
}

class _MissionDashboardSectionState extends State<MissionDashboardSection> {
  final _pageController = PageController(viewportFraction: 0.88);
  MissionToday? _today;
  UserMission? _lastCompleted;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      MissionSettings settings;
      try {
        settings = await widget.gateway.getSettings(widget.userKey);
      } on MissionApiException catch (exception) {
        if (exception.code != 'MISSION_SETTINGS_REQUIRED') rethrow;
        settings = await widget.gateway.saveSettings(
          widget.userKey,
          const MissionSettings(
            availableTime: AvailableTime.long,
            dailyLimit: 1,
          ),
        );
      }
      if (settings.availableTime != AvailableTime.long) {
        settings = await widget.gateway.saveSettings(
          widget.userKey,
          MissionSettings(
            availableTime: AvailableTime.long,
            dailyLimit: settings.dailyLimit,
          ),
        );
      }
      var today = await widget.gateway.getToday(widget.userKey);
      if (today.activeMissions.isEmpty &&
          today.candidates.isEmpty &&
          today.completedToday == 0) {
        today = await widget.gateway.recommendToday(widget.userKey);
      }
      if (!mounted) return;
      setState(() {
        _today = today;
        _loading = false;
      });
    } on MissionApiException catch (exception) {
      if (!mounted) return;
      if (exception.code == 'MISSION_SETTINGS_REQUIRED') {
        setState(() {
          _today = null;
          _loading = false;
        });
      } else {
        setState(() {
          _error = exception.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '미션 정보를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
        _loading = false;
      });
    }
  }

  Future<void> _requestRecommendations() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final today = await widget.gateway.recommendToday(widget.userKey);
      if (!mounted) return;
      setState(() {
        _today = today;
      });
    } on MissionApiException catch (exception) {
      if (mounted) _showActionError(exception.message);
    } catch (_) {
      if (mounted) _showActionError('미션을 준비하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<MissionActionResult?> _act(
    Future<MissionActionResult> Function() request,
  ) async {
    if (_busy) return null;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await request();
      if (!mounted) return result;
      setState(() => _today = result.today);
      if (result.worldGrowth != null) {
        widget.onWorldGrowth?.call(result.worldGrowth!);
      }
      return result;
    } on MissionApiException catch (exception) {
      if (mounted) _showActionError(exception.message);
    } catch (_) {
      if (mounted) _showActionError('미션을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return null;
  }

  Future<void> _complete(UserMission mission) async {
    final result = await _act(
      () => widget.gateway.complete(widget.userKey, mission.userMissionId),
    );
    if (result == null || !mounted) return;
    setState(() => _lastCompleted = result.mission);
    widget.onMissionCompleted?.call(result);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('미션을 완료했어요!')));
  }

  void _showActionError(String message) {
    setState(() => _error = message);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('mission-dashboard'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "TODAY'S QUEST",
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: NoveltyColors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text('오늘의 미션', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          if (_today case final today?)
            _MissionCountBadge(completed: today.completedToday),
        ],
      ),
      const SizedBox(height: 16),
      if (_loading)
        const SizedBox(
          height: 220,
          child: Center(
            child: CircularProgressIndicator(key: Key('mission-loading')),
          ),
        )
      else if (_error != null && _today == null)
        _loadFailure()
      else if (_lastCompleted != null)
        _CompletedMissionCard(mission: _lastCompleted!)
      else if (_today?.activeMissions case [final active, ...])
        _ActiveMissionCard(
          mission: active,
          busy: _busy,
          onComplete: () => _complete(active),
          onCancel: () => _act(
            () => widget.gateway.cancel(widget.userKey, active.userMissionId),
          ),
        )
      else if (_today?.completedToday case final count? when count > 0)
        const _CompletedTodayCard()
      else if (_today?.candidates case final candidates?
          when candidates.isNotEmpty)
        _MissionCarousel(
          missions: candidates,
          controller: _pageController,
          busy: _busy,
          onSelect: (mission) => _act(
            () => widget.gateway.select(widget.userKey, mission.userMissionId),
          ),
        )
      else
        _MissionStartCard(busy: _busy, onStart: _requestRecommendations),
      if (_error != null && _today != null) ...[
        const SizedBox(height: 12),
        _errorView(),
      ],
    ],
  );

  Widget _loadFailure() => Container(
    padding: const EdgeInsets.all(20),
    decoration: _missionDecoration(),
    child: Column(
      children: [
        _errorView(),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('mission-retry'),
          onPressed: _load,
          child: const Text('다시 시도'),
        ),
      ],
    ),
  );

  Widget _errorView() => Container(
    key: const Key('mission-error'),
    padding: const EdgeInsets.all(12),
    decoration: NoveltyDecorations.error(),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 20,
          color: NoveltyColors.error,
        ),
        const SizedBox(width: NoveltySpacing.sm),
        Expanded(
          child: Text(
            _error!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: NoveltyColors.ink),
          ),
        ),
      ],
    ),
  );
}

class _MissionStartCard extends StatelessWidget {
  const _MissionStartCard({required this.busy, required this.onStart});

  final bool busy;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('mission-settings-form'),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: NoveltyColors.primaryFaint,
      border: Border.all(color: NoveltyColors.primarySubtle),
      borderRadius: BorderRadius.circular(NoveltyRadii.card),
    ),
    child: Column(
      key: const Key('mission-start'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: NoveltyColors.primary,
                borderRadius: BorderRadius.circular(NoveltyRadii.medium),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: NoveltyColors.canvas,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오늘의 새로운 경험',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '다섯 가지 미션 중 하나를 골라보세요',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            key: const Key('mission-start-select'),
            onPressed: busy ? null : onStart,
            label: const Text('미션 보기'),
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ),
      ],
    ),
  );
}

class _MissionCountBadge extends StatelessWidget {
  const _MissionCountBadge({required this.completed});

  final int completed;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: completed > 0 ? NoveltyColors.successFaint : NoveltyColors.surface,
      borderRadius: BorderRadius.circular(NoveltyRadii.medium),
      border: Border.all(
        color: completed > 0 ? NoveltyColors.success : NoveltyColors.line,
      ),
    ),
    child: Text(
      '$completed / 1',
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: completed > 0 ? NoveltyColors.success : NoveltyColors.gray040,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _MissionCarousel extends StatelessWidget {
  const _MissionCarousel({
    required this.missions,
    required this.controller,
    required this.busy,
    required this.onSelect,
  });

  final List<UserMission> missions;
  final PageController controller;
  final bool busy;
  final ValueChanged<UserMission> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              '오늘의 후보',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text('밀어서 더 보기', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      const SizedBox(height: 10),
      SizedBox(
        key: const Key('mission-carousel'),
        height: 292,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: const {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.stylus,
              PointerDeviceKind.trackpad,
            },
          ),
          child: PageView.builder(
            controller: controller,
            padEnds: false,
            itemCount: missions.length,
            itemBuilder: (context, index) {
              final mission = missions[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: NoveltyDecorations.card(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          _MissionCategoryIcon(category: mission.category),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              mission.category.label,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          Text(
                            '${mission.estimatedMinutes}분',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        mission.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(height: 1.35),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        mission.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          key: Key('mission-select-${mission.userMissionId}'),
                          onPressed: busy ? null : () => onSelect(mission),
                          child: const Text('이 미션 선택하기'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
}

class _MissionCategoryIcon extends StatelessWidget {
  const _MissionCategoryIcon({required this.category});

  final MissionCategory category;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: NoveltyColors.primaryFaint,
      borderRadius: BorderRadius.circular(NoveltyRadii.medium),
    ),
    child: Icon(
      switch (category) {
        MissionCategory.movement => Icons.directions_walk_rounded,
        MissionCategory.creative => Icons.palette_outlined,
        MissionCategory.food => Icons.restaurant_outlined,
        MissionCategory.learning => Icons.menu_book_outlined,
        MissionCategory.social => Icons.groups_outlined,
        MissionCategory.outdoor => Icons.explore_outlined,
        MissionCategory.organizing => Icons.checklist_rounded,
        MissionCategory.culture => Icons.museum_outlined,
      },
      size: 20,
      color: NoveltyColors.primary,
    ),
  );
}

class _ActiveMissionCard extends StatelessWidget {
  const _ActiveMissionCard({
    required this.mission,
    required this.busy,
    required this.onComplete,
    required this.onCancel,
  });

  final UserMission mission;
  final bool busy;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 520;
      final status = _MissionStatusPanel(
        label: '진행중',
        icon: Icons.play_arrow_rounded,
      );
      final content = _MissionProgressContent(
        mission: mission,
        busy: busy,
        onComplete: onComplete,
        onCancel: onCancel,
      );
      return Container(
        key: const Key('mission-today-screen'),
        decoration: _missionDecoration(),
        clipBehavior: Clip.antiAlias,
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [status, content],
              )
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 124, child: status),
                    Expanded(child: content),
                  ],
                ),
              ),
      );
    },
  );
}

class _MissionProgressContent extends StatelessWidget {
  const _MissionProgressContent({
    required this.mission,
    required this.busy,
    required this.onComplete,
    required this.onCancel,
  });

  final UserMission mission;
  final bool busy;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${mission.category.label} · ${mission.estimatedMinutes}분 · 난이도 ${mission.difficulty}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        Text(mission.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(mission.description, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              key: Key('mission-cancel-${mission.userMissionId}'),
              onPressed: busy ? null : onCancel,
              child: const Text('취소'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              key: Key('mission-complete-${mission.userMissionId}'),
              onPressed: busy ? null : onComplete,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(busy ? '처리 중...' : '미션 완료'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _MissionStatusPanel extends StatelessWidget {
  const _MissionStatusPanel({
    required this.label,
    required this.icon,
    this.completed = false,
  });
  final String label;
  final IconData icon;
  final bool completed;

  @override
  Widget build(BuildContext context) => Container(
    color: completed ? NoveltyColors.successFaint : NoveltyColors.primaryFaint,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: completed ? NoveltyColors.success : NoveltyColors.primary,
          size: 28,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: completed
                ? NoveltyColors.success
                : NoveltyColors.primaryStrong,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _CompletedMissionCard extends StatelessWidget {
  const _CompletedMissionCard({required this.mission});
  final UserMission mission;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('mission-completed-card'),
    decoration: _missionDecoration(),
    clipBehavior: Clip.antiAlias,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(
            width: 124,
            child: _MissionStatusPanel(
              label: '완료',
              icon: Icons.check_circle_rounded,
              completed: true,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${mission.category.label} · ${mission.estimatedMinutes}분',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    mission.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(mission.description),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: NoveltyColors.success,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '오늘의 새로운 경험을 완료했어요.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CompletedTodayCard extends StatelessWidget {
  const _CompletedTodayCard();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('mission-completed-today'),
    padding: const EdgeInsets.all(24),
    decoration: _missionDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Chip(
          label: const Text('완료'),
          avatar: const Icon(
            Icons.check_rounded,
            size: 16,
            color: NoveltyColors.success,
          ),
          backgroundColor: NoveltyColors.successFaint,
          side: const BorderSide(color: NoveltyColors.success),
          labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: NoveltyColors.ink,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Text('오늘의 미션을 완료했어요', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text('내일 새로운 미션으로 다시 만나요.'),
      ],
    ),
  );
}

BoxDecoration _missionDecoration({bool emphasized = false}) => BoxDecoration(
  color: emphasized ? NoveltyColors.primaryFaint : NoveltyColors.canvas,
  border: Border.all(
    color: emphasized ? NoveltyColors.primarySubtle : NoveltyColors.line,
  ),
  borderRadius: BorderRadius.circular(NoveltyRadii.card),
);
