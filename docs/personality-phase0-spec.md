# 사용자 성향 분석 Phase 0 사양 (V1, 대체됨)

> 상태: **대체됨**
> 2026-08-19에 현재 정책과 실제 구현의 차이를 다시 분석하여 `docs/personality-sdd-v2.md`로 기준 사양을 재정의했다. 이 문서는 당시 결정과 검증 이력을 보존하기 위한 참고 자료이며, 앞으로의 구현 기준이나 Phase 완료 근거로 사용하지 않는다.

## 1. 문서 정보

- 프로젝트: 노벨티(Novelty)
- 기능: 최초 1회 사용자 성향 분석과 익명 사용자 프로필
- 사양 버전: `V1`
- 작성일: 2026-08-19
- 상태: 대체됨 (`docs/personality-sdd-v2.md` 참고)

이 문서는 기존 선택지 폼 저장 기능을 확장하여 익명 사용자를 생성하고, 최초 1회 성향을 분석하여 Oracle에 현재 프로필로 저장하는 계약을 정의한다.

성향 결과는 심리 검사나 의료 진단이 아니라 랜덤 미션의 방향과 표현 방식을 결정하기 위한 행동 선호 정보다.

## 2. 목표

최종 사용자 흐름은 다음과 같다.

```text
최초 접속
→ 익명 사용자 생성 및 랜덤 닉네임 부여
→ 최초 1회 성향 선택지 폼
→ 설문 원본과 현재 성향 프로필 저장
→ 성향 프로필 표시
→ 오늘 할애 가능한 시간 선택
→ 성향·관심 분야·실행 방식·시간을 반영한 랜덤 미션 생성
```

재접속 흐름은 다음과 같다.

```text
재접속
→ 캐시의 사용자 키로 자동 로그인
→ 저장된 사용자와 현재 성향 프로필 조회
→ 성향 분석 생략
→ 프로필 표시
→ 오늘 할애 가능한 시간 선택
```

사용자가 `성향 분석 다시하기`를 명시적으로 선택한 경우에만 설문을 다시 진행한다.

## 3. 범위

### 포함

- 회원가입 없는 익명 사용자 생성과 동일 기기 자동 로그인
- 중복되지 않는 초기 랜덤 닉네임 생성
- 닉네임 조회와 변경 계약
- 닉네임 형식, 중복, 공백, 특수문자, 비속어 검증 계약
- 기존 선택지 폼의 에너지 문항을 실행 방식 문항으로 교체하는 계약
- 9개 주 성향과 3개 실행 방식 분류
- 최초 분석과 사용자 요청에 의한 재분석
- 원본 설문 보존과 현재 성향 프로필 갱신
- 사용 가능 시간 질문을 성향 분석 이후로 분리
- 향후 랜덤 미션 생성에 필요한 프로필 데이터 계약
- Oracle 논리 모델과 기존 스키마의 비파괴 마이그레이션 정책
- REST API, 오류, 트랜잭션, 보안 및 인수 조건

### 제외

- 이메일, 비밀번호, 소셜 계정을 이용한 회원가입
- 닉네임만 입력하는 인증
- 다른 기기에서의 계정 복구 또는 동기화
- 성향 변경 이력 전용 화면과 이력 테이블
- 랜덤 미션 생성 알고리즘 구현
- 미션 수행, 스티커, 3D 공간 성장 및 레벨 구현
- 관리자용 금지어 관리 화면

## 4. 확정 결정

1. 성향 분석은 사용자별 최초 1회만 자동으로 실행한다.
2. 프로필이 존재하는 사용자는 접속 시 성향 분석을 건너뛴다.
3. 재분석은 사용자가 `성향 분석 다시하기`를 선택한 경우에만 실행한다.
4. 재분석 시 과거 설문 원본은 보존하고 현재 프로필만 최신 결과로 갱신한다.
5. 오늘 할애 가능한 시간은 성향 값이 아니며 성향 분석 이후 매 미션 생성 시 묻는다.
6. 기존 에너지 문항은 실행 방식 문항으로 교체한다.
7. 닉네임은 표시 이름이며 인증정보로 사용하지 않는다.
8. 자동 로그인에는 클라이언트 캐시에 저장한 고엔트로피 `userKey`를 사용한다.
9. API에는 `X-User-Key` Header로 사용자 키를 전달한다.
10. Oracle에는 원문 `userKey` 대신 SHA-256 Hash를 저장한다.
11. 캐시를 삭제하면 현재 범위에서는 기존 프로필을 복구할 수 없다.
12. 성향 분석 알고리즘 버전은 `V1`로 저장한다.
13. 주 성향은 활동 공간과 사회 활동의 3×3 조합인 9개로 유지한다.
14. 새로움 수용도, 실행 방식, 관심 분야는 주 성향을 보완하는 독립 속성으로 저장한다.
15. 신규 API는 Swagger UI에서 요청·응답과 오류 코드를 확인할 수 있어야 한다.

## 5. 성향 선택지 폼

폼은 다섯 문항으로 구성한다.

### Q1. 활동 공간 성향

질문:

```text
쉬는 날의 나는?
```

| 코드 | 표시 문구 | 점수 |
|---|---|---:|
| `INDOOR` | 집에서 보내는 편 | -1 |
| `MIXED` | 필요하면 나가는 편 | 0 |
| `OUTDOOR` | 밖에서 보내는 편 | 1 |

### Q2. 사회 활동 성향

질문:

```text
시간이 남는다면?
```

| 코드 | 표시 문구 | 점수 |
|---|---|---:|
| `LOW` | 혼자 시간을 보낸다 | -1 |
| `MEDIUM` | 아는 사람에게 연락한다 | 0 |
| `HIGH` | 사람을 만난다 | 1 |

### Q3. 새로움 수용도

질문:

```text
새로운 일을 해본다면?
```

| 코드 | 표시 문구 | 분석 이름 | 점수 |
|---|---|---|---:|
| `LOW` | 익숙한 것에 작은 변화 | 안정 선호형 | 0 |
| `MEDIUM` | 안 해본 것 하나쯤 | 균형 확장형 | 1 |
| `HIGH` | 완전히 새로운 것도 좋아요 | 도전 선호형 | 2 |

### Q4. 관심 분야

사용자는 한 개 이상 세 개 이하를 선택한다.

| 코드 | 표시 문구 |
|---|---|
| `MOVEMENT` | 움직이기 |
| `CREATIVE` | 만들기 |
| `FOOD` | 먹기 |
| `LEARNING` | 배우기 |
| `SOCIAL` | 사람 |
| `OUTDOOR` | 바깥 |
| `ORGANIZING` | 정리 |
| `CULTURE` | 문화 |

### Q5. 실행 방식

기존 오늘의 에너지 문항을 다음 문항으로 교체한다.

질문:

```text
새로운 일을 시작할 때 나는?
```

| 코드 | 표시 문구 | 분석 이름 |
|---|---|---|
| `PLANNED` | 순서와 준비물을 먼저 확인하는 편 | 계획 실행형 |
| `FLEXIBLE` | 큰 방향만 정하고 상황에 맞춰 바꾸는 편 | 유연 실행형 |
| `SPONTANEOUS` | 일단 시작하면서 다음을 정하는 편 | 즉흥 실행형 |

실행 방식은 앞선 활동 공간, 사회 활동, 새로움 수용도 및 관심 분야와 중복되지 않는다. 향후 미션의 안내 형식을 결정한다.

- `PLANNED`: 준비물, 예상 시간, 단계별 순서를 명확하게 제공한다.
- `FLEXIBLE`: 기본 방법과 축소·확장 가능한 선택지를 함께 제공한다.
- `SPONTANEOUS`: 준비 없이 바로 실행할 수 있는 짧은 행동을 우선 제공한다.

## 6. 주 성향 분류

주 성향은 Q1과 Q2만으로 결정한다. Q3~Q5는 주 성향을 변경하지 않고 미션 생성용 보조 속성으로 사용한다.

| 활동 | 사회성 | 코드 | 사용자 표시 이름 |
|---|---|---|---|
| `INDOOR` | `LOW` | `QUIET_FOCUSER` | 고요한 몰입가 |
| `INDOOR` | `MEDIUM` | `COZY_EXPLORER` | 아늑한 탐색가 |
| `INDOOR` | `HIGH` | `WARM_HOST` | 다정한 아지트지기 |
| `MIXED` | `LOW` | `FLEXIBLE_INDEPENDENT` | 유연한 독립가 |
| `MIXED` | `MEDIUM` | `BALANCED_COORDINATOR` | 균형 조율가 |
| `MIXED` | `HIGH` | `OPEN_CONNECTOR` | 열린 연결가 |
| `OUTDOOR` | `LOW` | `SOLO_EXPLORER` | 독립 탐험가 |
| `OUTDOOR` | `MEDIUM` | `FREE_PIONEER` | 자유로운 개척자 |
| `OUTDOOR` | `HIGH` | `ACTIVE_CONNECTOR` | 활기찬 연결가 |

같은 답변과 같은 분석 버전은 항상 같은 성향 결과를 반환해야 한다.

## 7. 미션 생성용 해석 계약

향후 미션 생성기는 성향 이름만 사용하지 않고 다음 값을 함께 조회한다.

```text
주 성향 코드
+ 활동 공간 점수
+ 사회 활동 점수
+ 새로움 수용 점수
+ 실행 방식
+ 관심 분야
+ 오늘 할애 가능한 시간
+ 최근 미션 이력
```

반대 성향 미션은 다음 규칙을 따른다.

- `INDOOR`에는 외부 활동을 우선하고 `OUTDOOR`에는 실내 몰입 활동을 우선한다.
- 사회성 `LOW`에는 가벼운 교류를, `HIGH`에는 혼자 집중하는 활동을 우선한다.
- `MIXED`와 `MEDIUM`은 최근 미션 이력에서 덜 사용된 방향을 우선한다.
- 새로움 `LOW`에는 한 단계만 확장된 미션을 제공하고 극단적인 변화는 피한다.
- 새로움 `HIGH`에는 익숙하고 구조화된 활동도 섞어 균형을 준다.
- 관심 분야는 반대로 뒤집지 않고 낯선 행동의 참여 장벽을 낮추는 소재로 사용한다.
- 사용 가능 시간은 성향과 반대로 만들지 않고 미션 소요 시간의 상한으로 사용한다.

## 8. 성향 분석 이후 시간 질문

질문:

```text
오늘 미션에 얼마나 시간을 쓸 수 있나요?
```

| 코드 | 표시 문구 | 최대 시간(분) |
|---|---|---:|
| `QUICK` | 5분 이내 | 5 |
| `SHORT` | 10~15분 | 15 |
| `MEDIUM` | 20~30분 | 30 |
| `LONG` | 30분 이상 | 60 |

이 값은 성향 프로필에 저장하지 않는다. 미션 생성 기능이 구현되면 미션 생성 요청과 생성된 미션 기록에 저장한다.

## 9. 익명 사용자와 자동 로그인

### 사용자 키

- Backend는 최초 사용자 생성 시 암호학적으로 안전한 256-bit 임의 `userKey`를 생성한다.
- 원문 `userKey`는 최초 응답으로 한 번 전달하고 Flutter의 브라우저 또는 앱 캐시에 저장한다.
- Oracle에는 `SHA-256(userKey)`인 `USER_KEY_HASH`만 저장한다.
- 이후 요청은 `X-User-Key` Header를 사용한다.
- 사용자 조회 시 Backend가 전달받은 키를 Hash하여 `USER_KEY_HASH`와 비교한다.
- 사용자 키는 로그, 오류 응답, URL 및 Swagger 예시에 실제 값으로 노출하지 않는다.
- 유효하지 않은 키에는 `401 INVALID_USER_KEY`를 반환한다.

### 캐시 정책

Flutter는 다음 값을 로컬 캐시에 저장한다.

```text
userKey
pendingSubmissionKey
```

닉네임과 성향 프로필의 기준 데이터는 Oracle이며 캐시된 화면 값은 서버 응답으로 갱신한다.

캐시가 없으면 신규 익명 사용자를 생성한다. 유효하지 않은 키가 발견되면 사용자에게 기존 프로필을 불러오지 못했다는 사실을 알리고 명시적 확인 후 신규 사용자 흐름으로 전환한다.

## 10. 닉네임 계약

### 초기 랜덤 닉네임

형식:

```text
노벨티 + 숫자 2자리 + 영문 대문자 2자리
```

정규식:

```regex
^노벨티[0-9]{2}[A-Z]{2}$
```

예시:

```text
노벨티07QK
```

Backend가 생성하며 Frontend는 초기 닉네임을 생성하지 않는다. `NICKNAME_NORMALIZED`의 Oracle UNIQUE 제약조건을 최종 중복 방지 수단으로 사용한다. 충돌하면 최대 20회 다시 생성하고, 모두 실패하면 `500 NICKNAME_GENERATION_FAILED`를 반환한다.

### 사용자 지정 닉네임

- 길이는 한 글자 이상 열두 글자 이하로 제한한다.
- 한글 완성형, 영문자, 숫자만 허용한다.
- 공백과 특수문자는 허용하지 않는다.
- Unicode NFC 정규화 후 영문자를 대문자로 변환한 값을 중복 검사에 사용한다.
- 정규화된 닉네임은 중복될 수 없다.
- 활성화된 금지어를 포함할 수 없다.

허용 정규식:

```regex
^[가-힣A-Za-z0-9]{1,12}$
```

검증 순서:

1. 원본 입력의 길이와 허용 문자 확인
2. Unicode NFC 정규화
3. 영문 대문자 변환
4. 활성 금지어의 포함 여부 확인
5. 정규화 닉네임 중복 확인
6. Oracle UNIQUE 제약조건으로 동시 요청 충돌 방지

금지어는 Java 코드가 아닌 `NICKNAME_BANNED_WORD`에서 관리한다. 실제 금지어를 API 응답이나 로그에 포함하지 않고 사용자에게는 안전한 일반 오류 문구를 반환한다.

## 11. REST API 계약

### 11.1 익명 사용자 생성

```http
POST /api/users/anonymous
```

성공: `201 Created`

```json
{
  "userKey": "<ONE_TIME_RAW_USER_KEY>",
  "nickname": "노벨티07QK",
  "personalityCompleted": false
}
```

### 11.2 현재 사용자와 프로필 조회

```http
GET /api/users/me
X-User-Key: <USER_KEY>
```

성향 분석 전 응답:

```json
{
  "nickname": "노벨티07QK",
  "personalityCompleted": false,
  "personality": null
}
```

성향 분석 후 응답:

```json
{
  "nickname": "노벨티07QK",
  "personalityCompleted": true,
  "personality": {
    "typeCode": "QUIET_FOCUSER",
    "typeName": "고요한 몰입가",
    "summary": "혼자 집중하는 활동에서 편안함을 느끼는 성향이에요.",
    "activityTendency": "INDOOR",
    "socialTendency": "LOW",
    "noveltyStyle": "MEDIUM",
    "executionStyle": "PLANNED",
    "interests": ["CREATIVE", "LEARNING"],
    "analysisVersion": "V1",
    "analyzedAt": "2026-08-19T14:00:00+09:00"
  }
}
```

### 11.3 닉네임 변경

```http
PATCH /api/users/me/nickname
X-User-Key: <USER_KEY>
Content-Type: application/json
```

```json
{
  "nickname": "새로운닉네임"
}
```

성공: `200 OK`

```json
{
  "nickname": "새로운닉네임"
}
```

### 11.4 최초 성향 분석 또는 재분석

기존 설문 저장 API를 확장한다.

```http
POST /api/surveys
X-User-Key: <USER_KEY>
Content-Type: application/json
```

```json
{
  "submissionKey": "<CLIENT_GENERATED_IDEMPOTENCY_KEY>",
  "activityLevel": "INDOOR",
  "socialActivity": "LOW",
  "noveltyTolerance": "MEDIUM",
  "interests": ["CREATIVE", "LEARNING"],
  "executionStyle": "PLANNED"
}
```

최초 저장 성공: `201 Created`

```json
{
  "surveyId": 12,
  "status": "SAVED",
  "nickname": "노벨티07QK",
  "personality": {
    "typeCode": "QUIET_FOCUSER",
    "typeName": "고요한 몰입가",
    "summary": "혼자 집중하는 활동에서 편안함을 느끼는 성향이에요.",
    "activityTendency": "INDOOR",
    "socialTendency": "LOW",
    "noveltyStyle": "MEDIUM",
    "executionStyle": "PLANNED",
    "interests": ["CREATIVE", "LEARNING"],
    "analysisVersion": "V1",
    "analyzedAt": "2026-08-19T14:00:00+09:00"
  }
}
```

동일한 `submissionKey` 재요청은 새 데이터를 만들지 않고 기존 결과와 `200 OK`를 반환한다.

### 11.5 향후 미션 생성 요청

이 API는 이번 성향 분석 기능에서 구현하지 않지만 다음 계약을 전달한다.

```http
POST /api/missions/random
X-User-Key: <USER_KEY>
```

```json
{
  "availableTime": "SHORT"
}
```

## 12. 오류 계약

공통 형식:

```json
{
  "code": "ERROR_CODE",
  "message": "사용자에게 보여줄 안전한 메시지"
}
```

| HTTP | 코드 | 조건 |
|---:|---|---|
| 400 | `INVALID_SURVEY` | 설문 누락, 관심 분야 개수 또는 중복 오류 |
| 400 | `INVALID_NICKNAME` | 길이, 문자, 공백 또는 특수문자 오류 |
| 400 | `BANNED_NICKNAME` | 활성 금지어 포함 |
| 401 | `INVALID_USER_KEY` | 사용자 키 누락 또는 불일치 |
| 409 | `DUPLICATE_NICKNAME` | 정규화 닉네임 중복 |
| 409 | `SUBMISSION_KEY_CONFLICT` | 제출 키가 다른 사용자 요청과 충돌 |
| 500 | `NICKNAME_GENERATION_FAILED` | 초기 랜덤 닉네임 생성 반복 실패 |
| 500 | `PROFILE_SAVE_FAILED` | 사용자, 설문 또는 프로필 저장 실패 |

Oracle 오류 메시지, SQL, 계정정보, 사용자 키 원문 및 Stack Trace는 응답에 포함하지 않는다.

## 13. Oracle 논리 모델

### `NOVELTY_USER`

| 컬럼 | 타입 | 규칙 |
|---|---|---|
| `USER_ID` | `NUMBER(19)` | PK, Sequence 발급 |
| `USER_KEY_HASH` | `VARCHAR2(64)` | NOT NULL, UNIQUE |
| `NICKNAME` | `VARCHAR2(36 CHAR)` | NOT NULL |
| `NICKNAME_NORMALIZED` | `VARCHAR2(36 CHAR)` | NOT NULL, UNIQUE |
| `CREATED_AT` | `TIMESTAMP` | NOT NULL |
| `UPDATED_AT` | `TIMESTAMP` | NOT NULL |
| `LAST_SEEN_AT` | `TIMESTAMP` | NOT NULL |

Sequence: `NOVELTY_USER_SEQ`

### `USER_PERSONALITY_PROFILE`

| 컬럼 | 타입 | 규칙 |
|---|---|---|
| `USER_ID` | `NUMBER(19)` | PK, `NOVELTY_USER` FK |
| `PERSONALITY_CODE` | `VARCHAR2(32)` | 9개 코드 CHECK |
| `ACTIVITY_SCORE` | `NUMBER(1)` | `-1, 0, 1` CHECK |
| `SOCIAL_SCORE` | `NUMBER(1)` | `-1, 0, 1` CHECK |
| `NOVELTY_SCORE` | `NUMBER(1)` | `0, 1, 2` CHECK |
| `EXECUTION_STYLE` | `VARCHAR2(16)` | 3개 코드 CHECK |
| `SOURCE_SURVEY_ID` | `NUMBER(19)` | `SURVEY_RESPONSE` FK |
| `ANALYSIS_VERSION` | `VARCHAR2(10)` | 최초 `V1` |
| `ANALYZED_AT` | `TIMESTAMP` | NOT NULL |
| `UPDATED_AT` | `TIMESTAMP` | NOT NULL |

### `USER_PROFILE_INTEREST`

| 컬럼 | 타입 | 규칙 |
|---|---|---|
| `USER_ID` | `NUMBER(19)` | `NOVELTY_USER` FK |
| `INTEREST_CODE` | `VARCHAR2(20)` | 기존 8개 코드 CHECK |

PK는 `(USER_ID, INTEREST_CODE)`를 사용한다.

### `NICKNAME_BANNED_WORD`

| 컬럼 | 타입 | 규칙 |
|---|---|---|
| `BANNED_WORD_ID` | `NUMBER(19)` | PK, Sequence 발급 |
| `WORD_NORMALIZED` | `VARCHAR2(36 CHAR)` | NOT NULL, UNIQUE |
| `ACTIVE` | `CHAR(1)` | `Y, N` CHECK |
| `CREATED_AT` | `TIMESTAMP` | NOT NULL |

Sequence: `NICKNAME_BANNED_WORD_SEQ`

금지어 초기 데이터는 `DB.sql`의 필수 기준 데이터로 관리하되 실제 단어는 API, 테스트 로그와 사용자 문서에 출력하지 않는다. 테스트에서는 실제 비속어 대신 중립적인 Fixture를 사용한다.

### 기존 `SURVEY_RESPONSE` 변경

다음 컬럼을 추가한다.

| 컬럼 | 타입 | 규칙 |
|---|---|---|
| `USER_ID` | `NUMBER(19)` | 기존 행 호환을 위해 nullable, 신규 저장은 필수 |
| `SUBMISSION_KEY` | `VARCHAR2(64)` | 기존 행 nullable, 신규 저장은 필수, UNIQUE |
| `EXECUTION_STYLE` | `VARCHAR2(16)` | 기존 행 nullable, 신규 저장은 필수, 3개 코드 CHECK |

기존 `ENERGY_LEVEL`은 데이터를 보존한다. Phase 1에서 nullable로 변경하고 신규 저장 코드가 더 이상 쓰지 않도록 한다. 기존 CHECK 제약조건은 NULL을 허용하므로 보존할 수 있다.

`SURVEY_RESPONSE.USER_ID`에는 `NOVELTY_USER.USER_ID` FK와 조회용 Index를 추가한다.

## 14. 트랜잭션과 중복 제출

### 익명 사용자 생성

1. 안전한 `userKey`와 랜덤 닉네임 후보 생성
2. `USER_KEY_HASH` 계산
3. `NOVELTY_USER_SEQ`로 ID 발급
4. `NOVELTY_USER` 저장
5. 닉네임 UNIQUE 충돌 시 전체 Rollback 후 새 후보로 재시도

### 설문과 성향 저장

다음 처리를 하나의 `@Transactional` 범위에서 실행한다.

1. 사용자 키 검증과 사용자 조회
2. `submissionKey` 중복 확인
3. 요청 검증
4. 설문 ID 발급과 `SURVEY_RESPONSE` 저장
5. `SURVEY_INTEREST` 저장
6. 성향 분석 V1 실행
7. `USER_PERSONALITY_PROFILE` upsert
8. 기존 `USER_PROFILE_INTEREST` 삭제 후 현재 관심 분야 저장
9. 사용자 `UPDATED_AT`, `LAST_SEEN_AT` 갱신
10. Commit 후 응답 생성

하나라도 실패하면 전체를 Rollback한다. 동일 사용자의 재분석은 새 설문 원본을 만들되 현재 프로필은 갱신한다.

## 15. Frontend 상태 전이

```text
앱 시작
├─ 캐시 userKey 없음
│  └─ 익명 사용자 생성 → userKey 캐시 → 성향 폼
└─ 캐시 userKey 있음
   └─ GET /api/users/me
      ├─ personalityCompleted=false → 성향 폼
      ├─ personalityCompleted=true → 프로필
      └─ 401 → 안내 후 신규 사용자 전환 확인
```

프로필 화면에는 다음 정보를 표시한다.

- 닉네임과 변경 기능
- 주 성향 이름과 설명
- 새로움 수용 스타일
- 실행 방식
- 관심 분야
- 마지막 분석일
- `오늘의 미션 받기`
- `성향 분석 다시하기`

`오늘의 미션 받기`를 선택하면 사용 가능 시간 질문으로 이동한다. `성향 분석 다시하기`를 선택하면 확인 후 기존 다섯 문항을 다시 진행한다.

## 16. 책임 경계

### Flutter

- 사용자 키와 진행 중 제출 키 캐시
- 최초/재접속 화면 분기
- 설문 입력과 실행 방식 문항 제공
- 프로필과 닉네임 변경 UI
- 재분석 명시적 실행
- 성향 결과 이후 사용 가능 시간 질문

### User 영역

- 사용자 키 생성, Hash, 검증
- 랜덤 닉네임 생성
- 닉네임 정규화, 금지어, 중복 검증
- 사용자와 현재 프로필 조회

### Survey 영역

- 설문 계약 검증
- 원본 답변 저장
- 제출 키 중복 처리
- 성향 분석 실행과 현재 프로필 갱신 조정

### Mission 영역

- 현재 프로필과 오늘 사용 가능 시간 조회
- 반대 성향 미션 생성
- 최근 미션 이력과 시간 상한 반영

Mission 구현은 이번 기능 범위에서 제외한다.

## 17. 비기능 및 보안 요구사항

- Secret과 사용자 키 원문을 코드, SQL, Git 추적 설정, 로그에 작성하지 않는다.
- 닉네임은 개인정보 입력을 권장하지 않는다는 안내를 제공한다.
- 사용자 키 비교는 Hash 기반으로 처리한다.
- 닉네임 중복은 사전 조회와 Oracle UNIQUE 제약조건을 함께 사용한다.
- 모든 신규 API는 `/api/**`에 위치하고 Swagger에 자동 노출한다.
- 분석 로직은 DB와 분리한 순수 Java 코드로 작성하고 9개 조합을 단위 테스트한다.
- 같은 입력과 `ANALYSIS_VERSION`은 같은 결과를 반환해야 한다.
- 기존 설문 데이터와 `ENERGY_LEVEL` 값을 삭제하지 않는다.
- 추가 Library는 캐시 등 기존 Library로 해결할 수 없는 범위에만 추가한다.
- Frontend는 `DESIGN.md`와 `Noto Sans KR`을 따른다.

## 18. 인수 조건

### AC-01 익명 사용자 최초 생성

캐시에 사용자 키가 없을 때 익명 사용자가 한 명 생성되고 유일한 랜덤 닉네임과 원문 사용자 키가 한 번 반환된다.

### AC-02 동일 기기 자동 로그인

캐시의 유효한 사용자 키로 재접속하면 새 사용자를 만들지 않고 기존 사용자와 프로필을 반환한다.

### AC-03 최초 분석 한 번

현재 프로필이 존재하면 일반 접속에서 성향 설문을 표시하지 않는다.

### AC-04 명시적 재분석

사용자가 다시 분석하기를 선택했을 때만 새 설문을 저장하고 현재 프로필을 갱신한다.

### AC-05 9개 성향 결정성

활동 공간과 사회 활동의 9개 조합이 정확히 하나의 주 성향으로 분류되고 같은 입력은 같은 결과를 반환한다.

### AC-06 실행 방식 분석

기존 에너지 문항 대신 `PLANNED`, `FLEXIBLE`, `SPONTANEOUS` 중 하나가 저장되고 프로필에 표시된다.

### AC-07 시간 질문 분리

사용 가능 시간은 성향 분석이 완료된 이후에만 질문하며 성향 프로필 값으로 저장하지 않는다.

### AC-08 초기 닉네임 유일성

초기 닉네임은 `노벨티+숫자2자리+영문대문자2자리` 형식이고 동시 요청에서도 중복 저장되지 않는다.

### AC-09 닉네임 정책

공백, 특수문자, 열두 글자 초과, 중복 및 활성 금지어 포함 닉네임은 저장되지 않는다.

### AC-10 원자적 저장

설문, 관심 분야, 현재 성향 프로필 중 하나라도 실패하면 같은 요청의 모든 변경이 Rollback된다.

### AC-11 중복 제출 방지

동일한 `submissionKey` 재요청은 새 설문이나 프로필을 만들지 않고 기존 결과를 반환한다.

### AC-12 기존 데이터 보존

기존 설문과 `ENERGY_LEVEL` 데이터는 스키마 변경 후에도 유지된다.

### AC-13 미래 미션 입력 준비

Mission 영역이 사용자 키로 주 성향, 점수, 새로움 수용도, 실행 방식과 관심 분야를 조회할 수 있다.

### AC-14 Secret 비노출

DB Secret, 사용자 키 원문, SQL과 내부 예외가 API 오류 응답이나 Git 추적 파일에 포함되지 않는다.

## 19. Phase 1 진입 조건

- 기존 `POST /api/surveys`가 올바른 DB 환경 변수에서 `201 Created`를 반환한다.
- 저장된 기존 설문과 관심 분야를 Oracle에서 조회할 수 있다.
- 이 문서의 질문, 9개 이름, 실행 방식, 닉네임 정책과 캐시 기반 자동 로그인 정책이 구현 기준으로 확정된다.
- `DB.sql`과 Backend 스키마 SQL이 현재 동일하다.
- Oracle 계정에 `CREATE TABLE`, `CREATE SEQUENCE`, `ALTER`, `CREATE INDEX` 권한과 Tablespace quota가 있다.
- Phase 1에서는 실제 금지어를 외부에 노출하지 않는 방식으로 기준 데이터를 구성한다.

## 20. 예상 변경 파일

Phase 1~7에서 생성하거나 수정할 가능성이 있는 파일은 다음과 같다.

```text
DB.sql
back/src/main/resources/db/survey-schema.sql

back/src/main/java/com/novelty/user/*
back/src/main/java/com/novelty/survey/SurveyRequest.java
back/src/main/java/com/novelty/survey/SurveyResponse.java
back/src/main/java/com/novelty/survey/SurveyRepository.java
back/src/main/java/com/novelty/survey/SurveyService.java
back/src/main/java/com/novelty/survey/SurveyController.java
back/src/main/java/com/novelty/survey/SurveyExceptionHandler.java
back/src/test/java/com/novelty/user/*
back/src/test/java/com/novelty/survey/*

front/app/pubspec.yaml
front/app/pubspec.lock
front/app/lib/user/*
front/app/lib/personality/*
front/app/lib/api/survey_api.dart
front/app/lib/survey/survey_models.dart
front/app/lib/survey/survey_screen.dart
front/app/test/*
front/app/tool/personality_e2e_check.dart

docs/personality-phase7-completion.md
```

## 21. Phase 0 검증 결과

검증일: 2026-08-19

| 검증 항목 | 결과 |
|---|---|
| 현재 `DB.sql`과 Backend 스키마 SQL 일치 | 성공 |
| 기존 `POST /api/surveys` 호출 | `201 Created` |
| 기존 응답 계약 | 양수 `surveyId`, `status=SAVED` 확인 |
| `SURVEY_RESPONSE` 요청값 일치 | 성공 |
| `SURVEY_INTEREST` 두 개 코드 일치 | 성공 |
| 부모 설문 삭제 시 관심 분야 cascade | 성공 |
| 검증 데이터 정리 | 부모 0건, 관심 분야 0건 확인 |
| Backend 회귀 테스트 | 11개 통과 |
| 문서 diff 형식 검사 | 성공 |

기준선 검증에는 현재 구현된 기존 계약의 `energyLevel`을 사용했다. 신규 `executionStyle` 계약은 Phase 1 이후 스키마와 코드를 순서대로 변경하며, Phase 0에서는 기존 기능 코드를 수정하지 않았다.
