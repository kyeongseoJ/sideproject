import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/api/world_api.dart';
import 'package:novelty_app/world/world_models.dart';
import 'package:novelty_app/world/world_screen.dart';

class _FakeWorldGateway implements WorldGateway {
  _FakeWorldGateway({this.snapshot});

  final WorldSnapshot? snapshot;

  @override
  Future<WorldSnapshot> getSnapshot(String userKey) async =>
      snapshot ??
      WorldSnapshot([
        const WorldObjectProgress(
          objectCode: 'BOOKSHELF',
          categoryCode: 'LEARNING',
          displayName: '책장',
          level: 2,
          exp: 60,
          nextLevelRequiredExp: 120,
          maxLevel: 5,
        ),
      ]);
}

void main() {
  testWidgets('shows personality and level tooltip on hover and click', (
    tester,
  ) async {
    void Function(Map<String, Object?> message)? rendererCallback;
    var readySent = false;
    await tester.pumpWidget(
      MaterialApp(
        home: WorldScreen(
          gateway: _FakeWorldGateway(),
          userKey: 'user-key',
          worldName: '테스트 공간',
          onBack: () {},
          rendererBuilder: (controller, onMessage) {
            rendererCallback = onMessage;
            controller.attach((_) async {});
            if (!readySent) {
              readySent = true;
              Future.microtask(
                () => onMessage({
                  'version': 1,
                  'type': 'rendererReady',
                  'payload': <String, Object?>{},
                }),
              );
            }
            return const ColoredBox(color: Colors.white);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    rendererCallback!({
      'version': 1,
      'type': 'objectHovered',
      'payload': <String, Object?>{'objectCode': 'BOOKSHELF'},
    });
    await tester.pump();

    expect(find.byKey(const Key('world-object-tooltip')), findsOneWidget);
    expect(find.text('책장'), findsOneWidget);
    expect(find.text('학습 성향 · 현재 2단계 / 5단계'), findsOneWidget);
    expect(find.text('60 EXP · 다음 단계 120 EXP'), findsOneWidget);

    rendererCallback!({
      'version': 1,
      'type': 'objectHovered',
      'payload': <String, Object?>{'objectCode': null},
    });
    await tester.pump();
    expect(find.byKey(const Key('world-object-tooltip')), findsNothing);

    rendererCallback!({
      'version': 1,
      'type': 'objectSelected',
      'payload': <String, Object?>{'objectCode': 'BOOKSHELF'},
    });
    await tester.pump();
    expect(find.text('선택한 성장 오브젝트'), findsOneWidget);

    await tester.tap(find.byKey(const Key('world-object-tooltip-close')));
    await tester.pump();
    expect(find.byKey(const Key('world-object-tooltip')), findsNothing);
  });

  testWidgets('snapshot is sent only after renderer ready', (tester) async {
    final messages = <Map<String, Object?>>[];
    var readySent = false;
    await tester.pumpWidget(
      MaterialApp(
        home: WorldScreen(
          gateway: _FakeWorldGateway(),
          userKey: 'user-key',
          worldName: '테스트 공간',
          onBack: () {},
          rendererBuilder: (controller, onMessage) {
            controller.attach((raw) async {
              messages.add(jsonDecode(raw) as Map<String, Object?>);
            });
            if (!readySent) {
              readySent = true;
              Future.microtask(
                () => onMessage({
                  'version': 1,
                  'type': 'rendererReady',
                  'payload': <String, Object?>{},
                }),
              );
            }
            return const ColoredBox(color: Colors.white);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final initialize = messages.singleWhere(
      (message) => message['type'] == 'initializeWorld',
    );
    final payload = initialize['payload'] as Map<String, Object?>;
    final objects = payload['objects'] as List<Object?>;
    expect((objects.single as Map<String, Object?>)['level'], 2);
  });

  testWidgets('sends the grown model level and level-up animation', (
    tester,
  ) async {
    final messages = <Map<String, Object?>>[];
    var readySent = false;
    await tester.pumpWidget(
      MaterialApp(
        home: WorldScreen(
          gateway: _FakeWorldGateway(),
          userKey: 'user-key',
          worldName: '테스트 공간',
          pendingGrowth: const WorldGrowth(
            objectCode: 'BOOKSHELF',
            categoryCode: 'LEARNING',
            awardedExp: 20,
            previousLevel: 1,
            currentLevel: 2,
            currentExp: 60,
            nextLevelRequiredExp: 120,
            levelUp: true,
            rewardApplied: true,
          ),
          onBack: () {},
          rendererBuilder: (controller, onMessage) {
            controller.attach((raw) async {
              messages.add(jsonDecode(raw) as Map<String, Object?>);
            });
            if (!readySent) {
              readySent = true;
              Future.microtask(
                () => onMessage({
                  'version': 1,
                  'type': 'rendererReady',
                  'payload': <String, Object?>{},
                }),
              );
            }
            return const ColoredBox(color: Colors.white);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      messages.map((message) => message['type']),
      containsAllInOrder([
        'initializeWorld',
        'updateObjectLevel',
        'playLevelUp',
      ]),
    );
    final levelMessage = messages.singleWhere(
      (message) => message['type'] == 'updateObjectLevel',
    );
    expect((levelMessage['payload'] as Map<String, Object?>)['level'], 2);
    expect(find.text('BOOKSHELF Lv.2 달성!'), findsOneWidget);
  });

  testWidgets('shows an error when the world snapshot has no objects', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorldScreen(
          gateway: _FakeWorldGateway(snapshot: WorldSnapshot(const [])),
          userKey: 'user-key',
          worldName: '빈 공간',
          onBack: () {},
          rendererBuilder: (controller, onMessage) =>
              const ColoredBox(color: Colors.white),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('World 오브젝트 정보를 불러오지 못했습니다.'), findsOneWidget);
  });

  testWidgets('falls back to all objects when personality filtering is empty', (
    tester,
  ) async {
    final messages = <Map<String, Object?>>[];
    var readySent = false;
    await tester.pumpWidget(
      MaterialApp(
        home: WorldScreen(
          gateway: _FakeWorldGateway(
            snapshot: WorldSnapshot([
              const WorldObjectProgress(
                objectCode: 'BOOKSHELF',
                categoryCode: 'LEARNING',
                displayName: '책장',
                level: 1,
                exp: 0,
                nextLevelRequiredExp: 50,
                maxLevel: 5,
              ),
            ]),
          ),
          userKey: 'user-key',
          worldName: '테스트 공간',
          baseCategoryCodes: const {'CULTURE'},
          onBack: () {},
          rendererBuilder: (controller, onMessage) {
            controller.attach((raw) async {
              messages.add(jsonDecode(raw) as Map<String, Object?>);
            });
            if (!readySent) {
              readySent = true;
              Future.microtask(
                () => onMessage({
                  'version': 1,
                  'type': 'rendererReady',
                  'payload': <String, Object?>{},
                }),
              );
            }
            return const ColoredBox(color: Colors.white);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final initialize = messages.singleWhere(
      (message) => message['type'] == 'initializeWorld',
    );
    final payload = initialize['payload'] as Map<String, Object?>;
    expect(payload['objectCount'], 1);
    expect((payload['objects'] as List<Object?>).length, 1);
  });
}
