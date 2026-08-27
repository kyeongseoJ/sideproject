# 사용자 성향 분석 V2 Phase 0 검증 기록

## 1. 검증 정보

- 검증일: 2026-08-19
- 대상 SDD: `SDD/v2/personality-sdd.md`
- 대상 Phase: Phase 0. V2 기준선 확정
- 결과: **통과**

Phase 0은 기능 코드를 구현하는 단계가 아니라 현재 정책, 실제 구현의 차이, 정상·실패 계약과 이후 개발 순서를 확정하는 단계다. 아직 존재하지 않는 V2 API를 실행 성공으로 간주하지 않으며, API 동작 검증은 Phase 3 이후 수행한다.

## 2. Phase 0 산출물

- 활성 V2 SDD: `SDD/v2/personality-sdd.md`
- 대체된 V1 표시: `docs/personality-phase0-spec.md`
- 통합 정책 갱신: `SPEC.md`
- 실제 진행 상태 갱신: `PROJECT_STATUS.md`

확정한 주요 결정:

1. V2 성향 폼은 여섯 문항이다.
2. `indoorOutdoor`와 `physicalActivityLevel`을 서로 다른 축으로 관리한다.
3. 기존 `energyLevel`은 V2 입력에서 제거한다.
4. 주 성향은 실내·실외 3단계와 사회성 3단계의 9개 조합으로 결정한다.
5. 원본 답변과 현재 Profile을 분리하여 보존한다.
6. 최초 분석과 명시적인 재분석을 구분한다.
7. 시간 질문, 미션 생성, OpenAI와 World는 V2 Phase 0~7에서 제외한다.

## 3. 정상 시나리오 검증

| ID | 시나리오 | 검증 방법 | 결과 |
|---|---|---|---|
| N-01 | 활성 SDD에 Phase 0~7이 빠짐없이 정의됨 | Phase 제목 정적 Count | 8개, 통과 |
| N-02 | 인수 조건이 독립적으로 식별됨 | `AC-*` 제목 정적 Count | 14개, 통과 |
| N-03 | Q1×Q2가 9개 유형을 유일하게 결정함 | 조합·코드 중복 검사 | 조합 9개, 코드 9개, 통과 |
| N-04 | 네 축의 의미가 분리됨 | 필드·점수 계약 확인 | `indoorOutdoor`, `socialLevel`, `physicalActivityLevel`, `noveltyLevel` 확인 |
| N-05 | 최초 분석과 재분석 계약이 분리됨 | REST Request의 `analysisMode` 확인 | `INITIAL`, `REANALYSIS` 확인 |
| N-06 | 정상 저장의 원자적 순서가 정의됨 | Transaction 11단계와 Rollback 규칙 확인 | 통과 |
| N-07 | 미션 구현이 현재 범위에 섞이지 않음 | 포함·제외 범위 및 예상 변경 파일 확인 | 통과 |
| N-08 | V1 이력이 보존되고 활성 기준에서 제외됨 | V1 문서 상태 확인 | `대체됨`, 통과 |
| N-09 | 두 기준 SQL이 현재 동일함 | SHA-256 비교 | 동일, 통과 |

## 4. 주요 실패 시나리오 검증

Phase 0에서는 아래 실패 동작을 실행하는 Controller가 아직 없으므로 오류 계약과 인수 조건의 존재 및 모순 여부를 검증했다. 실제 HTTP 및 Oracle Rollback 테스트는 Phase 3과 Phase 7에서 수행한다.

| ID | 실패 시나리오 | 기대 결과 | Phase 0 검증 결과 |
|---|---|---|---|
| F-01 | 필수 답변 누락, 잘못된 Enum, 관심 분야 개수·중복 오류 | `400 INVALID_PERSONALITY_ANSWERS` | 오류 계약·AC-05 확인 |
| F-02 | 제출 키 누락 또는 UUID 형식 오류 | `400 INVALID_SUBMISSION_KEY` | 오류 계약 확인 |
| F-03 | 사용자 키 누락 또는 불일치 | `401 INVALID_USER_KEY` | 오류 계약·보안 규칙 확인 |
| F-04 | Profile이 있는데 `INITIAL` 요청 | `409 PERSONALITY_ALREADY_ANALYZED` | 상태 규칙·오류 계약 확인 |
| F-05 | Profile이 없는데 `REANALYSIS` 요청 | `409 PERSONALITY_NOT_ANALYZED` | 상태 규칙·오류 계약 확인 |
| F-06 | 동일 제출 키로 다른 답변 전송 | `409 SUBMISSION_KEY_CONFLICT` | 멱등 규칙·오류 계약 확인 |
| F-07 | 원본 또는 Profile 저장 중 일부 실패 | 전체 Rollback, 기존 Profile 유지 | Transaction 규칙·AC-06·AC-09 확인 |
| F-08 | 동일 사용자의 동시 최초 분석 | 한 건만 생성, 나머지는 멱등 성공 또는 409 | 동시성 규칙 확인 |
| F-09 | V1 데이터를 V2로 자동 오인 | V1 보존, V2 여부를 버전으로 구분 | 마이그레이션 규칙·AC-11 확인 |
| F-10 | 미션 구현이 Phase 0~7 변경 대상에 포함됨 | 범위 위반으로 판단 | Mission Package 제외 문구와 AC-14 확인 |

## 5. 현재 구현 차이 탐지 결과

다음 항목은 Phase 0 검증으로 발견한 이후 Phase의 구현 대상이다. 아직 구현되지 않았으므로 이번 Phase에서 숨기거나 통과 처리하지 않는다.

| 항목 | 실제 확인 결과 | 처리 Phase |
|---|---|---|
| 기존 `energyLevel` 사용 | Flutter·Survey Backend 관련 파일 5개에서 확인 | Phase 2~5 |
| V2 신체 활동 설문 입력 | Flutter·Survey Backend 관련 파일 0개 | Phase 1~5 |
| 실제 성향 분석 Domain | `com.novelty.personality`에 `package-info.java`만 존재 | Phase 2 |
| 현재 Profile API Mapping | `UserProfileResponse`가 `personality=null` 반환 | Phase 3 |
| V2 성향 REST API | `/api/personality-analyses` 미구현 | Phase 3 |
| V2 Flutter 선택폼·Profile | 기존 V1 Survey UI만 존재 | Phase 4~6 |

이 차이들은 SDD와 현재 코드가 불일치한다는 사실을 확인하는 Phase 0의 예상 결과다.

## 6. 회귀 테스트

### Backend

최초 명령:

```powershell
cd back
.\mvnw.cmd test
```

결과: 실행 실패

```text
Cannot index into a null array.
Cannot start maven from wrapper
```

원인: Maven Wrapper 3.3.4 PowerShell 구문이 일반 Directory의 비어 있는 `Target` 값을 배열로 접근하여 Maven 시작 전에 중단됐다. 기능 테스트 실패가 아니다.

로컬 Wrapper가 내려받아 둔 Maven 3.9.16 실행 파일로 같은 `pom.xml`의 테스트를 다시 실행했다. 최초 Sandbox 실행은 Maven Central 접근 권한 부족으로 의존성 확인에 실패했고, Network 권한이 허용된 실행에서 성공했다.

최종 결과:

```text
Tests run: 49, Failures: 0, Errors: 0, Skipped: 0
BUILD SUCCESS
```

경고: Mockito/Byte Buddy의 동적 Java agent loading이 향후 JDK에서 제한될 수 있다는 경고가 있다. 현재 테스트 결과에는 영향이 없다.

### Flutter

최초 `flutter test`는 120초 동안 출력 없이 대기하여 시간 초과됐다. 시간 초과 후 남은 이번 테스트의 `flutter_tester` 프로세스만 종료하고 다른 Dart 프로세스는 변경하지 않았다.

재실행:

```powershell
cd front/app
flutter test --concurrency=1 --reporter expanded
```

최종 결과:

```text
17 tests passed
All tests passed!
```

현재 Flutter 테스트는 V1 Survey의 정상·오류·중복 제출 방지와 기존 공통 기능 회귀 테스트다. V2 여섯 문항 테스트는 Phase 4~6에서 추가한다.

## 7. Phase 0 완료 판단

Phase 0의 정상·실패 계약과 현재 구현 차이가 모두 식별되어 **Phase 0은 완료**로 판단한다.

Phase 1 진입 전 해결하거나 확인할 사항:

1. 로컬 Oracle 접속의 기존 `ORA-12638` 문제 해결
2. 실제 Oracle의 V1 데이터 건수와 현재 Constraint 조회
3. Maven Wrapper 자체 오류를 Phase 1 코드와 무관한 개발환경 문제로 별도 수정할지 결정

Oracle 접속 문제를 해결하지 못하면 Phase 1 SQL은 작성할 수 있어도 실제 적용 완료로 처리할 수 없다.
