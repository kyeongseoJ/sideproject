import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/personality/submission_key.dart';

void main() {
  test('generates RFC 4122 version 4 submission keys', () {
    final generator = UuidV4SubmissionKeyGenerator(random: Random(7));

    final first = generator.generate();
    final second = generator.generate();

    expect(
      first,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(second, isNot(first));
  });

  test(
    'reuses a key for retries and rotates only after complete or restart',
    () {
      final generator = _SequenceGenerator();
      final session = PersonalitySubmissionSession(generator: generator);

      expect(session.keyForAttempt(), 'submission-1');
      expect(session.keyForAttempt(), 'submission-1');
      expect(generator.calls, 1);

      session.complete();
      expect(session.keyForAttempt(), 'submission-2');

      session.restart();
      expect(session.keyForAttempt(), 'submission-3');
    },
  );
}

class _SequenceGenerator implements SubmissionKeyGenerator {
  int calls = 0;

  @override
  String generate() => 'submission-${++calls}';
}
