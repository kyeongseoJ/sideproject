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
      level: 1,
      exp: 0,
      nextLevelRequiredExp: 50,
    ),
    const WorldObjectProgress(
      objectCode: 'BOOKSHELF',
      categoryCode: 'LEARNING',
      level: 2,
      exp: 60,
      nextLevelRequiredExp: 120,
    ),
    const WorldObjectProgress(
      objectCode: 'KITCHEN_TABLE',
      categoryCode: 'FOOD',
      level: 1,
      exp: 0,
      nextLevelRequiredExp: 50,
    ),
  ]);
}

void main() {
  testWidgets(
    'sends personality objects and completed categories to renderer',
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

      final initialize = messages.singleWhere(
        (message) => message['type'] == 'initializeWorld',
      );
      final payload = initialize['payload'] as Map<String, Object?>;
      final objects = payload['objects'] as List<Object?>;
      final codes = objects
          .map((object) => (object as Map<String, Object?>)['objectCode'])
          .toSet();
      expect(codes, {'ART_EASEL', 'BOOKSHELF'});
      expect(find.text('고요한 몰입 작업실'), findsOneWidget);

      expect(find.textContaining('드래그 회전'), findsNothing);
      await tester.tap(find.byKey(const Key('world-help-toggle')));
      await tester.pumpAndSettle();
      expect(find.textContaining('드래그 회전'), findsOneWidget);

      await tester.tap(find.byKey(const Key('world-preview-open-header')));
      expect(opened, 1);
    },
  );
}
