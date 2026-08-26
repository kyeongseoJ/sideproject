import 'package:flutter/material.dart';
import 'package:novelty_app/api/personality_api.dart';
import 'package:novelty_app/novelty_theme.dart';
import 'package:novelty_app/personality/personality_models.dart';

class AccountEntryScreen extends StatefulWidget {
  const AccountEntryScreen({
    super.key,
    required this.gateway,
    required this.onAuthenticated,
  });

  final PersonalityGateway gateway;
  final ValueChanged<AnonymousUser> onAuthenticated;

  @override
  State<AccountEntryScreen> createState() => _AccountEntryScreenState();
}

class _AccountEntryScreenState extends State<AccountEntryScreen> {
  final _loginIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _registerMode = false;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _loginIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = _registerMode
          ? await widget.gateway.register(
              _loginIdController.text,
              _passwordController.text,
            )
          : await widget.gateway.login(
              _loginIdController.text,
              _passwordController.text,
            );
      if (mounted) widget.onAuthenticated(user);
    } on PersonalityApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = '계정 정보를 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _registerMode = !_registerMode;
      _error = null;
      _passwordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Novelty',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: NoveltyColors.primary,
                  ),
                ),
                const SizedBox(height: 48),
                Container(
                  key: const Key('account-entry-card'),
                  padding: const EdgeInsets.all(NoveltySpacing.lg),
                  decoration: NoveltyDecorations.card(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _registerMode ? '새 계정 만들기' : '다시 만나 반가워요',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _registerMode
                            ? '닉네임은 가입과 동시에 무작위로 만들어지며 프로필에서 바꿀 수 있어요.'
                            : '아이디와 비밀번호로 나의 성향과 오늘의 미션을 이어가세요.',
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        key: const Key('account-login-id'),
                        controller: _loginIdController,
                        enabled: !_busy,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: '사용자 아이디',
                          hintText: '영문 소문자·숫자·밑줄 4~20자',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        key: const Key('account-password'),
                        controller: _passwordController,
                        enabled: !_busy,
                        obscureText: _obscurePassword,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: '비밀번호',
                          hintText: _registerMode ? '영문·숫자 포함 8자 이상' : null,
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword ? '비밀번호 표시' : '비밀번호 숨기기',
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                        ),
                      ),
                      if (_error case final error?) ...[
                        const SizedBox(height: 12),
                        Container(
                          key: const Key('account-entry-error'),
                          padding: const EdgeInsets.all(NoveltySpacing.md),
                          decoration: NoveltyDecorations.error(),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 20,
                                color: NoveltyColors.error,
                              ),
                              const SizedBox(width: NoveltySpacing.sm),
                              Expanded(
                                child: Text(
                                  error,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: NoveltyColors.ink),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        key: const Key('account-submit'),
                        onPressed: _busy ? null : _submit,
                        child: Text(
                          _busy ? '처리 중...' : (_registerMode ? '회원가입' : '로그인'),
                        ),
                      ),
                      TextButton(
                        key: const Key('account-mode-toggle'),
                        onPressed: _busy ? null : _toggleMode,
                        child: Text(
                          _registerMode
                              ? '이미 계정이 있어요 · 로그인'
                              : '처음 방문했어요 · 회원가입',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '노벨티 효과는 새로운 자극을 접했을 때 호기심과 참여 동기가 높아지는 현상입니다.\n\n노벨티는 이 효과를 활용해 매일 작은 새로운 행동을 시작하도록 돕습니다.',
                  key: Key('novelty-service-description'),
                  style: TextStyle(color: NoveltyColors.gray040, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
