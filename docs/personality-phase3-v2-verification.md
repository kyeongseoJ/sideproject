# 사용자 성향 분석 V2 Phase 3 검증 기록

- 검증일: 2026-08-19
- 대상: Spring Boot REST API, Oracle 원자적 저장, 현재 사용자 Profile 조회
- 분석 버전: `PERSONALITY_V2`
- 결과: 검증 완료

## 구현 범위

- `POST /api/personality-analyses`
- 신규 분석 `201 Created`, 동일 제출 재시도 `200 OK`
- `X-User-Key` 사용자 인증 연결
- UUID `submissionKey` 정규화와 사용자 범위 멱등 처리
- `INITIAL`, `REANALYSIS` 상태 검증
- 사용자 행 `FOR UPDATE` 잠금을 통한 동일 사용자 동시 저장 직렬화
- 원본 답변과 원본 관심 분야 저장
- 현재 Profile insert 또는 update와 현재 관심 분야 교체
- 사용자 최근 접근 시각 갱신
- `GET /api/users/me`의 실제 현재 성향 Profile 조합
- 안전한 400·401·409·500 오류 응답
- Swagger/OpenAPI 자동 등록

원본 답변, 현재 Profile, 관심 분야와 최근 접근 시각 변경은 하나의 `@Transactional` 범위에서 처리한다.

## 정상 시나리오

| 시나리오 | 결과 |
|---|---|
| Profile이 없는 사용자의 `INITIAL` 제출 | 원본과 Profile 저장, `201` |
| 같은 사용자와 같은 제출 키·답변 재시도 | 새 행 없이 기존 결과, `200` |
| 관심 분야 순서만 다른 동일 제출 | 같은 제출로 처리 |
| Profile이 있는 사용자의 `REANALYSIS` | 원본 이력 추가, 현재 Profile 한 건 갱신 |
| 분석 전 `GET /api/users/me` | `personalityCompleted=false`, `personality=null` |
| 분석 후 `GET /api/users/me` | 네 축, 유형, 실행 방식, 관심 분야, 버전과 분석 시각 반환 |
| OpenAPI 조회 | 분석 POST와 사용자 GET 경로 및 주요 응답 코드 노출 |

## 주요 실패 시나리오

| 실패 조건 | HTTP 또는 결과 | 검증 결과 |
|---|---|---|
| 제출 키 누락·UUID 형식 오류 | `400 INVALID_SUBMISSION_KEY` | 통과 |
| 필수 답변 누락·관심 분야 오류 | `400 INVALID_PERSONALITY_ANSWERS` | 통과 |
| 알 수 없는 Enum·잘못된 JSON | `400 INVALID_PERSONALITY_ANSWERS` | 통과 |
| 사용자 키 누락·불일치 | `401 INVALID_USER_KEY` | 통과 |
| 이미 Profile이 있는데 `INITIAL` | `409 PERSONALITY_ALREADY_ANALYZED` | 통과 |
| Profile이 없는데 `REANALYSIS` | `409 PERSONALITY_NOT_ANALYZED` | 통과 |
| 같은 제출 키에 다른 답변 | `409 SUBMISSION_KEY_CONFLICT` | 통과 |
| Database 또는 Transaction 실패 | 안전한 `500 PERSONALITY_SAVE_FAILED` | 통과 |
| 재분석 저장 도중 강제 실패 | 새 원본과 Profile 변경 전체 Rollback | 실제 Oracle 통과 |

500 응답에는 내부 SQL, 접속정보, Stack trace와 사용자 키 원문이 포함되지 않는다.

## 실제 Oracle 검증

환경 변수로 로컬 Oracle 접속정보를 테스트 프로세스에만 주입했다. 저장소 파일에는 접속 Secret을 추가하지 않았다.

검증한 내용:

1. V2 원본의 `ENERGY_LEVEL`이 `NULL`인지 확인
2. `ANALYSIS_MODE`, `ANALYSIS_VERSION` 저장 확인
3. 원본과 현재 관심 분야가 각각 두 건인지 확인
4. 멱등 재시도 후 원본 행 수가 증가하지 않는지 확인
5. 재분석 후 원본은 두 건이고 현재 Profile은 한 건인지 확인
6. 현재 Profile이 새 원본과 새 유형을 가리키는지 확인
7. Profile update 후 강제 예외를 발생시켜 원본 insert와 Profile update가 모두 Rollback되는지 확인
8. 테스트용 사용자와 관련 행 정리

Oracle Sequence는 Transaction Rollback 대상이 아니므로 검증 중 사용한 Sequence 값은 정상적으로 증가한다. 테스트용 업무 데이터 행은 모두 정리했다.

처음 Oracle 통합 Test만 단독 실행했을 때는 `RUN_ORACLE_INTEGRATION`이 없어 1건이 제외됐다. 이후 필요한 환경 변수를 주입하여 같은 Test와 전체 Test를 다시 실행했고 제외 없이 통과했다.

## 실행 명령과 결과

Maven Wrapper의 기존 PowerShell 호환 문제를 우회하기 위해 로컬 Wrapper 배포본의 Maven 실행 파일을 사용했다.

```powershell
mvn -Dtest=PersonalityAnalyzerTest,PersonalityServiceTest,PersonalityControllerTest,UserServiceTest,UserControllerTest test
mvn -Dtest=PersonalityOpenApiTest test

$env:RUN_ORACLE_INTEGRATION='true'
$env:DB_USERNAME='<local username>'
$env:DB_PASSWORD='<local password>'
mvn -Dtest=PersonalityPhase3OracleIntegrationTest test
mvn clean test
```

- Phase 3 Service Test: 12개 통과
- Phase 3 Controller Test: 11개 통과
- OpenAPI Test: 1개 통과
- Phase 3 실제 Oracle Test: 1개 통과, 내부 정상·충돌·Rollback 시나리오 전체 통과
- Backend 전체: 113개 통과, 실패 0, 오류 0, 제외 0
- 마지막 사용자 Profile 호환성 점검: 21개 통과, 실패 0, 오류 0, 제외 0
- Build: 성공

Mockito 동적 Java Agent 로딩에 대한 향후 JDK 호환 경고가 출력됐지만 현재 Build나 Test 실패는 아니다. 새 Library는 추가하지 않았다.

마지막 사용자 Profile 회귀 Test를 처음 재실행할 때 프로젝트 루트에서 Maven을 호출하여 `pom.xml`을 찾지 못하는 경로 오류가 한 번 발생했다. Backend 경로에서 동일 명령을 다시 실행해 21개 Test가 모두 통과했으며 코드 또는 Database 오류는 아니었다.

## 완료 판단

Phase 3 인수 조건인 정상 저장, Validation, 401, 409, 멱등 재시도, 실제 Profile 조회, 원자적 Rollback과 OpenAPI 경로를 모두 자동 검증했다. 다음 단계는 Phase 4의 Flutter API Model과 앱 시작 분기다.
