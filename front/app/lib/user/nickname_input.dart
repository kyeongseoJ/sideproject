import 'package:flutter/material.dart';
import 'package:novelty_app/api/personality_api.dart';
import 'package:novelty_app/novelty_theme.dart';
import 'package:novelty_app/user/nickname_validator.dart';

typedef NicknameSubmit = Future<String> Function(String nickname);

class NicknameSetupScreen extends StatefulWidget {
  const NicknameSetupScreen({
    super.key,
    required this.initialNickname,
    required this.onSubmit,
  });

  final String initialNickname;
  final NicknameSubmit onSubmit;

  @override
  State<NicknameSetupScreen> createState() => _NicknameSetupScreenState();
}

class _NicknameSetupScreenState extends State<NicknameSetupScreen> {
  late final TextEditingController _controller;
  NicknameValidator? _validator;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNickname);
    _loadValidator();
  }

  Future<void> _loadValidator() async {
    try {
      final validator = await NicknameValidator.load();
      if (mounted) setState(() => _validator = validator);
    } catch (_) {
      if (mounted) setState(() => _error = '닉네임 설정을 준비하지 못했습니다.');
    }
  }

  Future<void> _submit() async {
    if (_busy || _validator == null) return;
    final nickname = _controller.text;
    final validation = _validator!.validate(nickname);
    if (!validation.isValid) {
      setState(() => _error = validation.message);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(nickname);
    } on PersonalityApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '닉네임을 저장하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                minHeight: constraints.maxHeight - 64,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Novelty',
                      key: const Key('novelty-onboarding-logo'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: NoveltyColors.primary),
                    ),
                    const Spacer(),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: NoveltyColors.line),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '먼저 이름을 정해 주세요',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '나중에 프로필에서 다시 바꿀 수 있어요.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 24),
                            TextField(
                              key: const Key('nickname-setup-input'),
                              controller: _controller,
                              enabled: !_busy,
                              maxLength: 12,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                labelText: '닉네임',
                                hintText: '한글, 영문, 숫자 1~12자',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            if (_error case final error?) ...[
                              const SizedBox(height: 8),
                              Text(
                                error,
                                key: const Key('nickname-setup-error'),
                                style: const TextStyle(
                                  color: NoveltyColors.error,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            FilledButton(
                              key: const Key('nickname-setup-submit'),
                              onPressed: _busy || _validator == null
                                  ? null
                                  : _submit,
                              child: Text(
                                _busy ? '설문을 준비하는 중...' : '이 닉네임으로 시작',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '노벨티 효과는 새로운 자극을 접했을 때\n'
                      '호기심과 참여 동기가 높아지는 현상입니다.\n\n'
                      '노벨티는 이 효과를 활용해\n'
                      '매일 작은 새로운 행동을 시작하도록 설계된 서비스입니다.',
                      key: const Key('novelty-service-description'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      key: const Key('returning-user-guidance'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: NoveltyColors.primaryFaint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '이미 이용 중인 사용자는 같은 브라우저나 앱으로 접속하면 저장된 정보로 자동으로 이어집니다.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: NoveltyColors.primaryStrong,
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<String?> showNicknameEditDialog({
  required BuildContext context,
  required String initialNickname,
  required NicknameSubmit onSubmit,
}) async {
  final validator = await NicknameValidator.load();
  if (!context.mounted) return null;
  var nickname = initialNickname;
  String? errorText;
  bool busy = false;
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        key: const Key('nickname-edit-dialog'),
        title: const Text('닉네임 수정'),
        content: TextFormField(
          key: const Key('nickname-edit-input'),
          initialValue: initialNickname,
          onChanged: (value) => nickname = value,
          autofocus: true,
          enabled: !busy,
          maxLength: 12,
          decoration: InputDecoration(
            labelText: '닉네임',
            errorText: errorText,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const Key('nickname-edit-submit'),
            onPressed: busy
                ? null
                : () async {
                    final validation = validator.validate(nickname);
                    if (!validation.isValid) {
                      setDialogState(() => errorText = validation.message);
                      return;
                    }
                    setDialogState(() {
                      busy = true;
                      errorText = null;
                    });
                    try {
                      final saved = await onSubmit(nickname);
                      if (dialogContext.mounted)
                        Navigator.of(dialogContext).pop(saved);
                    } on PersonalityApiException catch (error) {
                      setDialogState(() {
                        busy = false;
                        errorText = error.message;
                      });
                    } catch (_) {
                      setDialogState(() {
                        busy = false;
                        errorText = '닉네임을 저장하지 못했습니다.';
                      });
                    }
                  },
            child: Text(busy ? '저장 중...' : '저장'),
          ),
        ],
      ),
    ),
  );
}
