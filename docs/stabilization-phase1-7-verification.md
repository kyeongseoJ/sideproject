# 핵심 기능 1~3 안정화 Phase 1~7 검증 기록

- 검증일: 2026-08-20
- 범위: 선택지 폼, 성향 분석, 미션 추천·선택·취소·교체·완료
- 결과: 코드 안정화와 로컬 Build 검증 완료

## Phase별 적용 결과

1. Mission 레거시 API 제거
   - `POST /api/missions/random` 제거
   - `PATCH /api/missions/{missionId}/status` 제거
   - 전용 DTO, Service, Repository와 상태 로그 조회 경로 제거
2. 완료 경로 통합
   - `UserMissionService.complete(userMissionId)`를 유일한 완료 경로로 유지
   - `USER_MISSION`, 로그, 카테고리 통계와 성향 후처리의 단일 Transaction 및 재요청 멱등성 회귀 검증
   - LLM 생성은 기존 정책대로 커밋 이후 장애 격리
3. Survey와 Personality 역할 정리
   - 구형 Survey Frontend·Backend 런타임과 전용 테스트 도구 제거
   - 원본 선택지는 Personality 경로가 `SURVEY_RESPONSE`, `SURVEY_INTEREST`에 저장
   - 현재 성향은 Personality Profile 테이블에서 관리
4. Dead Code와 Category 계약 정리
   - 호출되지 않는 Mission 상태 조회·응답 경로 제거
   - 8개 Category Code를 Backend와 Flutter 테스트로 고정
5. Database 기준 파일 정리
   - `USER_MISSION_SEQ`, `USER_MISSION`, 관련 FK와 Index의 중복 정의 제거
   - `DB.sql`과 Backend Schema SQL의 완전 일치 확인
   - World 테이블의 기능·컬럼은 변경하지 않음
6. Swagger 정리
   - 공식 설정·추천·UserMission API 노출 확인
   - 구형 Survey·random·직접 상태 변경 API 미노출 확인
7. 전체 검증과 문서 동기화
   - SPEC, PROJECT_STATUS, AGENTS, README와 활성 SDD 갱신

## 검증 명령과 결과

| 명령 | 결과 |
|---|---|
| `.\mvnw.cmd test` | 성공, 162개 실행, 실패·오류 0, 환경 조건부 10개 제외 |
| `.\mvnw.cmd package` | 성공, `back/target/back-0.0.1-SNAPSHOT.jar` 생성 |
| `flutter analyze` | 성공, 문제 0 |
| `flutter test --no-pub` | 성공, 70개 통과, 환경 조건부 1개 제외 |
| `flutter build web --no-pub --dart-define=API_BASE_URL=http://localhost:8080` | 성공 |
| `npm.cmd run build` (`front/world3d`) | 성공, 500KB 초과 Chunk 경고 |
| `fc.exe /N DB.sql back\src\main\resources\db\survey-schema.sql` | 차이 없음 |

## 미실행·경고

- 이번 작업에서는 `RUN_ORACLE_INTEGRATION=true`, `DB_USERNAME`, `DB_PASSWORD`가 설정되지 않아 실제 Oracle 조건부 테스트 10개가 실행되지 않았다. SQL 정리는 최종 Schema 의미를 바꾸지 않는 중복 제거이며 실제 Oracle 적용 성공으로 기록하지 않는다.
- Flutter Web Build에서 미포함 CupertinoIcons 폰트 경고가 있었지만 Build는 성공했다.
- Mockito의 동적 Java Agent 로딩은 향후 JDK에서 제한될 수 있다는 경고가 있으나 현재 테스트 실패는 아니다.
- World EXP와 3D 기능은 구현하지 않았으며 다음 World SDD 범위다.
