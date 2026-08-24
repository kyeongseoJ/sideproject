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
  bool _choosingTime = false;
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
      await widget.gateway.getSettings(widget.userKey);
      final today = await widget.gateway.getToday(widget.userKey);
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

  Future<void> _chooseTime(AvailableTime time) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.gateway.saveSettings(
        widget.userKey,
        MissionSettings(availableTime: time, dailyLimit: 1),
      );
      final today = await widget.gateway.recommendToday(widget.userKey);
      if (!mounted) return;
      setState(() {
        _today = today;
        _choosingTime = false;
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
        children: [
          Expanded(
            child: Text(
              '오늘의 미션',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (_today case final today? when today.completedToday > 0)
            Text('오늘 완료', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
      const SizedBox(height: 12),
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
          onChangeTime: () => setState(() {
            _today = null;
            _choosingTime = true;
          }),
        )
      else
        _MissionStartCard(
          choosingTime: _choosingTime,
          busy: _busy,
          onStart: () => setState(() => _choosingTime = true),
          onTimeSelected: _chooseTime,
        ),
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
  const _MissionStartCard({
    required this.choosingTime,
    required this.busy,
    required this.onStart,
    required this.onTimeSelected,
  });

  final bool choosingTime;
  final bool busy;
  final VoidCallback onStart;
  final ValueChanged<AvailableTime> onTimeSelected;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('mission-settings-form'),
    height: 220,
    padding: const EdgeInsets.all(24),
    decoration: _missionDecoration(emphasized: true),
    child: AnimatedSwitcher(
      duration: NoveltyMotion.standard,
      switchInCurve: NoveltyMotion.enter,
      switchOutCurve: NoveltyMotion.exit,
      child: choosingTime
          ? Column(
              key: const Key('mission-time-picker'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '새로운 모험에 사용할 시간을 알려주세요.',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final time in const [
                      AvailableTime.short,
                      AvailableTime.medium,
                      AvailableTime.long,
                    ])
                      OutlinedButton(
                        key: Key('mission-time-${time.code}'),
                        onPressed: busy ? null : () => onTimeSelected(time),
                        child: Text(
                          time == AvailableTime.long ? '1시간' : time.label,
                        ),
                      ),
                  ],
                ),
              ],
            )
          : Column(
              key: const Key('mission-start'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '평소와 다른 작은 행동을 시작해 보세요.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    key: const Key('mission-start-select'),
                    onPressed: onStart,
                    label: const Text('선택하기'),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ],
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
    required this.onChangeTime,
  });

  final List<UserMission> missions;
  final PageController controller;
  final bool busy;
  final ValueChanged<UserMission> onSelect;
  final VoidCallback onChangeTime;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        key: const Key('mission-carousel'),
        height: 270,
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
                  decoration: _missionDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${mission.category.label} · ${mission.estimatedMinutes}분 · 난이도 ${mission.difficulty}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        mission.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        mission.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      FilledButton(
                        key: Key('mission-select-${mission.userMissionId}'),
                        onPressed: busy ? null : () => onSelect(mission),
                        child: const Text('선택'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          key: const Key('mission-change-time'),
          onPressed: busy ? null : onChangeTime,
          child: const Text('시간 변경'),
        ),
      ),
    ],
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
