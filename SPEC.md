# Novelty 통합 사양

최종 갱신일: 2026-08-19

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

- Flutter / Dart: 선택지 폼, 성향 분석 UI, 미션 UI, 프로필, 설정, 3D World 화면
- Three.js / JavaScript / Vite: GLB Load, Camera, Lighting, Object placement, Level model switching, Simple animation
- Flutter 위치: `front/app`
- Three.js 위치: `front/world3d`

### Backend

- Java 21 / Spring Boot / Maven
- 기능 경계: User, Personality, Mission, Mission Completion, World / Progression
- 위치: `back`

### Database

- Oracle Database 21c
- 논리 테이블: `USER`, `PERSONALITY`, `MISSION`, `USER_MISSION`, `WORLD_OBJECT`, `WORLD_OBJECT_LEVEL`, `USER_WORLD_OBJECT`
- Oracle 예약어 충돌과 현재 물리 Schema를 고려한 실제 이름 대응은 `ARCHITECTURE.md`를 따른다.
- 기준 DDL은 루트 `DB.sql`이며 Backend 대응 SQL과 동일한 실행 내용을 유지한다.

### 3D Asset 흐름

```text
Blender 또는 Asset 제작
→ GLB
→ Flutter bundle 또는 CDN
→ Three.js World Renderer
```

## 4. 전체 사용자 흐름

신규 사용자의 기본 흐름은 다음과 같다.

```text
접속
→ 익명 사용자 생성 및 사용자 키 저장
→ 최초 1회 성향 분석 선택폼
→ 성향 결과와 프로필 표시
→ 할애 가능 시간 질문
→ 종합 결과 기반 미션 후보 생성
→ 미션 선택 및 수행
→ 완료
→ 3D 공간과 레벨 성장
```

- 성향 분석은 기본적으로 사용자당 최초 1회만 진행한다.
- 재접속 시 브라우저 또는 앱 캐시에 저장된 사용자 키로 사용자를 복원하고, 완료된 최초 분석을 반복하지 않는다.
- 사용자가 원하면 `성향 분석 다시하기` 버튼으로 다시 진행할 수 있다.
- 할애 가능 시간은 성향 질문에 포함하지 않고 성향 결과가 나온 뒤 별도로 묻는다.
- 닉네임은 회원가입 없이 사용할 수 있으며 초기 랜덤값을 제공하고 사용자가 변경할 수 있다.

## 5. 사용자 식별과 캐시

- Database 내부 식별자는 `userId`로 관리한다.
- Client 인증·복원에는 추측하기 어려운 별도 `userKey`를 사용한다.
- `userKey` 원문은 생성 응답에서 Client에 전달하고 Browser cache 또는 App cache에 저장한다.
- Server는 `userKey` 원문 대신 안전한 해시를 저장하는 것을 원칙으로 한다.
- 이후 사용자 범위 REST 요청은 `X-User-Key` Header를 사용한다.
- 닉네임은 표시 이름이며 인증 수단으로 사용하지 않는다.
- 캐시가 사라진 경우 기존 사용자를 임의 닉네임만으로 복원하지 않고 새 익명 사용자로 시작한다.
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
- `DB.sql`의 `NICKNAME_BANNED_WORD` 기준 데이터는 금칙어 파일과 함께 갱신한다.
- Frontend validation, Backend validation, DB constraint 또는 trigger의 3단계로 방어한다.
- Client 검증은 사용자 경험을 위한 것이며 최종 신뢰 경계는 Backend와 Database다.

## 7. 선택지 폼과 성향 분석

### 질문 영역

최초 성향 분석은 성격 전체를 진단하지 않고 사용자의 행동 선호를 수집한다. 상세 계약은 활성 문서인 `docs/personality-sdd-v2.md`를 따른다.

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

- 분석 결과는 사용자 정보와 연결하여 Oracle에 저장한다.
- 프로필은 현재 값과 분석 버전을 관리한다.
- 최초 설문 답변뿐 아니라 추후 완료한 미션 이력을 근거로 갱신할 수 있다.
- 성향 결과는 사용자에게 이름과 설명이 있는 프로필로 표시한다.
- 현재 분류 체계는 `PERSONALITY_V2`의 9개 성향 유형이며 코드, 한글 이름과 Mapping은 Personality SDD를 기준으로 한다.
- 미션 거리 계산에 쓰는 축과 사용자에게 보여주는 성향 유형 코드를 구분하여 관리한다.

### 할애 가능 시간

- 성향 결과를 보여준 다음 질문한다.
- 사용자별 미션 추천 조건으로 저장한다.
- 미션의 `estimatedMinutes` 필터와 비교할 수 있는 단위로 관리한다.
- 시간 선택지, 저장 및 API 구현은 성향 분석 SDD V2 범위에 포함하지 않고 후속 Mission SDD에서 정의한다.

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
- 완료 미션이 5회 이상인 사용자는 검수된 기본 미션과 공유 LLM 미션 Catalog의 후보가 될 수 있다.
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

### 이력과 재추천 제한

- 서비스 날짜와 기간 계산 기준 Timezone은 `Asia/Seoul`이다.
- 최근 완료한 미션은 완료 시각부터 3일 동안 재추천하지 않는다.
- 최근 노출한 미션은 노출 시각부터 2일 동안 재노출하지 않는다.
- 동일 카테고리의 연속 추천을 제한한다.
- 3일과 2일의 정확한 기간 경계를 경과 시간으로 계산할지 달력 날짜로 계산할지는 Mission SDD에서 확정한다.

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
- 사용자는 여러 개의 추천 후보 중 하나를 선택한다.
- 하루 수행 미션 수의 초기 기본값은 1개이며 설정에서 수행 개수를 변경할 수 있게 한다.
- 설정에서 허용할 최소·최대 개수는 Mission SDD에서 확정한다.
- 수행 중인 미션은 목록 상단에 표시한다.
- 사용자는 수행 중인 미션을 취소하거나 기존 추천 목록의 다른 미션으로 변경할 수 있다.

## 9. 3D World와 레벨

- 미션 완료는 미션 `category`와 연결된 World object의 경험치 또는 성장값에 반영한다.
- 사용자별 Object 상태는 `USER_WORLD_OBJECT` 영역에서 관리한다.
- Object의 레벨별 요구치와 GLB 모델 정보는 `WORLD_OBJECT_LEVEL` 영역에서 관리한다.
- Three.js는 렌더링을 담당하고 Flutter는 사용자 화면과 앱 상태를 담당한다.
- GLB 로드 실패 시 앱 전체가 중단되지 않도록 오류 또는 대체 UI를 제공한다.
- 레벨 변경은 Backend의 저장 결과를 기준으로 처리하며 Client만의 값으로 확정하지 않는다.
- 구체적인 경험치 산식, 최대 레벨, 카테고리와 Object 매핑은 World SDD에서 확정한다.

## 10. REST API 공통 규칙

- API 경로는 `/api/**`를 사용한다.
- Controller는 요청 검증과 HTTP 변환을 맡고 핵심 정책은 Service에서 처리한다.
- 사용자 범위 API는 `X-User-Key` Header로 사용자를 식별한다.
- 요청·응답 DTO를 명시하고 Flutter와 Backend의 필드 이름, enum과 nullable 규칙을 일치시킨다.
- Validation 오류, 중복, 찾을 수 없음, 상태 충돌과 Server 오류를 구분된 HTTP 상태와 오류 Body로 반환한다.
- API는 springdoc-openapi에 노출하고 Swagger UI의 `Try it out`으로 정상·오류 사례를 시험할 수 있어야 한다.
- 로컬 Swagger UI 주소는 `http://localhost:8080/swagger-ui.html`이다.

## 11. Database 규칙

- 기준 파일은 루트 `DB.sql`이다.
- Backend Schema 파일은 기준 DDL과 동일한 실행 내용을 유지한다.
- 테이블, Sequence, Index, Constraint, Trigger 및 필수 기준 데이터 변경은 코드 적용과 같은 작업에서 SQL에도 반영한다.
- 가능한 DDL과 기준 데이터는 재실행 가능한 형태로 작성한다.
- 실제 Oracle 적용 후 객체와 Constraint를 조회하여 검증하기 전에는 적용 완료로 기록하지 않는다.
- Oracle 접속 실패나 SQL 실패를 숨기지 않고 `PROJECT_STATUS.md`에 남긴다.
- Database 접속정보와 Secret은 SQL 또는 추적되는 설정 파일에 직접 작성하지 않는다.

## 12. 디자인과 접근성

- 모든 화면은 `DESIGN.md`를 기준으로 한다.
- 기본 Font는 Google Fonts의 `Noto Sans KR`이다.
- Flutter는 공통 Theme, Three.js Web UI는 공통 CSS Token을 우선 사용한다.
- 주요 CTA, 상태, 오류와 성공 표현은 `DESIGN.md`의 Color 및 Component 규칙을 따른다.
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
- Database 변경은 SQL 기준 파일과 실제 Oracle 적용 결과를 함께 확인한다.
- 새 Library는 현재 기능에 반드시 필요한 경우에만 추가한다.
- 검증 실패, 경고와 외부 환경 차단을 숨기지 않는다.
- 작업 마지막에는 변경 파일, Library 변경, 실행 명령, 결과와 남은 문제를 설명한다.

## 15. 미확정 결정 목록

다음 항목은 임의로 확정하지 않고 해당 기능의 SDD Phase 0에서 결정한다.

- 한 번에 보여줄 미션 후보 개수
- 설정에서 선택할 수 있는 하루 미션 개수의 최소·최대 범위
- 취소 후 교체 추천 가능 횟수
- 최근 완료 3일·최근 노출 2일을 경과 시간과 달력 날짜 중 어떤 경계로 계산할지
- 사용자 성향 벡터와 미션 벡터의 정확한 점수 범위 및 가중치
- 9개 성향 유형의 최종 코드·한글 이름·경계값
- 미션 유사도 판정 방식과 임계값
- World 경험치 산식, 최대 레벨, 카테고리별 Object 매핑
- GLB 배포를 Flutter bundle과 CDN 중 어떤 방식으로 사용할지

## 16. 사양 변경 관리

- 새로운 정책이나 규칙이 정의되면 구현 전에 또는 구현과 같은 작업에서 이 문서를 갱신한다.
- API·Database·상태 전이·보안·디자인에 영향을 주는 상세 변경은 관련 SDD도 갱신한다.
- Phase 상태가 바뀌면 `PROJECT_STATUS.md`를 갱신한다.
- 기존 규칙을 대체할 때는 이전 문서가 계속 완료 근거로 사용되지 않도록 대체 사실을 명시한다.
- 날짜와 변경 이유를 아래 이력에 남긴다.

## 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-08-19 | 성향 분석을 `PERSONALITY_V2`로 재정의: 실내·실외와 신체 활동 분리, 여섯 문항, Mission 범위 분리 |
| 2026-08-19 | 최초 작성. 현재까지 정의된 사용자, 성향, 미션, World, REST, DB, 디자인, 보안 정책 통합 |
