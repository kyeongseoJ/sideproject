import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/mission/mission_status.dart';

void main() {
  test('서버 미션 상태 코드를 모두 변환한다', () {
    expect(MissionStatus.fromCode('GENERATED'), MissionStatus.generated);
    expect(MissionStatus.fromCode('SHOWN'), MissionStatus.shown);
    expect(MissionStatus.fromCode('SELECTED'), MissionStatus.selected);
    expect(MissionStatus.fromCode('CANCELLED'), MissionStatus.cancelled);
    expect(MissionStatus.fromCode('COMPLETED'), MissionStatus.completed);
  });

  test('사용자에게 표시할 상태만 한글 라벨을 제공한다', () {
    expect(MissionStatus.selected.uiLabel, '수행중');
    expect(MissionStatus.completed.uiLabel, '완료');
    expect(MissionStatus.generated.uiLabel, isNull);
    expect(MissionStatus.shown.uiLabel, isNull);
    expect(MissionStatus.cancelled.uiLabel, isNull);
  });

  test('알 수 없는 상태 코드는 거부한다', () {
    expect(
      () => MissionStatus.fromCode('UNKNOWN'),
      throwsA(isA<FormatException>()),
    );
  });
}
