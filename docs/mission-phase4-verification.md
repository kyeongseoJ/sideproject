# Mission V1 Phase 4 검증 기록

- 검증일: 2026-08-20
- 기준 문서: `docs/mission-sdd-v1.md`
- 범위: 사용자 미션 선택·취소·교체·완료 Backend API와 Oracle 상태 이력
- 결과: 검증 완료

## 구현 범위

- `POST /api/user-missions/{userMissionId}/select`
- `POST /api/user-missions/{userMissionId}/cancel`
- `POST /api/user-missions/{userMissionId}/replace`
- `POST /api/user-missions/{userMissionId}/complete`
- `X-User-Key` 소유권 확인과 다른 사용자 리소스의 `404` 처리
- 서울 서비스 날짜와 오늘 후보 여부 확인
- 사용자·설정·대상 사용자 미션 비관적 잠금
- `SHOWN`·`CANCELLED`에서 선택, `SELECTED`에서 취소·완료 상태 전이
- 하루 한도와 사용 가능한 활성 슬롯 검증
- 교체 시 기존 슬롯을 새 후보로 한 Transaction에서 이전
- 완료 재요청 멱등 처리와 중복 로그 차단
- 상태 변경마다 `MISSION_STATUS_LOG.USER_MISSION_ID`, 이전 상태와 변경 이유 저장
- 오늘 `SELECTED + COMPLETED`보다 낮은 수행 한도 저장 차단

기존 `/api/missions/random`과 범용 상태 변경 API는 기존 호출 호환을 위해 유지했다. 신규 흐름은 `/api/user-missions/**`를 기준으로 한다. 완료 카테고리 통계·성향 완료 횟수·LLM 연결은 Phase 5 범위이므로 이번 단계에서 변경하지 않았다.

## 정상 시나리오

1. 오늘 노출된 후보를 선택하면 첫 빈 슬롯에 `SELECTED`로 저장된다.
2. 수행 중 미션을 취소하면 슬롯이 해제되고 같은 후보를 다시 선택할 수 있다.
3. 수행 중 미션을 오늘의 다른 후보로 교체하면 기존 미션은 `CANCELLED`, 새 후보는 같은 슬롯의 `SELECTED`가 된다.
4. 수행 중 미션을 완료하면 `COMPLETED`가 되고 해당 슬롯은 오늘 한도를 계속 점유한다.
5. 동일 완료 요청을 재전송하면 성공 응답의 `idempotent`가 참이며 새 로그가 생성되지 않는다.
6. 각 응답에 변경된 미션과 갱신된 오늘 상태가 함께 반환된다.

## 주요 실패 시나리오

- 0 이하 ID, 잘못된 교체 Body: `400 INVALID_MISSION_REQUEST`
- 사용자 키 누락·불일치: `401 INVALID_USER_KEY`
- 없거나 다른 사용자의 사용자 미션: `404 USER_MISSION_NOT_FOUND`
- 하루 슬롯 초과 또는 점유 수보다 낮은 한도 변경: `409 DAILY_LIMIT_REACHED`
- 허용하지 않는 취소·완료 상태 전이: `409 INVALID_MISSION_TRANSITION`
- 다른 날짜·완료 상태·부적합 후보로 교체: `409 REPLACEMENT_NOT_AVAILABLE`
- Database 또는 예기치 않은 내부 오류: 민감정보 없는 `500 MISSION_PROCESSING_FAILED`
- 교체나 로그 저장 실패: Transaction 전체 Rollback

## 검증 결과

| 검증 | 결과 |
|---|---|
| Phase 4 Service·Controller·OpenAPI 및 Phase 3 회귀 집중 테스트 | 32개 성공, 실패 0 |
| 실제 Oracle 상태 전이·로그·제약조건·Rollback 통합 테스트 | 1개 성공 |
| Backend 전체 테스트 | 153개 실행, 실패 0, 오류 0, 조건부 1개 제외 |
| Backend Package | 성공, `back/target/back-0.0.1-SNAPSHOT.jar` 생성 |

실제 Oracle 통합 테스트는 임시 사용자와 성향 Profile을 생성하고 후보 추천부터 선택·취소·재선택·교체·완료·완료 재요청까지 수행했다. 테스트 Transaction을 Rollback한 뒤 기준 데이터 건수가 동일함을 확인했다. 새 Library는 추가하지 않았다.

## 남은 범위

- Phase 5: 완료 카테고리 통계, 성향 완료 횟수와 5회 경계 LLM 연결
- Phase 6: Flutter 미션 설정·후보·수행 화면과 상태 변경 API 연결
- Phase 7: Flutter부터 Oracle까지 전체 E2E
