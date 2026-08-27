# 랜덤 미션 V1 Phase 2 검증 기록

> 이 문서는 최초 추천 Domain 검증 이력이다. 현재 추천 알고리즘은 `SDD/v1/mission-sdd.md`와 최신 테스트를 따른다.

## 검증 범위

Phase 2에서는 DB나 신규 REST 계약을 확장하지 않고, Spring과 분리해 반복 검증할 수 있는 순수 Java 추천 Domain을 구현했다.

- 비활성, 가용 시간 초과, LLM 자격 미달 후보 제외
- 최근 완료 3일 및 최근 노출 2일의 Asia/Seoul 달력 날짜 필터
- 성향 거리 70%, 카테고리 탐색 20%, 난이도 적합 10% 점수
- 추천 점수 상위 10개 중 최대 5개 가중 무복원 추출
- 서로 다른 카테고리 우선 및 최근 수행 카테고리 후순위
- 고정 `Clock`과 난수 Seed를 이용한 결정적 테스트

기존 단일 미션 API 내부도 새 추천 정책의 첫 결과를 사용하도록 연결했다. 사용자별 카테고리 완료 통계와 다중 후보 저장·응답은 Phase 3 범위다.

## 정상 시나리오

- 문서화한 세 가중치와 `1 / (1 + 완료 횟수)` 탐색 점수가 정확히 계산된다.
- 비활성 미션, 가용 시간 초과 미션과 완료 5회 미만 사용자의 LLM 미션이 제외된다.
- 완료 5회부터 공유 LLM 미션이 후보가 된다.
- 최근 완료·노출 금지 기간과 최근 수행 카테고리는 Asia/Seoul 달력 날짜로 계산되며 미래 로그는 현재 추천 판단에 포함하지 않는다.
- 후보는 최대 5개이며 가능한 동안 서로 다른 카테고리를 먼저 선택한다.
- 가장 최근 `SELECTED` 또는 `COMPLETED` 카테고리는 삭제하지 않고 후순위로 미룬다.
- 서로 다른 카테고리가 소진되면 동일 카테고리도 선택할 수 있다.
- 가중 추출은 추천 점수 상위 10개 안에서만 이루어진다.
- 같은 난수 Seed는 같은 무복원 선택 결과를 만든다.
- 적격 후보가 5개 미만이면 전부 반환하고, 적격 후보가 없으면 빈 목록을 반환한다.

## 주요 실패 시나리오

- Mission의 잘못된 ID, 빈 제목·설명, 길이 초과, 누락 Enum과 속성 범위를 거부한다.
- 추천 결과의 NaN·무한대·0~1 범위 밖 점수를 거부한다.
- 중복 Mission ID와 음수 카테고리 완료 횟수를 거부한다.
- 필수 입력과 이력의 null, 0 이하 Mission ID, 누락 필드 및 알 수 없는 카테고리를 거부한다.

최초 집중 테스트에서 null 이력 fixture를 `List.of(null)`로 생성해 Domain 진입 전에 JDK가 예외를 발생시키는 테스트 오류 1건이 있었다. `Collections.singletonList(null)`로 fixture를 수정한 뒤 의도한 Domain Validation까지 도달함을 확인했다.

## 실행 결과

- 집중 테스트: `MissionRecommendationPolicyTest`, `MissionTest`, `UserMissionVectorTest` 총 21개 성공
- Backend 전체 회귀: 총 129개 실행, 실패 0, 오류 0, 조건부 테스트 1개 제외
- Phase 1 실제 Oracle 통합 회귀: 성공, 테스트 생성 데이터 Rollback 및 기준 행 수 유지
- Backend Package: 성공, `target/back-0.0.1-SNAPSHOT.jar` 생성

Maven Wrapper의 기존 PowerShell 실행 오류 때문에 로컬 Maven Wrapper Cache의 Maven 3.9.16 실행 파일을 사용했다. Mockito/Byte Buddy 동적 Agent 경고는 남지만 테스트 실패나 Package 실패는 발생하지 않았다.

최종 집중 테스트의 첫 실행은 Sandbox 네트워크 제한으로 Spring Boot Parent POM 확인이 거부되어 실패했다. 같은 명령에 필요한 Maven 네트워크 권한을 적용해 재실행했으며 21개 테스트가 모두 통과했다. 이는 코드 실패가 아니라 의존성 Repository 접근 제한이었다.

## 판정

Phase 2의 정상 및 주요 실패 시나리오는 모두 통과했다. 다음 단계는 Phase 3의 다중 추천 REST·Service·Oracle 통합이다.

## 재검증 이력

- 2026-08-20: 집중 테스트 21개 성공
- 2026-08-20: 실제 Oracle 통합 테스트를 포함한 Backend 전체 129개 성공, 조건부 테스트 1개 제외
- 2026-08-20: Backend 실행 JAR Package 성공
