# 사용자 성향 분석 SDD V2

> 2026-08-24 계정 V1 개정: 이 문서의 익명 사용자 생성·닉네임 선입력·다른 기기 복구 미지원 내용은 `docs/account-sdd-v1.md`로 대체한다. 현재는 회원가입/로그인 후 기존 `X-User-Key` 성향 API를 사용하며, 회원가입 시 랜덤 닉네임을 자동 배정하고 즉시 최초 선택폼을 시작한다. 성향 질문·분석·저장 계약은 그대로 유지한다.

현재 운영 Database는 Supabase PostgreSQL이다. 아래의 Oracle 표현은 과거 Phase 설계·검증 기록을 설명하는 경우를 제외하고 현재 구현 기준으로 해석하지 않는다.

## 1. 문서 정보

- 프로젝트: Novelty
- 핵심 기능: 2. 사용자 성향 분석
- 사양 버전: `PERSONALITY_V2`
- 작성일: 2026-08-19
- 상태: 활성 사양, Phase 0~7 완료

이 문서는 현재 구현 중 서로 다른 의미로 사용되는 성향 필드를 정리하고, 성향 분석만 독립적으로 완성하기 위한 사양과 Phase 0~7을 정의한다.

성향 분석은 심리 검사나 의료 진단이 아니다. 사용자가 어떤 환경과 방식의 행동을 편하게 느끼는지 설명하는 행동 선호 프로필이다.

## 2. 재정의 배경

V2 설계 당시 프로젝트에는 다음 불일치가 있었다. 현재 구현에서는 아래 항목을 해소했다.

1. 기존 `activityLevel`은 `INDOOR`, `MIXED`, `OUTDOOR` 값을 사용하여 실제 의미가 활동 강도가 아니라 실내·실외 선호다.
2. 향후 사용될 성향 벡터에는 실내·실외와 별개로 신체 활동 강도가 필요하지만 최초 설문에는 해당 입력이 없다.
3. Flutter와 `POST /api/surveys`는 `energyLevel`을 전송했고, 개정 정책의 `executionStyle`을 사용하지 않았다.
4. 익명 사용자와 성향 Profile용 기존 Oracle 구조는 일부 준비됐지만 설문 저장과 연결되지 않았다.
5. 사용자 Profile 응답은 현재 성향 객체를 실제로 조회하지 않고 `null`로 반환한다.
6. 이전 SDD에는 시간 질문과 미션 해석 규칙이 함께 포함되어 성향 분석 자체의 완료 범위가 불명확했다.

V2는 이 불일치를 해소하고 미션 관련 구현을 후속 SDD로 분리한다.

## 3. 목표

다음 흐름을 Frontend부터 Supabase PostgreSQL과 응답까지 완성한다.

```text
Flutter 성향 선택폼
→ REST API
→ Spring Boot 입력 검증
→ 결정적 성향 분석
→ Supabase PostgreSQL 원본 답변과 현재 Profile 저장
→ 성향 결과 Response
→ Flutter 성향 Profile 표시
```

재접속과 재분석 흐름도 지원한다.

```text
재접속
→ 캐시의 userKey로 사용자 조회
→ 현재 Profile이 있으면 선택폼 생략
→ 성향 Profile 표시

성향 분석 다시하기
→ 사용자 확인
→ 새 원본 답변 저장
→ 현재 Profile 갱신
→ 새 결과 표시
```

## 4. 범위

### 포함

- `X-User-Key` 기반 사용자 식별과 기존 익명 사용자 연계
- 최초 1회 성향 분석 화면 분기
- 여섯 개 성향 질문과 입력 검증
- 9개 사용자 표시 유형 분류
- 네 개 수치 축과 실행 방식 및 관심 분야 분석
- 원본 답변 보존과 현재 성향 Profile 저장
- 중복 제출 방지
- 성향 결과와 Profile 조회
- 사용자가 명시적으로 실행하는 재분석
- Flutter 결과 Profile 화면
- REST API의 Swagger 문서화
- Oracle, Backend, Flutter 단위 테스트와 통합 검증

### 제외

- 사용 가능 시간의 선택지, 저장 및 API
- 미션 후보 생성, 추천 점수와 무작위 선택
- 미션의 성향 거리 계산
- 미션 상태, 완료 이력 및 완료 기반 성향 갱신
- OpenAI API와 LLM 미션 생성
- 3D World, Object, 경험치 및 Level
- 회원가입, 다른 기기 복구 및 계정 동기화
- 닉네임 정책의 신규 구현

성향 결과 화면 다음 단계는 후속 기능으로 이동할 수 있는 경계만 제공한다. 시간 질문이나 미션 API를 이번 Phase 0~7에 구현하지 않는다.

## 5. 선행 조건과 의존성

- 익명 사용자는 `NOVELTY_USER.USER_ID`로 식별한다.
- Client는 최초 발급받은 원문 `userKey`를 캐시에 저장한다.
- 사용자 범위 API는 `X-User-Key` Header를 사용한다.
- Server는 Header 값을 Hash하여 `USER_KEY_HASH`와 비교한다.
- 닉네임은 Profile 화면의 표시 정보일 뿐 성향 계산 입력이 아니다.
- 캐시 로그인과 닉네임의 세부 정책은 `SPEC.md`를 따른다.
- 같은 브라우저·앱은 `userKey` 캐시로 기존 사용자를 자동 복원한다. 캐시가 없을 때 닉네임만으로 복구하지 않는다.

기존 사용자 API가 완성되지 않은 부분은 성향 분석의 선행 작업으로 보완할 수 있지만 닉네임 규칙을 새로 확장하지 않는다.

## 6. 용어와 필드 의미

| 개념 | API 이름 | 점수 범위 | 의미 |
|---|---|---:|---|
| 실내·실외 선호 | `indoorOutdoor` | `-1..1` | 실내 선호에서 실외 선호까지 |
| 사회적 활동 선호 | `socialLevel` | `-1..1` | 혼자 하기에서 함께하기까지 |
| 신체 활동 강도 선호 | `physicalActivityLevel` | `0..2` | 정적인 활동에서 높은 움직임까지 |
| 새로움 수용도 | `noveltyLevel` | `0..2` | 작은 변화에서 큰 변화까지 |
| 실행 방식 | `executionStyle` | Enum | 계획형, 유연형, 즉흥형 |
| 관심 분야 | `interests` | 1~3개 | 사용자가 선택한 활동 소재 |

`activityLevel`이라는 API 이름은 V2에서 사용하지 않는다. 실내·실외와 신체 활동 강도를 혼동하지 않도록 명시적인 두 필드로 분리한다.

Oracle의 기존 `ACTIVITY_LEVEL`, `ACTIVITY_SCORE`는 비파괴 마이그레이션을 위해 각각 실내·실외 답변과 점수를 의미하는 Legacy 물리 이름으로 유지할 수 있다. Java와 Dart에서는 `indoorOutdoor` 의미로 Mapping하고 신규 신체 활동 값에는 `PHYSICAL_ACTIVITY_*` 이름을 사용한다.

## 7. 성향 선택폼

폼은 여섯 문항이며 Q1, Q2, Q3, Q4, Q6은 단일 선택, Q5는 복수 선택이다.

### Q1. 실내·실외 선호

질문: `쉬는 날의 나는?`

| 코드 | 표시 문구 | 점수 |
|---|---|---:|
| `INDOOR` | 집이나 실내에서 보내는 편 | -1 |
| `MIXED` | 상황에 따라 달라지는 편 | 0 |
| `OUTDOOR` | 밖으로 나가는 편 | 1 |

### Q2. 사회적 활동 선호

질문: `시간이 생겼을 때 더 편한 쪽은?`

| 코드 | 표시 문구 | 점수 |
|---|---|---:|
| `LOW` | 혼자 시간을 보낸다 | -1 |
| `MEDIUM` | 가끔 아는 사람과 함께한다 | 0 |
| `HIGH` | 사람을 만나거나 함께한다 | 1 |

### Q3. 신체 활동 강도 선호

질문: `새로운 활동을 고를 때 편한 움직임은?`

| 코드 | 표시 문구 | 점수 |
|---|---|---:|
| `LOW` | 앉아서 하거나 거의 움직이지 않는 활동 | 0 |
| `MEDIUM` | 가볍게 걷고 움직이는 활동 | 1 |
| `HIGH` | 땀이 나거나 몸을 많이 쓰는 활동 | 2 |

이 문항은 장소가 아니라 움직임의 강도를 묻기 때문에 Q1과 독립적이다.

### Q4. 새로움 수용도

질문: `새로운 일을 해본다면?`

| 코드 | 표시 문구 | 점수 |
|---|---|---:|
| `LOW` | 익숙한 것에 작은 변화를 주는 정도 | 0 |
| `MEDIUM` | 안 해본 것 하나쯤 시도하는 정도 | 1 |
| `HIGH` | 완전히 새로운 것도 시도하는 정도 | 2 |

### Q5. 관심 분야

한 개 이상 세 개 이하를 중복 없이 선택한다.

| 코드 | 표시 문구 |
|---|---|
| `MOVEMENT` | 움직이기 |
| `CREATIVE` | 만들기 |
| `FOOD` | 음식 |
| `LEARNING` | 배우기 |
| `SOCIAL` | 사람 |
| `OUTDOOR` | 바깥 |
| `ORGANIZING` | 정리 |
| `CULTURE` | 문화 |

### Q6. 실행 방식

질문: `새로운 일을 시작할 때 나는?`

| 코드 | 표시 문구 | 사용자 표시 이름 |
|---|---|---|
| `PLANNED` | 순서와 준비물을 먼저 확인하는 편 | 계획 실행형 |
| `FLEXIBLE` | 큰 방향만 정하고 상황에 맞춰 바꾸는 편 | 유연 실행형 |
| `SPONTANEOUS` | 일단 시작하면서 다음을 정하는 편 | 즉흥 실행형 |

기존 `energyLevel` 질문은 V2에서 제거한다. 오늘의 컨디션은 일시 상태이므로 최초 성향 Profile에 포함하지 않는다.

## 8. 분석 규칙

### 8.1 점수 Mapping

- Q1: `INDOOR=-1`, `MIXED=0`, `OUTDOOR=1`
- Q2: `LOW=-1`, `MEDIUM=0`, `HIGH=1`
- Q3: `LOW=0`, `MEDIUM=1`, `HIGH=2`
- Q4: `LOW=0`, `MEDIUM=1`, `HIGH=2`
- Q6는 Enum을 그대로 저장한다.
- Q5는 선택 코드를 별도 관계로 저장한다.

점수 평균이나 확률 모델을 사용하지 않는다. 같은 V2 입력은 항상 같은 결과를 반환한다.

### 8.2 주 성향 유형

주 성향은 Q1과 Q2의 3×3 조합으로 결정한다. Q3~Q6은 유형 이름을 바꾸지 않는 독립 Profile 속성이다.

| 실내·실외 | 사회성 | 코드 | 표시 이름 | 요약 |
|---|---|---|---|---|
| `INDOOR` | `LOW` | `QUIET_FOCUSER` | 고요한 몰입가 | 익숙하고 조용한 공간에서 혼자 집중할 때 편안해요. |
| `INDOOR` | `MEDIUM` | `COZY_EXPLORER` | 아늑한 탐색가 | 편안한 공간을 중심으로 가끔 새로운 연결을 즐겨요. |
| `INDOOR` | `HIGH` | `WARM_HOST` | 다정한 아지트지기 | 편안한 공간에서 사람들과 온기를 나누는 것을 좋아해요. |
| `MIXED` | `LOW` | `FLEXIBLE_INDEPENDENT` | 유연한 독립가 | 장소에 얽매이지 않고 혼자만의 리듬을 지키는 편이에요. |
| `MIXED` | `MEDIUM` | `BALANCED_COORDINATOR` | 균형 조율가 | 혼자와 함께, 실내와 실외 사이를 상황에 맞게 조율해요. |
| `MIXED` | `HIGH` | `OPEN_CONNECTOR` | 열린 연결가 | 다양한 장소에서 사람과 자연스럽게 어울리는 편이에요. |
| `OUTDOOR` | `LOW` | `SOLO_EXPLORER` | 독립 탐험가 | 바깥에서 혼자 발견하고 경험하는 시간을 좋아해요. |
| `OUTDOOR` | `MEDIUM` | `FREE_PIONEER` | 자유로운 개척자 | 바깥 활동을 즐기며 필요할 때 사람과 연결돼요. |
| `OUTDOOR` | `HIGH` | `ACTIVE_CONNECTOR` | 활기찬 연결가 | 바깥에서 사람들과 함께 움직일 때 활력을 느껴요. |

### 8.3 분석 버전

- 원본 답변과 현재 Profile에 `PERSONALITY_V2`를 저장한다.
- 재분석도 당시 실행한 분석 버전을 원본 답변에 기록한다.
- 유형 이름과 Mapping이 바뀌면 기존 버전을 덮어쓰지 않고 새 버전을 만든다.
- API Response는 `analysisVersion`을 항상 포함한다.

## 9. 상태와 불변 조건

사용자 성향 상태는 다음 두 가지로 판단한다.

| 상태 | 조건 | 앱 동작 |
|---|---|---|
| `NOT_ANALYZED` | 현재 Profile 없음 | 최초 성향 폼 표시 |
| `ANALYZED` | 현재 Profile 있음 | 폼을 건너뛰고 Profile 표시 |

불변 조건:

1. 사용자당 현재 Profile은 최대 한 건이다.
2. 완료된 분석마다 원본 답변은 한 건씩 보존한다.
3. 현재 Profile은 반드시 자신의 원본 답변 한 건을 참조한다.
4. 현재 Profile의 관심 분야는 한 개 이상 세 개 이하다.
5. 재분석은 사용자의 명시적 동작으로만 시작한다.
6. 재분석 실패 시 기존 현재 Profile은 유지한다.
7. 동일 제출의 재시도는 원본 답변이나 Profile을 중복 생성하지 않는다.

## 10. REST API 계약

### 10.1 사용자와 현재 Profile 조회

기존 사용자 조회 API를 사용한다.

```http
GET /api/users/me
X-User-Key: <USER_KEY>
```

분석 전 응답:

```json
{
  "userId": 1,
  "nickname": "노벨티07AB",
  "personalityCompleted": false,
  "personality": null
}
```

분석 후 응답:

```json
{
  "userId": 1,
  "nickname": "노벨티07AB",
  "personalityCompleted": true,
  "personality": {
    "typeCode": "QUIET_FOCUSER",
    "typeName": "고요한 몰입가",
    "summary": "익숙하고 조용한 공간에서 혼자 집중할 때 편안해요.",
    "indoorOutdoor": "INDOOR",
    "indoorOutdoorScore": -1,
    "socialLevel": "LOW",
    "socialScore": -1,
    "physicalActivityLevel": "LOW",
    "physicalActivityScore": 0,
    "noveltyLevel": "MEDIUM",
    "noveltyScore": 1,
    "executionStyle": "PLANNED",
    "interests": ["CREATIVE", "LEARNING"],
    "analysisVersion": "PERSONALITY_V2",
    "analyzedAt": "2026-08-19T14:00:00+09:00"
  }
}
```

### 10.2 최초 분석과 재분석

```http
POST /api/personality-analyses
X-User-Key: <USER_KEY>
Content-Type: application/json
```

요청:

```json
{
  "submissionKey": "<CLIENT_GENERATED_UUID>",
  "analysisMode": "INITIAL",
  "indoorOutdoor": "INDOOR",
  "socialLevel": "LOW",
  "physicalActivityLevel": "LOW",
  "noveltyLevel": "MEDIUM",
  "interests": ["CREATIVE", "LEARNING"],
  "executionStyle": "PLANNED"
}
```

`analysisMode` 값:

- `INITIAL`: 현재 Profile이 없는 사용자만 허용
- `REANALYSIS`: 현재 Profile이 있는 사용자만 허용하고 사용자의 다시 하기 확인 후 전송

신규 저장 성공: `201 Created`

```json
{
  "analysisId": 12,
  "status": "ANALYZED",
  "personality": {
    "typeCode": "QUIET_FOCUSER",
    "typeName": "고요한 몰입가",
    "summary": "익숙하고 조용한 공간에서 혼자 집중할 때 편안해요.",
    "indoorOutdoor": "INDOOR",
    "indoorOutdoorScore": -1,
    "socialLevel": "LOW",
    "socialScore": -1,
    "physicalActivityLevel": "LOW",
    "physicalActivityScore": 0,
    "noveltyLevel": "MEDIUM",
    "noveltyScore": 1,
    "executionStyle": "PLANNED",
    "interests": ["CREATIVE", "LEARNING"],
    "analysisVersion": "PERSONALITY_V2",
    "analyzedAt": "2026-08-19T14:00:00+09:00"
  }
}
```

동일 사용자와 동일 `submissionKey`의 같은 요청은 새 행을 만들지 않고 기존 결과와 `200 OK`를 반환한다. 같은 제출 키에 다른 답변이 들어오면 `409 SUBMISSION_KEY_CONFLICT`를 반환한다.

안정화 Phase 3에서 기존 `POST /api/surveys`와 V1 Frontend·Backend 런타임 코드를 제거했다. 원본 선택지는 `POST /api/personality-analyses`가 `SURVEY_RESPONSE`와 `SURVEY_INTEREST`에 저장하며, 현재 성향은 `USER_PERSONALITY_PROFILE`과 `USER_PROFILE_INTEREST`에서 관리한다.

## 11. 오류 계약

공통 Body:

```json
{
  "code": "ERROR_CODE",
  "message": "사용자에게 보여줄 안전한 메시지"
}
```

| HTTP | 코드 | 조건 |
|---:|---|---|
| 400 | `INVALID_PERSONALITY_ANSWERS` | 필수 답변 누락, Enum 오류, 관심 분야 개수·중복 오류 |
| 400 | `INVALID_SUBMISSION_KEY` | UUID 형식이 아니거나 누락 |
| 401 | `INVALID_USER_KEY` | 사용자 키 누락 또는 불일치 |
| 409 | `PERSONALITY_ALREADY_ANALYZED` | Profile이 있는 사용자의 `INITIAL` 요청 |
| 409 | `PERSONALITY_NOT_ANALYZED` | Profile이 없는 사용자의 `REANALYSIS` 요청 |
| 409 | `SUBMISSION_KEY_CONFLICT` | 동일 제출 키의 요청 내용이 다름 |
| 500 | `PERSONALITY_SAVE_FAILED` | 저장 실패 |

내부 SQL, Stack trace, DB 접속정보와 사용자 키 원문을 응답이나 로그에 포함하지 않는다.

## 12. Oracle 저장 모델

### 12.1 `SURVEY_RESPONSE`: 원본 답변 이력

기존 테이블을 비파괴 확장한다.

| 물리 컬럼 | V2 의미 | 규칙 |
|---|---|---|
| `SURVEY_ID` | `analysisId` | PK |
| `USER_ID` | 응답 사용자 | 신규 V2 행 NOT NULL 취급, FK |
| `SUBMISSION_KEY` | 중복 제출 키 | 사용자 범위 UNIQUE |
| `ACTIVITY_LEVEL` | `indoorOutdoor` | Legacy 물리 이름, `INDOOR/MIXED/OUTDOOR` |
| `SOCIAL_ACTIVITY` | `socialLevel` | `LOW/MEDIUM/HIGH` |
| `PHYSICAL_ACTIVITY_LEVEL` | `physicalActivityLevel` | 신규, `LOW/MEDIUM/HIGH` |
| `NOVELTY_TOLERANCE` | `noveltyLevel` | `LOW/MEDIUM/HIGH` |
| `EXECUTION_STYLE` | 실행 방식 | `PLANNED/FLEXIBLE/SPONTANEOUS` |
| `ANALYSIS_MODE` | 최초·재분석 | `INITIAL/REANALYSIS` |
| `ANALYSIS_VERSION` | 분석 규칙 버전 | 신규 V2는 `PERSONALITY_V2` |
| `ENERGY_LEVEL` | V1 Legacy 값 | 신규 V2 행은 `NULL` |
| `CREATED_AT` | 제출 시각 | `Asia/Seoul` 서비스 기준 |

`SUBMISSION_KEY`의 최종 Unique 범위는 `(USER_ID, SUBMISSION_KEY)`로 정의한다. 기존 전역 Unique 제약은 데이터를 확인한 뒤 복합 Unique로 안전하게 마이그레이션한다.

`SURVEY_INTEREST`는 분석 당시 선택한 관심 분야 원본을 보존한다.

### 12.2 `USER_PERSONALITY_PROFILE`: 현재 Profile

| 물리 컬럼 | 의미 | 규칙 |
|---|---|---|
| `USER_ID` | 사용자 | PK, FK |
| `PERSONALITY_CODE` | 9개 주 성향 코드 | NOT NULL, CHECK |
| `ACTIVITY_SCORE` | 실내·실외 점수 | Legacy 물리 이름, `-1/0/1` |
| `SOCIAL_SCORE` | 사회성 점수 | `-1/0/1` |
| `PHYSICAL_ACTIVITY_SCORE` | 신체 활동 강도 | `0/1/2` |
| `NOVELTY_SCORE` | 새로움 수용 점수 | `0/1/2` |
| `EXECUTION_STYLE` | 실행 방식 | Enum CHECK |
| `SOURCE_SURVEY_ID` | 현재 Profile을 만든 원본 | FK |
| `ANALYSIS_VERSION` | 분석 규칙 버전 | `PERSONALITY_V2` |
| `ANALYZED_AT` | 분석 완료 시각 | NOT NULL |
| `UPDATED_AT` | 갱신 시각 | NOT NULL |

현재 관심 분야는 `USER_PROFILE_INTEREST`에 저장한다. `COMPLETED_MISSION_COUNT`는 성향 설문 계산값이 아니며 이번 SDD에서 읽거나 변경하지 않는다.

### 12.3 기존 데이터 보존

- 기존 V1 설문과 `ENERGY_LEVEL`을 삭제하거나 임의 변환하지 않는다.
- 기존 nullable 컬럼은 V1 호환을 위해 유지한다.
- V2 필수 조건은 Backend validation과 V2 식별용 Constraint 조합으로 보장한다.
- 기존 Profile을 V2로 자동 간주하지 않는다. V1 Profile 처리 정책은 Phase 1에서 실제 데이터 건수를 확인하여 결정하고 결과를 SDD에 기록한다.
- `DB.sql`과 `back/src/main/resources/db/survey-schema.sql`을 동일하게 유지한다.

## 13. 트랜잭션과 동시성

성향 분석 저장은 하나의 `@Transactional` 범위에서 처리한다.

1. `X-User-Key` 검증 및 사용자 조회
2. 사용자와 `submissionKey` 기준 기존 제출 조회
3. `analysisMode`와 현재 Profile 상태 검증
4. 요청값 검증
5. `SURVEY_RESPONSE` 원본 저장
6. `SURVEY_INTEREST` 저장
7. `PERSONALITY_V2` 분석 실행
8. `USER_PERSONALITY_PROFILE` insert 또는 update
9. `USER_PROFILE_INTEREST`를 현재 선택으로 교체
10. 사용자 최근 접근 시각 갱신
11. Commit 후 응답

어느 단계든 실패하면 새 원본과 Profile 변경을 모두 Rollback한다. 재분석 실패 시 기존 Profile이 남아 있어야 한다.

동일 사용자에 대한 동시 `INITIAL` 요청은 현재 Profile PK 또는 명시적 잠금으로 한 건만 성공하도록 한다. Unique/PK 충돌을 일반 500으로 노출하지 않고 정의된 409 또는 멱등 성공으로 변환한다.

## 14. Backend 책임 구조

```text
com.novelty.user
└─ 사용자 키 검증과 현재 사용자 조회

com.novelty.survey
└─ 설문 원본 이력 저장과 V1 호환 경계

com.novelty.personality
├─ V2 Request/Response와 Controller
├─ 입력 검증
├─ 결정적 분석 규칙
├─ 원본·현재 Profile 트랜잭션 조정
└─ Profile 조회와 표시 정보 Mapping
```

- V2 성향 분석 비즈니스 로직은 `com.novelty.personality`에 둔다.
- `Controller`는 HTTP 변환만 담당한다.
- 점수와 유형 결정은 DB나 Mission Package에 의존하지 않는 순수 Java 로직으로 만든다.
- 사용자 Profile 응답은 `personality` 조회 결과를 조합하며 임의로 `null`을 넣지 않는다.
- Mission Package는 이번 구현에서 수정하지 않는다.

## 15. Flutter 화면과 상태 전이

### 앱 시작

```text
userKey 없음
└─ 기존 익명 사용자 생성 흐름
   └─ 성향 Profile 없음 → V2 선택폼

userKey 있음
└─ GET /api/users/me
   ├─ personalityCompleted=false → V2 선택폼
   ├─ personalityCompleted=true → 성향 Profile
   └─ 401 → 기존 사용자 복원 실패 안내
```

### 선택폼 상태

```text
LOADING_PROFILE
→ ANSWERING
→ SUBMITTING
→ RESULT

오류 시
SUBMITTING → SUBMIT_ERROR → 동일 submissionKey로 재시도
```

- 이전·다음 이동 시 기존 답변을 유지한다.
- Q5는 1~3개 선택 제한을 즉시 안내한다.
- 마지막 제출 버튼은 여섯 문항이 유효할 때만 활성화한다.
- 중복 탭을 막고 전송 중에는 제출 버튼을 비활성화한다.
- Network 실패 재시도에는 같은 `submissionKey`를 사용한다.
- 저장 성공 또는 사용자가 폼을 처음부터 다시 시작할 때만 새 제출 키를 만든다.

### Profile 화면

최소 표시 항목:

- 닉네임
- 주 성향 이름과 요약
- 실내·실외 선호
- 사회적 활동 선호
- 신체 활동 강도 선호
- 새로움 수용도
- 실행 방식
- 관심 분야
- 마지막 분석 시각
- `성향 분석 다시하기` 버튼

다시 하기는 확인 Dialog 후 시작하며 취소하면 기존 Profile을 유지한다. 결과 화면 다음의 시간 질문은 이번 SDD에서 구현하지 않는다.

모든 화면은 `DESIGN.md`와 `Noto Sans KR`을 따른다.

## 16. 인수 조건

### AC-01 최초 1회 분기

현재 Profile이 없는 사용자는 선택폼을 보고, Profile이 있는 사용자는 일반 접속에서 선택폼을 건너뛴다.

### AC-02 여섯 문항 계약

실내·실외, 사회성, 신체 활동, 새로움, 관심 분야, 실행 방식이 모두 입력되고 `energyLevel`은 V2 요청에 존재하지 않는다.

### AC-03 의미가 분리된 네 축

실내·실외 점수와 신체 활동 점수가 서로 다른 필드와 Oracle 컬럼에 저장된다.

### AC-04 9개 유형 결정성

Q1×Q2의 모든 9개 조합이 정확히 하나의 유형으로 Mapping되고 같은 입력과 버전은 같은 결과를 반환한다.

### AC-05 입력 검증

필수값 누락, 잘못된 Enum, 관심 분야 0개·4개 이상·중복은 PostgreSQL에 저장되지 않고 400으로 반환된다.

### AC-06 원자적 저장

원본 답변, 원본 관심 분야, 현재 Profile, 현재 관심 분야 중 하나라도 실패하면 요청 전체가 Rollback된다.

### AC-07 멱등 재시도

동일 사용자와 동일 제출 키의 같은 요청을 재전송해도 원본과 Profile이 추가되지 않고 기존 결과가 반환된다.

### AC-08 명시적 재분석

재분석은 `REANALYSIS` 요청으로만 실행되고 성공하면 원본은 추가되며 현재 Profile만 새 결과로 교체된다.

### AC-09 재분석 실패 안전성

재분석 저장이 실패하면 기존 현재 Profile과 관심 분야가 변경되지 않는다.

### AC-10 Profile 조회

분석 후 `GET /api/users/me`는 `personalityCompleted=true`와 V2 Profile 전체를 반환한다.

### AC-11 기존 데이터 보존

V1 설문과 `ENERGY_LEVEL` 값은 마이그레이션 후에도 보존된다.

### AC-12 Secret 비노출

사용자 키 원문, DB 인증정보, SQL과 Stack trace가 로그 및 오류 Response에 노출되지 않는다.

### AC-13 Swagger 검증

V2 API와 Request/Response Schema 및 주요 오류가 `/v3/api-docs`와 Swagger UI에 나타난다.

### AC-14 범위 격리

Phase 0~7 완료에 미션 생성, OpenAI, 시간 질문 또는 3D 기능 구현을 요구하지 않으며 관련 파일을 변경하지 않는다.

## 17. Phase 0~7 개발 계획

### Phase 0. V2 기준선 확정

- 기존 SDD, 코드, Schema의 불일치 목록 확정
- 여섯 문항, 9개 유형, 점수와 명명 규칙 확정
- API, Oracle, 트랜잭션, 화면 상태와 인수 조건 확정
- V1 문서를 대체됨으로 표시
- `SPEC.md`와 `PROJECT_STATUS.md` 갱신

완료 기준: 문서 간 필드명, 범위와 Phase 순서가 일치하고 미션 구현이 제외되어 있다.

### Phase 1. Oracle V2 Schema

- 실제 Oracle의 기존 객체와 데이터 건수 확인
- `PHYSICAL_ACTIVITY_LEVEL`, `ANALYSIS_MODE`, `ANALYSIS_VERSION` 추가
- `(USER_ID, SUBMISSION_KEY)` 멱등성 제약과 V2용 Check 구성
- 기존 V1 데이터 보존 검증
- `DB.sql`과 Backend Schema 동기화

완료 기준: SQL 재실행 가능, 두 SQL 동일, 실제 Oracle 컬럼·제약·기존 데이터 보존 확인.

### Phase 2. 순수 성향 Domain

- V2 Enum과 입력 Model 작성
- 6개 문항 Validation 작성
- 점수 Mapping과 9개 유형 분석기 작성
- 표시 이름·요약 Mapping 작성
- 모든 조합과 경계 단위 테스트

완료 기준: Oracle 없이 분석기 테스트가 결정적으로 통과하고 9개 유형과 네 점수 축이 검증됨.

### Phase 3. Spring Boot 저장·조회 API

- `com.novelty.personality` Controller, Service, Repository, DTO 작성
- 사용자 키 인증 연결
- 원본 답변과 현재 Profile 원자적 저장
- 최초·재분석 상태 및 멱등성 처리
- `GET /api/users/me`의 실제 Profile 조합
- Swagger와 Backend 통합 테스트

완료 기준: 정상·Validation·401·409·Rollback·멱등 사례와 OpenAPI 경로 검증.

### Phase 4. Flutter API와 앱 시작 분기

- V2 Request/Response Model 작성
- `X-User-Key` Header와 제출 키 처리
- 사용자 Profile 조회와 최초 접속 분기
- Network 및 정의된 오류 Mapping
- API 단위 테스트

완료 기준: 캐시 사용자 기준으로 폼 또는 Profile이 올바르게 선택되고 V1 API를 호출하지 않음.

### Phase 5. Flutter 여섯 문항 선택폼

- Q1~Q6 UI와 상태 유지
- 관심 분야 1~3개 검증
- 이전·다음, 제출 잠금과 오류 재시도
- `DESIGN.md`, `Noto Sans KR`, 반응형·접근성 적용
- Widget 테스트

완료 기준: 모든 문항과 Validation 및 중복 제출 방지가 Widget 테스트에서 통과.

### Phase 6. 결과 Profile과 재분석

- 성향 결과 및 현재 Profile 화면 구현
- Profile 조회 후 화면 복원
- 다시 하기 확인과 `REANALYSIS` 흐름 구현
- 실패 시 기존 Profile 유지 UI 검증
- 시간 질문과 미션 화면으로 넘어가지 않는 명확한 완료 경계 제공

완료 기준: 최초 분석, 재접속, 재분석 성공·실패 흐름의 Widget/API 조합 테스트 통과.

### Phase 7. Oracle E2E와 완료 기록

- Flutter → REST → Spring Boot → Oracle → Response → Flutter E2E
- 최초 분석, 새로고침 복원, 중복 제출, 재분석, 오류 사례 검증
- Oracle 원본 이력과 현재 Profile 직접 조회
- Backend Test·Package, Flutter Analyze·Test·Web Build 수행
- Swagger UI 확인
- `PROJECT_STATUS.md`와 Phase 7 완료 문서 갱신

완료 기준: AC-01~AC-14가 증거와 함께 모두 충족되고 알려진 오류가 기록됨.

## 18. 최종 구현 파일 범위

```text
DB.sql
back/src/main/resources/db/survey-schema.sql

back/src/main/java/com/novelty/personality/*
back/src/main/java/com/novelty/user/UserProfileResponse.java
back/src/main/java/com/novelty/user/UserRepository.java
back/src/main/java/com/novelty/user/UserService.java
back/src/test/java/com/novelty/personality/*
back/src/test/java/com/novelty/user/*

front/app/lib/main.dart
front/app/lib/api/*
front/app/lib/personality/*
front/app/lib/profile/*
front/app/test/*

docs/personality-phase0-v2-verification.md ~ docs/personality-phase7-v2-verification.md
PROJECT_STATUS.md
SPEC.md
```

안정화 Phase에서 구형 `front/app/lib/survey/*`와 `/api/surveys`는 제거됐으며,
선택지 입력·원본 저장·분석은 Personality 경로로 통합됐다.

이번 SDD 구현 중 `back/src/main/java/com/novelty/mission/*`, `front/app/lib/mission/*`, OpenAI 설정과 World 관련 파일은 변경 대상이 아니다.

## 19. Phase 0 검증 기록

검증일: 2026-08-19

상세 정상·실패 시나리오와 실행 결과는 `docs/personality-phase0-v2-verification.md`에 기록한다.

| 확인 항목 | 결과 |
|---|---|
| 기존 `activityLevel`의 실내·실외 의미 확인 | 확인 |
| 신체 활동 입력 부재와 Profile 기본값 문제 확인 | 확인 |
| Flutter·Backend의 기존 `energyLevel` 사용 확인 | 확인 |
| 현재 Profile 응답이 실제 성향을 반환하지 않는 문제 확인 | 확인 |
| 기존 V1 원본 보존 방침 | 확정 |
| 미션·시간 질문·OpenAI·World 범위 제외 | 확정 |
| Phase 0~7 순서와 인수 조건 | 확정 |
| 정상·주요 실패 시나리오 계약 검사 | 통과 |
| Backend 기존 회귀 테스트 | 49개 통과 |
| Flutter 기존 회귀 테스트 | 17개 통과 |

Phase 0에서는 기능 코드와 Oracle Schema를 수정하지 않는다.

## 20. Phase 1 검증 기록

- 검증일: 2026-08-19
- 상태: 검증 완료
- 상세 기록: `docs/personality-phase1-v2-verification.md`
- 실제 Oracle 기준선: V1 설문 4건, 현재 Profile 0건
- 기존 V1 설문과 `ENERGY_LEVEL` 보존: 성공
- Phase 1 SQL 연속 2회 적용: 성공
- 정상 V2 및 사용자 범위 제출 키 검증: 성공
- 주요 Constraint 실패 시나리오 6개: 성공
- 실제 Oracle 통합 Test를 포함한 Backend 전체 Test: 50개 통과

Profile이 0건이므로 기존 Profile을 자동 변환하지 않는다. Phase 2는 `PERSONALITY_V2` 순수 Domain 구현부터 시작한다.

## 21. Phase 2 검증 기록

- 검증일: 2026-08-19
- 상태: 검증 완료
- 상세 기록: `docs/personality-phase2-v2-verification.md`
- 여섯 문항 Enum과 불변 입력 Model: 구현 완료
- 네 개 축의 모든 점수 Mapping: 검증 완료
- 실내·실외와 사회성의 9개 조합 및 이름·요약: 검증 완료
- 관심 분야 1~3개와 필수 문항 Validation: 검증 완료
- 동일 입력의 결정성 및 관심 분야 방어적 복사: 검증 완료
- Phase 2 전용 Test: 36개 통과
- Backend 전체 Test: 86개, 실패 0, 오류 0, 환경 의존 Oracle 통합 Test 1개 제외

Phase 2 Domain은 Spring, REST, Oracle 및 Mission Package에 의존하지 않는다. 존재하지 않는 Enum 문자열과 HTTP 오류 Mapping은 Phase 3에서 검증한다.

## 22. Phase 3 검증 기록

- 검증일: 2026-08-19
- 상태: 검증 완료
- 상세 기록: `docs/personality-phase3-v2-verification.md`
- `POST /api/personality-analyses`: 구현 및 201·200 응답 검증 완료
- 사용자 키 인증, UUID 제출 키, 최초·재분석 상태: 검증 완료
- 사용자 행 잠금과 사용자 범위 멱등 재시도: 검증 완료
- 원본 답변·현재 Profile·두 관심 분야 집합의 원자적 저장: 실제 Oracle 검증 완료
- `GET /api/users/me` 실제 Profile 조합: 검증 완료
- 400·401·409·500 오류 계약: 검증 완료
- 재분석 저장 도중 실패 시 원본과 기존 Profile Rollback: 실제 Oracle 검증 완료
- OpenAPI의 분석 POST와 사용자 GET 경로: 검증 완료
- Backend 전체 Test: 113개 통과, 실패 0, 오류 0, 제외 0

Phase 3 검증용 Oracle 업무 데이터 행은 정리했다. Oracle Sequence 값 증가는 Transaction Rollback 대상이 아니므로 정상적으로 유지된다. Phase 4는 이 API 계약을 사용하는 Flutter Model과 앱 시작 분기를 구현한다.

## 23. Phase 4 검증 기록

- 검증일: 2026-08-19
- 상태: 검증 완료
- 상세 기록: `docs/personality-phase4-v2-verification.md`
- V2 Request·Response Model과 모든 Backend 정의 오류 Mapping: 검증 완료
- `X-User-Key`, UUID v4 제출 키와 멱등 재시도 세션: 검증 완료
- `SharedPreferencesAsync` 사용자 키 저장·복원: 검증 완료
- 신규 사용자 생성과 분석 전·완료 사용자 앱 시작 분기: 검증 완료
- V1 `/api/surveys` 런타임 제거 및 공식 Personality 경로 단일화: 검증 완료
- 캐시·401·Timeout·Network·응답 계약·설정 실패 시나리오: 검증 완료
- Phase 4 전용 Test: 32개 통과
- Flutter 전체 Test: 49개 통과
- Flutter Analyze와 Web Build: 성공

Phase 4 화면은 앱 시작 분기와 오류 복구 경계만 제공한다. 여섯 문항 선택폼과 완성된 Profile·재분석 UI는 각각 Phase 5와 Phase 6에서 구현한다.

## 24. Phase 5 검증 기록

- 검증일: 2026-08-19
- 상태: 검증 완료
- 상세 기록: `docs/personality-phase5-v2-verification.md`
- SDD Q1~Q6 단일·복수 선택 UI와 상태 유지: 검증 완료
- 관심 분야 1~3개 제한과 필수 안내: 검증 완료
- 이전·다음 이동, 최종 Validation과 제출 잠금: 검증 완료
- Network 실패 시 답변과 동일 제출 키 재시도: 검증 완료
- 안전한 오류 표시와 320px 좁은 화면: 검증 완료
- `DESIGN.md`, Noto Sans KR Theme와 접근성 Semantics: 적용 완료
- Phase 5 신규 Test: 10개 통과
- Bootstrap 회귀를 포함한 집중 Test: 19개 통과
- Flutter 전체 Test: 59개 통과
- Flutter Analyze와 Web Build: 성공

Phase 5 성공 화면은 전체 Profile을 대신하지 않는 최소 완료 경계다. Profile 복원과 전체 속성 표시, 확인 Dialog를 포함한 `REANALYSIS` 흐름은 Phase 6에서 구현한다.

## 25. Phase 6 검증 기록

- 검증일: 2026-08-19
- 상태: 검증 완료
- 상세 기록: `docs/personality-phase6-v2-verification.md`
- 최초 분석 성공 후 전체 Profile 전환: 검증 완료
- 재접속 시 선택폼 생략과 Profile 복원: 검증 완료
- Profile 최소 표시 항목과 `Asia/Seoul` 분석 시각: 검증 완료
- 확인 Dialog 취소와 명시적 `REANALYSIS` 제출: 검증 완료
- 재분석 성공 시 Profile 교체, 실패 시 기존 Profile 보존: 검증 완료
- 시간 질문·미션 화면으로 이동하지 않는 완료 경계: 검증 완료
- `DESIGN.md`, Noto Sans KR Theme와 320px 반응형: 적용 완료
- Phase 6 신규 Test: 9개 통과
- Form·Bootstrap 회귀를 포함한 집중 Test: 26개 통과
- Flutter 전체 Test: 68개 통과
- Flutter Analyze와 Web Build: 성공

Phase 6까지 Flutter 사용자 화면 흐름은 완성됐다. Phase 7에서는 실제 Spring Boot와 Oracle을 실행하여 최초 분석, 새로고침 복원, 멱등 재시도, 재분석 성공·실패를 E2E로 검증하고 AC-01~AC-14 완료 여부를 최종 판정한다.

후속 UI 정리에서는 신규 닉네임 화면에 서비스 목적 설명과 동일 Client 자동 복원 안내를 추가했다. 여섯 문항 선택폼은 워드마크·문항 번호·질문 카드 구조를 사용하며 첫 문항에는 이전 버튼을 렌더링하지 않고 두 번째 문항부터 표시한다. API·분석 계약은 변경하지 않았다.

## 26. Phase 7 검증 기록

- 검증일: 2026-08-19
- 상태: 검증 완료
- 상세 기록: `docs/personality-phase7-v2-verification.md`
- Flutter → REST → Spring Boot → Oracle → Response → Flutter 실제 E2E: 통과
- 최초 분석, Profile 복원, 멱등 재시도, 제출 키 충돌, 명시적 재분석: 통과
- 잘못된 답변, 잘못된 사용자 키, 잘못된 최초·재분석 상태: 기대한 400·401·409 확인
- Oracle 원본 2행, 현재 Profile 1행, 재분석 원본 참조, 관심 분야와 V1 데이터 보존: 직접 조회 통과
- Swagger UI HTTP 200과 OpenAPI 필수 경로: 확인 완료
- Backend Package: 114개 실행, 실패 0, 오류 0, 조건부 검증 1개 제외
- Flutter Analyze: 문제 없음
- Flutter 전체 Test: 68개 통과
- Flutter Web release Build: 성공
- AC-01~AC-14: 모두 충족

Phase 7 검증 데이터는 직접 조회 후 삭제했다. 이로써 사용자 성향 분석 V2의 Phase 0~7은 완료됐으며, 다음 핵심 기능인 미션 생성은 별도 SDD에서 진행한다.
