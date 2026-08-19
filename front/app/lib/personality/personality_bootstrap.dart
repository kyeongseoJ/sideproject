import 'package:flutter/material.dart';
import 'package:novelty_app/api/personality_api.dart';
import 'package:novelty_app/personality/personality_experience_screen.dart';
import 'package:novelty_app/personality/personality_models.dart';
import 'package:novelty_app/user/user_key_store.dart';

enum PersonalityEntry { form, profile }

class PersonalityBootstrapResult {
  const PersonalityBootstrapResult({
    required this.entry,
    required this.user,
    required this.userKey,
  });

  final PersonalityEntry entry;
  final UserProfile user;
  final String userKey;
}

enum PersonalityBootstrapFailureKind { cache, api, unexpected }

class PersonalityBootstrapException implements Exception {
  const PersonalityBootstrapException({
    required this.kind,
    required this.message,
    this.apiError,
  });

  final PersonalityBootstrapFailureKind kind;
  final String message;
  final PersonalityApiException? apiError;

  @override
  String toString() => 'PersonalityBootstrapException($kind)';
}

class PersonalityBootstrapService {
  const PersonalityBootstrapService({
    required PersonalityGateway gateway,
    required UserKeyStore userKeyStore,
  }) : _gateway = gateway,
       _userKeyStore = userKeyStore;

  final PersonalityGateway _gateway;
  final UserKeyStore _userKeyStore;

  Future<PersonalityBootstrapResult> load() async {
    final String? userKey;
    try {
      userKey = await _userKeyStore.read();
    } catch (_) {
      throw const PersonalityBootstrapException(
        kind: PersonalityBootstrapFailureKind.cache,
        message: '저장된 사용자 정보를 불러오지 못했습니다.',
      );
    }

    try {
      if (userKey == null) {
        final anonymousUser = await _gateway.createAnonymousUser();
        try {
          await _userKeyStore.write(anonymousUser.userKey);
        } catch (_) {
          throw const PersonalityBootstrapException(
            kind: PersonalityBootstrapFailureKind.cache,
            message: '새 사용자 정보를 기기에 저장하지 못했습니다.',
          );
        }
        return PersonalityBootstrapResult(
          entry: PersonalityEntry.form,
          user: anonymousUser.toProfile(),
          userKey: anonymousUser.userKey,
        );
      }

      final user = await _gateway.getCurrentUser(userKey);
      return PersonalityBootstrapResult(
        entry: user.personalityCompleted
            ? PersonalityEntry.profile
            : PersonalityEntry.form,
        user: user,
        userKey: userKey,
      );
    } on PersonalityBootstrapException {
      rethrow;
    } on PersonalityApiException catch (exception) {
      throw PersonalityBootstrapException(
        kind: PersonalityBootstrapFailureKind.api,
        message: exception.message,
        apiError: exception,
      );
    } catch (_) {
      throw const PersonalityBootstrapException(
        kind: PersonalityBootstrapFailureKind.unexpected,
        message: '사용자 정보를 준비하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }
  }
}

class PersonalityBootstrapScreen extends StatefulWidget {
  const PersonalityBootstrapScreen({
    super.key,
    this.gateway,
    this.userKeyStore,
  });

  final PersonalityGateway? gateway;
  final UserKeyStore? userKeyStore;

  @override
  State<PersonalityBootstrapScreen> createState() =>
      _PersonalityBootstrapScreenState();
}

class _PersonalityBootstrapScreenState
    extends State<PersonalityBootstrapScreen> {
  PersonalityApi? _ownedApi;
  late final PersonalityBootstrapService _service;
  PersonalityBootstrapResult? _result;
  PersonalityBootstrapException? _error;

  @override
  void initState() {
    super.initState();
    final gateway = widget.gateway ?? (_ownedApi = PersonalityApi());
    _service = PersonalityBootstrapService(
      gateway: gateway,
      userKeyStore: widget.userKeyStore ?? SharedPreferencesUserKeyStore(),
    );
    _load();
  }

  @override
  void dispose() {
    _ownedApi?.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _result = null;
      _error = null;
    });
    try {
      final result = await _service.load();
      if (!mounted) return;
      setState(() => _result = result);
    } on PersonalityBootstrapException catch (exception) {
      if (!mounted) return;
      setState(() => _error = exception);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return _BootstrapMessageScaffold(
        key: const Key('personality-bootstrap-error'),
        title: '사용자 정보를 불러오지 못했어요',
        message: error.message,
        actionLabel: '다시 시도',
        onAction: _load,
      );
    }

    final result = _result;
    if (result == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            key: Key('personality-bootstrap-loading'),
          ),
        ),
      );
    }

    return PersonalityExperienceScreen(
      key: Key(
        result.entry == PersonalityEntry.profile
            ? 'personality-profile-entry'
            : 'personality-form-entry',
      ),
      gateway: widget.gateway ?? _ownedApi!,
      userKey: result.userKey,
      initialUser: result.user,
    );
  }
}

class _BootstrapMessageScaffold extends StatelessWidget {
  const _BootstrapMessageScaffold({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  border: Border.all(color: const Color(0xFFEBEBEB)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      Text(message, style: theme.textTheme.bodyLarge),
                      if (onAction != null && actionLabel != null) ...[
                        const SizedBox(height: 24),
                        FilledButton(
                          key: const Key('personality-bootstrap-retry'),
                          onPressed: onAction,
                          child: Text(actionLabel!),
                        ),
                      ],
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
}
