# 사용자 성향 분석 V2 Phase 5 검증 기록

## 1. 검증 정보

- 검증일: 2026-08-19
- 대상: Flutter 여섯 문항 선택폼, 입력 상태, 제출·오류 재시도
- 결과: 검증 완료
- 제외 범위: 전체 Profile·재분석 화면(Phase 6), 실제 Oracle E2E(Phase 7), 시간·미션·World

## 2. 구현 내용

- SDD에 정의된 Q1~Q6 문구와 V2 Enum을 사용하는 선택폼을 구현했다.
- Q1·Q2·Q3·Q4·Q6은 단일 선택, Q5는 1~3개 복수 선택으로 구현했다.
- 단계별 진행률, 이전·다음 이동과 답변 상태 유지를 구현했다.
- 현재 단계의 필수 답변이 없으면 다음 또는 분석 버튼이 활성화되지 않는다.
- 관심 분야가 없으면 즉시 필수 안내를 표시하고 네 번째 선택은 저장하지 않으며 제한 안내를 표시한다.
- 제출 중 전체 선택 영역과 이전·제출 버튼을 잠가 중복 요청을 차단한다.
- Network·API 실패 후 답변과 동일 `submissionKey`를 유지한 채 재시도한다.
- 예상하지 못한 예외는 내부 내용을 노출하지 않고 안전한 메시지로 표시한다.
- 분석 성공 후 Phase 6과 명확히 구분되는 최소 결과 경계를 표시한다.
- 720px 이상은 최대 680px 카드, 작은 화면은 전체 폭으로 표시하며 320×568 화면을 검증했다.
- 선택 상태, 진행률, 오류 안내에 접근성 Semantics를 적용했다.
- `DESIGN.md`의 Noto Sans KR Theme, NC Purple, 무그림자, hairline, 카드·버튼 radius를 사용했다.

## 3. 정상 시나리오 검증

| 시나리오 | 기대 결과 | 결과 |
|---|---|---|
| Q1~Q6 순차 응답 | 여섯 문항을 순서대로 이동 | 통과 |
| 이전·다음 이동 | 기존 단일·복수 선택 유지 | 통과 |
| 관심 분야 1~3개 | 선택 개수와 선택 상태 즉시 반영 | 통과 |
| 유효한 최종 제출 | `INITIAL` V2 요청과 사용자 키 전달 | 통과 |
| 분석 성공 | 결과 경계와 성향 이름 표시 | 통과 |
| 좁은 화면 | 320×568에서 Render Overflow 없음 | 통과 |
| Bootstrap 연계 | 신규·분석 전 사용자가 실제 V2 폼으로 진입 | 통과 |

## 4. 주요 실패 시나리오 검증

| 시나리오 | 기대 결과 | 결과 |
|---|---|---|
| 현재 문항 미응답 | 다음 버튼 비활성화 | 통과 |
| 관심 분야 0개 | 필수 안내와 다음 버튼 비활성화 | 통과 |
| 관심 분야 네 번째 선택 | 기존 3개 유지, 제한 안내 | 통과 |
| 제출 버튼 중복 탭 | 요청 1회, 이전·제출·선택 잠금 | 통과 |
| Network 실패 | 답변 유지, 안전한 오류와 재시도 제공 | 통과 |
| 실패 후 재시도 | 최초 요청과 동일 `submissionKey` 사용 | 통과 |
| 예상하지 못한 예외 | 내부 예외 문구 비노출 | 통과 |
| V1 필드 혼입 | `energyLevel`, `activityLevel` 요청에 없음 | 통과 |

## 5. 실행 명령과 결과

```powershell
cd C:\Users\6122\Desktop\DXSchool_JKS\JAVA\vibecoding\sideproject\front\app
dart format lib\personality\personality_form_state.dart lib\personality\personality_form_screen.dart lib\personality\personality_bootstrap.dart test\personality_form_state_test.dart test\personality_form_screen_test.dart test\personality_bootstrap_test.dart
flutter analyze
flutter test test\personality_form_state_test.dart test\personality_form_screen_test.dart test\personality_bootstrap_test.dart
flutter test
flutter build web --dart-define=API_BASE_URL=http://localhost:8080
```

- Format: 성공
- `flutter analyze`: `No issues found`
- Phase 5 신규 테스트: 10개 통과
- Phase 4 Bootstrap 회귀를 포함한 집중 테스트: 19개 통과
- Flutter 전체 테스트: 59개 통과
- Flutter Web Build: 성공, 산출물 `front/app/build/web`
- 운영 V2 정적 검색: `SurveyApi`, `SurveyScreen`, `/api/surveys`, `energyLevel`, 구형 `activityLevel` 참조 없음
- Phase 5 파일 Secret 검색과 변경 파일 공백 검사: 이상 없음

## 6. 검증 중 발견하고 해결한 실패

1. 최초 Format·Analyze 명령은 Dart 분석 설정을 `C:\Users\6122\AppData\Roaming\.dart-tool`에 만들 권한이 없어 Timeout과 함께 실패했다. 샌드박스 외 실행 승인을 사용해 다시 실행했고 Format과 Analyze가 통과했다.
2. 최초 집중 테스트는 선택 옵션의 바깥 위젯을 `Semantics`로 형변환해 2개가 실패했다. 내부 접근성 노드를 찾도록 테스트를 수정했다.
3. 두 번째 집중 테스트는 옵션 아래 여러 `Semantics` 중 하나를 특정하지 않아 같은 2개가 실패했다. `button=true`인 접근성 노드만 찾도록 수정했고 이후 19개가 모두 통과했다.

위 실패는 테스트 탐색 코드와 실행 환경 문제였으며 최종 제품 코드의 검증 결과에는 남아 있지 않다.

## 7. 남은 경고와 경계

- Web Build는 성공했지만 Flutter가 `CupertinoIcons` 폰트가 없다는 경고를 출력했다. 프로젝트 소스에 해당 아이콘 참조가 없어 불필요한 Library를 추가하지 않았다.
- MaterialIcons Tree Shaking과 Wasm Dry Run 안내는 실패가 아니다.
- 성공 화면은 Phase 5의 완료 경계만 제공한다. 전체 Profile 표시와 재분석은 Phase 6에서 구현한다.
- 실제 Spring Boot·Oracle 저장 E2E는 Phase 7에서 검증한다.
