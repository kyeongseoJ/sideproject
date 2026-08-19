# Novelty 프로젝트 진행 상태

최종 갱신일: 2026-08-19

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

## 핵심 기능 요약

| 핵심 기능 | 현재 상태 | SDD 상태 | 실제 구현 판단 |
|---|---|---|---|
| 1. 선택지 폼 | 검증 완료 | V2 Phase 5~7 완료 | 여섯 문항·검증·제출 재시도와 실제 Oracle E2E 완료 |
| 2. 사용자 성향 분석 | 검증 완료 | V2 Phase 0~7 완료 | Backend 계약과 Flutter 최초 분기·선택폼·Profile·재분석·Oracle E2E 완료 |
| 3. 랜덤 미션 생성 | 진행 중 | 정식 기능 SDD 미작성 | Backend 추천 프로토타입은 있으나 Frontend 선택 흐름과 전체 정책 검증이 미완성 |
| 4. 3D 공간·레벨 | 진행 중 | 정식 기능 SDD 미작성 | Three.js 렌더러 기반 모듈만 있으며 자산·Backend 진행도·화면 통합은 미완성 |

## SDD Phase 현황표

`부분`은 관련 코드나 Schema가 있더라도 해당 Phase의 현재 인수 조건을 모두 검증하지 못했다는 뜻이다. `재정의`는 과거 Phase 기록이 있으나 개정 사양에 맞춰 범위와 인수 조건을 다시 정해야 한다는 뜻이다.

| 핵심 기능 | Phase 0 | Phase 1 | Phase 2 | Phase 3 | Phase 4 | Phase 5 | Phase 6 | Phase 7 |
|---|---|---|---|---|---|---|---|---|
| 선택지 폼(현재 흐름) | 성향 SDD에 포함 | 재정의 | 재정의 | 재정의 | 재정의 | 검증 완료 | 검증 완료 | 검증 완료 |
| 사용자 성향 분석 V2 | 검증 완료 | 검증 완료 | 검증 완료 | 검증 완료 | 검증 완료 | 검증 완료 | 검증 완료 | 검증 완료 |
| 랜덤 미션 | SDD 필요 | 미착수 | 미착수 | 미착수 | 미착수 | 미착수 | 미착수 | 미착수 |
| 3D 공간·레벨 | SDD 필요 | 미착수 | 미착수 | 미착수 | 미착수 | 미착수 | 미착수 | 미착수 |

선택지 폼의 기존 Phase 0~7은 과거 계약 기준으로는 완료됐지만 현재 흐름에서는 모두 현재 인수 조건을 다시 확인해야 한다. 이 표는 앞으로 각 Phase 작업이 끝날 때 검증 근거와 함께 갱신한다.

## 1. 선택지 폼

현재 상태: **검증 완료**

- 과거 기준 문서: `docs/survey-phase0-spec.md`, `docs/survey-phase7-completion.md`
- 과거의 Phase 0~7 완료는 기존 에너지 질문을 포함한 설문 저장 계약에 대한 기록이다.
- 현재 유효한 흐름은 최초 1회 성향 분석, 결과 표시, 할애 가능 시간 질문의 순서이므로 과거 완료 기록은 현재 사양의 완료 근거로 사용하지 않는다.
- Flutter에는 선택지 화면과 REST 호출 코드가 있고 Backend에는 Oracle 저장 API가 있다.
- V2 익명 사용자 식별과 제출 계약 및 개정된 여섯 문항 선택폼이 연결됐다.

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
- Backend 사용자 프로필 응답은 저장된 성향 유형, 네 축, 실행 방식, 관심 분야, 버전과 분석 시각을 반환한다.
- 기존 `activityLevel`은 실내·실외 의미여서 V2에서 `indoorOutdoor`로 명확히 하고 별도 `physicalActivityLevel` 문항을 추가한다.
- V2 범위는 성향 분석과 Profile 및 재분석까지다. 시간 질문, 미션 생성, OpenAI와 World는 제외한다.

성향 분석 V2의 Phase 0~7 완료 조건을 모두 충족했다. 이후 변경은 별도 SDD 개정으로 관리한다.

## 3. 랜덤 미션 생성·선택·완료

현재 상태: **진행 중(프로토타입)**

- 정식 Phase 0 SDD 문서가 아직 없다.
- Backend에는 미션 속성, 성향 거리 기반 추천, 상태 로그, 완료 횟수 기반 LLM 생성 코드와 테스트가 일부 존재한다.
- 초기 기본 미션 데이터와 관련 Oracle DDL이 준비되어 있다.
- Flutter에는 추천 목록, 선택, 취소, 완료를 연결한 핵심 화면 흐름이 없다.
- 최근 완료 3일, 최근 노출 2일, 동일 카테고리 연속 제한, 하루 수행 제한, 유사 미션 차단, 완료 5회 단위 LLM 생성 정책은 현재 코드와 DB에서 전부 검증 완료되지 않았다.
- 신규 사용자에게 성향 프로필이 생성되지 않으면 정상 추천 흐름에 진입할 수 없다.

다음 완료 조건:

1. 미션 기능 Phase 0 SDD와 REST 계약을 먼저 작성한다.
2. 추천 후보 수, 하루 제한, 취소·교체 정책 등 미확정 항목을 확정한다.
3. Oracle 적용, 동시성, 재노출 제한과 상태 전이를 검증한다.
4. Flutter까지 연결한 E2E를 수행한다.

## 4. 3D 공간·레벨 시스템

현재 상태: **진행 중(기반 구조)**

- 정식 Phase 0 SDD 문서가 아직 없다.
- `front/world3d`에 GLB 로드, Camera, Lighting, Object placement, Level model switching, Simple animation 모듈이 있다.
- `front/app`에는 World 기능 경계를 위한 구조가 있으나 완성된 사용자 화면과 통합 흐름은 없다.
- `WORLD_OBJECT`, `WORLD_OBJECT_LEVEL`, `USER_WORLD_OBJECT` 목표 Schema는 SQL에 준비되어 있으나 실제 Oracle 적용은 확인되지 않았다.
- 실제 GLB 자산, 미션 완료와 성장 경험치의 매핑, 레벨 전환 API, Flutter와 Three.js 통합은 미완성이다.

다음 완료 조건:

1. World 기능 Phase 0 SDD를 작성하고 성장·레벨 규칙을 확정한다.
2. GLB 자산 규약과 Flutter bundle 또는 CDN 배포 방식을 확정한다.
3. Backend 진행도 API와 Oracle Schema를 구현·적용한다.
4. 미션 완료부터 3D 오브젝트 성장까지 E2E로 검증한다.

## 공통 기반 상태

| 영역 | 상태 | 비고 |
|---|---|---|
| 익명 사용자·닉네임 | 진행 중 | Backend·DB와 Flutter 사용자 키 캐시 복원 완료, 닉네임 변경 UI는 미완성 |
| Oracle Personality V2 Schema | 검증 완료 | 로컬 Oracle에 Phase 1 적용 및 재실행 성공. 기존 V1 설문 4건 보존 |
| Oracle Mission·World 목표 Schema | 진행 중 | SQL은 준비됐으나 이번 Phase에서 실제 객체 상태를 검증하지 않음 |
| Swagger UI | 검증 완료 | 실제 서버에서 UI 200과 성향 API OpenAPI 경로 확인. 기본 주소 `http://localhost:8080/swagger-ui/index.html` |
| OpenAI 설정 | 진행 중 | API Key는 `OPENAI_API_KEY` 환경 변수로만 주입; 실제 연동 성공 검증 필요 |
| Backend 자동 테스트 | 검증 완료 | Phase 1·3 실제 Oracle 통합 Test를 포함한 전체 114개 실행, 실패 0, 오류 0, 조건부 Phase 7 검증 1개 제외 |
| Three.js Build | 검증 완료 | 최근 Build 성공, 번들 크기 500KB 초과 경고 존재 |
| Flutter 자동 테스트 | 검증 완료 | Phase 6 집중 테스트 26개, Flutter 전체 테스트 68개 통과 |
| Flutter 성향 분석 흐름 | 검증 완료 | 최초 분석·복원·멱등 재시도·재분석과 Oracle 직접 조회 E2E 완료 |
| Flutter 전체 사용자 흐름 | 진행 중 | 성향 분석 이후 시간 질문·미션 생성·World 연결 E2E 미완성 |

## 권장 진행 순서

1. 미션 기능 Phase 0 SDD를 작성한 뒤 추천·선택·완료를 연결한다.
2. World 기능 Phase 0 SDD를 작성한 뒤 미션 완료와 공간 성장을 연결한다.

## 상태 갱신 규칙

- Phase 시작, 완료, 실패 또는 보류 시 이 문서를 같은 작업에서 갱신한다.
- 완료 표기에는 확인한 날짜, 명령 또는 E2E 증거를 남긴다.
- 코드나 테이블 파일이 존재하는 것과 기능 완료를 구분한다.
- 이전 사양을 대체하는 정책이 생기면 이전 완료 상태를 `대체됨`으로 바꾼다.
- 장애나 외부 설정 문제는 숨기지 않고 `차단` 또는 비고에 기록한다.
- 새 기능 구현 전에 `AGENTS.md`, `SPEC.md`, 이 문서, 관련 SDD 및 실제 코드를 함께 확인한다.

## 변경 이력

| 날짜 | 변경 내용 |
|---|---|
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
