import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/user/nickname_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('공용 금칙어 asset을 불러온다', () async {
    final validator = await NicknameValidator.load();

    expect(validator.bannedWordCount, 9);
  });

  test('허용 문자와 길이를 검증한다', () {
    final validator = NicknameValidator.fromContents('BLOCKED');

    expect(validator.validate('정상Nick12').isValid, isTrue);
    expect(
      validator.validate('공백 닉네임').error,
      NicknameValidationError.invalidFormat,
    );
    expect(
      validator.validate('닉네임!').error,
      NicknameValidationError.invalidFormat,
    );
    expect(
      validator.validate('열두글자를초과하는닉네임123').error,
      NicknameValidationError.invalidFormat,
    );
  });

  test('대소문자와 포함 관계를 정규화해 금칙어를 차단한다', () {
    final validator = NicknameValidator.fromContents('''
# test words
BLOCKED
''');

    final result = validator.validate('myBlocked1');

    expect(result.error, NicknameValidationError.bannedWord);
    expect(result.message, '사용할 수 없는 닉네임입니다.');
  });
}
