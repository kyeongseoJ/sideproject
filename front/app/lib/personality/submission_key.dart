import 'dart:math';

abstract interface class SubmissionKeyGenerator {
  String generate();
}

class UuidV4SubmissionKeyGenerator implements SubmissionKeyGenerator {
  UuidV4SubmissionKeyGenerator({Random? random})
    : _random = random ?? Random.secure();

  final Random _random;

  @override
  String generate() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}

class PersonalitySubmissionSession {
  PersonalitySubmissionSession({SubmissionKeyGenerator? generator})
    : _generator = generator ?? UuidV4SubmissionKeyGenerator();

  final SubmissionKeyGenerator _generator;
  String? _submissionKey;

  String keyForAttempt() => _submissionKey ??= _generator.generate();

  void complete() {
    _submissionKey = null;
  }

  void restart() {
    _submissionKey = null;
  }
}
