import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelty_app/api/personality_api.dart';
import 'package:novelty_app/main.dart';
import 'package:novelty_app/personality/personality_bootstrap.dart';
import 'package:novelty_app/personality/personality_models.dart';
import 'package:novelty_app/user/user_key_store.dart';

void main() {
  test('creates and caches an anonymous user when no key exists', () async {
    final store = _FakeUserKeyStore();
    final gateway = _FakePersonalityGateway();
    final service = PersonalityBootstrapService(
      gateway: gateway,
      userKeyStore: store,
    );

    final result = await service.load();

    expect(result.entry, PersonalityEntry.form);
    expect(result.user.nickname, '노벨티07QK');
    expect(result.userKey, 'new-user-key');
    expect(store.value, 'new-user-key');
    expect(gateway.createCalls, 1);
    expect(gateway.getCalls, 0);
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
    expect(gateway.createCalls, 0);
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
    'does not replace cached identity after a 401 restore failure',
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
      expect(gateway.createCalls, 0);
    },
  );

  test('maps cache read and write failures to safe bootstrap errors', () async {
    final readFailure = _FakeUserKeyStore(readError: StateError('cache path'));
    final writeFailure = _FakeUserKeyStore(writeError: StateError('disk path'));

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
    await expectLater(
      PersonalityBootstrapService(
        gateway: _FakePersonalityGateway(),
        userKeyStore: writeFailure,
      ).load(),
      throwsA(
        isA<PersonalityBootstrapException>()
            .having(
              (error) => error.kind,
              'kind',
              PersonalityBootstrapFailureKind.cache,
            )
            .having(
              (error) => error.message,
              'message',
              isNot(contains('disk path')),
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

  testWidgets('shows loading then the V2 form entry for a new user', (
    tester,
  ) async {
    final completer = Completer<AnonymousUser>();
    final gateway = _FakePersonalityGateway(createFuture: completer.future);

    await tester.pumpWidget(
      NoveltyApp(
        personalityGateway: gateway,
        userKeyStore: _FakeUserKeyStore(),
      ),
    );

    expect(
      find.byKey(const Key('personality-bootstrap-loading')),
      findsOneWidget,
    );
    completer.complete(_anonymousUser());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('personality-form-entry')), findsOneWidget);
    expect(find.text('쉬는 날의 나는?'), findsOneWidget);
  });

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
  _FakeUserKeyStore({this.value, this.readError, this.writeError});

  String? value;
  final Object? readError;
  final Object? writeError;
  int clearCalls = 0;

  @override
  Future<String?> read() async {
    if (readError != null) throw readError!;
    return value;
  }

  @override
  Future<void> write(String userKey) async {
    if (writeError != null) throw writeError!;
    value = userKey;
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    value = null;
  }
}

class _FakePersonalityGateway implements PersonalityGateway {
  _FakePersonalityGateway({this.currentUser, this.getError, this.createFuture});

  UserProfile? currentUser;
  Object? getError;
  final Future<AnonymousUser>? createFuture;
  int createCalls = 0;
  int getCalls = 0;
  String? receivedUserKey;

  @override
  Future<AnonymousUser> createAnonymousUser() async {
    createCalls++;
    return createFuture == null ? _anonymousUser() : await createFuture!;
  }

  @override
  Future<UserProfile> getCurrentUser(String userKey) async {
    getCalls++;
    receivedUserKey = userKey;
    if (getError != null) throw getError!;
    return currentUser ?? _notAnalyzedUser();
  }

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
