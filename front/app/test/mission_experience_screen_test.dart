import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/api/mission_api.dart';
import 'package:novelty_app/mission/mission_experience_screen.dart';
import 'package:novelty_app/mission/mission_models.dart';
import 'package:novelty_app/novelty_theme.dart';

void main() {
  testWidgets('loads candidates without requesting mission settings', (tester) async {
    final gateway = _FakeMissionGateway();
    await _pump(tester, gateway);

    expect(gateway.getTodayCalls, 1);
    expect(find.byKey(const Key('mission-carousel')), findsOneWidget);
  });

  testWidgets('selects, cancels and completes a single daily mission', (tester) async {
    final gateway = _FakeMissionGateway();
    await _pump(tester, gateway);

    await tester.tap(find.byKey(const Key('mission-select-13')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mission-complete-13')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mission-cancel-13')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mission-select-14')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mission-select-13')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mission-complete-13')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mission-completed-card')), findsOneWidget);
  });

  testWidgets('supports mouse drag on the mission carousel', (tester) async {
    await _pump(tester, _FakeMissionGateway());
    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.controller?.page, 0);

    await tester.drag(
      find.byType(PageView),
      const Offset(-500, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(pageView.controller?.page, greaterThan(0.5));
  });

  testWidgets('shows a retry path for an initial network failure', (tester) async {
    final gateway = _FakeMissionGateway(loadFailures: 1);
    await _pump(tester, gateway);

    expect(find.byKey(const Key('mission-retry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mission-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mission-carousel')), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester, MissionGateway gateway) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildNoveltyTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: MissionDashboardSection(
            gateway: gateway,
            userKey: 'cached-user-key',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeMissionGateway implements MissionGateway {
  _FakeMissionGateway({this.loadFailures = 0});

  int loadFailures;
  int getTodayCalls = 0;
  late MissionToday today = _today(
    candidates: [_mission(13), _mission(14, title: 'Try a new recipe')],
  );

  @override
  Future<MissionToday> getToday(String userKey) async {
    getTodayCalls++;
    if (loadFailures > 0) {
      loadFailures--;
      throw const MissionApiException(
        kind: MissionApiFailureKind.network,
        message: 'Network error',
      );
    }
    return today;
  }

  @override
  Future<MissionToday> recommendToday(String userKey) async => today;

  @override
  Future<MissionSummary> getSummary(String userKey) async => _summary(0);

  @override
  Future<MissionActionResult> select(String userKey, int id) async {
    final selected = today.candidates.firstWhere(
      (mission) => mission.userMissionId == id,
    );
    today = _today(
      active: [_copy(selected, MissionStatus.selected)],
      candidates: today.candidates
          .where((mission) => mission.userMissionId != id)
          .toList(),
    );
    return MissionActionResult(
      mission: today.activeMissions.single,
      today: today,
      idempotent: false,
    );
  }

  @override
  Future<MissionActionResult> cancel(String userKey, int id) async {
    final cancelled = _copy(today.activeMissions.single, MissionStatus.cancelled);
    today = _today(candidates: [cancelled, ...today.candidates]);
    return MissionActionResult(mission: cancelled, today: today, idempotent: false);
  }

  @override
  Future<MissionActionResult> replace(
    String userKey,
    int currentId,
    int replacementId,
  ) async => throw UnimplementedError();

  @override
  Future<MissionActionResult> complete(String userKey, int id) async {
    final completed = _copy(today.activeMissions.single, MissionStatus.completed);
    today = _today(completed: 1);
    return MissionActionResult(
      mission: completed,
      today: today,
      idempotent: false,
      summary: _summary(1),
    );
  }

}

MissionToday _today({
  List<UserMission> active = const [],
  List<UserMission> candidates = const [],
  int completed = 0,
}) => MissionToday(
  serviceDate: DateTime(2026, 8, 20),
  completedToday: completed,
  activeMissions: active,
  candidates: candidates,
);

UserMission _mission(int id, {String title = 'Try a new walk'}) => UserMission(
  userMissionId: id,
  missionId: id + 100,
  title: title,
  description: 'Take a different route today.',
  category: MissionCategory.outdoor,
  difficulty: 1,
  estimatedMinutes: 10,
  indoorOutdoor: 1,
  socialLevel: 0,
  activityLevel: 1,
  noveltyLevel: 2,
  status: MissionStatus.shown,
  personalityDistance: 0.8,
);

UserMission _copy(UserMission source, MissionStatus status) => UserMission(
  userMissionId: source.userMissionId,
  missionId: source.missionId,
  title: source.title,
  description: source.description,
  category: source.category,
  difficulty: source.difficulty,
  estimatedMinutes: source.estimatedMinutes,
  indoorOutdoor: source.indoorOutdoor,
  socialLevel: source.socialLevel,
  activityLevel: source.activityLevel,
  noveltyLevel: source.noveltyLevel,
  status: status,
  personalityDistance: source.personalityDistance,
);

MissionSummary _summary(int completed) => MissionSummary(
  completedMissionCount: completed,
  lastPersonalityAdaptedCount: completed == 0 ? 0 : 1,
  personalityCode: 'QUIET_FOCUSER',
  categoryStats: completed == 0
      ? const []
      : const [MissionCategoryStat(category: MissionCategory.outdoor, completedCount: 1)],
);
