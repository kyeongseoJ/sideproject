import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/api/personality_api.dart';
import 'package:novelty_app/main.dart';
import 'package:novelty_app/personality/personality_bootstrap.dart';
import 'package:novelty_app/personality/personality_models.dart';
import 'package:novelty_app/user/user_key_store.dart';

void main() {
  test('requires sign in when no cached user key exists', () async {
    final store = _FakeUserKeyStore();
    final gateway = _FakePersonalityGateway();
    final service = PersonalityBootstrapService(
      gateway: gateway,
      userKeyStore: store,
    );

    await expectLater(
      service.load(),
      throwsA(
        isA<PersonalityBootstrapException>().having(
          (error) => error.kind,
          'kind',
          PersonalityBootstrapFailureKind.signInRequired,
        ),
      ),
    );
    expect(store.value, isNull);
  });

  test('restores cached user and branches to form when not analyzed', () async {
    final store = _FakeUserKeyStore(value: 'cached-user-key');
    final gateway = _FakePersonalityGateway(currentUser: _notAnalyzedUser());

    final result = await PersonalityBootstrapService(
      gateway: gateway,
      userKeyStore: store,
    ).load();

    expect(result.entry, PersonalityEntry.form);
    expect(result.userKey, 'cached-user-key');
    expect(gateway.receivedUserKey, 'cached-user-key');
  });

  test('restores cached user and branches to profile when analyzed', () async {
    final result = await PersonalityBootstrapService(
      gateway: _FakePersonalityGateway(currentUser: _analyzedUser()),
      userKeyStore: _FakeUserKeyStore(value: 'cached-user-key'),
    ).load();

    expect(result.entry, PersonalityEntry.profile);
    expect(result.user.personality?.typeName, '고요한 몰입가');
  });

  test(
    'reports an invalid cached identity so the UI can return to login',
    () async {
      final store = _FakeUserKeyStore(value: 'expired-user-key');
      final gateway = _FakePersonalityGateway(
        getError: const PersonalityApiException(
          kind: PersonalityApiFailureKind.api,
          code: PersonalityApiErrorCode.invalidUserKey,
          statusCode: 401,
          message: '사용자 정보를 확인할 수 없습니다.',
        ),
      );

      await expectLater(
        PersonalityBootstrapService(
          gateway: gateway,
          userKeyStore: store,
        ).load(),
        throwsA(
          isA<PersonalityBootstrapException>()
              .having(
                (error) => error.apiError?.code,
                'code',
                PersonalityApiErrorCode.invalidUserKey,
              )
              .having(
                (error) => error.message,
                'message',
                '사용자 정보를 확인할 수 없습니다.',
              ),
        ),
      );
      expect(store.value, 'expired-user-key');
      expect(store.clearCalls, 0);
    },
  );

  testWidgets('returns an expired cached identity to the login screen', (
    tester,
  ) async {
    final store = _FakeUserKeyStore(value: 'expired-user-key');
    await tester.pumpWidget(
      NoveltyApp(
        personalityGateway: _FakePersonalityGateway(
          getError: const PersonalityApiException(
            kind: PersonalityApiFailureKind.api,
            code: PersonalityApiErrorCode.invalidUserKey,
            statusCode: 401,
            message: '사용자 정보를 확인할 수 없습니다.',
          ),
        ),
        userKeyStore: store,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-entry-card')), findsOneWidget);
    expect(store.value, isNull);
    expect(store.clearCalls, 1);
  });

  test('maps cache read failures to safe bootstrap errors', () async {
    final readFailure = _FakeUserKeyStore(readError: StateError('cache path'));

    await expectLater(
      PersonalityBootstrapService(
        gateway: _FakePersonalityGateway(),
        userKeyStore: readFailure,
      ).load(),
      throwsA(
        isA<PersonalityBootstrapException>().having(
          (error) => error.kind,
          'kind',
          PersonalityBootstrapFailureKind.cache,
        ),
      ),
    );
  });

  test('preserves network error classification and safe message', () async {
    final gateway = _FakePersonalityGateway(
      getError: const PersonalityApiException(
        kind: PersonalityApiFailureKind.network,
        message: '서버에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      ),
    );

    await expectLater(
      PersonalityBootstrapService(
        gateway: gateway,
        userKeyStore: _FakeUserKeyStore(value: 'cached-user-key'),
      ).load(),
      throwsA(
        isA<PersonalityBootstrapException>()
            .having(
              (error) => error.apiError?.kind,
              'kind',
              PersonalityApiFailureKind.network,
            )
            .having(
              (error) => error.toString(),
              'toString',
              isNot(contains('cached-user-key')),
            ),
      ),
    );
  });

  testWidgets(
    'shows login first and offers registration before continuing to the form',
    (tester) async {
      final gateway = _FakePersonalityGateway(currentUser: _notAnalyzedUser());

      await tester.pumpWidget(
        NoveltyApp(
          personalityGateway: gateway,
          userKeyStore: _FakeUserKeyStore(),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-entry-card')), findsOneWidget);
      expect(
        find.byKey(const Key('novelty-service-description')),
        findsOneWidget,
      );
      expect(find.text('다시 만나 반가워요'), findsOneWidget);
      expect(find.text('처음 방문했어요 · 회원가입'), findsOneWidget);
      await tester.tap(find.byKey(const Key('account-mode-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('새 계정 만들기'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('account-login-id')),
        'tester1',
      );
      await tester.enterText(
        find.byKey(const Key('account-password')),
        'Password1',
      );
      await tester.tap(find.byKey(const Key('account-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('personality-form-entry')), findsOneWidget);
      expect(find.text('쉬는 날의 나는?'), findsOneWidget);
    },
  );

  testWidgets('skips the form and shows profile entry for analyzed user', (
    tester,
  ) async {
    await tester.pumpWidget(
      NoveltyApp(
        personalityGateway: _FakePersonalityGateway(
          currentUser: _analyzedUser(),
        ),
        userKeyStore: _FakeUserKeyStore(value: 'cached-user-key'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('personality-profile-entry')), findsOneWidget);
    expect(find.byKey(const Key('personality-form-entry')), findsNothing);
    expect(find.text('고요한 몰입가'), findsOneWidget);
    expect(find.text('실내 중심'), findsOneWidget);
    expect(find.text('계획 실행형'), findsOneWidget);
    expect(find.text('만들기'), findsOneWidget);
  });

  testWidgets('shows a safe error and retries the same cached user', (
    tester,
  ) async {
    final gateway = _FakePersonalityGateway(
      getError: const PersonalityApiException(
        kind: PersonalityApiFailureKind.network,
        message: '서버에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      ),
    );
    final store = _FakeUserKeyStore(value: 'cached-user-key');

    await tester.pumpWidget(
      NoveltyApp(personalityGateway: gateway, userKeyStore: store),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('personality-bootstrap-error')),
      findsOneWidget,
    );
    gateway
      ..getError = null
      ..currentUser = _notAnalyzedUser();
    await tester.tap(find.byKey(const Key('personality-bootstrap-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('personality-form-entry')), findsOneWidget);
    expect(gateway.receivedUserKey, 'cached-user-key');
    expect(gateway.getCalls, 2);
  });
}

class _FakeUserKeyStore implements UserKeyStore {
  _FakeUserKeyStore({this.value, this.readError});

  String? value;
  final Object? readError;
  int clearCalls = 0;

  @override
  Future<String?> read() async {
    if (readError != null) throw readError!;
    return value;
  }

  @override
  Future<void> write(String userKey) async {
    value = userKey;
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    value = null;
  }
}

class _FakePersonalityGateway implements PersonalityGateway {
  _FakePersonalityGateway({this.currentUser, this.getError});

  UserProfile? currentUser;
  Object? getError;
  int getCalls = 0;
  String? receivedUserKey;

  @override
  Future<AnonymousUser> register(String loginId, String password) async =>
      _anonymousUser();

  @override
  Future<AnonymousUser> login(String loginId, String password) async =>
      _anonymousUser();

  @override
  Future<UserProfile> getCurrentUser(String userKey) async {
    getCalls++;
    receivedUserKey = userKey;
    if (getError != null) throw getError!;
    return currentUser ?? _notAnalyzedUser();
  }

  @override
  Future<String> updateNickname(String userKey, String nickname) async =>
      nickname;

  @override
  Future<PersonalityAnalysisResult> submitAnalysis(
    String userKey,
    PersonalityAnalysisRequest request,
  ) {
    throw UnimplementedError('Phase 4 bootstrap does not submit answers.');
  }
}

AnonymousUser _anonymousUser() => const AnonymousUser(
  userId: 7,
  userKey: 'new-user-key',
  nickname: '노벨티07QK',
);

UserProfile _notAnalyzedUser() => const UserProfile(
  userId: 7,
  nickname: '노벨티07QK',
  personalityCompleted: false,
  personality: null,
);

UserProfile _analyzedUser() => UserProfile(
  userId: 7,
  nickname: '노벨티07QK',
  personalityCompleted: true,
  personality: PersonalityProfile(
    typeCode: 'QUIET_FOCUSER',
    typeName: '고요한 몰입가',
    summary: '익숙하고 조용한 공간에서 혼자 집중할 때 편안해요.',
    indoorOutdoor: IndoorOutdoor.indoor,
    indoorOutdoorScore: -1,
    socialLevel: SocialLevel.low,
    socialScore: -1,
    physicalActivityLevel: PhysicalActivityLevel.medium,
    physicalActivityScore: 1,
    noveltyLevel: NoveltyLevel.high,
    noveltyScore: 2,
    executionStyle: ExecutionStyle.planned,
    interests: const [
      PersonalityInterest.creative,
      PersonalityInterest.learning,
    ],
    analysisVersion: 'PERSONALITY_V2',
    analyzedAt: DateTime.parse('2026-08-19T17:15:00+09:00'),
  ),
);
