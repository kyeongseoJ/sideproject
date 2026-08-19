# 사용자 성향 분석 V2 Phase 4 검증 기록

## 1. 검증 정보

- 검증일: 2026-08-19
- 대상: Flutter V2 API 계약, 사용자 키 캐시, 앱 시작 분기
- 결과: 검증 완료
- 제외 범위: 여섯 문항 선택폼(Phase 5), 전체 Profile·재분석 화면(Phase 6), Oracle E2E(Phase 7)

## 2. 구현 내용

- `PERSONALITY_V2` 요청·응답 Model과 Enum을 추가했다.
- 익명 사용자 생성, 현재 사용자 조회, 성향 분석 제출 REST Client를 추가했다.
- 현재 사용자 조회와 성향 분석 제출에 `X-User-Key`를 전송한다.
- 제출 키는 보안 난수 기반 UUID v4로 생성하며, 동일 제출의 재시도 중에는 재사용하고 새 제출 때 교체한다.
- `SharedPreferencesAsync` 기반 사용자 키 저장소를 추가했다.
- 캐시된 사용자 키가 없으면 익명 사용자를 생성·저장한 뒤 성향 분석 진입점으로 이동한다.
- 캐시된 사용자가 분석 전이면 성향 분석 진입점, 분석 완료 상태면 Profile 진입점으로 분기한다.
- 앱 운영 진입점을 V2 Bootstrap으로 교체했다. 기존 V1 설문 구현은 회귀 테스트를 위해 보존하지만 운영 진입점에서 호출하지 않는다.
- Phase 5·6의 UI 범위를 침범하지 않도록 현재 화면은 로딩·진입 분기·안전한 오류·재시도 경계만 제공한다.

## 3. 정상 시나리오 검증

| 시나리오 | 기대 결과 | 결과 |
|---|---|---|
| 사용자 키 캐시 없음 | 익명 사용자 생성 후 키 저장, 성향 분석 진입 | 통과 |
| 분석 전 사용자 키 복원 | `GET /api/users/me` 후 성향 분석 진입 | 통과 |
| 분석 완료 사용자 키 복원 | 선택폼을 건너뛰고 Profile 진입 | 통과 |
| 최초 분석 제출 | V2 Body와 `X-User-Key` 전송, 201 응답 해석 | 통과 |
| 같은 제출 키 재시도 | 제출 키 유지, 200 멱등 응답 해석 | 통과 |
| 앱 운영 진입 | V2 Bootstrap 사용, V1 `/api/surveys` 미호출 | 통과 |

## 4. 주요 실패 시나리오 검증

| 시나리오 | 기대 결과 | 결과 |
|---|---|---|
| 캐시 읽기·쓰기 실패 | 내부 예외를 노출하지 않는 캐시 오류 | 통과 |
| 캐시 사용자 조회 401 | 기존 사용자 키를 임의 삭제·교체하지 않고 오류 표시 | 통과 |
| Timeout과 Network 실패 | 서로 다른 오류 종류와 안전한 메시지 | 통과 |
| Backend 정의 오류 7종 | 상태 코드와 오류 코드를 지정된 Flutter 오류로 Mapping | 통과 |
| 오류 Body가 JSON이 아님 | 서버 본문을 노출하지 않는 일반 오류 | 통과 |
| 성공 응답 계약 누락·불일치 | Contract 오류 | 통과 |
| `API_BASE_URL` 누락 | Configuration 오류 | 통과 |
| 빈 사용자 키 저장 | 캐시에 기록하지 않고 Validation 실패 | 통과 |
| 손상되거나 V1인 Profile 응답 | V2 Model 파싱 거부 | 통과 |
| 실패 뒤 다시 시도 | 같은 캐시 사용자를 유지해 재조회 | 통과 |

## 5. 실행 명령과 결과

```powershell
cd C:\Users\6122\Desktop\DXSchool_JKS\JAVA\vibecoding\sideproject\front\app
flutter pub get
dart format lib\main.dart lib\api\personality_api.dart lib\personality lib\user test
flutter analyze
flutter test test\personality_models_test.dart test\personality_api_test.dart test\personality_bootstrap_test.dart test\submission_key_test.dart test\user_key_store_test.dart
flutter test
flutter build web --dart-define=API_BASE_URL=http://localhost:8080
```

- `flutter pub get`: 성공
- `flutter analyze`: 최종 `No issues found`
- Phase 4 집중 테스트: 32개 통과
- Flutter 전체 테스트: 49개 통과
- Flutter Web Build: 성공, 산출물 `front/app/build/web`
- 정적 검색: 운영 진입점과 V2 경로에서 `SurveyApi`, `SurveyScreen`, `/api/surveys`, `energyLevel`, 구형 `activityLevel` 참조 없음
- 비밀값 검색: Phase 4 Frontend 파일에 OpenAI Key와 DB 접속 정보 없음

## 6. 검증 중 발견하고 해결한 실패

1. 최초 `flutter analyze`는 Map 타입 승격, Flutter `Key` import 누락, 미사용 import로 실패했다. 타입 처리와 import를 수정한 뒤 다시 실행해 통과했다.
2. 최초 집중 테스트는 단위 테스트 환경에 `SharedPreferencesAsyncPlatform` 구현이 없어 2개가 실패했다. 저장소에 비동기 Preferences Adapter를 주입할 수 있게 바꾸고, 운영 구현은 그대로 `SharedPreferencesAsync`를 사용하도록 한 뒤 32개가 모두 통과했다.
3. 최초 환경 확인 명령은 Flutter 응답 지연과 잘못 중복된 lockfile 경로 때문에 Timeout 됐다. 파일 변경은 없었으며 경로를 바로잡아 후속 명령을 실행했다.

## 7. 남은 경고와 경계

- Web Build는 성공했지만 Flutter가 `CupertinoIcons` 폰트가 없다는 경고를 출력했다. 프로젝트 소스에 `CupertinoIcons` 참조가 없고 현재 기능에 필요하지 않아 불필요한 Library를 추가하지 않았다.
- `MaterialIcons` Tree Shaking 및 Wasm Dry Run 안내가 출력됐으나 실패가 아니다.
- `flutter pub get`은 일부 간접 의존성에 더 새로운 호환 불가 버전이 있다고 안내했으나 현재 해석과 Build에는 문제가 없다.
- 실제 Backend·Oracle을 연결한 전체 흐름은 Phase 7에서 검증한다.
