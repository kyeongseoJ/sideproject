# 사용자 성향 분석 V2 Phase 1 검증 기록

## 1. 검증 정보

- 검증일: 2026-08-19
- 대상 Phase: Phase 1. Oracle V2 Schema
- 대상 Oracle: 로컬 Oracle XE, Application Schema
- 결과: **통과**

실제 접속정보는 환경 변수로만 주입했으며 문서, SQL, Java Source와 Test Report에 기록하지 않았다.

## 2. 구현 내용

`SURVEY_RESPONSE`를 비파괴 확장했다.

| 항목 | 구현 내용 |
|---|---|
| 신체 활동 답변 | `PHYSICAL_ACTIVITY_LEVEL VARCHAR2(10 CHAR)` |
| 분석 실행 구분 | `ANALYSIS_MODE VARCHAR2(12 CHAR)` |
| 분석 버전 | `ANALYSIS_VERSION VARCHAR2(24 CHAR)` |
| 제출 키 Unique | 전역 Unique를 `(USER_ID, SUBMISSION_KEY)` 사용자 범위 Unique로 변경 |
| 신체 활동 Check | `LOW`, `MEDIUM`, `HIGH` 또는 Legacy `NULL` |
| 분석 모드 Check | `INITIAL`, `REANALYSIS` 또는 Legacy `NULL` |
| 분석 버전 Check | `PERSONALITY_V2` 또는 Legacy `NULL` |
| V2 필수값 Check | V2 행의 사용자, 제출 키, 신체 활동, 실행 방식, 분석 모드 필수 및 `ENERGY_LEVEL=NULL` |

`USER_PERSONALITY_PROFILE.ANALYSIS_VERSION`은 기존 10자에서 24자로 확장했다. `PERSONALITY_V2`가 14자이므로 이 변경이 없으면 Phase 3 저장 시 길이 오류가 발생한다.

신규 설치용 `CREATE TABLE USER_PERSONALITY_PROFILE` 정의도 24자로 맞췄다.

## 3. 실제 Oracle 기준선

마이그레이션 전후에 확인된 실제 데이터는 다음과 같다.

| 데이터 | 적용 전 | 적용 후 |
|---|---:|---:|
| 전체 `SURVEY_RESPONSE` | 4 | 4 |
| `ENERGY_LEVEL`이 있는 V1 응답 | 4 | 4 |
| 전체 `USER_PERSONALITY_PROFILE` | 0 | 0 |
| `PERSONALITY_V2` Profile | 0 | 0 |

기존 Profile이 0건이므로 V1 Profile을 변환하거나 삭제하지 않았다. 기존 V1 설문 4건과 `ENERGY_LEVEL`은 그대로 보존했다.

## 4. 정상 시나리오

| ID | 시나리오 | 결과 |
|---|---|---|
| N-01 | Phase 1 SQL 최초 적용 | 신규 컬럼과 Constraint 생성 성공 |
| N-02 | 같은 Phase 1 SQL 재적용 | 오류 없이 성공, 객체 중복 없음 |
| N-03 | 적용 전후 기존 데이터 Count 비교 | 4건 모두 보존 |
| N-04 | Legacy V1 형식 저장 | V2 컬럼이 `NULL`인 상태로 저장 가능 |
| N-05 | 모든 필수값이 있는 V2 형식 저장 | 성공 |
| N-06 | 서로 다른 사용자가 같은 `submissionKey` 사용 | 성공, 사용자 범위 Unique 확인 |
| N-07 | Profile 분석 버전 컬럼 길이 | 24자 이상 확인 |
| N-08 | 검증 Fixture Rollback | 사용자·설문 Test 행 미잔존 |
| N-09 | `DB.sql`과 Backend Schema 비교 | SHA-256 동일 |

## 5. 주요 실패 시나리오

| ID | 실패 입력 | 기대 Oracle 결과 | 실제 결과 |
|---|---|---|---|
| F-01 | 같은 사용자의 동일 `submissionKey` 중복 | Unique 위반 | `ORA-00001`, 통과 |
| F-02 | `PHYSICAL_ACTIVITY_LEVEL=EXTREME` | Check 위반 | `ORA-02290`, 통과 |
| F-03 | V2인데 신체 활동 값 누락 | V2 필수값 Check 위반 | `ORA-02290`, 통과 |
| F-04 | `ANALYSIS_MODE=AUTOMATIC` | Check 위반 | `ORA-02290`, 통과 |
| F-05 | `ANALYSIS_VERSION=UNKNOWN_VERSION` | Check 위반 | `ORA-02290`, 통과 |
| F-06 | V2인데 Legacy `ENERGY_LEVEL` 저장 | V2 필수값 Check 위반 | `ORA-02290`, 통과 |

실패 Fixture를 포함한 모든 Test DML은 마지막에 Rollback했다.

## 6. 자동화 Test

추가한 Test:

```text
back/src/test/java/com/novelty/personality/PersonalityPhase1OracleIntegrationTest.java
```

- `RUN_ORACLE_INTEGRATION=true`일 때만 실제 Oracle Test를 실행한다.
- 접속정보는 `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` 환경 변수에서 읽는다.
- 일반 단위 Test에서는 실제 Oracle Test를 건너뛴다.
- Test ID는 음수 Fixture를 사용하므로 향후 재실행에서 Sequence 값을 소비하지 않는다.

최종 검증 명령:

```powershell
cd back
# DB 환경 변수는 현재 Shell에만 설정
mvn clean test
```

최종 결과:

```text
Tests run: 50, Failures: 0, Errors: 0, Skipped: 0
BUILD SUCCESS
PHASE1_ORACLE_VERIFICATION=PASS
```

## 7. 발생한 문제와 처리

### Maven Wrapper 시작 오류

기존 `mvnw.cmd`는 Maven Wrapper 3.3.4 PowerShell 처리 중 비어 있는 Directory `Target`을 배열로 접근하여 시작하지 못했다.

```text
Cannot index into a null array.
Cannot start maven from wrapper
```

이번 검증은 Wrapper가 이미 내려받은 Maven 3.9.16 실행 파일로 같은 `pom.xml`을 사용하여 수행했다. Wrapper 자체는 Phase 1 Schema 범위가 아니므로 수정하지 않았다.

### Sandbox Network 제한

Sandbox 내부 Maven 실행은 Maven Central 접근이 차단되어 실패했다. 허용된 Network 환경에서 동일 명령을 다시 실행하여 성공했다.

### 분석 버전 컬럼 길이

초기 Phase 1 구현 검토 중 Profile의 10자 컬럼에 14자인 `PERSONALITY_V2`가 들어가지 않는 문제를 발견했다. 실제 Oracle과 신규 설치 DDL 모두 24자로 수정하고 전체 Test를 다시 수행했다.

### 최초 검증의 Sequence 소비

최초 Oracle 검증 Fixture가 Sequence를 사용하여 `NOVELTY_USER_SEQ` 2개와 `SURVEY_RESPONSE_SEQ` 9개 값을 소비했다. Fixture 행은 Rollback되어 남지 않았지만 Oracle Sequence 값은 Rollback되지 않는다. 이후 Test는 고정된 음수 Fixture ID를 사용하도록 수정하여 재실행 시 Sequence를 소비하지 않는다.

Sequence 번호의 공백은 PK 유일성과 서비스 동작에 영향을 주지 않는다.

## 8. 완료 판단

Phase 1의 다음 조건을 모두 충족했다.

- SQL 재실행 가능
- 두 기준 SQL 동일
- 실제 Oracle 신규 컬럼과 Constraint 확인
- 기존 V1 데이터 보존 확인
- 정상 V2 저장 확인
- 주요 잘못된 V2 데이터 차단 확인
- Test Fixture 정리 확인
- Backend 전체 Test 통과

따라서 Personality V2 Phase 1은 **검증 완료** 상태이며 다음 개발 단계는 Phase 2 순수 성향 Domain이다.
