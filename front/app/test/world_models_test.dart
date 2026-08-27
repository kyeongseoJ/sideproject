import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/world/world_models.dart';

void main() {
  test('world snapshot parses valid objects', () {
    final snapshot = WorldSnapshot.fromJson({
      'objects': [
        {
          'objectCode': 'TRAINING_CORNER',
          'categoryCode': 'MOVEMENT',
          'displayName': '운동 코너',
          'level': 2,
          'exp': 60,
          'nextLevelRequiredExp': 120,
          'maxLevel': 5,
        },
      ],
    });
    expect(snapshot.objects.single.level, 2);
    expect(snapshot.objects.single.displayName, '운동 코너');
    expect(snapshot.objects.single.categoryDisplayName, '운동');
  });

  test('world snapshot rejects an invalid level', () {
    expect(
      () => WorldSnapshot.fromJson({
        'objects': [
          {
            'objectCode': 'TRAINING_CORNER',
            'categoryCode': 'MOVEMENT',
            'displayName': '운동 코너',
            'level': 0,
            'exp': 0,
            'nextLevelRequiredExp': 50,
            'maxLevel': 5,
          },
        ],
      }),
      throwsFormatException,
    );
  });
}
