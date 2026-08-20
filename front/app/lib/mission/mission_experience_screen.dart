import 'package:flutter/material.dart';
import 'package:novelty_app/api/mission_api.dart';
import 'package:novelty_app/mission/mission_models.dart';
import 'package:novelty_app/novelty_theme.dart';

class MissionExperienceScreen extends StatefulWidget {
  const MissionExperienceScreen({
    super.key,
    required this.gateway,
    required this.userKey,
    required this.onBackToProfile,
  });

  final MissionGateway gateway;
  final String userKey;
  final Future<void> Function() onBackToProfile;

  @override
  State<MissionExperienceScreen> createState() =>
      _MissionExperienceScreenState();
}

class _MissionExperienceScreenState extends State<MissionExperienceScreen> {
  MissionToday? _today;
  MissionSummary? _summary;
  MissionSettings _settings = const MissionSettings(
    availableTime: AvailableTime.short,
    dailyLimit: 1,
  );
  bool _needsSettings = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await widget.gateway.getSettings(widget.userKey);
      var today = await widget.gateway.getToday(widget.userKey);
      if (today.activeMissions.isEmpty &&
          today.candidates.isEmpty &&
          today.remainingSlots > 0) {
        today = await widget.gateway.recommendToday(widget.userKey);
      }
      final summary = await widget.gateway.getSummary(widget.userKey);
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _today = today;
        _summary = summary;
        _needsSettings = false;
        _loading = false;
      });
    } on MissionApiException catch (exception) {
      if (!mounted) return;
      if (exception.code == 'MISSION_SETTINGS_REQUIRED') {
        setState(() {
          _needsSettings = true;
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

  Future<void> _saveSettings() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final settings = await widget.gateway.saveSettings(
        widget.userKey,
        _settings,
      );
      final today = await widget.gateway.recommendToday(widget.userKey);
      final summary = await widget.gateway.getSummary(widget.userKey);
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _today = today;
        _summary = summary;
        _needsSettings = false;
      });
    } on MissionApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } catch (_) {
      if (mounted) setState(() => _error = '설정을 저장하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _act(
    Future<MissionActionResult> Function() request, {
    String? successMessage,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await request();
      if (!mounted) return;
      setState(() {
        _today = result.today;
        if (result.summary != null) _summary = result.summary;
      });
      if (successMessage != null) {
        final suffix = result.personalityUpdated ? ' 성향 프로필도 갱신되었어요.' : '';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$successMessage$suffix')));
      }
    } on MissionApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } catch (_) {
      if (mounted) setState(() => _error = '미션을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _replace(UserMission current) async {
    final candidates = _today?.candidates ?? const <UserMission>[];
    final replacement = await showModalBottomSheet<UserMission>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('바꿀 미션 선택', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              if (candidates.isEmpty)
                const Text('변경할 수 있는 다른 미션이 없습니다.')
              else
                for (final candidate in candidates)
                  ListTile(
                    key: Key('mission-replacement-${candidate.userMissionId}'),
                    title: Text(candidate.title),
                    subtitle: Text(
                      '${candidate.category.label} · ${candidate.estimatedMinutes}분',
                    ),
                    onTap: () => Navigator.of(context).pop(candidate),
                  ),
            ],
          ),
        ),
      ),
    );
    if (replacement == null || !mounted) return;
    await _act(
      () => widget.gateway.replace(
        widget.userKey,
        current.userMissionId,
        replacement.userMissionId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 미션'),
        leading: IconButton(
          key: const Key('mission-back-profile'),
          onPressed: _busy ? null : () => widget.onBackToProfile(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: '프로필로 돌아가기',
        ),
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading)
      return const Center(
        child: CircularProgressIndicator(key: Key('mission-loading')),
      );
    if (_needsSettings) return _settingsForm();
    if (_today == null) return _loadFailure();
    return _todayContent(_today!);
  }

  Widget _loadFailure() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _errorView(),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('mission-retry'),
            onPressed: _load,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    ),
  );

  Widget _settingsForm() => SingleChildScrollView(
    key: const Key('mission-settings-form'),
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('미션 설정', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('오늘 미션에 사용할 수 있는 시간과 하루 목표를 알려주세요.'),
            const SizedBox(height: 24),
            Text('할애 가능 시간', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final time in AvailableTime.values)
                  ChoiceChip(
                    key: Key('mission-time-${time.code}'),
                    label: Text(time.label),
                    selected: _settings.availableTime == time,
                    onSelected: _busy
                        ? null
                        : (_) => setState(
                            () => _settings = MissionSettings(
                              availableTime: time,
                              dailyLimit: _settings.dailyLimit,
                            ),
                          ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('하루 미션 수', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (var limit = 1; limit <= 3; limit++)
                  ChoiceChip(
                    key: Key('mission-limit-$limit'),
                    label: Text('$limit개'),
                    selected: _settings.dailyLimit == limit,
                    onSelected: _busy
                        ? null
                        : (_) => setState(
                            () => _settings = MissionSettings(
                              availableTime: _settings.availableTime,
                              dailyLimit: limit,
                            ),
                          ),
                  ),
              ],
            ),
            if (_error != null) ...[const SizedBox(height: 16), _errorView()],
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('mission-settings-save'),
              onPressed: _busy ? null : _saveSettings,
              child: Text(_busy ? '저장 중...' : '설정 저장하고 미션 보기'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _todayContent(MissionToday today) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      key: const Key('mission-today-screen'),
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${today.completedToday}개 완료 · ${today.remainingSlots}개 남음',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _errorView(),
                ],
                const SizedBox(height: 20),
                Text('수행 중', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (today.activeMissions.isEmpty)
                  const _EmptyCard('수행 중인 미션이 없습니다. 아래에서 하나를 선택해 보세요.')
                else
                  for (final mission in today.activeMissions)
                    _MissionCard(
                      mission: mission,
                      busy: _busy,
                      active: true,
                      onComplete: () => _act(
                        () => widget.gateway.complete(
                          widget.userKey,
                          mission.userMissionId,
                        ),
                        successMessage: '미션을 완료했어요!',
                      ),
                      onCancel: () => _act(
                        () => widget.gateway.cancel(
                          widget.userKey,
                          mission.userMissionId,
                        ),
                      ),
                      onReplace: () => _replace(mission),
                    ),
                const SizedBox(height: 24),
                Text('추천 미션', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (today.candidates.isEmpty)
                  const _EmptyCard('지금 선택할 수 있는 추천 미션이 없습니다.')
                else
                  for (final mission in today.candidates)
                    _MissionCard(
                      mission: mission,
                      busy: _busy,
                      active: false,
                      onSelect: () => _act(
                        () => widget.gateway.select(
                          widget.userKey,
                          mission.userMissionId,
                        ),
                      ),
                    ),
                if (_summary != null) ...[
                  const SizedBox(height: 24),
                  _SummaryCard(summary: _summary!),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _errorView() => Container(
    key: const Key('mission-error'),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: NoveltyColors.errorFaint,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(_error!, style: const TextStyle(color: NoveltyColors.error)),
  );
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.mission,
    required this.busy,
    required this.active,
    this.onSelect,
    this.onComplete,
    this.onCancel,
    this.onReplace,
  });
  final UserMission mission;
  final bool busy;
  final bool active;
  final VoidCallback? onSelect;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;
  final VoidCallback? onReplace;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: active ? NoveltyColors.primaryFaint : Colors.white,
      border: Border.all(
        color: active ? NoveltyColors.primarySubtle : NoveltyColors.line,
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(mission.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(mission.description),
        const SizedBox(height: 10),
        Text(
          '${mission.category.label} · ${mission.estimatedMinutes}분 · 난이도 ${mission.difficulty}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        if (!active)
          FilledButton(
            key: Key('mission-select-${mission.userMissionId}'),
            onPressed: busy ? null : onSelect,
            child: const Text('이 미션 선택'),
          )
        else ...[
          FilledButton(
            key: Key('mission-complete-${mission.userMissionId}'),
            onPressed: busy ? null : onComplete,
            child: const Text('완료'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: Key('mission-replace-${mission.userMissionId}'),
                  onPressed: busy ? null : onReplace,
                  child: const Text('변경'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  key: Key('mission-cancel-${mission.userMissionId}'),
                  onPressed: busy ? null : onCancel,
                  child: const Text('취소'),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final MissionSummary summary;
  @override
  Widget build(BuildContext context) => Container(
    key: const Key('mission-summary'),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: NoveltyColors.line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('나의 미션 기록', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('총 ${summary.completedMissionCount}개 완료'),
        if (summary.categoryStats.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final stat in summary.categoryStats)
                Chip(
                  label: Text('${stat.category.label} ${stat.completedCount}'),
                ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: NoveltyColors.surfaceAlt,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(message),
  );
}
