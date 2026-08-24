# 랜덤 미션 생성·선택·완료 SDD V1

## 1. 문서 정보

- 프로젝트: 노벨티(Novelty)
- 기능: 사용자 성향과 거리가 먼 랜덤 미션 생성·선택·취소·변경·완료
- 사양 버전: `MISSION_V1.1`
- 작성일: 2026-08-19
- 상태: Phase 0~7 완료 후 추천 다양성 개정 적용

이 문서는 세 번째 핵심 기능의 활성 기준 사양이다. 의료 진단이나 치료를 제공하지 않으며, 안전한 일상 활동을 통해 새로운 행동을 시도하도록 돕는 범위로 한정한다.

## 2. 목표

```text
Flutter
→ REST API
→ Spring Boot
→ Oracle
→ Response
→ Flutter
```

1. 저장된 사용자 성향과 거리가 먼 미션을 우선 추천한다.
2. 같은 날의 추천 후보를 Oracle에 고정하여 재접속해도 같은 목록을 복원한다.
3. 사용자가 후보를 선택·취소·변경·완료할 수 있게 한다.
4. 하루 수행 한도를 설정으로 관리한다.
5. 완료 결과를 카테고리 통계와 성향 갱신의 근거로 저장한다.

## 3. 범위

### 포함

- 할애 가능 시간과 하루 수행 한도 설정
- 검수된 기본 미션과 사용 가능한 공유 LLM 미션 조회
- 성향 거리, 최근 행동 다양성, 탐색 보너스와 현재 조건 적합도를 반영한 후보 생성
- 서로 다른 경험 패턴의 하루 후보 최대 3개 저장 및 복원
- 선택, 취소, 기존 후보로 변경, 완료
- 상태 집계와 상태 로그 분리
- 카테고리별 완료 통계
- 완료 5회 단위 성향 벡터 갱신과 성향 유형 재분류
- 완료 5회 단위 LLM 생성 시도와 공유 Catalog 저장
- Swagger/OpenAPI 계약과 Flutter 미션 화면

### 제외

- 3D Object 경험치 산식과 레벨 변경
- GLB 자산 배포와 Three.js 연동
- 관리자용 미션 편집 화면
- 회원가입과 다중 기기 계정 복구
- 의료 효과 보장 또는 위험 행동 추천

World 기능은 `category`와 완료 통계를 후속 입력으로 사용하지만 이번 SDD에서는 World 데이터를 변경하지 않는다.

## 4. 확정 정책

### 4.1 서비스 날짜

- 모든 서비스 날짜 계산은 `Asia/Seoul`을 사용한다.
- 서버의 기본 Timezone과 무관하게 주입된 `Clock`과 서울 Zone으로 계산한다.
- Oracle의 `SERVICE_DATE`는 시간 없는 서울 달력 날짜를 저장한다.

### 4.2 시간과 하루 수행 한도

| 코드 | 최대 예상 시간 |
|---|---:|
| `QUICK` | 5분 |
| `SHORT` | 15분 |
| `MEDIUM` | 30분 |
| `LONG` | 60분 |

- 하루 수행 한도 기본값은 1개다.
- V1 Backend/DB 계약의 설정 가능 범위는 1~3개로 유지한다. 2026-08-24 UI 개정부터 Flutter는 미션 수 선택을 노출하지 않고 항상 1개를 저장한다.
- 오늘의 `SELECTED + COMPLETED` 슬롯 수보다 낮게 한도를 줄일 수 없다.
- 한도 증가는 저장 성공 후 즉시 적용한다.

### 4.3 후보 목록

- 하루 추천 후보 수는 최대 3개다.
- 최초 생성 후 같은 서비스 날짜에는 기존 후보를 반환한다.
- 후보 생성 요청을 반복해도 새 후보나 상태 로그를 중복 생성하지 않는다.
- 필터를 통과한 미션이 3개 미만이면 가능한 후보만 반환한다.
- 후보가 0개면 `NO_MISSION_AVAILABLE`로 실패한다.
- 완료·노출 제한은 후보 부족을 이유로 완화하지 않는다.

### 4.4 취소와 변경

- 취소·변경 횟수 자체에는 제한을 두지 않는다.
- 변경 대상은 오늘 저장된 `SHOWN` 또는 `CANCELLED` 후보로 한정한다.
- 취소한 후보는 같은 날 다시 선택할 수 있다.
- 완료한 미션은 취소하거나 변경할 수 없다.
- 변경은 기존 `SELECTED → CANCELLED`와 새 후보 `SHOWN/CANCELLED → SELECTED`를 하나의 Transaction으로 처리한다.

## 5. 사용자와 미션 벡터

| 축 | 사용자 필드 | 미션 필드 | 범위 |
|---|---|---|---|
| 활동 공간 | `indoorOutdoor` | `indoorOutdoor` | -1~1 |
| 사회 활동 | `socialLevel` | `socialLevel` | -1~1 |
| 신체 활동 | `physicalActivityLevel` | `activityLevel` | 0~2 |
| 새로움 | `noveltyLevel` | `noveltyLevel` | 0~2 |

Backend Mission Domain에서는 호환성을 위해 사용자 신체 활동 값을 `activityLevel`로 Mapping할 수 있지만, Personality API와 저장 의미는 `physicalActivityLevel`이다.

각 축의 차이를 전체 범위로 나눈 뒤 동일 가중치의 정규화 유클리드 거리를 계산한다.

```text
personalityDistance = sqrt((d1² + d2² + d3² + d4²) / 4)
```

- 각 `d`는 0~1이다.
- 최종 거리는 0~1이다.
- 1에 가까울수록 현재 성향과 멀다.

## 6. 추천 정책

### 6.1 필수 제외 조건

다음 조건을 하나라도 만족하면 후보에서 제외한다.

- `enabled = N`
- `estimatedMinutes`가 사용자 시간 설정을 초과함
- 완료 횟수 5회 미만인데 `sourceType = LLM`
- 서울 달력 날짜 기준 최근 완료 제한에 해당함
- 서울 달력 날짜 기준 최근 노출 제한에 해당함
- 안전 정책 또는 중복·유사도 정책을 통과하지 못함

기간 경계:

- D일 완료: D, D+1, D+2 추천 금지, D+3부터 가능
- D일 노출: D, D+1, D+2 재노출 금지, D+3부터 가능
- 최근 7일 또는 최신 10개 이내 완료 이력과 경험 유사도가 `0.82` 이상이면 문구가 달라도 후보에서 제외한다.

오늘 이미 저장된 후보를 다시 조회하는 것은 재노출 생성이 아니므로 동일 후보를 그대로 반환한다.

### 6.2 점수

```text
positiveScore =
  personalityDistance × 0.35
+ noveltyScore × 0.10
+ categoryExplorationScore × 0.05
+ recentDiversityScore × 0.15
+ explorationBonus × 0.15
+ contextFitScore × 0.20

recommendationScore = clamp(positiveScore
  - recentSimilarity × 0.25
  - repeatedPattern × 0.15
  - rejectedPattern × 0.10)
```

- `categoryExplorationScore = 1 / (1 + categoryCompletedCount)`이다.
- 카테고리 완료 이력이 없으면 해당 카테고리를 1로 계산한다.
- `recentDiversityScore`와 `explorationBonus`는 최근 완료 이력과의 메타데이터 유사도·패턴 중복의 역수다.
- 최근성 가중치는 당일 `1.0`에서 하루마다 `0.75`를 곱한다.
- `contextFitScore`는 난이도 적합도와 선택한 할애 가능 시간 적합도의 평균이다.
- 최근 `category`, `actionType`, 환경, 태그, 사회·신체·창의 특성의 반복은 감점한다.
- `SHOWN` 뒤 선택되지 않은 후보와 `CANCELLED` 후보는 skipped/rejected로 해석한다. 반복될수록 같은 패턴의 빈도를 낮추되 하드 제외하지 않고 `comfortZoneDistance`가 큰 후보를 더 감점한다.
- 최종 점수는 0~1 범위로 제한하고 후보 레코드에 저장한다.

### 6.3 랜덤성과 카테고리 다양성

- 추천 점수 내림차순 상위 20개를 최종 후보군으로 사용한다.
- 첫 후보는 점수 기반 가중 추출하고, 다음 후보는 이미 선택한 후보와의 경험 유사도 패널티 `0.35`를 반영한다.
- 최종 후보끼리 유사도 `0.75` 미만인 후보를 우선하며 최대 3개를 반환한다. Catalog가 부족한 경우에만 유사도 조건을 완화한다.
- 최근 수행 카테고리는 가장 최근의 `SELECTED` 또는 `COMPLETED` 로그로 정한다.
- Category뿐 아니라 `actionType`, 태그와 행동 수준이 서로 다른 경험을 우선한다.
- 테스트에서는 고정 `Clock`과 고정 난수 공급자로 결과를 재현한다.

## 7. 미션 Catalog와 LLM

- 최초 추천과 완료 5회 미만 사용자는 `BASE` 미션만 사용한다.
- 완료 5회 이상 사용자는 `BASE`와 검증을 통과한 공유 `LLM` 미션을 사용한다.
- 완료 횟수 5, 10, 15처럼 5의 배수에 도달했을 때 사용자별 한 번만 LLM 생성을 시도한다.
- 제목 정규화와 Content fingerprint의 완전 중복을 차단한다.
- 의미 유사도 기준은 현재 구현의 문자 bigram Jaccard 0.65 이상을 유지한다.
- LLM 결과는 속성 범위, 안전성, 완전 중복과 유사도 검사를 통과한 뒤 공용 Catalog에 저장한다.
- OpenAI 장애, 잘못된 응답 또는 중복 결과는 기본 추천·완료 Transaction을 실패시키지 않는다.
- 같은 사용자·완료 마일스톤은 최초 Claim 결과를 보존하며 실패한 마일스톤을 완료 재요청으로 다시 생성하지 않는다.
- API Key는 `OPENAI_API_KEY`, 모델은 `OPENAI_MODEL` 환경 변수로만 주입한다.
- 현재 DB는 Oracle 21c이므로 PostgreSQL `pgvector`를 추가하지 않는다. `MissionSemanticSimilarity` 확장 지점은 유지하되 기본 구현은 비활성이고, 현재 추천은 메타데이터와 제목·설명 bigram 유사도를 사용한다.

## 8. 상태와 불변식

상태는 다음 값만 사용한다.

```text
GENERATED
SHOWN
SELECTED
CANCELLED
COMPLETED
```

허용 전이:

```text
GENERATED → SHOWN
SHOWN → SELECTED
SELECTED → CANCELLED
SELECTED → COMPLETED
CANCELLED → SELECTED
```

- 후보 생성 Transaction 안에서 `GENERATED`, `SHOWN` 로그를 순서대로 남기고 집계 상태는 `SHOWN`으로 확정한다.
- 현재 상태는 `USER_MISSION`, 전체 이력은 `MISSION_STATUS_LOG`가 기준이다.
- `SELECTED`와 `COMPLETED`만 하루 슬롯을 점유한다.
- 취소 시 슬롯을 비우고, 변경 시 기존 슬롯을 새 후보에 원자적으로 이전한다.
- 같은 완료 요청은 `200 OK`로 기존 완료 결과를 반환하며 완료 횟수와 통계를 다시 증가시키지 않는다.
- UI에서는 `SELECTED`를 `수행중`, `COMPLETED`를 `완료`로 표시한다.

## 9. Oracle 논리 계약

### 기존 `MISSION`

기존 `category`, `estimatedMinutes`, `indoorOutdoor`, `socialLevel`, `activityLevel`, `noveltyLevel`을 재사용한다. 다양성 계산을 위해 `ACTION_TYPE`, `CREATIVITY_LEVEL`, `UNPREDICTABILITY_LEVEL`, `COMFORT_ZONE_DISTANCE`, `COST_LEVEL`, 쉼표 구분 정규화 `TAGS`를 추가한다. 각 수준 값은 0~2이고 태그는 대문자 영문·숫자·underscore 조합으로 개별 1~30자, 1~10개만 허용한다. `durationLevel`은 예상 시간으로 파생하므로 별도 Column을 만들지 않는다.

### 보강할 `USER_MISSION`

- `USER_MISSION_ID`
- `USER_ID`
- `MISSION_ID`
- `SERVICE_DATE`
- `STATUS`
- `AVAILABLE_TIME`
- `OFFER_BATCH_ID`
- `PERSONALITY_DISTANCE`
- `RECOMMENDATION_SCORE`
- `DAILY_SLOT_NO`
- `SHOWN_AT`, `SELECTED_AT`, `CANCELLED_AT`, `COMPLETED_AT`
- `CREATED_AT`, `UPDATED_AT`

사용자·미션·서비스 날짜는 중복 저장하지 않는다. 상태 변경 API는 Catalog의 `missionId`가 아니라 소유권이 있는 `userMissionId`를 사용한다.

### 신규 `USER_MISSION_SETTING`

- `USER_ID` PK/FK
- `AVAILABLE_TIME`
- `DAILY_MISSION_LIMIT` 1~3

### 2026-08-24 Flutter 화면 계약 개정

- 성향 완료 홈 상단에 오늘의 미션을 인라인으로 표시한다.
- 미션 시작 버튼을 누르면 할애 가능 시간만 선택하며 미션 수 옵션은 표시하지 않는다.
- 추천 후보는 `PageView` 가로 캐러셀로 표시한다.
- 선택 후 수행 중 미션 하나를 크게 표시하고 변경·취소·완료를 지원한다.
- 완료 미션의 네 축 벡터와 현재 성향 점수 차이를 행동 선호 경험 방향으로 표시한다.
- 저장 성향 그래프는 기존 5회 단위 갱신 정책을 유지하며 Client가 임의로 확정값을 계산하지 않는다.
- `CREATED_AT`, `UPDATED_AT`

### 신규 `USER_MISSION_CATEGORY_STAT`

- `USER_ID`
- `CATEGORY`
- `COMPLETED_COUNT`
- `LAST_COMPLETED_AT`
- `UPDATED_AT`
- PK: `USER_ID + CATEGORY`

### 기존 `MISSION_STATUS_LOG`

Phase 1에서 nullable `USER_MISSION_ID`, `PREVIOUS_STATUS`, `CHANGE_REASON`을 추가했다. 기존 로그는 보존하고 신규 로그부터 사용자 미션 집계 레코드와 연결한다.

일일 슬롯 중복은 일반 복합 Unique Constraint가 아니라 `SELECTED`, `COMPLETED`에만 값이 생성되는 Oracle 함수 기반 Unique Index로 차단한다. 따라서 `SHOWN`, `CANCELLED` 후보는 슬롯 없이 여러 건 저장할 수 있다.

### `USER_PERSONALITY_PROFILE`

전체 완료 횟수와 마지막 성향 반영 완료 횟수를 관리한다. 완료 5회 단위에만 최근 5개 완료 미션 벡터를 기존 프로필과 혼합하고 `PERSONALITY_V2` 유형을 다시 분류한다.

## 10. REST 계약

모든 API는 `X-User-Key` Header로 소유권을 검증하고 `{ "code": "...", "message": "..." }` 오류 Body를 사용한다.

| Method | Path | 목적 |
|---|---|---|
| GET | `/api/missions/settings` | 사용자 미션 설정 조회 |
| PUT | `/api/missions/settings` | 시간과 하루 한도 저장 |
| GET | `/api/missions/today` | 설정, 수행 중, 완료 수, 기존 후보 조회 |
| POST | `/api/missions/today/recommendations` | 오늘 후보를 최초 생성하거나 기존 후보 반환 |
| POST | `/api/user-missions/{userMissionId}/select` | 후보 선택 |
| POST | `/api/user-missions/{userMissionId}/cancel` | 선택 취소 |
| POST | `/api/user-missions/{userMissionId}/replace` | 기존 선택을 요청 Body의 후보로 교체 |
| POST | `/api/user-missions/{userMissionId}/complete` | 수행 완료 |
| GET | `/api/missions/summary` | 전체·카테고리별 완료 통계 조회 |

`POST /api/missions/today/recommendations`는 최초 생성 시 `201`, 기존 후보 재사용 시 `200`을 반환한다. 안정화 Phase 1~7에서 `/api/missions/random`과 범용 `PATCH /api/missions/{missionId}/status`를 제거했다. 추천 후보의 상태 변경과 완료는 소유권·슬롯·상태 전이를 검증하는 `/api/user-missions/**`와 `UserMissionService`만 사용한다.

완료 응답의 `completion`은 전체 완료 수, 마지막 성향 반영 횟수, 현재 성향 코드, 카테고리별 통계, 성향 갱신 여부, 마일스톤과 LLM 처리 상태를 포함한다. 선택·취소·교체 응답에서는 `completion`이 `null`이다. `GET /api/missions/summary`는 같은 누적 통계를 별도로 조회한다.

오늘 조회 응답은 최소한 다음을 포함한다.

- `serviceDate`
- `settings`
- `completedToday`
- `remainingSlots`
- `activeMissions`
- `candidates`
- 후보별 `userMissionId`, Catalog 속성, 거리, 점수, 상태와 상태 시각

## 11. 오류 계약

| HTTP | Code | 상황 |
|---:|---|---|
| 400 | `INVALID_MISSION_REQUEST` | Enum, 숫자 범위 또는 Body 오류 |
| 401 | `INVALID_USER_KEY` | 사용자 키 누락·불일치 |
| 404 | `USER_MISSION_NOT_FOUND` | 없거나 소유하지 않은 사용자 미션 |
| 409 | `PERSONALITY_REQUIRED` | 성향 분석 미완료 |
| 409 | `MISSION_SETTINGS_REQUIRED` | 미션 설정 없음 |
| 409 | `DAILY_LIMIT_REACHED` | 오늘 수행 한도 초과 |
| 409 | `INVALID_MISSION_TRANSITION` | 허용하지 않는 상태 전이 |
| 409 | `REPLACEMENT_NOT_AVAILABLE` | 오늘 교체 가능한 후보가 아님 |
| 409 | `NO_MISSION_AVAILABLE` | 추천 가능한 후보 0개 |
| 500 | `MISSION_PROCESSING_FAILED` | DB 또는 내부 처리 실패 |

다른 사용자의 `userMissionId`는 소유 여부를 노출하지 않도록 `404`로 응답한다.

## 12. Transaction과 동시성

- 후보 생성은 사용자와 서비스 날짜 단위로 직렬화한다.
- 선택·취소·변경·완료는 대상 `USER_MISSION`과 사용자 설정을 잠근다.
- 선택 시 슬롯의 유일성을 DB Constraint와 Service 검증으로 함께 보장한다.
- 완료 상태, 로그, 카테고리 통계와 성향 완료 횟수는 한 Transaction으로 처리한다.
- LLM 네트워크 호출은 완료 Transaction 성공 이후 수행하여 Oracle Lock을 오래 유지하지 않는다.
- 실패 시 일부 상태·로그·통계가 남지 않도록 전체 Rollback한다.

## 13. Flutter 계약

- 설정이 없으면 성향 결과 다음에 시간과 하루 수행 한도를 묻는다.
- 오늘 화면 상단에 `activeMissions`, 하단에 `candidates`를 표시한다.
- 하루 한도가 2개 이상이면 상단에 수행 중 미션을 여러 개 표시한다.
- 변경 버튼은 오늘의 기존 후보를 선택하는 화면 또는 Bottom sheet를 연다.
- 완료 후 서버 응답으로 화면과 프로필 통계를 갱신한다.
- 요청 중 버튼 중복 입력을 막고 실패 시 기존 화면 상태를 유지한다.
- `DESIGN.md`와 Noto Sans KR을 적용하고 색상만으로 상태를 구분하지 않는다.

## 14. Phase 0~7

| Phase | 범위 | 완료 근거 |
|---:|---|---|
| 0 | 정책·REST·DB·상태·오류 계약 확정 | SDD와 정적 정상·실패 검증 |
| 1 | Oracle Schema와 Migration | 실제 Oracle 객체·제약조건 검증 |
| 2 | 추천 Domain | 고정 Clock·난수 기반 단위 테스트 |
| 3 | 설정·오늘 후보 Backend API | Service·Controller·Oracle·OpenAPI 테스트 |
| 4 | 선택·취소·변경·완료 Backend API | 상태·동시성·멱등·Rollback 테스트 |
| 5 | 통계·성향 갱신·LLM 연결 | 5회 경계·중복·장애 격리 테스트 |
| 6 | Flutter 미션 흐름 | Model·API·Widget 정상·실패 테스트 |
| 7 | 전체 통합 | Flutter→Oracle E2E와 전체 Build |

## 15. 인수 조건

- `AC-01`: 후보 수, 하루 한도, 시간 코드와 서울 날짜 경계가 유일하게 정의된다.
- `AC-02`: 네 개 성향 축의 이름·범위와 거리 공식이 정의된다.
- `AC-03`: 추천 필터, 점수, 랜덤성과 카테고리 다양성 순서가 정의된다.
- `AC-04`: 상태 값과 모든 허용 전이가 정의된다.
- `AC-05`: 취소와 변경의 원자성 및 완료 멱등성이 정의된다.
- `AC-06`: Oracle 집계, 로그, 설정과 통계의 역할이 분리된다.
- `AC-07`: REST 경로, 사용자 식별, 성공 상태와 오류 코드가 정의된다.
- `AC-08`: 동시 후보 생성·선택·완료의 직렬화 기준이 정의된다.
- `AC-09`: LLM 장애가 기본 추천과 완료를 막지 않는다.
- `AC-10`: World 구현이 이번 범위에서 제외되고 category 통계만 제공된다.
- `AC-11`: 현재 프로토타입과 목표 계약의 차이를 완료로 오인하지 않는다.
- `AC-12`: Phase 1~7의 구현·검증 경계가 정의된다.

## 16. 예상 변경 파일

```text
DB.sql
back/src/main/resources/db/survey-schema.sql

back/src/main/java/com/novelty/mission/*
back/src/test/java/com/novelty/mission/*
back/src/main/java/com/novelty/personality/*
back/src/test/java/com/novelty/personality/*

front/app/lib/mission/*
front/app/lib/settings/*
front/app/lib/profile/*
front/app/test/*

SPEC.md
PROJECT_STATUS.md
ARCHITECTURE.md
docs/mission-phase*-verification.md
```

새 Library는 계획하지 않는다. 기존 Spring JDBC, Spring MVC, Java HTTP Client, Flutter `http`와 현재 캐시 의존성을 우선 사용한다.

## 17. 구현 진행 상태

1. Phase 0: 계약과 수용 기준을 확정하고 정적 검증을 완료했다.
2. Phase 1: Oracle Schema를 멱등 적용하고 정상·실패 Constraint 및 Rollback을 검증했다.
3. Phase 2: 순수 Java 추천 정책을 구현한 뒤 V1.1에서 최근 7일 행동 메타데이터, 최근성 가중치, 반복·거부 패널티와 최종 3개 상호 다양성으로 개정하고 검증했다.
4. Phase 3: 설정과 오늘 후보 REST·Service·Oracle 통합, 사용자 잠금, 후보 재사용과 OpenAPI를 구현하고 검증했다.
5. Phase 4: `userMissionId` 기반 선택·취소·변경·완료 API, 소유권 검증, 활성 슬롯, 원자적 교체, 완료 멱등성과 연결 로그를 구현하고 검증했다.
6. Phase 5: 완료 상태·로그·카테고리 통계·완료 횟수를 원자적으로 저장하고, 5회마다 최근 완료 벡터로 성향과 유형을 갱신하며 커밋 이후 LLM 생성·중복/유사도 차단을 연결하고 검증했다.
7. Phase 6: Flutter 미션 설정·후보·수행·통계 흐름과 안전한 오류·중복 요청 방지를 구현하고 정상·실패 시나리오를 검증했다.
8. Phase 7: Flutter → REST → Spring Boot → Oracle → Response → Flutter E2E, 잘못된 사용자 키 실패와 Oracle 직접 조회·정리를 검증했다.
9. 2026-08-24 V1.1: 추천 다양성 개정과 Oracle 메타데이터를 적용하고 집중 22개, 실제 Oracle 1개, Backend 전체 179개와 Flutter 81개 회귀 테스트를 통과했다.
