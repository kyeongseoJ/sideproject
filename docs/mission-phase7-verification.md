# 랜덤 미션 V1 Phase 7 검증

검증일: 2026-08-20

## 실제 E2E

최신 Backend를 8081에 임시 실행하고 다음 흐름을 실제 로컬 Oracle XE와 연결했다.

```text
Flutter UI → REST → Spring Boot → Oracle → Response → Flutter UI
```

익명 사용자 생성, 최초 성향 분석, 시간·하루 한도 저장, 후보 생성, 선택, 완료, 요약 갱신을 확인했다. 잘못된 사용자 키는 `401 INVALID_USER_KEY`이며 입력 키가 오류 메시지에 노출되지 않음을 확인했다.

## Oracle 직접 검증

- `USER_MISSION_SETTING` 1건
- `USER_MISSION` 완료 상태 1건
- `MISSION_STATUS_LOG` 완료 로그 1건
- `USER_MISSION_CATEGORY_STAT` 합계 1건
- `USER_PERSONALITY_PROFILE.COMPLETED_MISSION_COUNT` 1
- 검증 사용자와 종속 테스트 데이터 정리 성공

## 전체 회귀

- Flutter 전체 테스트 80개: 통과
- Flutter 정적 분석: 통과
- Flutter Web Build: 통과
- Backend 전체 171개: 실패 0, 오류 0, 환경 조건부 10개 제외
- Backend Package: 통과
- Phase 7 Oracle 검증 테스트 1개: 통과

## 실행 중 확인한 실패

- 기존 8080은 다른 서비스가 사용 중이어서 최신 Novelty Backend를 8081에 분리 실행했다.
- Windows 대상 미구성 및 WebDriver 미설치로 장치 기반 integration 실행은 불가했다. 동일 Flutter Widget·REST 코드를 Flutter 테스트 VM에서 실제 Backend·Oracle과 연결해 검증했다.
- 테스트 환경의 Noto Sans KR 런타임 캐시 Plugin 경고는 네트워크 폰트 로딩을 비활성화해 격리했으며 기능 E2E 결과에는 영향이 없었다.
