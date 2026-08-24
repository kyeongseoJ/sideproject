# 랜덤 미션 V1 Phase 3 검증 기록

> 이 문서의 최대 5개 후보 내용은 당시 구현 이력이다. 현재 Runtime은 `MISSION_V1.1`에 따라 최대 3개 후보를 저장·복원한다.

## 구현 범위

Phase 3에서는 설정과 오늘 추천 후보 Backend 흐름을 실제 Oracle까지 연결했다.

- `GET /api/missions/settings`: 미션 설정 조회
- `PUT /api/missions/settings`: 사용 가능 시간과 하루 한도 1~3 저장
- `GET /api/missions/today`: 서울 날짜 기준 설정, 완료 수, 남은 슬롯, 수행 중 미션과 후보 조회
- `POST /api/missions/today/recommendations`: 최대 5개 후보 최초 생성 또는 기존 후보 재사용
- 사용자 행 `FOR UPDATE` 잠금으로 같은 사용자·날짜의 후보 생성을 직렬화
- 사용자별 카테고리 완료 통계를 Phase 2 추천 점수에 연결
- `USER_MISSION`에 거리와 최종 추천 점수를 저장
- 후보별 `GENERATED → SHOWN` 로그를 `USER_MISSION_ID`와 연결해 같은 Transaction에 저장
- 최초 생성은 HTTP 201, 기존 후보 재사용은 HTTP 200
- Swagger/OpenAPI 경로와 주요 응답 코드 노출

Phase 4 범위인 선택·취소·변경·완료 API는 구현하지 않았다. 기존 `/api/missions/random`과 범용 상태 API도 호환을 위해 유지했다.

## 정상 시나리오

- 설정을 최초 저장하거나 다시 저장하면 같은 사용자 행이 생성 또는 갱신된다.
- 설정과 오늘 상태는 `X-User-Key`의 소유 사용자 범위로 조회된다.
- 성향 Profile과 설정이 있는 사용자는 필터를 통과한 후보를 최대 5개 받는다.
- 후보에는 `userMissionId`, Catalog 속성, 성향 거리, 추천 점수, 상태와 상태 시각이 포함된다.
- 최초 추천 후보와 상태 로그가 한 Transaction으로 Oracle에 저장된다.
- 같은 서울 날짜의 두 번째 추천 요청은 새 후보나 로그를 만들지 않고 기존 `userMissionId` 목록을 반환한다.
- 사용자별 카테고리 완료 횟수가 추천 Domain으로 전달된다.
- 실제 Oracle 검증 데이터는 테스트 종료 시 Rollback되어 기준 행 수가 유지된다.

## 주요 실패 시나리오

- 시간 누락, 알 수 없는 Enum, 하루 한도 0·4와 malformed JSON은 `400 INVALID_MISSION_REQUEST`로 처리한다.
- 사용자 키 누락·불일치는 `401 INVALID_USER_KEY`로 처리한다.
- 설정 누락은 `409 MISSION_SETTINGS_REQUIRED`로 처리한다.
- 성향 Profile 누락은 `409 PERSONALITY_REQUIRED`로 처리한다.
- 적격 후보가 없으면 `409 NO_MISSION_AVAILABLE`로 처리한다.
- Database, Transaction과 내부 상태 오류는 상세 내용을 노출하지 않고 `500 MISSION_PROCESSING_FAILED`로 처리한다.
- 후보 생성 중 실패하면 설정 이외의 일부 후보·로그가 남지 않도록 Transaction Rollback을 사용한다.

## 검증 결과

- Phase 3 집중 테스트: Service 5개, Controller 4개, OpenAPI 1개와 기존 추천 Domain 19개를 포함해 총 29개 성공
- 실제 Oracle Phase 3 통합 테스트: 1개 성공
- Backend 전체 회귀: 총 140개 실행, 실패 0, 오류 0, 조건부 테스트 1개 제외
- Backend Package: 성공
- 실행 JAR: `back/target/back-0.0.1-SNAPSHOT.jar`

Mockito/Byte Buddy 동적 Agent 경고는 남지만 테스트와 Package 결과에는 영향을 주지 않았다. 새 Library는 추가하지 않았다.

## 판정

Phase 3의 정상 및 주요 실패 시나리오는 모두 통과했다. 다음 단계는 Phase 4의 `userMissionId` 기반 상태 변경 API다.
