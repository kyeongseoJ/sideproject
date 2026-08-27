# Mission V1 Phase 5 검증 기록

- 검증일: 2026-08-24
- 기준 문서: `SDD/v1/mission-sdd.md`
- 범위: 완료 통계·매 완료 성향 갱신·5회 LLM 생성 격리·요약 API
- 결과: 검증 완료

## 구현 범위

- 완료 상태, 연결 로그, 카테고리 통계와 전체 완료 횟수의 단일 Transaction 저장
- `USER_MISSION_CATEGORY_STAT` 카테고리별 누적 수와 최근 완료 시각 갱신
- 매 완료 시 해당 완료 미션 벡터와 현재 성향 혼합
- 매 완료마다 네 축 갱신, `PERSONALITY_CODE` 재분류와 `LAST_MISSION_ADAPTED_COUNT` 기록
- Profile API의 축 enum과 유형을 갱신된 현재 점수에서 일관되게 복원
- 완료 재요청 시 상태·로그·통계·성향·LLM 중복 적용 차단
- 완료 Transaction 이후 LLM 생성 시도와 장애 격리
- 성향 거리 0.5 미만, 제목·내용 중복, 문자 bigram Jaccard 0.65 이상 결과 차단
- 검증된 LLM 미션을 공유 Oracle `MISSION` Catalog에 저장
- 사용자·완료 마일스톤별 최초 Claim만 허용
- `GET /api/missions/summary`와 완료 응답의 누적 통계 제공

## 정상 시나리오

1. 일반 완료는 해당 카테고리와 전체 완료 횟수를 한 번 증가시킨다.
2. 모든 완료는 해당 미션 벡터를 반영하고 성향 유형을 다시 분류하며, 5번째 완료는 추가로 LLM 생성을 시도한다.
3. OpenAI가 설정되지 않아도 완료는 성공하며 LLM 상태는 `NOT_CONFIGURED`다.
4. 검증된 LLM 결과는 공유 Catalog에 `LLM` 출처로 한 번 저장된다.
5. 요약 API는 전체 완료 수, 마지막 성향 반영 횟수, 성향 코드와 카테고리 통계를 반환한다.

## 주요 실패 시나리오

- 사용자 키 누락·불일치: `401 INVALID_USER_KEY`
- 성향 Profile 없음: `409 PERSONALITY_REQUIRED`
- 최근 완료 이력과 완료 횟수 불일치: 상태·로그·통계·Profile 전체 Rollback
- 완료 재요청: 성공 응답을 반환하지만 모든 누적값과 로그 불변
- OpenAI 미설정: 완료 유지, `NOT_CONFIGURED`
- OpenAI·Repository 예외: 완료 유지, `FAILED`
- 이미 처리한 마일스톤: 새 호출·미션 없이 `ALREADY_PROCESSED`
- 사용자 성향과 너무 가까운 결과: `REJECTED_TOO_CLOSE`
- 기존 미션과 너무 유사한 결과: `REJECTED_SIMILAR`
- Database 조회 실패: 민감정보 없는 `500 MISSION_PROCESSING_FAILED`

## 검증 결과

| 검증 | 결과 |
|---|---|
| 일일 추천·완료·성향·5회 LLM 경계 집중 테스트 | 22개 성공 |
| 실제 Oracle Schema 멱등 적용·성향 반영 횟수 무결성 | 1개 성공 |
| Backend 전체 테스트 | 190개 실행, 실패 0, 오류 0, 조건부 12개 제외 |
| Flutter 전체 테스트 | 88개 성공, 조건부 1개 제외 |
| Flutter Analyze·Web Build | 성공 |
| Backend Package | 성공, `back/target/back-0.0.1-SNAPSHOT.jar` 생성 |

실제 Oracle 테스트 데이터는 Transaction Rollback 후 기준 테이블 건수가 동일함을 확인했다. 새 Library는 추가하지 않았고, `LAST_MISSION_ADAPTED_COUNT`의 기존 5회 배수 제약은 매 완료 반영 정책에 맞게 전체 완료 수 이하만 허용하도록 개정했다.

실제 OpenAI 네트워크 호출은 회귀 테스트에서 실행하지 않았다. `OPENAI_API_KEY` 설정 존재 여부와 결정적 Test Generator를 이용한 5회 마일스톤, 중복·유사도 차단 및 공유 Catalog 저장 경로를 검증했다.
