enum MissionStatus {
  generated('GENERATED'),
  shown('SHOWN'),
  selected('SELECTED'),
  cancelled('CANCELLED'),
  completed('COMPLETED');

  const MissionStatus(this.code);

  final String code;

  String? get uiLabel => switch (this) {
    MissionStatus.selected => '수행중',
    MissionStatus.completed => '완료',
    _ => null,
  };

  static MissionStatus fromCode(String code) {
    return MissionStatus.values.firstWhere(
      (status) => status.code == code,
      orElse: () => throw const FormatException('Unknown mission status.'),
    );
  }
}
