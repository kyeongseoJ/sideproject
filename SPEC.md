# Novelty 통합 사양

최종 갱신일: 2026-08-26

## 1. 문서 목적과 우선순위

이 문서는 Novelty 프로젝트에서 현재 유효한 제품 정책과 공통 기술 규칙의 기준이다. 기능별 상세 요청·응답, 계산식, 예외 및 인수 조건은 `docs/`의 SDD Phase 문서에 작성한다.

충돌이 있을 때는 다음 우선순위를 적용한다.

1. 사용자의 최신 명시적 지시
2. 이 문서의 현재 활성 사양
3. 기능별 최신 SDD Phase 문서
4. `ARCHITECTURE.md`
5. 기존 구현

기존 구현이나 과거 완료 문서가 현재 사양과 다르면 이를 그대로 정답으로 간주하지 않는다. 최신 지시를 반영하면서 `SPEC.md`, 관련 SDD와 `PROJECT_STATUS.md`를 함께 갱신한다.

## 2. 프로젝트 목적과 범위

Novelty는 사용자가 평소 잘 하지 않던 작은 행동을 제안하여 권태와 무기력에서 벗어나도록 돕는 서비스다. 의료 진단이나 치료를 제공하는 서비스로 표현하지 않는다.

현재 핵심 범위는 다음 네 가지다.

1. 선택지 폼 제공
2. 사용자 성향 분석
3. 성향과 거리가 있는 랜덤 미션 생성
4. 미션 수행으로 성장하는 3D 공간과 레벨 시스템

## 3. 기술 구조

### Frontend

- Flutter / Dart(Web, Android): 선택지 폼, 성향 분석 UI, 미션 UI, 프로필, 설정, 3D World 화면
- Web과 Android는 동일한 `front/app/lib` UI를 사용하며 플랫폼별 화면을 중복 구현하지 않는다.
- Three.js / JavaScript / Vite: GLB Load, Camera, Lighting, Object placement, Level model switching, Simple animation
- Flutter 위치: `front/app`
- Three.js 위치: `front/world3d`

### Backend

- Java 21 / Spring Boot / Maven
- 기능 경계: User, Personality, Mission, Mission Completion, World / Progression
- 위치: `back`

### Database

- Supabase PostgreSQL
- 논리 테이블: `USER`, `PERSONALITY`, `MISSION`, `USER_MISSION`, `WORLD_OBJECT`, `WORLD_OBJECT_LEVEL`, `USER_WORLD_OBJECT`
- 운영 기준 DDL과 기준 데이터는 `supabase/migrations`에서 관리한다.

### 3D Asset 흐름

```text
Blender 또는 Asset 제작
→ GLB
→ Flutter bundle 또는 CDN
→ Three.js World Renderer
```

- 현재 배포 구성은 GLB를 `front/app/assets/world3d/models`에 번들한다.
- Three.js는 Flutter가 전달한 성향 룸만 로드하며 초기 placeholder 룸을 먼저 로드하지 않는다.
- 동일 asset URI의 GLB 요청은 Loader 캐시를 사용하고, Bridge 재시도 요청은 동일한 초기화 작업을 중복 실행하지 않는다.

## 4. 전체 사용자 흐름

신규 사용자의 기본 흐름은 다음과 같다.

```text
접속
→ 회원가입 또는 로그인 및 사용자 키 저장
→ 회원가입 시 초기 랜덤 닉네임 자동 배정
→ 최초 1회 성향 분석 선택폼
→ 성향 결과와 프로필 표시
→ 종합 결과 기반 미션 후보 최대 5개 생성
→ 미션 선택 및 수행
→ 완료
→ 3D 공간과 레벨 성장
```

- 성향 분석은 기본적으로 사용자당 최초 1회만 진행한다.
- 재접속 시 브라우저 또는 앱 캐시에 저장된 사용자 키로 사용자를 복원하고, 캐시가 없으면 아이디·비밀번호 로그인을 제공한다.
- 사용자가 원하면 `성향 분석 다시하기` 버튼으로 다시 진행할 수 있다.
- 현재 Flutter 사용자 흐름에서는 할애 가능 시간과 수행 미션 수를 묻지 않는다. Backend는 하루 1개 미션 정책을 적용한다.
- 닉네임은 회원가입 시 초기 랜덤값을 자동 배정하고 사용자가 추후 변경할 수 있다.
- 최초 미분석 사용자는 회원가입 직후 닉네임 입력을 반복하지 않고 선택폼을 시작한다.
- 신규 사용자 시작 화면은 노벨티 효과와 매일 작은 새로운 행동을 돕는 서비스 목적을 설명한다.
- Web과 Android는 `assets/ui`의 White 로고를 사용하는 공통 애니메이션 스플래시를 먼저 표시한다.
- 캐시 사용자가 없는 경우 스플래시 다음 화면은 로그인을 기본으로 열며, 신규 사용자는 화면의 회원가입 선택지로 전환할 수 있다.
- 닉네임 변경 API와 정책은 유지하지만, 현재 성향 프로필 화면에는 닉네임과 편집 버튼을 표시하지 않는다.

## 5. 사용자 식별과 캐시

- Database 내부 식별자는 `userId`로 관리한다.
- 사용자가 입력하는 계정 식별자는 `loginId`이며 소문자 정규화 후 중복을 허용하지 않는다.
- Client 인증·복원에는 추측하기 어려운 별도 `userKey`를 사용한다.
- `userKey` 원문은 생성 응답에서 Client에 전달하고 Browser cache 또는 App cache에 저장한다.
- Server는 `userKey` 원문 대신 안전한 해시를 저장하는 것을 원칙으로 한다.
- 비밀번호 원문은 저장하거나 응답하지 않으며 PBKDF2-HMAC-SHA256과 사용자별 무작위 Salt로 해시한다.
- 이후 사용자 범위 REST 요청은 `X-User-Key` Header를 사용한다.
- 닉네임은 표시 이름이며 인증 수단으로 사용하지 않는다.
- 같은 브라우저 또는 앱의 기존 사용자는 캐시에 저장된 `userKey`로 자동 복원하고 완료된 온보딩을 반복하지 않는다.
- 캐시가 사라지거나 다른 기기를 사용하면 아이디·비밀번호로 로그인한다. 닉네임은 인증 수단으로 사용하지 않는다.
- `loginId`는 영문 소문자·숫자·밑줄 4~20자이며 Backend와 DB에서 중복을 차단한다.
- 비밀번호는 영문과 숫자를 포함한 8~64자다.
- Secret, API Key, Database 비밀번호는 Client cache에 저장하지 않는다.

## 6. 닉네임 정책

초기 닉네임 형식은 다음과 같다.

```text
노벨티 + 숫자 2자리 + 영문 대문자 2자리
예: 노벨티07AB
```

정책:

- 초기 닉네임은 중복 없이 생성한다.
- 사용자가 변경할 수 있다.
- 최소 1글자, 최대 12글자다.
- 한글, 영문, 숫자만 허용한다.
- 공백과 특수문자를 허용하지 않는다.
- 중복 닉네임을 허용하지 않는다.
- 금칙어와 비속어를 허용하지 않는다.
- 금칙어의 파일 기준은 `front/app/assets/config/nickname_banned_words.txt` 하나로 관리하고 Backend Build에서도 이 Resource를 사용한다.
- Supabase의 `NICKNAME_BANNED_WORD` 기준 데이터는 금칙어 파일과 함께 갱신한다.
- Frontend validation, Backend validation, DB constraint 또는 trigger의 3단계로 방어한다.
- Client 검증은 사용자 경험을 위한 것이며 최종 신뢰 경계는 Backend와 Database다.

## 7. 선택지 폼과 성향 분석

### 질문 영역

최초 성향 분석은 성격 전체를 진단하지 않고 사용자의 행동 선호를 수집한다. 상세 계약은 활성 문서인 `docs/personality-sdd-v2.md`를 따른다.

선택폼 UI는 `Novelty` 워드마크, 현재 문항/전체 문항 표시, 흰색 질문 카드와 선택지를 사용한다. 첫 문항에는 이전 버튼을 렌더링하지 않고 두 번째 문항부터 이전 버튼을 표시한다. 답변하지 않은 문항의 다음 버튼은 비활성화한다.

- 실내·실외 선호
- 혼자·함께하기 선호 또는 사회적 활동 수준
- 신체 활동 강도 선호
- 익숙함·새로움 선호
- 관심 카테고리 1~3개
- 활동 실행 방식에 관한 질문

성향 폼은 총 여섯 문항이다. 기존 `사용 가능한 시간` 및 `energyLevel` 질문은 성향 폼에서 제거한다. 실행 방식과 신체 활동 강도는 앞 질문과 중복되지 않는 독립 속성으로 분석한다.

- API에서 `indoorOutdoor`와 `physicalActivityLevel`을 분리한다.
- 기존 `activityLevel` API 이름은 V2에서 사용하지 않는다.
- 주 성향 유형은 실내·실외 3단계와 사회성 3단계의 조합으로 결정한다.
- 신체 활동, 새로움, 실행 방식과 관심 분야는 주 성향을 보완하는 독립 Profile 속성이다.

### 성향 프로필

- 분석 결과는 사용자 정보와 연결하여 Supabase PostgreSQL에 저장한다.
- 프로필은 현재 값과 분석 버전을 관리한다.
- 최초 설문 답변뿐 아니라 추후 완료한 미션 이력을 근거로 갱신할 수 있다.
- 성향 결과는 사용자에게 이름과 설명이 있는 프로필로 표시한다.
- 현재 분류 체계는 `PERSONALITY_V2`의 9개 성향 유형이며 코드, 한글 이름과 Mapping은 Personality SDD를 기준으로 한다.
- 미션 거리 계산에 쓰는 축과 사용자에게 보여주는 성향 유형 코드를 구분하여 관리한다.

### 할애 가능 시간

- 현재 사용자 플로우에서는 성향 결과 이후에도 별도의 시간 선택지를 노출하지 않는다.
- 기존 `availableTime` 및 `dailyMissionLimit` 설정 API는 제거했다. 미션의 `estimatedMinutes`는 Catalog 메타데이터로만 사용한다.
- 추천 화면에서는 사용자가 시간 대신 서로 다른 경험의 미션 후보를 최대 5개까지 비교하고 하나를 선택한다.

## 8. 미션 사양

### 미션 속성

각 미션은 최소한 다음 속성을 가진다.

| 속성 | 의미 |
|---|---|
| `id` | 미션 식별자 |
| `title` | 제목 |
| `description` | 수행 설명 |
| `category` | 활동 및 World 성장 카테고리 |
| `difficulty` | 난이도 |
| `estimatedMinutes` | 예상 시간(분) |
| `indoorOutdoor` | 실내·실외 성향 축 |
| `socialLevel` | 사회적 활동 성향 축 |
| `activityLevel` | 신체 활동 성향 축 |
| `noveltyLevel` | 새로움 성향 축 |
| `enabled` | 추천 가능 여부 |

- 사용자와 미션은 동일한 성향 축 척도를 사용한다.
- 추천은 사용자 벡터와 미션 벡터 사이의 거리를 계산하여 평소 덜 했을 가능성이 높은 행동을 우선한다.
- 거리만 극대화하지 않고 난이도, 시간, 관심사, 안전성과 최근 이력을 함께 고려한다.

### 추천 원천과 LLM

- 최초 성향 분석 후에는 미리 검수해 둔 기본 미션 중에서 추천한다.
- 기본 미션 Catalog는 5분·10분·15분·30분·45분·60분·90분·120분·180분 구간을 포함하는 BASE seed 기준으로 관리한다. 기존 행은 과거 이력 참조를 위해 삭제하지 않고 `enabled=N`으로 보존하며, 신규 seed는 `CONTENT_FINGERPRINT`와 `TITLE_NORMALIZED` 기준으로 멱등 삽입한다.
- 검증을 통과한 공유 LLM 미션은 생성자뿐 아니라 모든 사용자의 추천 후보가 될 수 있다.
- LLM 신규 생성은 사용자별 완료 횟수 5회 단위를 기준으로 시도한다.
- 생성된 미션은 해당 사용자만의 일회성 데이터가 아니라 검증 후 유사 사용자도 사용할 수 있는 공용 Catalog에 저장한다.
- 기존 미션과 제목·설명이 중복되거나 의미가 지나치게 유사한 미션은 저장하지 않는다.
- LLM 출력도 Backend validation, 중복·유사도 검사와 안전 정책을 통과해야 한다.
- LLM 장애가 기본 미션 추천을 막아서는 안 된다.

OpenAI 설정:

- API Key는 `OPENAI_API_KEY` 환경 변수로만 주입한다.
- 모델은 `OPENAI_MODEL` 환경 변수로 변경 가능하게 한다.
- API Key 원문은 코드, 설정 기본값, 로그, 문서, Git 이력에 기록하지 않는다.
- 이미 노출된 Key는 폐기·재발급한다.
- 로컬 Secret은 Git 제외 `.env`에 저장하고 Spring Boot가 자동으로 읽는다.
- 추적 가능한 `.env.example`에는 변수 이름과 placeholder만 유지한다.
- Flutter 로컬 API 주소는 플랫폼 기본값을 사용하고, 배포 주소만 `API_BASE_URL` dart-define으로 주입한다.
- Backend는 `/api/**`에 대해 `CORS_ALLOWED_ORIGIN_PATTERNS`의 쉼표 구분 Origin Pattern만 허용한다. 운영에서는 Flutter Web 배포 도메인을 명시하고 전체 허용 Origin을 사용하지 않는다.

### 이력과 재추천 제한

- 하루 미션과 추천 이력의 날짜는 사용자의 설정 Timezone으로 변환한 Local Date를 기준으로 판정한다.
- MVP에는 사용자별 Timezone 설정 UI·DB 필드가 없으므로 현재 설정 Timezone은 모든 사용자에게 `Asia/Seoul`로 고정한다.
- 서버·JVM·Database의 기본 Timezone이나 UTC 날짜를 서비스 날짜로 직접 사용하지 않는다.
- 동일 사용자·동일 Local Date에서는 최초 생성한 추천 목록을 재사용하고, 설정 Timezone에서 Local Date가 바뀌면 새로운 추천 주기를 시작한다.
- 완료·노출 제한을 포함한 기간 계산도 같은 사용자 기준 Local Date를 사용한다.
- D일 완료한 미션은 경과일 0~3일인 D, D+1, D+2, D+3에 추천하지 않고 D+4부터 점수 후보로 복귀한다.
- D일 노출한 미션은 D, D+1, D+2에 재노출하지 않고 D+3부터 다시 추천할 수 있다.
- 제한 때문에 후보가 부족해도 완료·노출 제한을 완화하지 않는다.
- 동일 완료 Mission은 후보 복귀 후에도 4~7일 0.35, 8~14일 0.20, 15~30일 0.08의 장기 반복 감점을 받고 30일 초과 시 일반 후보가 된다. 이 감점은 동일 ID를 제외한 최근 경험 유사도·패턴 감점과 별도로 한 번만 계산한다.
- 최근 7일·최신 완료 10개의 `category`, `actionType`, 환경, 태그, 사회·신체·창의 특성과 유사할수록 감점하며 최근 이력일수록 더 크게 반영한다.
- 최근 완료 경험과 유사도 0.82 이상인 문구 변형 미션은 제외한다.

### 사용자 미션 상태

상태 로그는 다음 값만 사용한다.

```text
GENERATED
SHOWN
SELECTED
CANCELLED
COMPLETED
```

- UI에서는 `SELECTED`를 `수행중`, `COMPLETED`를 `완료`로 표시한다.
- 상태 전이는 이력으로 보존하며 현재 집계 상태와 로그를 구분한다.
- 같은 사용자가 같은 미션 완료 요청을 중복 전송해도 완료 횟수와 보상이 중복 반영되지 않아야 한다.
- 사용자는 서로 다른 경험으로 구성된 하루 최대 5개의 추천 후보 중 수행할 미션을 선택한다. 필터를 통과한 후보가 부족하면 가능한 개수만 반환한다.
- 현재 Flutter UI의 하루 수행 미션 수는 1개로 고정한다. 사용자는 매일 미션을 시작할 때 추천 후보 중 하나를 선택한다.
- 수행 중인 미션은 목록 상단에 표시한다.
- Flutter Web UI는 수행 중인 미션에 `완료`와 `취소`만 제공하고 직접 `변경` 버튼은 표시하지 않는다.
- 다른 미션을 수행하려면 현재 미션을 취소한 뒤 같은 날의 기존 추천 캐러셀에서 다시 선택한다.
- 취소한 후보는 같은 날 다시 선택할 수 있고 완료한 미션은 취소하거나 변경할 수 없다.
- 변경은 기존 미션 취소와 새 미션 선택을 하나의 Database Transaction으로 처리한다.
- 상태 변경 API는 Catalog `missionId`가 아닌 사용자에게 노출된 `userMissionId`를 기준으로 호출하며, 응답은 변경된 미션·오늘 상태·멱등 여부를 함께 반환한다.
- Mission 상태 변경의 유일한 공식 Service 경로는 `UserMissionService`이며, 완료는 `UserMissionService.complete(userMissionId)`에서만 처리한다.
- 완료 재요청은 성공으로 응답하되 새 상태 로그나 완료 횟수를 만들지 않는다.
- 완료 상태, 연결 로그, 카테고리 통계와 성향 완료 횟수는 하나의 Transaction으로 저장한다.
- 미션을 완료할 때마다 해당 미션의 네 축 벡터와 현재 성향을 혼합해 네 축과 성향 유형을 갱신하고 마지막 반영 완료 횟수를 기록한다.
- 성향 갱신 이후 Profile API의 축 enum과 유형은 최초 설문 원본이 아니라 현재 저장된 성향 점수에서 파생한다.
- LLM 생성은 완료 Transaction 커밋 이후 시도하며 설정 누락, API·Database 오류, 중복·유사 결과가 완료 성공을 되돌리지 않는다.
- 5회 완료 마일스톤에서 생성·검증된 신규 LLM 미션은 공용 Catalog에 저장되고, 같은 서비스 날짜 후보는 유지하므로 다음 서비스 날짜의 추천부터 최신 성향과 함께 후보에 반영된다.
- 동일 사용자·동일 완료 마일스톤은 한 번만 Claim하며 완료 재요청으로 통계·성향·LLM 생성을 중복 적용하지 않는다.
- 완료 응답과 `GET /api/missions/summary`는 전체 완료 수, 마지막 성향 반영 횟수, 성향 코드와 카테고리별 완료 통계를 제공한다.
- 같은 서비스 날짜에는 최초 생성한 후보를 저장하고 재접속·새로고침 시 동일 후보를 복원한다.
- PostgreSQL은 `SHOWN`·`CANCELLED` 후보의 슬롯 없음은 허용하고 `SELECTED`·`COMPLETED`의 동일 사용자·날짜·슬롯 중복만 partial Unique Index로 차단한다.

### 미션 추천 점수

- 네 개 성향 축의 정규화 유클리드 거리는 0~1 범위이며 동일 축 가중치를 사용한다.
- 양의 점수는 `성향 거리 35% + 새로움 10% + 전체 카테고리 탐색 5% + 최근 다양성 15% + 미경험 탐색 15% + 난이도·실행 방식 적합 20%`로 계산한다. 난이도 적합도와 실행 방식 적합도를 각각 절반씩 반영한다.
- 최근 경험 유사도 25%, 반복 행동 패턴 15%, 반복 skipped/rejected 패턴 10%와 동일 Mission 장기 반복 고정 감점을 적용하고 최종값을 0~1로 제한한다.
- 카테고리 탐색 점수는 `1 / (1 + 해당 카테고리 완료 횟수)`로 계산한다.
- 점수 상위 20개 후보군에서 첫 후보를 가중 추출하고 이후 후보에는 선택지 사이 경험 유사도 35% 패널티를 적용한다.
- 최종 후보끼리 유사도 0.75 미만을 우선하여 category·actionType·tags가 겹치지 않는 최대 5개를 구성한다.
- Mission Catalog는 기존 필드를 재사용하고 `actionType`, `creativityLevel`, `unpredictability`, `comfortZoneDistance`, `costLevel`, `tags`를 추가한다. `durationLevel`은 `estimatedMinutes`에서 파생한다. BASE Seed 태그는 식별자와 한글 태그를 허용하고 LLM 태그는 대문자 영문 규칙을 유지한다.
- PostgreSQL 운영 환경에서는 pgvector를 추가하지 않으며 현재는 메타데이터+문자 bigram을 사용하고 `MissionSemanticSimilarity` 확장 지점만 유지한다.
- 상세 공식, 상태 전이, REST와 PostgreSQL 계약은 `docs/mission-sdd-v1.md`를 기준으로 한다.

## 9. 3D World와 레벨

Current mission recommendation rules:

- Selected interest categories are excluded from the recommendation pool so missions intentionally lead users outside their stated interests.
- The shared catalog targets duration bands from 5 minutes through 180 minutes. Candidate selection prefers different duration bands when enough eligible missions exist.
- A validated LLM mission generated at each five-completion milestone is stored as a shared catalog mission and can be recommended to every user.

- 미션 완료는 미션 `category`와 연결된 World object의 경험치 또는 성장값에 반영한다.
- 사용자별 Object 상태는 `USER_WORLD_OBJECT` 영역에서 관리한다.
- Object의 레벨별 요구치는 `WORLD_OBJECT_LEVEL` 영역에서 관리한다.
- GLB 경로와 Position·Rotation·Scale은 Frontend Asset Manifest에서만 관리하고 DB에는 저장하지 않는다.
- Mission Category와 World Object는 MVP에서 1:1이며 난이도 1/2/3은 각각 10/20/30 EXP를 지급한다.
- 누적 EXP 0/50/120/220/350을 기준으로 Lv1~Lv5가 된다.
- Three.js는 렌더링을 담당하고 Flutter는 사용자 화면과 앱 상태를 담당한다.
- GLB 로드 실패 시 앱 전체가 중단되지 않도록 오류 또는 대체 UI를 제공한다.
- 레벨 변경은 Backend의 저장 결과를 기준으로 처리하며 Client만의 값으로 확정하지 않는다.
- 상세 계약은 `docs/world-sdd-v1.md`를 기준으로 한다.
- 성향 프로필 안에 회전·확대 가능한 World 미리보기를 표시하고 장면 또는 사물을 탭하면 전체 화면으로 이동한다.
- 초기 World에는 기본 룸만 표시하고 오브젝트는 표시하지 않는다. 첫 미션 완료로 EXP가 지급된 Category의 Lv1 Object부터 표시하며, 이후 완료 EXP가 있는 Category Object를 함께 표시한다.
- `/api/world`의 `objects`가 비어 있으면 Flutter는 빈 방을 정상 상태로 표시하지 않고 `World 오브젝트 정보를 불러오지 못했습니다.`를 표시한다.
- 성향 Category 필터 결과가 비어 있으면 전체 Snapshot Object를 fallback으로 사용해 빈 방을 방지한다.
- `initializeWorld` Bridge payload는 `objectCount`와 실제 `objects.length`가 일치해야 하며, 1개 이상인 경우에만 전송한다.
- GLB 로드 실패는 실패한 상대 asset 경로를 포함한 `rendererError`로 Flutter에 전달한다.
- 전체 World 공간명은 현재 성향 유형에 맞는 이름을 사용한다.
- 사용자 화면의 World 제목과 선택 UI에는 성향명만 표시하고 연결된 룸 에셋 파일명·룸 종류명은 표시하지 않는다.
- 기존 Object 선택 툴팁은 외부 placeholder Object 제거 이후 `노벨티 Lv.N` 배지로 대체한다. 배지 툴팁은 Lv.1의 장식 1개, Lv.2~4의 장식 약 25%·50%·75%, Lv.5의 전체 장식 표시 상태를 안내한다.
- 성향 유형별 기본 방 에셋 코드는 `classroom_2`, `art_gallery_4`, `cafe_5`, `music_store_20`, `flower_shop_26`, `Theatre_32`, `Gym_25`, `bookshop_7`, `stadium_40`으로 사전 등록하고, 각 실제 GLB를 Flutter Web 번들에 포함한다. 파일명은 제공된 에셋의 대소문자와 `Art_Galery` 표기를 그대로 사용한다.
- 각 기본 방 GLB에서 이름에 `floor` 또는 `wall`이 포함된 Mesh는 항상 표시한다. 그 외 Mesh는 장식 요소로 보고 World의 최고 Object Level에 따라 Lv.1에서는 최소 1개, 이후 25%, 50%, 75%, 100%를 표시한다. 장식 순서는 GLB 노드 순서를 따르며, 방마다 장식 수가 달라도 마지막 단계에서 전체가 표시된다.
- 전체 World에서 Object를 Web 마우스·펜으로 가리키거나 Web·Android에서 탭하면 Object명, 연결된 성향 Category와 현재 성장 단계를 툴팁으로 표시한다.
- 성향 완료 홈의 순서는 Novelty 워드마크·심볼, 3D World, 오늘의 미션, 프로필의 성향 분석 결과·설명, 관심 분야, 행동 선호, 분석 메타 정보다.
- 오늘의 미션은 시간 선택 없이 최대 5개 후보를 가로 캐러셀로 표시하고, 선택 뒤에는 수행 중 미션 하나만 크게 표시한다.
- 현재 오늘의 미션 후보 UI는 Spotlight 시작 카드, 완료 수 배지, 카테고리 아이콘·메타데이터와 명확한 선택 CTA를 사용해 대표 행동을 우선 강조한다.
- 관심 분야와 행동 선호는 별도 영역으로 표시한다. 행동 선호의 네 축은 저장된 점수를 수치와 막대그래프로 표시한다.
- 미션 완료 직후에는 Backend 완료 응답의 저장 전·후 네 축 차이 중 실제 변화가 있는 값만 프로필의 `성향 변동`으로 표시한다. Client가 미션 속성으로 변화량을 추정하지 않는다.
- 3D World 조작 설명은 화면 가장자리의 NavigationRail 도움말 아이콘으로 제공하며, 선택 시 설명 패널을 열고 닫기 버튼으로 닫는다. World 꾸미기 기능은 제공하지 않는다.
- `WORLD_TEST=true`를 지정한 개발 실행에서는 실제 성향별 룸 GLB를 선택하고 모든 World Object 레벨을 한 단계씩 올리는 테스트 화면을 제공한다. 이 화면은 기본 운영 빌드의 진입 플로우에 포함하지 않는다.
- Web 플랫폼 뷰가 클릭을 가로채지 않도록 인라인 World 도움말은 renderer 바깥의 Flutter 영역에 배치한다.
- 미션 완료 성장 응답은 전체 World뿐 아니라 현재 표시 중인 인라인 World에도 즉시 전달해 Level 모델과 Level Up 애니메이션을 갱신한다.
- 전체 World는 보상 반영 직후 성장 룸을 카메라로 포커싱하고 보라색 파동·입자 효과를 재생한다. 완료 결과 카드는 카테고리·표시명·실제 지급 EXP를 보여주며 5초 후 사라지거나 사용자가 닫을 수 있다.

## 10. REST API 공통 규칙

- API 경로는 `/api/**`를 사용한다.
- Controller는 요청 검증과 HTTP 변환을 맡고 핵심 정책은 Service에서 처리한다.
- 사용자 범위 API는 `X-User-Key` Header로 사용자를 식별한다.
- 요청·응답 DTO를 명시하고 Flutter와 Backend의 필드 이름, enum과 nullable 규칙을 일치시킨다.
- Validation 오류, 중복, 찾을 수 없음, 상태 충돌과 Server 오류를 구분된 HTTP 상태와 오류 Body로 반환한다.
- API는 springdoc-openapi에 노출하고 Swagger UI의 `Try it out`으로 정상·오류 사례를 시험할 수 있어야 한다.
- 로컬 Swagger UI 주소는 `http://localhost:8080/swagger-ui.html`이다.
- 공식 API는 회원가입·로그인·사용자 복원·닉네임 변경, `POST /api/personality-analyses`, `/api/missions/today`, `/api/missions/today/recommendations`, `GET /api/user-missions/history`, `/api/user-missions/{userMissionId}/select|cancel|replace|complete`, `/api/missions/summary`, `GET /api/world`다.
- `userId`는 내부 사용자 식별자, `userKey`는 `X-User-Key` 인증·복원 값, `missionId`는 Catalog 식별자, `userMissionId`는 사용자 상태 변경 대상이다.

## 11. Database 규칙

- 운영 기준 파일은 `supabase/migrations`다.
- 테이블, Sequence, Index, Constraint, Trigger 및 필수 기준 데이터 변경은 코드 적용과 같은 작업에서 SQL에도 반영한다.
- 가능한 DDL과 기준 데이터는 재실행 가능한 형태로 작성한다.
- 실제 Supabase 적용 후 테이블, Sequence, Constraint와 기준 데이터 건수를 조회하여 검증하기 전에는 적용 완료로 기록하지 않는다.
- PostgreSQL 접속 실패나 SQL 실패를 숨기지 않고 `PROJECT_STATUS.md`에 남긴다.
- Database 접속정보와 Secret은 SQL 또는 추적되는 설정 파일에 직접 작성하지 않는다.

## 12. 디자인과 접근성

- 모든 화면은 `DESIGN.md`를 기준으로 한다.
- 기본 Font는 Google Fonts의 `Noto Sans KR`이다.
- Flutter는 공통 Theme, Three.js Web UI는 공통 CSS Token을 우선 사용한다.
- 주요 CTA, 상태, 오류와 성공 표현은 `DESIGN.md`의 Color 및 Component 규칙을 따른다.
- Flutter 공통 CTA 높이는 44px, 버튼·입력·Badge radius는 6px, 주요 카드 radius는 16px로 유지한다.
- 화면 깊이는 그림자가 아니라 흰색·`#f2f2f3`·`#f7f7f8` Surface와 `#ebebeb` hairline으로 구분한다.
- 오류는 Point Red와 설명 문구, 완료·긍정 상태는 Point Green과 Icon을 함께 사용한다.
- 색상만으로 선택·오류·완료 상태를 전달하지 않는다.

## 13. 보안과 안전

- Secret을 코드, 문서, 테스트 fixture 또는 Git 추적 파일에 직접 작성하지 않는다.
- 입력값은 Frontend만 신뢰하지 않고 Backend에서 다시 검증한다.
- 사용자 키, 닉네임, 미션 상태 변경은 요청 사용자의 소유권을 확인한다.
- 로그에는 API Key, Database 비밀번호, 사용자 키 원문 등 민감정보를 남기지 않는다.
- 미션은 안전한 일상 활동 범위로 제한하고 의료적 효과를 확정적으로 약속하지 않는다.
- 위험 행위, 불법 행위, 혐오·성적·폭력적 내용과 개인을 특정하는 민감한 지시는 미션으로 생성하지 않는다.

## 14. 구현과 검증 규칙

새 기능을 구현하기 전 다음 순서를 지킨다.

1. `AGENTS.md` 확인
2. `SPEC.md`의 현재 정책 확인
3. `PROJECT_STATUS.md`의 실제 완료·미완료 상태 확인
4. 관련 SDD Phase 문서 확인 또는 Phase 0 신규 작성
5. `ARCHITECTURE.md`와 실제 프로젝트 구조 확인
6. 작은 단위로 구현하고 각 단계의 인수 조건 검증
7. 관련 Build·자동 테스트·필요한 E2E 수행
8. `PROJECT_STATUS.md`와 변경된 사양 문서 갱신

- Frontend와 Backend API 계약은 어느 한쪽만 변경하지 않는다.
- Database 변경은 `supabase/migrations` 기준 파일과 실제 Supabase 적용 결과를 함께 확인한다.
- 새 Library는 현재 기능에 반드시 필요한 경우에만 추가한다.
- 검증 실패, 경고와 외부 환경 차단을 숨기지 않는다.
- 작업 마지막에는 변경 파일, Library 변경, 실행 명령, 결과와 남은 문제를 설명한다.

## 15. World 확정 정책

- 난이도 1/2/3은 각각 10/20/30 EXP를 지급한다.
- 누적 EXP 0/50/120/220/350은 Lv1~Lv5에 대응한다.
- 현재 여덟 Mission Category는 여덟 World Object와 1:1로 연결한다.
- GLB는 MVP에서 Flutter Local Asset으로 배포하고 경로·Transform은 Frontend Manifest만 관리한다.
- Backend와 Supabase PostgreSQL이 EXP·Level의 Source of Truth이며 Flutter와 Three.js는 계산하지 않는다.
- World 미리보기와 전체 화면은 같은 Snapshot과 Renderer를 사용하며 별도 성장 상태를 만들지 않는다.

## 16. 사양 변경 관리

- 새로운 정책이나 규칙이 정의되면 구현 전에 또는 구현과 같은 작업에서 이 문서를 갱신한다.
- API·Database·상태 전이·보안·디자인에 영향을 주는 상세 변경은 관련 SDD도 갱신한다.
- Phase 상태가 바뀌면 `PROJECT_STATUS.md`를 갱신한다.
- 기존 규칙을 대체할 때는 이전 문서가 계속 완료 근거로 사용되지 않도록 대체 사실을 명시한다.
- 날짜와 변경 이유를 아래 이력에 남긴다.

## 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-08-24 | DESIGN.md 전반 재점검: Noto Sans KR 공통 Theme, 44px CTA, 6px 버튼·입력·Badge, 16px 카드, 무그림자 hairline, 오류·성공 상태 색상과 World Utility Control 통일 |
| 2026-08-24 | World Snapshot 빈 목록 오류 표시, 성향 필터 전체 fallback, initializeWorld objectCount 계약, GLB 실패 asset 경로 전달 정책 보강 |
| 2026-08-24 | 매 미션 완료 시 성향 네 축·유형 갱신과 실제 전후 변화 응답, 5회 LLM 생성 미션의 다음 서비스 날짜 후보 반영, World 도움말 5초 페이드 정책 적용 |
| 2026-08-24 | 계정 V1: 아이디·비밀번호 회원가입/로그인, PBKDF2 비밀번호 해시, 초기 랜덤 닉네임과 캐시 사용자 자동 복원 적용 |
| 2026-08-26 | 시작 화면에서 로그인 기본 진입, 회원가입 보조 선택지 제공으로 계정 진입 순서 변경 |
| 2026-08-24 | 성향 결과 Purple 카드, 미션 진행/완료 상태 패널, 클릭 가능한 World 도움말 영역과 3D 레벨 메시지 검증 보강 |
| 2026-08-24 | 전체 3D World Object 호버·클릭 Bridge와 성향 Category·현재 단계 정보 툴팁 적용 |
| 2026-08-26 | 미션 플로우에서 시간 선택 UI를 제거하고 `LONG` 기본 설정을 내부 적용, 추천 후보를 최대 5개로 확장 |
| 2026-08-26 | 기준 SQL에 30~150분 중심 BASE 미션 100건을 추가하고 `CONTENT_FINGERPRINT`·`TITLE_NORMALIZED` 기준 멱등 seed 정책을 반영 |
| 2026-08-24 | Mission V1.2: 기본 Catalog M001~M200 적용, 완료 0~3일 하드 필터와 4~30일 동일 Mission 장기 반복 패널티 추가 |
| 2026-08-24 | Mission 날짜 정책 명시: 사용자 설정 Timezone의 Local Date 기준, MVP는 Asia/Seoul 고정, 동일 날짜 추천 재사용과 날짜 변경 시 신규 주기 시작 |
| 2026-08-24 | Flutter Web 미션 UI 개정: 수행 카드의 직접 변경 버튼과 하루 한 개 문구 제거, 취소 후 재선택 흐름 및 마우스 드래그 캐러셀 적용 |
| 2026-08-24 | 신규 닉네임 시작 화면에 서비스 설명·기존 사용자 자동 복원 안내를 추가하고 선택폼을 카드형 문항 레이아웃으로 개편, 첫 문항 이전 버튼 미노출 정책 반영 |
| 2026-08-24 | 성향 완료 홈 재배치: 상단 오늘의 미션, 시간 선택·후보 캐러셀·단일 진행 카드, 분리된 관심/행동 선호와 점수 그래프·완료 경험 방향, 하단 World 접이식 도움말 적용 |
| 2026-08-20 | 최초 설문 전 닉네임 입력·프로필 편집, 단일 성향 카드, 인라인 World 미리보기·성향 기반 공간명과 기본 사물 정책 반영 |
| 2026-08-20 | 로컬 `.env` 자동 로드와 `.env.example` 계약 확정, Flutter 플랫폼별 로컬 API 기본값 문서화 |
| 2026-08-20 | World Phase 0~8 구현: Snapshot API, Mission 완료 EXP Transaction, Flutter 상태, Android WebView·Web iframe Bridge, 8종×5레벨 GLB와 Diorama·Level Up 연결 |
| 2026-08-20 | 핵심 기능 1~3 안정화: 공식 Personality·UserMission 경로 단일화, 구형 Survey·Mission API 제거, 완료 멱등 경로와 Category Code 계약 고정 |
| 2026-08-20 | Mission V1 Phase 5 완료 통계·5회 성향 재분류·LLM 커밋 후 처리, 중복/유사도 차단, 요약 API와 Oracle Rollback 검증 |
| 2026-08-20 | Mission V1 Phase 4 `userMissionId` 기반 선택·취소·교체·완료 API, 소유권·활성 슬롯·원자적 교체·완료 멱등성과 Oracle 연결 로그 검증 |
| 2026-08-20 | Mission V1 Phase 3 설정·오늘 후보 REST/Service/Oracle 통합, 사용자 잠금, 동일 날짜 후보 재사용과 OpenAPI 검증 |
| 2026-08-19 | Mission V1 Phase 2 추천 Domain 구현: 하드 필터, 점수 공식, 상위 10개·최대 5개 가중 무복원 추출과 카테고리 다양성 검증 |
| 2026-08-19 | Mission V1 Phase 1 실제 Oracle 적용: 사용자 미션·설정·카테고리 통계·로그 연결과 활성 슬롯 함수 기반 Unique Index 검증 |
| 2026-08-19 | Mission V1 Phase 0 확정: 후보 5개, 하루 1~3개, 서울 달력 날짜 경계, 추천 점수, 취소·변경·상태·REST·Oracle 계약 정의 |
| 2026-08-19 | 성향 분석을 `PERSONALITY_V2`로 재정의: 실내·실외와 신체 활동 분리, 여섯 문항, Mission 범위 분리 |
| 2026-08-19 | 최초 작성. 현재까지 정의된 사용자, 성향, 미션, World, REST, DB, 디자인, 보안 정책 통합 |
## Deployment contract (2026-08-27)

- The repository root is the Docker build context. `front/Dockerfile` builds
  the Three.js bundle first, copies it into the Flutter Web project, builds
  Flutter Web, and serves the resulting static files with Nginx on port 80.
- `front/Dockerfile` accepts the non-secret build argument `API_BASE_URL` and
  passes it to Flutter as `--dart-define`. The deployed API URL is fixed at
  frontend build time.
- `front/nginx.conf` preserves Flutter client-side routing by falling back
  unknown paths to `/index.html`.
- `back/Dockerfile` builds the Spring Boot JAR with Maven and Java 21, then
  runs it on the Java 21 JRE image on port 8080. Backend secrets are runtime
  environment variables and are not copied into the image.
- The backend runtime must provide `DB_URL`, `DB_USERNAME`, and `DB_PASSWORD`.
  `CORS_ALLOWED_ORIGIN_PATTERNS` must contain the deployed Flutter Web origin.
  `OPENAI_API_KEY`, `OPENAI_MODEL`, and `OPENAI_BASE_URL` are optional LLM
  configuration values.
- Supabase PostgreSQL migrations are applied separately from the application
  images using `supabase/apply-migrations.jsh` and verified with
  `supabase/verify-migration.jsh`.
- `.dockerignore` excludes `.env` and local build artifacts. The deployment
  platform must inject secrets through its environment configuration.
