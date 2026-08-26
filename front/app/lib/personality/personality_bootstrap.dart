import 'package:flutter/material.dart';
import 'package:novelty_app/api/mission_api.dart';
import 'package:novelty_app/api/personality_api.dart';
import 'package:novelty_app/api/world_api.dart';
import 'package:novelty_app/novelty_theme.dart';
import 'package:novelty_app/personality/personality_experience_screen.dart';
import 'package:novelty_app/personality/personality_models.dart';
import 'package:novelty_app/user/user_key_store.dart';
import 'package:novelty_app/user/account_entry_screen.dart';

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

enum PersonalityBootstrapFailureKind { signInRequired, cache, api, unexpected }

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
        throw const PersonalityBootstrapException(
          kind: PersonalityBootstrapFailureKind.signInRequired,
          message: '로그인이 필요합니다.',
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
    this.missionGateway,
    this.userKeyStore,
    this.worldGateway,
    this.onReady,
  });

  final PersonalityGateway? gateway;
  final MissionGateway? missionGateway;
  final UserKeyStore? userKeyStore;
  final WorldGateway? worldGateway;
  final VoidCallback? onReady;

  @override
  State<PersonalityBootstrapScreen> createState() =>
      _PersonalityBootstrapScreenState();
}

class _PersonalityBootstrapScreenState
    extends State<PersonalityBootstrapScreen> {
  PersonalityApi? _ownedApi;
  MissionApi? _ownedMissionApi;
  WorldApi? _ownedWorldApi;
  late final PersonalityBootstrapService _service;
  late final PersonalityGateway _gateway;
  late final UserKeyStore _userKeyStore;
  PersonalityBootstrapResult? _result;
  PersonalityBootstrapException? _error;
  bool _showAccount = false;

  @override
  void initState() {
    super.initState();
    _gateway = widget.gateway ?? (_ownedApi = PersonalityApi());
    _userKeyStore = widget.userKeyStore ?? SharedPreferencesUserKeyStore();
    _ownedMissionApi = widget.missionGateway == null ? MissionApi() : null;
    _ownedWorldApi = widget.worldGateway == null && widget.gateway == null
        ? WorldApi()
        : null;
    _service = PersonalityBootstrapService(
      gateway: _gateway,
      userKeyStore: _userKeyStore,
    );
    _load();
  }

  @override
  void dispose() {
    _ownedApi?.close();
    _ownedMissionApi?.close();
    _ownedWorldApi?.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _result = null;
      _error = null;
      _showAccount = false;
    });
    try {
      final result = await _service.load();
      if (!mounted) return;
      setState(() => _result = result);
      widget.onReady?.call();
    } on PersonalityBootstrapException catch (exception) {
      if (!mounted) return;
      if (exception.kind == PersonalityBootstrapFailureKind.signInRequired) {
        setState(() => _showAccount = true);
        widget.onReady?.call();
      } else if (exception.apiError?.code ==
          PersonalityApiErrorCode.invalidUserKey) {
        try {
          await _userKeyStore.clear();
        } catch (_) {
          if (!mounted) return;
          setState(() => _error = exception);
          widget.onReady?.call();
          return;
        }
        if (mounted) {
          setState(() => _showAccount = true);
          widget.onReady?.call();
        }
      } else {
        setState(() => _error = exception);
        widget.onReady?.call();
      }
    }
  }

  Future<void> _authenticated(AnonymousUser account) async {
    try {
      await _userKeyStore.write(account.userKey);
      final profile = await _gateway.getCurrentUser(account.userKey);
      if (!mounted) return;
      setState(() {
        _showAccount = false;
        _error = null;
        _result = PersonalityBootstrapResult(
          entry: profile.personalityCompleted
              ? PersonalityEntry.profile
              : PersonalityEntry.form,
          user: profile,
          userKey: account.userKey,
        );
      });
      widget.onReady?.call();
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = const PersonalityBootstrapException(
          kind: PersonalityBootstrapFailureKind.cache,
          message: '로그인 정보를 기기에 저장하지 못했습니다.',
        ),
      );
      widget.onReady?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showAccount) {
      return AccountEntryScreen(
        gateway: _gateway,
        onAuthenticated: _authenticated,
      );
    }
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
      gateway: _gateway,
      missionGateway: widget.missionGateway ?? _ownedMissionApi,
      worldGateway: widget.worldGateway ?? _ownedWorldApi,
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
                decoration: NoveltyDecorations.card(
                  color: theme.colorScheme.surfaceContainerLowest,
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
