import 'package:flutter/services.dart';

enum NicknameValidationError { invalidFormat, bannedWord }

class NicknameValidationResult {
  const NicknameValidationResult._({this.error});

  const NicknameValidationResult.valid() : this._();

  const NicknameValidationResult.invalid(NicknameValidationError error)
    : this._(error: error);

  final NicknameValidationError? error;

  bool get isValid => error == null;

  String? get message => switch (error) {
    NicknameValidationError.invalidFormat =>
      '닉네임은 한글, 영문, 숫자로 1자 이상 12자 이하로 입력해 주세요.',
    NicknameValidationError.bannedWord => '사용할 수 없는 닉네임입니다.',
    null => null,
  };
}

class NicknameValidator {
  NicknameValidator._(this._normalizedBannedWords);

  static const String assetPath = 'assets/config/nickname_banned_words.txt';
  static final RegExp _nicknamePattern = RegExp(r'^[가-힣A-Za-z0-9]{1,12}$');
  static Future<NicknameValidator>? _defaultLoad;

  final Set<String> _normalizedBannedWords;

  static Future<NicknameValidator> load({AssetBundle? bundle}) {
    if (bundle != null) return _loadFrom(bundle);
    return _defaultLoad ??= _loadDefault();
  }

  static Future<NicknameValidator> _loadDefault() async {
    try {
      return await _loadFrom(rootBundle);
    } catch (_) {
      _defaultLoad = null;
      rethrow;
    }
  }

  static Future<NicknameValidator> _loadFrom(AssetBundle bundle) async {
    final contents = await bundle.loadString(assetPath);
    return NicknameValidator.fromContents(contents);
  }

  factory NicknameValidator.fromContents(String contents) {
    final words = contents
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .map((word) => word.toUpperCase())
        .toSet();

    if (words.isEmpty) {
      throw const FormatException('Nickname banned-word file is empty.');
    }
    return NicknameValidator._(Set<String>.unmodifiable(words));
  }

  int get bannedWordCount => _normalizedBannedWords.length;

  NicknameValidationResult validate(String nickname) {
    if (!_nicknamePattern.hasMatch(nickname)) {
      return const NicknameValidationResult.invalid(
        NicknameValidationError.invalidFormat,
      );
    }

    final normalizedNickname = nickname.toUpperCase();
    if (_normalizedBannedWords.any(normalizedNickname.contains)) {
      return const NicknameValidationResult.invalid(
        NicknameValidationError.bannedWord,
      );
    }
    return const NicknameValidationResult.valid();
  }
}
