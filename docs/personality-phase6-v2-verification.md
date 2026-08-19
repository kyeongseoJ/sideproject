# 사용자 성향 분석 V2 Phase 6 검증 기록

## 1. 검증 정보

- 검증일: 2026-08-19
- 대상: Flutter 전체 성향 Profile, 최초 결과, 재접속 복원, 재분석
- 결과: 검증 완료
- 제외 범위: 실제 Oracle E2E(Phase 7), 할애 가능 시간, 미션, OpenAI, World

## 2. 구현 내용

- 최초 분석 성공 응답을 전체 성향 Profile 화면으로 즉시 전환한다.
- 재접속한 분석 완료 사용자는 선택폼을 건너뛰고 동일 Profile 화면으로 복원한다.
- Profile에 닉네임, 주 성향 이름·요약, 실내·실외, 사회성, 신체 활동, 새로움, 실행 방식, 관심 분야, 마지막 분석 시각과 분석 버전을 표시한다.
- 마지막 분석 시각은 서비스 정책에 따라 UTC 기준값을 `Asia/Seoul` 고정 오프셋으로 표시한다.
- `성향 분석 다시하기`는 확인 Dialog에서 명시적으로 승인한 경우에만 시작한다.
- 재분석 폼은 `analysisMode=REANALYSIS`로 제출한다.
- 재분석 성공 시에만 현재 화면의 Profile을 새 응답으로 교체한다.
- 재분석 실패 시 기존 Profile 객체를 보존하고 `기존 프로필로 돌아가기`를 제공한다.
- Dialog 취소는 Profile과 네트워크 상태를 변경하지 않는다.
- Profile 화면은 720px 이상 카드, 작은 화면 단일 열이며 320×568에서 Overflow 없이 동작한다.
- `DESIGN.md`의 Noto Sans KR Theme, NC Purple, 무그림자, surface·hairline, 카드·버튼 radius를 적용했다.
- 시간 질문이나 미션 화면으로 이동하지 않는 명확한 완료 경계를 표시한다.

## 3. 정상 시나리오 검증

| 시나리오 | 기대 결과 | 결과 |
|---|---|---|
| 최초 분석 성공 | 응답 전체를 Profile로 표시 | 통과 |
| 분석 완료 사용자 재접속 | 선택폼 없이 Profile 복원 | 통과 |
| Profile 전체 항목 | 최소 표시 항목과 서울 기준 시각 표시 | 통과 |
| 재분석 확인 후 제출 | `REANALYSIS`와 동일 사용자 키 전송 | 통과 |
| 재분석 성공 | 기존 Profile을 새 결과로 교체 | 통과 |
| 좁은 화면 | 320×568에서 Render Overflow 없음 | 통과 |

## 4. 주요 실패 시나리오 검증

| 시나리오 | 기대 결과 | 결과 |
|---|---|---|
| 재분석 Dialog 취소 | 폼·API 호출 없이 현재 Profile 유지 | 통과 |
| 재분석 API 저장 실패 | 오류 표시, 기존 Profile 객체 유지 | 통과 |
| 실패 후 기존 Profile 복귀 | 실패 전 유형과 속성 재표시 | 통과 |
| 예상하지 못한 재분석 예외 | 내부 예외 문구를 노출하지 않음 | 통과 |
| Profile 일반 접속 | 불필요한 성향 제출 API를 호출하지 않음 | 통과 |
| 후속 기능 경계 | 시간 질문·미션 CTA를 표시하거나 호출하지 않음 | 통과 |

## 5. 실행 명령과 결과

```powershell
cd C:\Users\6122\Desktop\DXSchool_JKS\JAVA\vibecoding\sideproject\front\app
dart format lib\profile\personality_profile_screen.dart lib\personality\personality_experience_screen.dart lib\personality\personality_form_screen.dart lib\personality\personality_bootstrap.dart test\personality_profile_screen_test.dart test\personality_experience_screen_test.dart test\personality_bootstrap_test.dart
flutter analyze
flutter test test\personality_profile_screen_test.dart test\personality_experience_screen_test.dart test\personality_form_screen_test.dart test\personality_bootstrap_test.dart
flutter test
flutter build web --dart-define=API_BASE_URL=http://localhost:8080
```

- Format: 성공
- `flutter analyze`: 최종 `No issues found`
- Phase 6 신규 테스트: 9개 통과
- Phase 5 Form·Bootstrap 회귀를 포함한 집중 테스트: 26개 통과
- Flutter 전체 테스트: 68개 통과
- Flutter Web Build: 성공, 산출물 `front/app/build/web`
- 운영 V2 정적 검색: `SurveyApi`, `SurveyScreen`, `/api/surveys`, `energyLevel`, 구형 `activityLevel` 참조 없음
- Phase 6 파일 Secret 검색과 변경 파일 공백 검사: 이상 없음

## 6. 검증 중 발견하고 해결한 실패

최초 `flutter analyze`에서 다음 3건이 발견됐다.

1. `PersonalityProfileScreen`의 `const` 생성자 assert가 인스턴스 필드를 읽어 Dart 상수 규칙 오류 2건이 발생했다.
2. 임시 Profile 화면 제거 후 Bootstrap 오류 컴포넌트의 `eyebrow` 선택 파라미터가 미사용 경고 1건을 발생시켰다.

Profile 생성자를 일반 생성자로 바꾸고 남은 임시 파라미터를 제거했다. 재실행한 Analyze는 무오류였고 집중 테스트 26개와 전체 테스트 68개가 모두 통과했다.

## 7. 남은 경고와 경계

- Web Build는 성공했지만 Flutter가 `CupertinoIcons` 폰트가 없다는 기존 경고를 출력했다. 프로젝트 소스에 해당 아이콘 참조가 없어 불필요한 Library를 추가하지 않았다.
- MaterialIcons Tree Shaking과 Wasm Dry Run 안내는 실패가 아니다.
- 이번 Phase는 Client와 Mock Gateway 조합 검증이다. 실제 Spring Boot·Oracle 저장 및 새로고침 E2E는 Phase 7에서 검증한다.
- 할애 가능 시간 질문과 미션 생성은 이 SDD의 범위가 아니므로 구현하지 않았다.
