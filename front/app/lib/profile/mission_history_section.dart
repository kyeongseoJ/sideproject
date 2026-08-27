import 'package:flutter/material.dart';
import 'package:novelty_app/api/mission_api.dart';
import 'package:novelty_app/mission/mission_models.dart';
import 'package:novelty_app/novelty_theme.dart';

class MissionHistorySection extends StatefulWidget {
  const MissionHistorySection({
    super.key,
    required this.gateway,
    required this.userKey,
    this.refreshSignal = 0,
  });

  final MissionGateway gateway;
  final String userKey;
  final int refreshSignal;

  @override
  State<MissionHistorySection> createState() => _MissionHistorySectionState();
}

class _MissionHistorySectionState extends State<MissionHistorySection> {
  late Future<List<UserMission>> _history;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MissionHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal ||
        oldWidget.userKey != widget.userKey) {
      _load();
    }
  }

  void _load() {
    _history = widget.gateway.getHistory(widget.userKey);
  }

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('mission-history-section'),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: NoveltyColors.canvas,
      border: Border.all(color: NoveltyColors.line),
      borderRadius: BorderRadius.circular(NoveltyRadii.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('미션 수행 기록', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          '지금까지 완료한 미션을 최신순으로 확인할 수 있어요.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<UserMission>>(
          future: _history,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            if (snapshot.hasError) {
              return Text(
                '수행 기록을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.',
                style: Theme.of(context).textTheme.bodySmall,
              );
            }
            final missions = snapshot.data ?? const <UserMission>[];
            if (missions.isEmpty) {
              return Text(
                '완료한 미션이 아직 없어요. 오늘의 미션부터 시작해 보세요.',
                style: Theme.of(context).textTheme.bodyMedium,
              );
            }
            return Column(
              children: [
                for (var index = 0; index < missions.length; index++) ...[
                  _HistoryTile(mission: missions[index]),
                  if (index < missions.length - 1)
                    const Divider(height: 20),
                ],
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.mission});

  final UserMission mission;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: NoveltyColors.successFaint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.check_rounded, color: NoveltyColors.success),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mission.title,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 3),
            Text(
              '${mission.category.label} · ${mission.estimatedMinutes}분',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (mission.statusAt != null)
              Text(
                _formatDate(mission.statusAt!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NoveltyColors.gray040,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

String _formatDate(DateTime value) {
  final date = value.toUtc().add(const Duration(hours: 9));
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}
