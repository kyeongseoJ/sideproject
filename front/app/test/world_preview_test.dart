import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/api/world_api.dart';
import 'package:novelty_app/world/world_models.dart';
import 'package:novelty_app/world/world_preview.dart';

class _FakeWorldGateway implements WorldGateway {
  @override
  Future<WorldSnapshot> getSnapshot(String userKey) async => WorldSnapshot([
    const WorldObjectProgress(
      objectCode: 'ART_EASEL',
      categoryCode: 'CREATIVE',
      displayName: '창작 이젤',
      level: 1,
      exp: 0,
      nextLevelRequiredExp: 50,
      maxLevel: 5,
    ),
    const WorldObjectProgress(
      objectCode: 'BOOKSHELF',
      categoryCode: 'LEARNING',
      displayName: '책장',
      level: 2,
      exp: 60,
      nextLevelRequiredExp: 120,
      maxLevel: 5,
    ),
    const WorldObjectProgress(
      objectCode: 'KITCHEN_TABLE',
      categoryCode: 'FOOD',
      displayName: '키친 테이블',
      level: 1,
      exp: 0,
      nextLevelRequiredExp: 50,
      maxLevel: 5,
    ),
  ]);
}

void main() {
    testWidgets(
    'sends only completed category objects to renderer',
    (tester) async {
      final messages = <Map<String, Object?>>[];
      var opened = 0;
      var readySent = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorldPreview(
              gateway: _FakeWorldGateway(),
              userKey: 'user-key',
              worldName: '고요한 몰입 작업실',
              baseCategoryCodes: const {'CREATIVE'},
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
              onOpen: () => opened++,
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
        ),
      );
      await tester.pumpAndSettle();

      final initialize = messages.firstWhere(
        (message) => message['type'] == 'initializeWorld',
      );
      final payload = initialize['payload'] as Map<String, Object?>;
      final objects = payload['objects'] as List<Object?>;
      final codes = objects
          .map((object) => (object as Map<String, Object?>)['objectCode'])
          .toSet();
      expect(codes, {'BOOKSHELF'});
      expect(
        messages.map((message) => message['type']),
        containsAllInOrder([
          'initializeWorld',
          'updateObjectLevel',
          'playLevelUp',
        ]),
      );
      expect(find.text('고요한 몰입 작업실'), findsOneWidget);

      expect(find.textContaining('드래그 회전'), findsNothing);
      await tester.tap(find.byKey(const Key('world-help-toggle')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('드래그 회전'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('드래그 회전'), findsNothing);

      await tester.tap(find.byKey(const Key('world-preview-open-header')));
      expect(opened, 1);
    },
  );

  testWidgets('reduces the inline World stage on a narrow mobile screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorldPreview(
            gateway: _FakeWorldGateway(),
            userKey: 'user-key',
            worldName: '고요한 몰입 작업실',
            baseCategoryCodes: const {'CREATIVE'},
            onOpen: () {},
            rendererBuilder: (controller, onMessage) =>
                const ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final stage = tester.widget<SizedBox>(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.height == 240,
      ),
    );
    expect(stage.height, 240);
    expect(tester.takeException(), isNull);
  });
}
