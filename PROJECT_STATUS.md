# Novelty 프로젝트 진행 상태

최종 갱신일: 2026-08-26

## 문서 목적

이 문서는 핵심 기능별 SDD와 실제 구현 상태를 한곳에서 관리한다. 과거 사양의 완료 기록, 현재 코드의 일부 구현, 현재 유효한 사양의 완료 상태를 서로 구분하여 기능이 완료된 것으로 잘못 판단하지 않도록 한다.

상태는 다음 기준으로 표시한다.

| 상태 | 의미 |
|---|---|
| 미착수 | 현재 사양과 Phase 문서가 아직 준비되지 않음 |
| 사양 확정 | Phase 사양과 인수 조건은 확정됐으나 구현 전임 |
| 진행 중 | 구현 또는 검증이 일부 완료됐으나 현재 사양 전체를 충족하지 않음 |
| 차단 | 외부 설정이나 선행 결정 없이는 다음 단계로 진행할 수 없음 |
| 검증 완료 | 현재 사양의 구현과 관련 Build·테스트 또는 E2E 검증이 완료됨 |
| 대체됨 | 과거에는 완료됐으나 이후 변경된 사양의 현재 완료 근거로 사용할 수 없음 |

## Supabase PostgreSQL 전환 상태

- 운영 기준은 Supabase PostgreSQL로 전환했으며, PostgreSQL JDBC driver와 Repository SQL 변환을 적용했다.
- `supabase/migrations/001_initial_schema.sql`과 `002_seed_missions.sql`을 테스트용 Supabase에 실제 적용했다.
- 적용 결과는 `MISSION` 300건, `WORLD_OBJECT` 8건, `WORLD_OBJECT_LEVEL` 40건, `NICKNAME_BANNED_WORD` 9건이다.
- 확인한 외래키 고아 레코드는 0건이며, 사용자·수행 이력 테이블은 이관 시점에 0건이었다.
- PostgreSQL 기준 `회원가입 → 사용자 조회 → World Snapshot` API 흐름을 실제 DB 연결로 확인했다.
- 기존 Oracle 실제 인스턴스는 `ORA-12638` 인증 오류로 읽기 전용 row count 확인이 불가능했으므로, 기존 사용자 데이터가 존재하는 환경의 데이터 이관 완료로 간주하지 않는다.

## 2026-08-26 최신 반영

- 시작 스플래시는 고정 `1600ms` 타이머를 제거하고 사용자 복원·로그인·오류 화면이 준비된 시점에 종료하도록 변경했다.
- Noto Sans KR Regular·Medium·Bold를 Flutter 번들에 포함하고 `google_fonts` 런타임 의존성을 제거했다.
- Three.js는 기본 placeholder 룸을 선행 로드하지 않고 Flutter가 지정한 성향 룸만 로드한다.
- GLB URI 캐시와 Bridge 초기화 중복 방지를 적용했다.
- `flutter analyze`, Flutter 전체 테스트 93개, `flutter build web`, `npm.cmd run build`를 통과했다. Three.js 번들 500KB 초과 경고는 남아 있다.

## 핵심 기능 요약

| 핵심 기능 | 현재 상태 | SDD 상태 | 실제 구현 판단 |
|---|---|---|---|
| 1. 선택지 폼 | 검증 완료 | V2 Phase 5~7 완료 | 여섯 문항·검증·제출 재시도와 PostgreSQL 연결 흐름 검증 |
| 2. 사용자 성향 분석 | 검증 완료 | V2 Phase 0~7 완료 | Backend 계약과 Flutter 최초 분기·선택폼·Profile·재분석 검증 |
| 3. 랜덤 미션 생성 | 검증 완료 | V1 Phase 0~7 검증 완료 | Flutter 추천·선택·변경·취소·완료·통계와 PostgreSQL seed 검증 |
| 4. 3D 공간·레벨 | 진행 중 | V1 Phase 0~8 검증 완료, Phase 9 부분 완료 | Backend·Flutter·Three.js·성향별 룸 GLB 9종과 로딩 최적화 완료, Web·Android 실제 조작 재확인 대기 |

## SDD Phase 현황표

`부분`은 관련 코드나 Schema가 있더라도 해당 Phase의 현재 인수 조건을 모두 검증하지 못했다는 뜻이다. `재정의`는 과거 Phase 기록이 있으나 개정 사양에 맞춰 범위와 인수 조건을 다시 정해야 한다는 뜻이다.

| 핵심 기능 | Phase 0 | Phase 1 | Phase 2 | Phase 3 | Phase 4 | Phase 5 | Phase 6 | Phase 7 |
|---|---|---|---|---|---|---|---|---|
| 선택지 폼(현재 흐름) | 성향 SDD에 포함 | 재정의 | 재정의 | 재정의 | 재정의 | 검증 완료 | 검증 완료 | 검증 완료 |
| 사용자 성향 분석 V2 | 검증 완료 | 검증 완료 | 검증 완료 | 검증 완료 | 검증 완료 | 검증 완료 | 검증 완료 | 검증 완료 |
| 랜덤 미션 V1 | 검증 완료 | 검증 완료 | 검증 완료 | 검증 완료 | 검증 완료 | 검증 완료 | 검증 완료 | 검증 완료 |
| 3D 공간·레벨 V1 | 검증 완료 | 검증 완료 | 검증 완료 | 검증 완료 | 검증 완료 | 검증 완료 | 검증 완료 | 검증 완료 |

World Phase 8의 Level Up UI·Animation은 검증 완료했다. Phase 9는 Backend·Flutter·Three.js
자동 회귀와 Android Emulator 검증을 통과했으며 Web·Android 사용자 흐름의 최종 수동 조작
재확인만 남아 있다. 운영 데이터베이스는 Supabase PostgreSQL 기준으로 확인한다.

핵심 기능 1~3 안정화 Phase 1~7은 완료했다. 공식 경로는 `POST /api/personality-analyses`, `/api/missions/today/recommendations`, `/api/user-missions/{userMissionId}/**`이며 구형 Survey·random mission·`missionId` 직접 상태 변경 API는 제거했다.

선택지 폼의 기존 Phase 0~7은 과거 계약 기록으로만 유지한다. 현재 완료 근거는 Personality V2의
Phase 5~7 선택폼·통합 검증이며, 이후 상태 변경도 현재 SDD의 검증 근거와 함께 갱신한다.

## 1. 선택지 폼

현재 상태: **검증 완료**

- 대체된 과거 문서: `docs/survey-phase0-spec.md`, `docs/survey-phase7-completion.md`
- 과거의 Phase 0~7 완료는 기존 에너지 질문을 포함한 설문 저장 계약에 대한 기록이다.
- 현재 유효한 흐름은 최초 1회 성향 분석, 결과 표시, 오늘의 미션 후보 선택의 순서다. 과거의 시간 질문 완료 기록은 현재 사양의 완료 근거로 사용하지 않는다.
- 구형 Survey 화면·API Client·Backend 전용 저장 API는 제거했다.
- 현재 선택지 원본 저장과 성향 분석은 `POST /api/personality-analyses`와 `PersonalityService` 하나로 통일했다.
- 계정 V1 회원가입·로그인과 사용자 키 식별, 제출 계약 및 개정된 여섯 문항 선택폼이 연결됐다.

- V2 Phase 7에서 Flutter부터 Oracle까지 동일 사용자 기준 E2E와 실패 시나리오 검증을 완료했다.

## 2. 사용자 성향 분석

현재 상태: **검증 완료, V2 Phase 0~7 완료**

- 활성 기준 문서: `docs/personality-sdd-v2.md`
- Phase 0 검증 기록: `docs/personality-phase0-v2-verification.md`
- Phase 1 검증 기록: `docs/personality-phase1-v2-verification.md`
- Phase 2 검증 기록: `docs/personality-phase2-v2-verification.md`
- Phase 3 검증 기록: `docs/personality-phase3-v2-verification.md`
- Phase 4 검증 기록: `docs/personality-phase4-v2-verification.md`
- Phase 5 검증 기록: `docs/personality-phase5-v2-verification.md`
- Phase 6 검증 기록: `docs/personality-phase6-v2-verification.md`
- Phase 7 검증 기록: `docs/personality-phase7-v2-verification.md`
- 대체된 문서: `docs/personality-phase0-spec.md`
- V2 Phase 0: 현재 정책과 실제 구현의 불일치를 반영하여 재정의하고 정상·실패 계약 검증 완료
- V2 Phase 1: 실제 Oracle 비파괴 Schema, 멱등 적용, 정상·실패 시나리오 검증 완료
- V2 Phase 2: 여섯 문항의 순수 Java 분석 Domain, 네 축 점수, 9개 유형, 정상·실패 시나리오 검증 완료
- V2 Phase 3: Spring Boot 저장 API, 사용자 Profile 조회, 멱등·상태 충돌·실제 Oracle Rollback과 OpenAPI 검증 완료
- V2 Phase 4: Flutter V2 Model·REST Client, 사용자 키 캐시, 최초 접속 분기와 정상·실패 시나리오 검증 완료
- V2 Phase 5: 여섯 문항 UI·상태 유지·Validation·중복 제출 잠금·오류 재시도와 반응형 검증 완료
- V2 Phase 6: 전체 Profile, 최초 결과·재접속 복원, 확인 Dialog와 재분석 성공·실패 흐름 검증 완료
- V2 Phase 7: Flutter → REST → Spring Boot → Oracle → Response → Flutter E2E, 주요 실패 시나리오, Oracle 직접 조회, 전체 회귀 Build 검증 완료
- 사용자, 닉네임 정책, 성향 프로필 Schema 및 Backend 코드가 일부 구현되어 있다.
- Flutter의 사용자 키 저장·복원, 최초 접속 분기, 여섯 문항, 전체 Profile과 재분석 화면 흐름이 완료됐다.
- 신규 닉네임 시작 화면의 서비스 설명과 선택폼 카드 레이아웃을 적용했으며 첫 문항은 이전 버튼을 표시하지 않는다.
- 같은 브라우저·앱의 기존 사용자는 캐시 `userKey`로 자동 복원되며 캐시 삭제·다른 기기에서는 아이디·비밀번호로 로그인한다.
- Backend 사용자 프로필 응답은 저장된 성향 유형, 네 축, 실행 방식, 관심 분야, 버전과 분석 시각을 반환한다.
- 기존 `activityLevel`은 실내·실외 의미여서 V2에서 `indoorOutdoor`로 명확히 하고 별도 `physicalActivityLevel` 문항을 추가한다.
- V2 범위는 성향 분석과 Profile 및 재분석까지다. 시간 질문, 미션 생성, OpenAI와 World는 제외한다.

성향 분석 V2의 Phase 0~7 완료 조건을 모두 충족했다. 이후 변경은 별도 SDD 개정으로 관리한다.

## 3. 랜덤 미션 생성·선택·완료

현재 상태: **검증 완료, Phase 0~7 검증 완료**

- 활성 기준 문서: `docs/mission-sdd-v1.md`
- Phase 0 검증 기록: `docs/mission-phase0-verification.md`
- Phase 1 검증 기록: `docs/mission-phase1-verification.md`
- Phase 2 검증 기록: `docs/mission-phase2-verification.md`
- Phase 3 검증 기록: `docs/mission-phase3-verification.md`
- Phase 4 검증 기록: `docs/mission-phase4-verification.md`
- Phase 5 검증 기록: `docs/mission-phase5-verification.md`
- Phase 6 검증 기록: `docs/mission-phase6-verification.md`
- Phase 7 검증 기록: `docs/mission-phase7-verification.md`
- Phase 0: 정상·실패 계약 정적 검사, Backend 114개와 Flutter 68개 회귀 테스트 완료
- Phase 1: 실제 Oracle 멱등 Migration, 정상 저장, 19개 실패 Constraint, Rollback과 Backend 115개 회귀 테스트 완료
- Phase 2: 순수 Java 추천 Domain의 정상·실패 집중 테스트 21개와 실제 Oracle 회귀를 포함한 Backend 전체 129개 테스트 및 Package 완료
- Phase 3: 설정·오늘 후보 API, 사용자별 통계, Oracle 후보·연결 로그 저장과 재사용을 구현하고 집중 29개·실제 Oracle·전체 140개 테스트 및 Package 완료
- Phase 4: `userMissionId` 기반 선택·취소·교체·완료 API, 소유권과 서울 날짜 검증, 활성 슬롯, 원자적 교체, 완료 멱등성을 구현하고 집중 32개·실제 Oracle·전체 153개 테스트 및 Package 완료
- Phase 5: 카테고리 통계, 전체 완료 수, 매 완료 성향 벡터·유형 갱신, 커밋 이후 5회 단위 LLM 생성과 중복·유사도 차단, 완료 요약 API를 구현했다.
- Phase 6: Flutter Model·REST Client·설정·추천·수행 중·변경·취소·완료·통계 화면과 중복 입력 잠금·안전한 오류 처리를 구현하고 집중 12개 테스트 완료
- Phase 7: Flutter UI → REST → 최신 Spring Boot → 실제 Oracle → 응답 UI 갱신 E2E, 잘못된 사용자 키 실패, Oracle 행·로그·통계 직접 조회와 테스트 데이터 정리 완료
- 하루 후보는 최대 5개다. 동일 미션 완료는 서울 달력 경과 0~3일 하드 필터와 4~30일 단계별 반복 감점을 적용하고, 노출은 D~D+2 재노출하지 않는다. 현재 Flutter UI는 하루 수행 미션을 1개로 고정하고 시간 선택 없이 후보를 보여준다.
- Flutter Web UI는 직접 변경 버튼을 제거하고 수행 중 미션 취소 후 오늘 저장된 후보 캐러셀에서 다시 선택하도록 확정했다. Backend 교체 API는 호환을 위해 유지한다.
- Mission V1.1에서 성향 거리·새로움·최근 다양성·미경험 탐색·조건 적합의 양의 점수와 최근 경험·반복·거부 패널티를 적용하고, 상위 20개에서 서로 다른 경험 최대 5개를 구성한다.
- REST, Oracle 논리 구조, 상태 전이, 동시성, 멱등성과 정상·실패 인수 조건을 정의했다.
- Backend에는 미션 속성, 성향 거리 기반 추천, 상태 로그, 완료 횟수 기반 LLM 생성 코드와 테스트가 일부 존재한다.
- M001~M200 기본 미션과 사용자 미션·설정·카테고리 통계·상태 로그 관련 Oracle DDL을 실제 적용했다. 기준 SQL에는 기존 200개에 30~150분 중심 BASE 미션 100개를 추가했지만, 신규 100개 seed의 실제 Oracle 적용은 별도 확인이 필요하다.
- Flutter 성향 완료 홈 상단에 오늘의 미션을 직접 배치했다. 시간 선택 없이 후보 캐러셀, 선택 뒤 단일 수행 카드, 완료 뒤 완료 카드 순서로 전환한다.
- 관심 분야와 행동 선호를 분리하고 네 축 점수 그래프와 완료 응답의 실제 저장 전·후 성향 변동을 표시한다.
- 최근 완료·노출 3일, 최근 7일·최신 완료 10개 행동 메타데이터와 최근성 가중치, 문구 변형 유사 미션 차단, 최종 후보 간 다양성을 추천 Domain에서 검증했다. 완료 5회 단위 LLM Catalog 저장 정책은 유지하며 생성 결과에도 같은 메타데이터를 요구한다.
- 신규 사용자에게 성향 프로필이 생성되지 않으면 정상 추천 흐름에 진입할 수 없다.

현재 SDD V1의 Phase 0~7 완료 조건을 충족했고 World 성장 연결도 별도 World SDD에 따라 구현되어 있다.

2026-08-24 Mission V1.1 추천 다양성 개정을 적용했다. Oracle `MISSION`에 행동 메타데이터 6개를 멱등 적용하고 기본 미션 12건을 보강했으며, 추천 집중 22개·실제 Oracle 정상/Constraint 실패 1개·Backend 전체 179개·Flutter 81개 테스트, Backend package, Flutter analyze와 Web build를 통과했다. 기본 전체 테스트에서 환경 조건부 Oracle/E2E 11개는 제외되며 새 Oracle 테스트는 환경 변수를 주입한 별도 실행에서 통과했다.

2026-08-24 Mission V1.2에서 기존 활성 후보를 비활성화하고 M001~M200을 실제 Oracle에 적용했다. 동일 Mission 완료 후 0~3일 하드 필터, 4~7일 0.35, 8~14일 0.20, 15~30일 0.08 감점을 추가했으며 동일 ID를 의미 유사도·패턴 감점에서 제외해 이중 계산을 막았다. 실제 Oracle 통합 테스트에서 활성 200개, Category별 24~26개, 한글 태그 및 실패 Constraint, 30일 동안 매일 3개 추천을 통과했다.
Backend 전체 181개 테스트는 실패 0·환경조건부 12개 제외로 통과했고 Package도 성공했다. Oracle 조건부 테스트 2개는 실제 DB 연결로 별도 통과했다. Frontend는 Dart analyze 오류 0, Flutter 테스트 81개 통과·1개 제외를 확인했다.

2026-08-24 Mission 날짜 계약을 사용자 설정 Timezone의 Local Date 기준으로 명시했다. MVP는 사용자별 Timezone 입력 없이 `Asia/Seoul`로 고정하며, 기존 Backend의 Service Clock과 `SERVICE_DATE` 구현이 동일 Local Date 추천 재사용 및 날짜 변경 시 신규 추천 주기 정책을 이미 충족함을 확인했다. 사용자별 Timezone 저장·변경 기능은 미구현 범위다.

2026-08-24 Flutter Web의 오늘의 미션 UI에서 수행 카드의 직접 변경 버튼과 제목 옆 `하루 한 개` 문구를 제거했다. 취소 후 기존 추천 후보를 다시 선택하는 흐름은 유지하고, 추천 캐러셀에 마우스·터치·스타일러스·트랙패드 드래그를 적용했다. 관련 위젯 테스트 7개와 전체 Flutter 테스트 82개가 통과했고 조건부 테스트 1개는 제외됐으며, 정적 분석과 Web 빌드도 성공했다.

안정화 Phase 1~7에서 `/api/missions/random`과 `PATCH /api/missions/{missionId}/status`를 제거했다. 완료는 `UserMissionService.complete(userMissionId)`만 사용하며 `USER_MISSION` 상태, 연결 로그, 카테고리 통계와 성향 후처리를 한 Transaction에서 처리한다. 완료 재요청은 멱등 응답이며 LLM 생성만 커밋 이후 격리한다.

## 4. 3D 공간·레벨 시스템

현재 상태: **Phase 0~8 구현·검증 완료, Phase 9 실제 UI 회귀 대기**

- 활성 기준 문서: `docs/world-sdd-v1.md`
- Phase 0: Category·Object, EXP·Level, Oracle, REST, Asset Manifest와 JSON Bridge 계약 확정 완료
- Phase 1: Android WebView·Three.js·GLB·Bridge Technical Spike 완료
- Phase 2~4: World Oracle DDL, Backend Domain, `GET /api/world`, Mission 완료 Transaction 연동과 중복 보상 방지 완료
- Phase 5~8: Flutter World 상태, Three.js Diorama, Backend↔Flutter↔Three.js 연결, Level Up UI·Animation 완료
- 성향별 기본 방 9종 GLB를 Flutter Web과 Three.js 모델 경로에 배치했다. `floor`·`wall` Mesh는 기본 골조로 유지하고, 나머지 장식 Mesh는 World 최고 레벨에 따라 5단계로 노출한다. 매핑 및 초기화 메시지 테스트와 Three.js production build를 통과했다.
- Android Emulator에서 Room GLB, Lv1→Lv2 모델 교체, Background/Foreground 복귀와 Renderer 재진입을 확인했다.
- Web/Android는 같은 Flutter UI와 Three.js 번들을 사용하며 성향별 룸 GLB 9종을 Local Asset으로 제공한다. Backend의 Category Object 성장 데이터는 룸 장식 노출 단계 계산에 사용하고, 기존 외부 placeholder GLB는 제거했다.
- 실제 Oracle에 World Table 3개, Object 8개, Level 40개를 적용·조회했다.
- Mission Phase 4 Oracle Rollback 통합 테스트로 완료→World EXP→Snapshot과 완료 재요청 보상 방지를 검증했다.
- 최신 자동 회귀는 Backend 179건(실패 0, 오류 0, 환경 조건부 11건 제외), Flutter 81건(조건부 1건 제외), Analyze와 Web Build를 통과했다. 이번 변경 전 검증된 APK·Three.js Build 상태는 유지한다.

다음 완료 조건:

1. Web과 Android에서 프로필 인라인 World→전체 화면→미션 완료 성장 표시를 실제 조작으로 재확인한다.

## 공통 기반 상태

| 영역 | 상태 | 비고 |
|---|---|---|
| 계정·닉네임 | 자동 검증 완료 | 회원가입·로그인, PBKDF2 비밀번호 해시, 랜덤 초기 닉네임, 프로필 편집, 동일 Client 캐시 자동 복원 검증 |
| Oracle Personality V2 Schema | 검증 완료 | 로컬 Oracle에 Phase 1 적용 및 재실행 성공. 기존 V1 설문 4건 보존 |
| Oracle Mission·World 목표 Schema | 검증 완료 | World Table 3개·Object 8개·Level 40개 적용, 완료→EXP→Snapshot Rollback 통합 테스트 통과 |
| Swagger UI | 검증 완료 | 회원가입·로그인·사용자·성향·미션·World 공식 API 노출과 `/api/users/anonymous`, `/api/surveys`, `/api/missions/random`, `missionId` 직접 상태 변경 미노출 자동 검증. 기본 주소 `http://localhost:8080/swagger-ui.html` |
| OpenAI 설정 | 진행 중 | API Key는 `OPENAI_API_KEY` 환경 변수로만 주입; 실제 연동 성공 검증 필요 |
| Backend 자동 테스트 | 검증 완료 | 전체 회귀 188개 실행, 실패 0, 오류 0, 환경 조건부 12개 제외; 계정 Swagger 1개 별도 통과 및 Package 성공 |
| Three.js Build | 검증 완료 | 성향별 룸 GLB 9종과 fallback·Spike 테스트 모델만 존재, Build 성공, 번들 500KB 경고 존재 |
| Flutter 자동 테스트 | 검증 완료 | 전체 93개 통과; Analyze 무결점과 Web build 성공 |
| Flutter Android 기반 | 검증 완료 | Debug APK Build, WebView Renderer Ready, GLB 표시·교체, Background/Foreground 복귀 성공 |
| Flutter 성향 분석 흐름 | 검증 완료 | 최초 분석·복원·멱등 재시도·재분석과 PostgreSQL API 흐름 검증 |
| 로컬 환경 설정 | 검증 완료 | Git 제외 `.env`, 추적 가능한 `.env.example`, Spring Boot 자동 import와 Oracle Connection 생성 확인. OpenAI Key는 유효한 값을 별도 입력해야 함 |
| Flutter 전체 사용자 흐름 | 진행 중 | 닉네임·성향·미션·인라인 World 연결 완료. Web·Android 실제 UI 재확인 대기 |

## 권장 진행 순서

1. Web·Android 실제 UI에서 인라인 World와 완료 성장 표시를 재확인한다.

## 상태 갱신 규칙

- Phase 시작, 완료, 실패 또는 보류 시 이 문서를 같은 작업에서 갱신한다.
- 완료 표기에는 확인한 날짜, 명령 또는 E2E 증거를 남긴다.
- 코드나 테이블 파일이 존재하는 것과 기능 완료를 구분한다.
- 이전 사양을 대체하는 정책이 생기면 이전 완료 상태를 `대체됨`으로 바꾼다.
- 장애나 외부 설정 문제는 숨기지 않고 `차단` 또는 비고에 기록한다.
- 새 기능 구현 전에 `AGENTS.md`, `SPEC.md`, 이 문서, 관련 SDD 및 실제 코드를 함께 확인한다.

## 변경 이력

| 2026-08-26 | 외부 미션 데이터 100건(30~150분)을 기본 미션 Pool에 추가하고 `DB.sql` 및 Backend 대응 SQL에 fingerprint·제목 기준 멱등 삽입을 적용 |

| 날짜 | 변경 내용 |
|---|---|
| 2026-08-26 | 미션 사용자 플로우에서 시간 선택 단계를 제거하고 기존 `availableTime`은 `LONG` 기본값으로 내부 정규화, 추천 후보 상한을 5개로 확장 |
| 2026-08-26 | 기준 `DB.sql`과 Backend Schema mirror에 BASE 미션 100건을 fingerprint·제목 기준 멱등 seed로 추가 |
| 2026-08-26 | 오늘의 미션 UI를 Spotlight 카드 중심으로 개편하고 완료 수 배지, 카테고리 아이콘, 메타데이터와 명확한 선택 CTA를 추가 |
| 2026-08-26 | 9개 성향 타입별 기본 룸 에셋 코드 매핑을 등록하고 GLB 추가 전까지 공통 `room.glb` fallback 정책을 유지 |
| 2026-08-26 | `WORLD_TEST=true` 전용 World 테스트 화면을 추가해 실제 성향별 룸 선택과 전체 Object 레벨 일괄 상승으로 Lv.1~Lv.5 장식 변화를 검증하도록 구성 |
| 2026-08-24 | DESIGN.md 기준 Flutter 공통 Theme와 계정·설문·미션·프로필·World 화면을 재점검하고 CTA·입력·Card·Chip·상태·Utility Control 토큰을 통일 |
| 2026-08-24 | World API 정상 Snapshot을 기준으로 빈 objects 오류 표시, 성향 필터 전체 fallback, Bridge objectCount 검증과 GLB 실패 asset 경로 표시를 구현하고 Flutter·Three.js 검증 완료 |
| 2026-08-24 | 미션 매 완료 시 성향 네 축·유형 반영, 완료 응답 실제 변화량 표시, 5회 LLM 신규 미션의 다음 날짜 추천 후보 반영 계약과 World 도움말 5초 페이드 적용 |
| 2026-08-24 | 계정 회원가입·로그인과 랜덤 닉네임 배정, PBKDF2 저장 및 Oracle 계정 컬럼·제약 적용, 성향 결과 Purple 카드, 미션 진행/완료 상태 패널, Web World 도움말 클릭 및 인라인·전체 World 8개 객체 5단계 즉시 성장 계약 보강 |
| 2026-08-26 | 시작 화면의 계정 진입을 로그인 우선으로 변경하고 회원가입을 보조 선택지로 제공, 캐시 사용자 자동 복원은 유지 |
| 2026-08-24 | 전체 3D World의 Object 마우스·펜 호버와 클릭 선택을 Bridge로 연결하고 한글 Object명·성향 Category·현재/최대 단계·EXP 툴팁 적용 |
| 2026-08-24 | 시작 화면 서비스 설명·기존 사용자 자동 복원 안내, 성향 선택폼 카드 레이아웃과 첫 문항 이전 버튼 미노출 적용 |
| 2026-08-24 | 성향 완료 홈을 첨부 레이아웃 기준으로 재구성하고 시간 선택·미션 캐러셀·단일 진행 카드·행동 선호 그래프와 완료 변화·World 도움말 토글 구현 |
| 2026-08-20 | 미션 완료 500 원인인 미적용 World Schema 해결: Oracle World 3 Table·8 Object·40 Level 적용, 완료→EXP→Snapshot 통합 검증 |
| 2026-08-20 | 최초 닉네임 입력·프로필 편집, 단일 성향 카드, 인라인 3D World와 성향 기반 공간명·기본 사물 구현 |
| 2026-08-20 | World V1 Phase 0 SDD: Category–Object 1:1, EXP·Level, Snapshot·완료 응답, Asset Manifest와 JSON Bridge 계약 확정 |
| 2026-08-20 | Flutter Android(AOS) 플랫폼 골격 추가, Web 공용 UI 정책과 Android Debug APK Build 검증 |
| 2026-08-20 | Git 제외 `.env`와 Spring Boot 자동 import 구성, 코드 기준 실행·World 상태 문서 동기화 |
| 2026-08-20 | World Phase 0~8 구현 및 Phase 9 자동·Android·실제 Oracle World E2E 검증 완료. Web·Android 전체 사용자 흐름 수동 재확인 대기 |
| 2026-08-20 | 핵심 기능 1~3 안정화 Phase 1~7: 구형 Survey·Mission API와 Dead Code 제거, 완료 경로 단일화, Category 계약·Swagger 미노출 테스트, DB.sql 중복 정리, Maven Wrapper 수정 및 전체 Build 검증 |
| 2026-08-20 | 랜덤 미션 V1 Phase 6~7 Flutter 전체 흐름, 정상·실패 테스트, 실제 Spring Boot·Oracle E2E와 Oracle 직접 검증 완료 |
| 2026-08-20 | 랜덤 미션 V1 Phase 5 완료 통계·5회 성향 갱신·LLM Catalog·요약 API, 실제 Oracle 3개와 Backend 전체 170개 검증 완료 |
| 2026-08-20 | 랜덤 미션 V1 Phase 4 선택·취소·교체·완료 API, Oracle 상태·로그·Rollback, OpenAPI와 Backend 전체 153개 검증 완료 |
| 2026-08-20 | 랜덤 미션 V1 Phase 3 설정·오늘 후보 API, Oracle 저장·재사용·Rollback, OpenAPI와 Backend 전체 140개 검증 완료 |
| 2026-08-20 | 랜덤 미션 V1 Phase 2 집중 테스트 21개, 실제 Oracle 포함 Backend 전체 129개와 Package 재검증 완료 |
| 2026-08-19 | 랜덤 미션 V1 Phase 2 순수 Java 추천 Domain, 정상·주요 실패 시나리오, 실제 Oracle 회귀와 Backend Package 검증 완료 |
| 2026-08-19 | 랜덤 미션 V1 Phase 1 실제 Oracle 멱등 Migration, 정상·19개 실패 Constraint, Rollback과 Backend 전체 회귀 검증 완료 |
| 2026-08-19 | 랜덤 미션 V1 Phase 0 정상·실패 계약 정적 검사, Backend 114개·Flutter 68개 회귀 테스트 완료 |
| 2026-08-19 | 랜덤 미션 V1 Phase 0 SDD 작성, 후보·하루 한도·추천 점수·상태·REST·Oracle 계약 확정 및 검증 시작 |
| 2026-08-19 | 사용자 성향 분석 V2 Phase 7 실제 Flutter·Spring Boot·Oracle E2E, 실패 시나리오, Oracle 직접 조회와 전체 회귀 검증 완료 |
| 2026-08-19 | 사용자 성향 분석 V2 Phase 6 전체 Profile·재접속 복원·재분석 성공/실패와 정상·실패 시나리오 검증 완료 |
| 2026-08-19 | 사용자 성향 분석 V2 Phase 5 여섯 문항 UI·Validation·제출 잠금·동일 키 재시도와 정상·실패 시나리오 검증 완료 |
| 2026-08-19 | 사용자 성향 분석 V2 Phase 4 Flutter API·사용자 키 캐시·앱 시작 분기와 정상·실패 시나리오 검증 완료 |
| 2026-08-19 | 사용자 성향 분석 V2 Phase 3 저장·조회 API, 멱등·상태 충돌·실제 Oracle Rollback과 OpenAPI 검증 완료 |
| 2026-08-19 | 사용자 성향 분석 V2 Phase 2 순수 Domain, 9개 유형, 네 축 점수와 정상·실패 시나리오 검증 완료 |
| 2026-08-19 | 사용자 성향 분석 V2 Phase 1 Oracle Schema 적용, 멱등성·정상·실패 시나리오 검증 완료 |
| 2026-08-19 | 사용자 성향 분석 V2 Phase 0 정상·실패 계약과 기존 회귀 테스트 검증 완료 |
| 2026-08-19 | 사용자 성향 분석을 `PERSONALITY_V2`로 재정의하고 Phase 0 완료·Phase 1~7 미착수로 재설정 |
| 2026-08-19 | 최초 작성. 현재 구현과 SDD 기록을 활성 사양 기준으로 재분류 |
