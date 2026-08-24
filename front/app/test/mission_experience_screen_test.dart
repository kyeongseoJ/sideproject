import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/api/mission_api.dart';
import 'package:novelty_app/mission/mission_experience_screen.dart';
import 'package:novelty_app/mission/mission_models.dart';
import 'package:novelty_app/novelty_theme.dart';

void main() {
  testWidgets('asks for settings once and shows recommendations after save', (
    tester,
  ) async {
    final gateway = _FakeMissionGateway(settingsRequired: true);
    await _pump(tester, gateway);

    expect(find.byKey(const Key('mission-settings-form')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mission-start-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mission-time-MEDIUM')));
    await tester.pumpAndSettle();

    expect(gateway.savedSettings?.availableTime, AvailableTime.medium);
    expect(gateway.savedSettings?.dailyLimit, 1);
    expect(find.byKey(const Key('mission-carousel')), findsOneWidget);
    expect(find.text('새로운 길 걷기'), findsOneWidget);
    expect(find.text('하루 한 개'), findsNothing);
  });

  testWidgets(
    'selects, cancels and completes without exposing direct replacement',
    (tester) async {
      final gateway = _FakeMissionGateway();
      await _pump(tester, gateway);

      await tester.tap(find.byKey(const Key('mission-select-13')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mission-complete-13')), findsOneWidget);
      expect(find.byKey(const Key('mission-replace-13')), findsNothing);
      expect(find.text('변경'), findsNothing);

      await tester.tap(find.byKey(const Key('mission-cancel-13')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mission-select-14')), findsOneWidget);

      await tester.tap(find.byKey(const Key('mission-select-13')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mission-complete-13')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mission-completed-card')), findsOneWidget);
      expect(find.text('미션을 완료했어요!'), findsOneWidget);
    },
  );

  testWidgets('supports mouse drag on the web mission carousel', (
    tester,
  ) async {
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

  testWidgets(
    'keeps current data and hides internal details when an action fails',
    (tester) async {
      final gateway = _FakeMissionGateway(
        actionError: StateError('oracle-password-detail'),
      );
      await _pump(tester, gateway);

      await tester.tap(find.byKey(const Key('mission-select-13')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mission-error')), findsOneWidget);
      expect(find.textContaining('oracle-password-detail'), findsNothing);
      expect(find.text('새로운 길 걷기'), findsOneWidget);
    },
  );

  testWidgets('blocks duplicate actions while the first request is pending', (
    tester,
  ) async {
    final completer = Completer<MissionActionResult>();
    final gateway = _FakeMissionGateway(pendingSelect: completer);
    await _pump(tester, gateway);

    final button = find.byKey(const Key('mission-select-13'));
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    expect(gateway.selectCalls, 1);

    completer.complete(gateway.selectResult(13));
    await tester.pumpAndSettle();
  });

  testWidgets('shows a retry path for initial network failure', (tester) async {
    final gateway = _FakeMissionGateway(loadFailures: 1);
    await _pump(tester, gateway);

    expect(find.byKey(const Key('mission-retry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mission-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mission-carousel')), findsOneWidget);
  });

  testWidgets('does not offer another candidate after today is completed', (
    tester,
  ) async {
    final gateway = _FakeMissionGateway();
    gateway.today = _today(
      completed: 1,
      remaining: 0,
      candidates: [_mission(13)],
    );
    await _pump(tester, gateway);

    expect(find.byKey(const Key('mission-completed-today')), findsOneWidget);
    expect(find.byKey(const Key('mission-carousel')), findsNothing);
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
  _FakeMissionGateway({
    this.settingsRequired = false,
    this.actionError,
    this.pendingSelect,
    this.loadFailures = 0,
  });

  bool settingsRequired;
  final Object? actionError;
  final Completer<MissionActionResult>? pendingSelect;
  int loadFailures;
  int selectCalls = 0;
  MissionSettings? savedSettings;
  late MissionToday today = _today(
    candidates: [
      _mission(13),
      _mission(14, title: '낯선 음악 듣기'),
    ],
  );

  @override
  Future<MissionSettings> getSettings(String userKey) async {
    if (loadFailures > 0) {
      loadFailures--;
      throw const MissionApiException(
        kind: MissionApiFailureKind.network,
        message: '서버에 연결하지 못했습니다.',
      );
    }
    if (settingsRequired) {
      throw const MissionApiException(
        kind: MissionApiFailureKind.api,
        code: 'MISSION_SETTINGS_REQUIRED',
        statusCode: 409,
        message: '미션 설정이 필요합니다.',
      );
    }
    return savedSettings ??
        const MissionSettings(
          availableTime: AvailableTime.short,
          dailyLimit: 1,
        );
  }

  @override
  Future<MissionSettings> saveSettings(
    String userKey,
    MissionSettings settings,
  ) async {
    savedSettings = settings;
    settingsRequired = false;
    today = _today(
      settings: settings,
      candidates: [
        _mission(13),
        _mission(14, title: '낯선 음악 듣기'),
      ],
    );
    return settings;
  }

  @override
  Future<MissionToday> getToday(String userKey) async => today;

  @override
  Future<MissionToday> recommendToday(String userKey) async => today;

  @override
  Future<MissionSummary> getSummary(String userKey) async => _summary(0);

  @override
  Future<MissionActionResult> select(String userKey, int id) {
    selectCalls++;
    if (actionError != null) throw actionError!;
    if (pendingSelect != null) return pendingSelect!.future;
    return Future.value(selectResult(id));
  }

  MissionActionResult selectResult(int id) {
    final selected = today.candidates.firstWhere(
      (mission) => mission.userMissionId == id,
    );
    today = _today(
      settings: today.settings,
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
    final active = today.activeMissions.single;
    final cancelled = _copy(active, MissionStatus.cancelled);
    today = _today(
      settings: today.settings,
      candidates: [cancelled, ...today.candidates],
    );
    return MissionActionResult(
      mission: cancelled,
      today: today,
      idempotent: false,
    );
  }

  @override
  Future<MissionActionResult> replace(
    String userKey,
    int currentId,
    int replacementId,
  ) async {
    final replacement = today.candidates.firstWhere(
      (mission) => mission.userMissionId == replacementId,
    );
    final previous = _copy(
      today.activeMissions.single,
      MissionStatus.cancelled,
    );
    final selected = _copy(replacement, MissionStatus.selected);
    today = _today(
      settings: today.settings,
      active: [selected],
      candidates: [previous],
    );
    return MissionActionResult(
      mission: selected,
      today: today,
      idempotent: false,
    );
  }

  @override
  Future<MissionActionResult> complete(String userKey, int id) async {
    final completed = _copy(
      today.activeMissions.single,
      MissionStatus.completed,
    );
    today = _today(settings: today.settings, completed: 1, remaining: 0);
    return MissionActionResult(
      mission: completed,
      today: today,
      idempotent: false,
      summary: _summary(1),
      personalityUpdated: true,
      personalityChange: const MissionPersonalityChange(
        previousIndoorOutdoor: -1,
        currentIndoorOutdoor: 0,
        previousSocialLevel: -1,
        currentSocialLevel: -1,
        previousActivityLevel: 0,
        currentActivityLevel: 1,
        previousNoveltyLevel: 0,
        currentNoveltyLevel: 1,
        previousPersonalityCode: 'QUIET_FOCUSER',
        currentPersonalityCode: 'BALANCED_COORDINATOR',
      ),
      llmGenerationStatus: 'NOT_DUE',
    );
  }
}

MissionToday _today({
  MissionSettings settings = const MissionSettings(
    availableTime: AvailableTime.short,
    dailyLimit: 1,
  ),
  List<UserMission> active = const [],
  List<UserMission> candidates = const [],
  int completed = 0,
  int remaining = 1,
}) => MissionToday(
  serviceDate: DateTime(2026, 8, 20),
  settings: settings,
  completedToday: completed,
  remainingSlots: remaining,
  activeMissions: active,
  candidates: candidates,
);

UserMission _mission(int id, {String title = '새로운 길 걷기'}) => UserMission(
  userMissionId: id,
  missionId: id + 100,
  title: title,
  description: '평소와 다른 행동을 십 분 해 보세요.',
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
      : const [
          MissionCategoryStat(
            category: MissionCategory.outdoor,
            completedCount: 1,
          ),
        ],
);
