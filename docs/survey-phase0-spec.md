# 선택지 폼 Phase 0 사양

> 문서 상태: 대체됨. 현재 공식 선택지 제출과 성향 분석 사양은 `SDD/v2/personality-sdd.md`를 사용하며 `/api/surveys` 런타임은 제거되었다.

- 문서 상태: 확정
- 사양 버전: 1.0.0
- 대상 기능: 초기 행동 선택지 폼 제출
- 구현 범위: Flutter 입력부터 Oracle 저장 결과 응답까지의 계약

## 1. 목적

사용자의 성격 전체를 판정하지 않고, 평소 행동과 현재 가능한 행동 수준을 5개 질문으로 수집한다. 수집된 값은 첫 미션 개인화에 사용할 초기 행동 프로필이다.

이번 기능은 사용자가 모든 선택을 완료한 뒤 설문 한 건을 REST API로 제출하고, Spring Boot가 검증하여 Oracle에 원자적으로 저장한 다음 저장 식별자를 Flutter에 반환하는 것까지 포함한다.

## 2. 범위

### 포함

- 소개 화면과 5개 질문
- 단일 선택 4문항
- 관심 활동 1~3개 다중 선택
- Client와 Server 양쪽의 입력 검증
- REST API를 통한 제출
- Oracle 설문 및 관심 활동 저장
- 저장 성공, 검증 실패, 서버 실패 응답
- Flutter의 제출 중, 성공, 실패 및 재시도 상태

### 제외

- 회원가입, 로그인 및 사용자 계정 연결
- MBTI와 같은 성격 유형 판정
- 미션 생성 및 선택
- 3D 공간 및 레벨 변경
- 설문 조회, 수정 및 삭제
- 장기간 행동 데이터를 이용한 프로필 갱신

## 3. 확정 결정

1. 첫 버전의 설문은 익명으로 저장한다.
2. Oracle이 생성한 `surveyId`를 저장 결과로 반환한다.
3. 이후 미션 기능은 `surveyId`를 초기 프로필 식별자로 사용한다.
4. 관심 활동의 `RANDOM` 항목은 분석 가능한 활동 영역이 아니므로 제외한다.
5. 설문 저장 직후에는 완료 상태만 표시하고 미션은 아직 생성하지 않는다.
6. API의 선택 코드는 대문자 영문 상수로 통일한다.

## 4. 질문과 데이터 사전

### Q1. 활동성

- 화면 문구: `쉬는 날의 나는?`
- 필드: `activityLevel`
- 선택 수: 정확히 1개

| 화면 선택지 | 전송 코드 |
|---|---|
| 집에서 보내는 편 | `INDOOR` |
| 필요하면 나가는 편 | `MIXED` |
| 밖에서 보내는 편 | `OUTDOOR` |

### Q2. 사람과의 활동 선호

- 화면 문구: `시간이 남는다면?`
- 필드: `socialActivity`
- 선택 수: 정확히 1개

| 화면 선택지 | 전송 코드 |
|---|---|
| 혼자 시간을 보낸다 | `LOW` |
| 아는 사람에게 연락한다 | `MEDIUM` |
| 사람을 만난다 | `HIGH` |

### Q3. 새로움 허용 수준

- 화면 문구: `새로운 일을 해본다면?`
- 필드: `noveltyTolerance`
- 선택 수: 정확히 1개

| 화면 선택지 | 전송 코드 |
|---|---|
| 익숙한 것에 작은 변화 | `LOW` |
| 안 해본 것 하나쯤 | `MEDIUM` |
| 완전히 새로운 것도 좋다 | `HIGH` |

### Q4. 관심 활동

- 화면 문구: `그나마 끌리는 걸 골라주세요.`
- 보조 문구: `1개 이상, 최대 3개`
- 필드: `interests`
- 선택 수: 1~3개

| 화면 선택지 | 전송 코드 |
|---|---|
| 움직이기 | `MOVEMENT` |
| 만들기 | `CREATIVE` |
| 먹기 | `FOOD` |
| 배우기 | `LEARNING` |
| 사람 | `SOCIAL` |
| 바깥 | `OUTDOOR` |
| 정리 | `ORGANIZING` |
| 문화 | `CULTURE` |

### Q5. 오늘의 에너지

- 화면 문구: `오늘은 어느 정도 움직일 수 있을까요?`
- 필드: `energyLevel`
- 선택 수: 정확히 1개

| 화면 선택지 | 전송 코드 |
|---|---|
| 5분 정도 | `LOW` |
| 10~30분 | `MEDIUM` |
| 조금 귀찮아도 괜찮다 | `HIGH` |

## 5. 사용자 흐름

```text
소개
→ Q1 활동성
→ Q2 사람과의 활동 선호
→ Q3 새로움 허용 수준
→ Q4 관심 활동
→ Q5 오늘의 에너지
→ 제출 중
→ 저장 완료 또는 오류 및 재시도
```

사용자는 이전 질문으로 이동하여 선택을 변경할 수 있다. 다음 단계 조건을 충족하지 못하면 다음 또는 제출 동작을 실행할 수 없다. 제출 중에는 제출 버튼을 비활성화한다.

## 6. 시스템 흐름

```text
Flutter SurveyScreen
→ POST /api/surveys
→ SurveyController
→ SurveyService 검증 및 트랜잭션
→ SurveyRepository
→ Oracle Database
→ HTTP Response
→ Flutter 성공 또는 오류 상태
```

## 7. REST API 계약

### 7.1 설문 제출

- Method: `POST`
- Path: `/api/surveys`
- Content-Type: `application/json`

요청 예시:

```json
{
  "activityLevel": "INDOOR",
  "socialActivity": "LOW",
  "noveltyTolerance": "MEDIUM",
  "interests": [
    "CREATIVE",
    "FOOD",
    "CULTURE"
  ],
  "energyLevel": "LOW"
}
```

### 7.2 저장 성공

- Status: `201 Created`

```json
{
  "surveyId": 1,
  "status": "SAVED"
}
```

### 7.3 입력 검증 실패

- Status: `400 Bad Request`

```json
{
  "code": "INVALID_SURVEY",
  "message": "관심 활동은 1개 이상 3개 이하로 선택해야 합니다."
}
```

검증 실패 조건:

- 필수 단일 선택값 누락
- 허용 목록에 없는 코드
- `interests`가 `null`
- 관심 활동 0개 또는 4개 이상
- 관심 활동 코드 중복

### 7.4 저장 실패

- Status: `500 Internal Server Error`

```json
{
  "code": "SURVEY_SAVE_FAILED",
  "message": "선택을 저장하지 못했습니다. 잠시 후 다시 시도해 주세요."
}
```

Database 오류 상세, SQL, 접속정보 및 Stack trace는 응답에 포함하지 않는다.

## 8. Oracle 논리 모델

Phase 1에서 실제 DDL을 작성한다. Phase 0에서는 다음 논리 구조를 계약으로 고정한다.

### SURVEY_RESPONSE

| Column | Type | Rule |
|---|---|---|
| `SURVEY_ID` | `NUMBER(19)` | Primary Key, Sequence 발급 |
| `ACTIVITY_LEVEL` | `VARCHAR2(10)` | Not Null, 허용 코드 제한 |
| `SOCIAL_ACTIVITY` | `VARCHAR2(10)` | Not Null, 허용 코드 제한 |
| `NOVELTY_TOLERANCE` | `VARCHAR2(10)` | Not Null, 허용 코드 제한 |
| `ENERGY_LEVEL` | `VARCHAR2(10)` | Not Null, 허용 코드 제한 |
| `CREATED_AT` | `TIMESTAMP` | Not Null, 기본값 `CURRENT_TIMESTAMP` |

### SURVEY_INTEREST

| Column | Type | Rule |
|---|---|---|
| `SURVEY_ID` | `NUMBER(19)` | Foreign Key → `SURVEY_RESPONSE.SURVEY_ID` |
| `INTEREST_CODE` | `VARCHAR2(20)` | 허용 코드 제한 |

Primary Key는 `(SURVEY_ID, INTEREST_CODE)` 복합키를 사용한다.

### Sequence

- 이름: `SURVEY_RESPONSE_SEQ`
- 용도: `SURVEY_RESPONSE.SURVEY_ID` 발급

### 트랜잭션 규칙

1. Sequence에서 `surveyId`를 발급한다.
2. `SURVEY_RESPONSE` 한 행을 저장한다.
3. `SURVEY_INTEREST`에 1~3개 행을 저장한다.
4. 하나라도 실패하면 전체 저장을 Rollback한다.

## 9. 보안 및 설정 계약

- Database URL, 사용자명 및 비밀번호는 환경 변수로 주입한다.
- 실제 비밀번호를 `application.yml`, Dart, Java, JavaScript 또는 문서에 기록하지 않는다.
- API Base URL은 Flutter의 `--dart-define=API_BASE_URL=...`로 주입한다.
- 오류 응답과 일반 로그에 Secret을 포함하지 않는다.
- CORS는 개발 단계에서 로컬 Flutter Web Origin에만 허용한다.

환경 변수 이름:

```text
DB_URL
DB_USERNAME
DB_PASSWORD
API_BASE_URL
```

## 10. 책임 경계

### Flutter

- 질문과 선택지 표시
- 현재 입력 상태 관리
- 기본 선택 개수 검증
- 요청 JSON 직렬화
- 제출 중 중복 클릭 방지
- 성공, 실패 및 재시도 상태 표시

### SurveyController

- HTTP 요청 수신
- Service 호출
- 계약에 맞는 HTTP 상태와 Body 반환
- 비즈니스 규칙을 직접 처리하지 않음

### SurveyService

- Server 입력 검증
- 중복 관심 코드 검증
- Transaction 경계 관리
- Repository 호출

### SurveyRepository

- Parameter binding을 사용한 SQL 실행
- Sequence 조회
- 설문 및 관심 활동 저장
- 비즈니스 규칙을 판단하지 않음

## 11. 비기능 요구사항

- 추가 Library는 HTTP 통신, JDBC, Oracle 연결 및 테스트에 실제 필요한 경우로 제한한다.
- 저장 요청 한 건은 하나의 Transaction으로 처리한다.
- 사용자의 선택값은 오류 발생 시 Flutter 화면에 유지한다.
- 입력값과 DB 오류를 로그로 과도하게 노출하지 않는다.
- Three.js와 `world` 기능은 이번 구현에서 변경하지 않는다.

## 12. 인수 조건

### AC-01 정상 저장

Given 사용자가 모든 단일 문항과 관심 활동 1~3개를 선택했고
When 설문을 제출하면
Then API는 `201 Created`와 양수 `surveyId`, `SAVED` 상태를 반환한다.

### AC-02 Oracle 데이터 일치

Given 정상 제출이 성공했을 때
Then `SURVEY_RESPONSE`에는 한 행이 저장되고 `SURVEY_INTEREST`에는 선택 개수와 같은 행이 저장된다.

### AC-03 관심 활동 최소 개수

Given 관심 활동을 선택하지 않았을 때
When 제출을 시도하면
Then Flutter가 제출을 막고, Server에 같은 요청이 들어와도 `400 Bad Request`를 반환한다.

### AC-04 관심 활동 최대 개수

Given 관심 활동을 4개 이상 선택하려 할 때
Then Flutter는 네 번째 선택을 허용하지 않고, Server에 4개 이상이 전달되어도 `400 Bad Request`를 반환한다.

### AC-05 원자적 저장

Given 관심 활동 저장 중 Database 오류가 발생했을 때
Then 같은 요청의 `SURVEY_RESPONSE`와 `SURVEY_INTEREST` 데이터는 모두 저장되지 않는다.

### AC-06 실패 후 재시도

Given 제출이 Network 또는 Server 오류로 실패했을 때
Then Flutter는 사용자의 기존 선택을 유지하고 오류 메시지와 재시도 동작을 제공한다.

### AC-07 Secret 비노출

Then 실제 DB 비밀번호는 Git 추적 파일과 HTTP 응답에 존재하지 않는다.

## 13. Phase 1 진입 조건

- 이 문서의 질문, 코드 및 API 필드명이 구현의 단일 기준으로 사용된다.
- Oracle Listener, SID 및 DB 계정 접속 가능 여부를 확인한다.
- DB 계정의 `CREATE TABLE`, `CREATE SEQUENCE`, `CREATE SESSION` 권한과 Tablespace quota를 확인한다.
- Phase 1에서는 이 문서의 논리 모델을 실제 Oracle DDL로 변환한다.
