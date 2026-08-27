# 랜덤 미션 Phase 1 검증 기록

## 1. 검증 정보

- 검증일: 2026-08-19
- 대상 SDD: `SDD/v1/mission-sdd.md`
- 대상 Phase: Phase 1. Oracle Schema와 비파괴 Migration
- 결과: **통과**

## 2. 구현 범위

- `USER_MISSION_SEQ`, `USER_MISSION`이 실제 DB에 없으면 멱등 생성
- `USER_MISSION`에 추천 묶음, 거리, 점수, 슬롯, 노출 시각 추가
- 서울 달력 날짜, 거리·점수 0~1, 슬롯 1~3, 상태·슬롯 일치 Constraint 추가
- 활성·완료 슬롯만 중복 차단하는 함수 기반 Unique Index 추가
- `USER_MISSION_SETTING` 추가
- `USER_MISSION_CATEGORY_STAT` 추가
- `USER_PERSONALITY_PROFILE.LAST_MISSION_ADAPTED_COUNT` 추가
- `MISSION_STATUS_LOG`에 사용자 미션, 이전 상태, 변경 원인 추가
- 두 기준 SQL과 실제 Oracle을 동일 Migration으로 검증

## 3. 실제 Oracle 기준선

최초 JDBC 확인 결과:

```text
USER_MISSION: 미생성
MISSION_STATUS_LOG rows: 0
USER_PERSONALITY_PROFILE rows: 0
```

과거 `DB.sql`에 목표 구조는 있었지만 실제 Oracle에는 `USER_MISSION`이 적용되지 않았다. Phase 1 Migration이 이 차이를 비파괴 방식으로 보완했다.

Migration 적용 후와 재적용 후 기준 행 수:

```text
MISSION_PHASE1_BASELINE userMissions=0 statusLogs=0 profiles=0
MISSION_PHASE1_ORACLE_VERIFICATION=PASS
```

## 4. 정상 시나리오

| ID | 시나리오 | 결과 |
|---|---|---|
| N-01 | 실제 DB에 없는 `USER_MISSION`과 Sequence 생성 | 통과 |
| N-02 | 동일 Migration 재실행 | 객체 중복·행 수 변화 없음, 통과 |
| N-03 | `SHORT`, 하루 한도 1 설정 저장 | 통과 |
| N-04 | 완료 0회 카테고리 생성 후 1회로 갱신 | 통과 |
| N-05 | 슬롯 없는 `SHOWN` 후보 여러 건 저장 | 통과 |
| N-06 | 슬롯 1의 `SELECTED` 저장 | 통과 |
| N-07 | `USER_MISSION`과 연결된 상태 로그 저장 | 통과 |
| N-08 | 완료 5회와 마지막 반영 5회 Profile 저장 | 통과 |
| N-09 | 검증 Fixture 전체 Rollback | 기준 행 수 유지, 통과 |

## 5. 주요 실패 시나리오

아래 실패는 실제 Oracle Constraint가 기대한 오류를 반환하는지 검증했다.

| ID | 실패 시나리오 | Oracle 결과 |
|---|---|---|
| F-01 | 사용자 설정 중복 | ORA-00001 |
| F-02 | 잘못된 시간 코드 | ORA-02290 |
| F-03 | 하루 한도 0 | ORA-02290 |
| F-04 | 존재하지 않는 사용자 설정 | ORA-02291 |
| F-05 | 잘못된 카테고리 | ORA-02290 |
| F-06 | 음수 완료 횟수 | ORA-02290 |
| F-07 | 완료 횟수 1인데 완료 시각 없음 | ORA-02290 |
| F-08 | 성향 거리 1 초과 | ORA-02290 |
| F-09 | 추천 점수 음수 | ORA-02290 |
| F-10 | `SELECTED`인데 슬롯 없음 | ORA-02290 |
| F-11 | `SHOWN`인데 슬롯 점유 | ORA-02290 |
| F-12 | 시간값이 포함된 서비스 날짜 | ORA-02290 |
| F-13 | 같은 사용자·날짜·활성 슬롯 중복 | ORA-00001 |
| F-14 | 같은 사용자·미션·날짜 중복 | ORA-00001 |
| F-15 | 존재하지 않는 Mission 참조 | ORA-02291 |
| F-16 | 잘못된 이전 상태 로그 | ORA-02290 |
| F-17 | 존재하지 않는 사용자 미션 로그 참조 | ORA-02291 |
| F-18 | 마지막 성향 반영 횟수가 5의 배수가 아님 | ORA-02290 |
| F-19 | 마지막 성향 반영 횟수가 전체 완료 횟수 초과 | ORA-02290 |

## 6. 발견하고 수정한 문제

1. SQL*Plus native 연결은 기존 `ORA-12638`로 실패했다. JDBC Thin 연결은 정상이라 통합 테스트와 실제 적용에 JDBC를 사용했다.
2. 실제 Oracle에 `USER_MISSION`이 없었다. Phase 1 Migration이 독립적으로 기본 테이블과 Sequence를 생성하도록 수정했다.
3. 최초 테스트는 미생성 테이블의 기준 행 수를 먼저 조회해 실패했다. 객체 존재 여부를 확인한 뒤 기준값을 계산하도록 수정했다.
4. 일반 복합 Unique Constraint는 슬롯이 없는 여러 후보를 충돌시켰다. 활성 상태에만 적용되는 함수 기반 Unique Index로 교체했다.

## 7. 테스트와 Build

Mission Phase 1 집중 테스트:

```text
Tests run: 1, Failures: 0, Errors: 0, Skipped: 0
BUILD SUCCESS
```

실제 Oracle 통합 테스트 포함 Backend 전체 테스트:

```text
Tests run: 115, Failures: 0, Errors: 0, Skipped: 1
BUILD SUCCESS
```

Backend Package:

```text
back/target/back-0.0.1-SNAPSHOT.jar
BUILD SUCCESS
```

알려진 경고:

- 기존 `mvnw.cmd` PowerShell 호환 오류가 있어 Wrapper Cache의 Maven 3.9.16을 사용했다.
- Mockito/Byte Buddy의 동적 Java Agent 경고가 있으며 현재 테스트 결과에는 영향이 없다.
- SQL*Plus의 `ORA-12638`은 남아 있지만 애플리케이션과 테스트가 사용하는 JDBC Thin 연결에는 영향이 없다.

## 8. 완료 판단

실제 Oracle 적용, 멱등 재적용, 정상 저장, 19개 주요 실패 제약, Rollback, 전체 Backend 회귀 테스트와 Package가 모두 성공했으므로 **Phase 1은 완료**다.
