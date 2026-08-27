# 랜덤 미션 Phase 0 검증 기록

> 이 문서는 2026-08-19 당시 계약의 이력이다. 현재 추천 후보 수·재노출 기간·점수 계약은 `SDD/v1/mission-sdd.md`를 따른다.

## 1. 검증 정보

- 검증일: 2026-08-19
- 대상 SDD: `SDD/v1/mission-sdd.md`
- 대상 Phase: Phase 0. 정책과 계약 확정
- 결과: **통과**

Phase 0은 실행 기능을 추가하는 단계가 아니다. 아직 구현되지 않은 REST API나 Oracle 객체를 성공으로 간주하지 않고, 정상·실패 계약의 존재와 모순 여부 및 기존 기능 회귀를 검증한다.

## 2. 산출물

- 활성 SDD: `SDD/v1/mission-sdd.md`
- 통합 정책: `SPEC.md`
- 진행 상태: `PROJECT_STATUS.md`

## 3. 정상 시나리오

| ID | 시나리오 | 기대 결과 | 검증 결과 |
|---|---|---|---|
| N-01 | Phase 0~7 정의 | 정확히 8개 Phase가 존재 | 8개, 통과 |
| N-02 | 인수 조건 식별 | `AC-01`~`AC-12`가 중복 없이 존재 | 12개, 통과 |
| N-03 | 추천 계약 | 후보 5개, 한도 1~3, 네 축과 점수 합 1.0 | 계약 확인, 통과 |
| N-04 | 날짜 경계 | 서울 달력 기준 완료 3일·노출 2일 경계 존재 | D+3·D+2 경계 확인, 통과 |
| N-05 | 상태 전이 | 다섯 상태와 다섯 허용 전이가 존재 | 상태·전이 확인, 통과 |
| N-06 | API 흐름 | 설정·오늘·선택·취소·변경·완료·통계 경로 존재 | 8개 경로 확인, 통과 |
| N-07 | 저장 역할 | Catalog, 집계, 로그, 설정, 통계 역할 분리 | Oracle 논리 계약 확인, 통과 |
| N-08 | 기존 구현 차이 | 프로토타입을 완료로 표시하지 않음 | Phase 1~7 미착수 표시, 통과 |

## 4. 주요 실패 시나리오

| ID | 실패 시나리오 | 기대 결과 | Phase 0 검증 기준 |
|---|---|---|---|
| F-01 | 사용자 키 누락·불일치 | `401 INVALID_USER_KEY` | 오류 계약 존재 |
| F-02 | 성향 분석 또는 설정 미완료 | 각각 `409` 오류 | 선행조건 존재 |
| F-03 | 후보 없음 | `409 NO_MISSION_AVAILABLE` | 제한 완화 없이 오류 정의 |
| F-04 | 하루 한도 초과 | `409 DAILY_LIMIT_REACHED` | 슬롯 불변식 존재 |
| F-05 | 다른 사용자 미션 접근 | `404 USER_MISSION_NOT_FOUND` | 소유권 비노출 규칙 존재 |
| F-06 | 허용하지 않는 상태 전이 | `409 INVALID_MISSION_TRANSITION` | 전이 목록과 오류 계약 존재 |
| F-07 | 변경 중 일부 실패 | 전체 Rollback | 원자적 변경 규칙 존재 |
| F-08 | 완료 요청 중복 | 기존 결과, 통계 중복 증가 없음 | 멱등 규칙 존재 |
| F-09 | 동시 후보 생성·선택 | 한 묶음·한 슬롯만 확정 | 잠금과 Unique 기준 존재 |
| F-10 | LLM 장애·중복 결과 | 기본 추천·완료 정상 유지 | 장애 격리 규칙 존재 |
| F-11 | World 구현 혼입 | 이번 SDD 범위 위반 | 제외 범위 존재 |
| F-12 | Secret 문서 기록 | 검증 실패 | 환경 변수 전용 규칙 존재 |

F-01~F-12는 오류 코드, 전이, Transaction, 소유권, 범위와 Secret 규칙의 존재 및 서로 모순되지 않는지를 정적으로 확인하여 모두 통과했다. 아직 신규 Controller와 Oracle 객체가 없으므로 실제 HTTP·Rollback·동시성 실행 검증은 각각 Phase 1, 3, 4, 5와 7에서 수행한다.

## 5. 현재 구현 차이

| 항목 | 현재 상태 | 예정 Phase |
|---|---|---:|
| 단일 `/api/missions/random` 응답 | 한 미션만 반환 | 3 |
| 범용 Catalog `missionId` 상태 변경 | 사용자 제안 건 소유권 단위가 아님 | 4 |
| `USER_MISSION` 집계 사용 | DDL은 있으나 Service가 사용하지 않음 | 1, 3 |
| 하루 설정·후보 고정 | 미구현 | 1, 3 |
| 선택·취소·원자적 변경 | 일부 상태 로그만 구현 | 4 |
| 카테고리 완료 통계 | 미구현 | 1, 5 |
| 완료 후 유형 재분류 | 현재 벡터 갱신만 일부 존재 | 5 |
| Flutter 미션 화면 | 상태 enum만 존재 | 6 |
| 실제 Oracle·전체 E2E | 현재 사양 기준 미검증 | 7 |

## 6. 회귀 및 정적 검증 결과

### 정적 계약 검사

PowerShell로 Phase·인수 조건 Count, 상태 전이, REST 경로, 정책값, SDD 링크, Secret 형태와 두 기준 SQL의 SHA-256을 검사했다.

```text
STATIC_CONTRACT_CHECK=PASS
PHASE_COUNT=8
AC_COUNT=12
SCHEMA_SQL_HASH_MATCH=PASS
SECRET_PATTERN_CHECK=PASS
```

`git diff --check`: 성공

### Backend

최초 명령:

```powershell
cd back
.\mvnw.cmd test
```

결과: Maven 실행 전 실패

```text
Cannot index into a null array.
Cannot start maven from wrapper
```

원인: 기존 Maven Wrapper PowerShell 구문이 비어 있는 `Target` 값을 배열로 접근한다. 기능 또는 테스트 실패가 아니다.

Wrapper Cache의 Maven 3.9.16 실행 파일로 같은 `pom.xml`을 테스트했다. 첫 Sandbox 실행은 Maven Central 접근 권한 부족으로 실패했으며, Network 허용 실행에서 성공했다.

```text
Tests run: 114, Failures: 0, Errors: 0, Skipped: 3
BUILD SUCCESS
```

알려진 경고: Mockito/Byte Buddy의 동적 Java agent loading이 향후 JDK에서 제한될 수 있다. 현재 결과에는 영향이 없다.

### Flutter

```powershell
cd front/app
flutter test --concurrency=1 --reporter expanded
```

결과:

```text
68 tests passed
All tests passed!
```

현재 미션 관련 Flutter 테스트는 상태 코드 변환 3개뿐이다. 신규 후보·설정·수행 화면 테스트는 Phase 6에서 추가한다.

## 7. 완료 판단

정상·실패 계약의 정적 검증과 기존 Backend·Flutter 회귀 테스트를 모두 통과했으므로 **Phase 0은 완료**다.

Phase 1에서 실제로 검증해야 할 항목:

1. `USER_MISSION` 기존 데이터와 Constraint를 보존하는 비파괴 Migration
2. `USER_MISSION_SETTING`, `USER_MISSION_CATEGORY_STAT` 생성 권한
3. 일일 슬롯과 후보 중복을 막는 Oracle Constraint
4. `MISSION_STATUS_LOG`와 `USER_MISSION`의 연결 방법
5. `DB.sql`과 Backend 기준 SQL의 적용 후 동일성
