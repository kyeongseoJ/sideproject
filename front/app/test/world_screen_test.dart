import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/api/world_api.dart';
import 'package:novelty_app/world/world_models.dart';
import 'package:novelty_app/world/world_screen.dart';

class _FakeWorldGateway implements WorldGateway {
  @override
  Future<WorldSnapshot> getSnapshot(String userKey) async => WorldSnapshot([
    const WorldObjectProgress(
      objectCode: 'BOOKSHELF',
      categoryCode: 'LEARNING',
      level: 2,
      exp: 60,
      nextLevelRequiredExp: 120,
    ),
  ]);
}

void main() {
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
}
