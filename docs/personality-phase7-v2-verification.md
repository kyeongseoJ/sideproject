# 사용자 성향 분석 V2 Phase 7 검증 기록

검증일: 2026-08-19  
상태: 검증 완료

## 검증 범위

Flutter 선택폼에서 시작해 REST API, Spring Boot, Oracle 저장, 응답, Flutter Profile 표시까지 실제 실행 환경으로 검증했다. 최초 분석, 재접속 복원, 멱등 재시도, 충돌, 재분석, 잘못된 사용자 키와 잘못된 답변을 포함한다. 시간 질문, 미션 생성, OpenAI, 3D World는 이 Phase에서 변경하지 않았다.

## 실제 E2E 결과

- 실행 방식: Flutter Web release + ChromeDriver + Spring Boot `8081` + Oracle XE
- 실행 옵션: 외부 CDN이 차단된 환경이므로 `--no-web-resources-cdn` 사용
- 결과: `All tests passed.`
- 최초 사용자: Profile 없음 → 여섯 문항 선택폼 표시
- 최초 분석: `QUIET_FOCUSER` Profile 저장 및 화면 표시
- 복원: `GET /api/users/me` 결과로 선택폼을 건너뛰고 Profile 표시
- 멱등 재시도: 동일 제출 키와 동일 요청은 같은 분석 ID 반환
- 제출 키 충돌: 같은 키의 다른 답변은 `SUBMISSION_KEY_CONFLICT` 409
- 최초 분석 중복: 새 키의 `INITIAL`은 `PERSONALITY_ALREADY_ANALYZED` 409
- 재분석 전 요청: Profile이 없을 때 `REANALYSIS`는 `PERSONALITY_NOT_ANALYZED` 409
- 잘못된 답변: 관심 분야 0개는 `INVALID_PERSONALITY_ANSWERS` 400
- 재분석: `REANALYSIS` 후 현재 Profile이 `ACTIVE_CONNECTOR`로 교체
- 잘못된 사용자 키: `INVALID_USER_KEY` 401이며 요청 키 원문은 오류 메시지에 없음

## Oracle 직접 검증

완료된 E2E 사용자에 대해 `PersonalityPhase7FlutterOracleVerificationTest`가 다음을 직접 조회했다.

- `NOVELTY_USER`: 1행, 사용자 키는 64자 Hash로만 저장
- `SURVEY_RESPONSE`: 2행, `INITIAL` 1행 + `REANALYSIS` 1행
- V2 설문: `ANALYSIS_VERSION=PERSONALITY_V2`, `ENERGY_LEVEL IS NULL`, 신체 활동 컬럼 저장
- `SURVEY_INTEREST`: 원본 분석별 관심 분야 총 2행
- `USER_PERSONALITY_PROFILE`: 현재 Profile 1행, 최종 유형 `ACTIVE_CONNECTOR`
- 현재 Profile의 `SOURCE_SURVEY_ID`: 재분석 원본을 가리킴
- `USER_PROFILE_INTEREST`: 현재 관심 분야 `MOVEMENT` 1행
- 기존 V1 `ENERGY_LEVEL` 데이터: 4행 보존

출력 증거는 `PHASE7_ORACLE_VERIFICATION=PASS`와 `PHASE7_ORACLE_CLEANUP=PASS`이며, 검증용 사용자는 확인 후 삭제했다. 실패 실행에서 생성된 분석 전 임시 사용자도 의존 행이 없음을 확인한 뒤 삭제했다.

## 주요 실패 시나리오

| 시나리오 | 기대 결과 | 결과 |
|---|---|---|
| 관심 분야 누락 | 400, Oracle 미저장 | 통과 |
| 유효하지 않은 사용자 키 | 401, Secret 비노출 | 통과 |
| Profile 없는 사용자의 재분석 | 409 | 통과 |
| 분석 완료 사용자의 추가 `INITIAL` | 409 | 통과 |
| 동일 제출 키의 다른 요청 | 409, 기존 데이터 유지 | 통과 |
| 저장 중 장애 | 요청 전체 Rollback | Phase 3 실제 Oracle 회귀 테스트 통과 |
| 재분석 실패 | 기존 Profile 유지 | Backend·Flutter 회귀 테스트 통과 |

## AC-01~AC-14 판정

| 인수 조건 | 판정 | 근거 |
|---|---|---|
| AC-01 최초 1회 분기 | 충족 | 최초 폼과 복원 Profile E2E |
| AC-02 여섯 문항 계약 | 충족 | 실제 V2 요청·Oracle 2개 원본 |
| AC-03 의미가 분리된 네 축 | 충족 | V2 컬럼 직접 조회와 Domain 테스트 |
| AC-04 9개 유형 결정성 | 충족 | Phase 2 전체 조합 회귀 테스트 |
| AC-05 입력 검증 | 충족 | 400 E2E와 Backend Validation 테스트 |
| AC-06 원자적 저장 | 충족 | Phase 3 실제 Oracle Rollback 회귀 테스트 |
| AC-07 멱등 재시도 | 충족 | 동일 분석 ID와 원본 2행 유지 E2E |
| AC-08 명시적 재분석 | 충족 | `REANALYSIS` 원본 추가·현재 Profile 교체 |
| AC-09 재분석 실패 안전성 | 충족 | Backend·Flutter 실패 회귀 테스트 |
| AC-10 Profile 조회 | 충족 | 실제 `GET /api/users/me` 복원 |
| AC-11 기존 데이터 보존 | 충족 | V1 `ENERGY_LEVEL` 4행 직접 확인 |
| AC-12 Secret 비노출 | 충족 | Hash 저장, `<redacted>` 로그, 안전 오류 응답 |
| AC-13 Swagger 검증 | 충족 | Swagger UI 200 및 OpenAPI 필수 경로 확인 |
| AC-14 범위 격리 | 충족 | Phase 7에서 시간·미션·OpenAI·3D 기능 변경 없음 |

## 전체 회귀 검증

- Backend: `mvn package`, 114개 실행, 실패 0, 오류 0, 조건부 Phase 7 검증 1개 제외
- 실제 Oracle 통합 테스트: Phase 1·3 포함 통과
- Flutter: `flutter analyze` 문제 없음
- Flutter: 전체 테스트 68개 통과
- Flutter Web release build: 성공
- Swagger UI: HTTP 200
- OpenAPI: `/api/personality-analyses`, `/api/users/me`, `/api/users/anonymous` 확인

## 확인된 도구·환경 이슈

- 프로젝트의 `mvnw.cmd`는 PowerShell 내부 오류로 실행되지 않아 캐시된 Maven 3.9.16을 직접 사용했다.
- Flutter Web debug는 외부 CanvasKit CDN 차단과 DWDS 연결 문제로 안정적으로 완료되지 않았다. release 모드와 `--no-web-resources-cdn`으로 실제 E2E를 통과했다.
- 브라우저에서 `/v3/api-docs`를 직접 호출하면 Swagger 리소스의 CORS 때문에 실패하므로 Swagger는 Backend 주소에서 별도 HTTP 검증했다. 앱 런타임 API CORS와는 무관하다.
- Maven은 Mockito 동적 Java Agent의 향후 제한을 경고했다.
- Flutter는 호환 범위 밖의 새 패키지 8개, PWA 옵션 폐기 예정, 미포함 CupertinoIcons 폰트를 경고했다. 현재 Analyze, Test, Build 결과에는 영향이 없다.

