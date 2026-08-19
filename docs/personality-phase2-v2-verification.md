# 사용자 성향 분석 V2 Phase 2 검증 기록

- 검증일: 2026-08-19
- 대상: Oracle, Spring, REST에 의존하지 않는 순수 Java 성향 Domain
- 분석 버전: `PERSONALITY_V2`
- 결과: 검증 완료

## 구현 범위

- 여섯 문항의 답변 Enum과 불변 입력 Model
- 실내·실외, 사회성, 신체 활동, 새로움의 네 개 점수 축
- 실내·실외와 사회성 조합으로 결정되는 아홉 개 표시 유형
- 유형 코드, 한국어 이름과 요약
- 결정적인 분석 결과와 분석 버전
- 관심 분야 1~3개 및 모든 필수 답변의 Domain Validation
- 호출자가 입력 또는 결과의 관심 분야 목록을 변경하지 못하도록 방어적 복사

이번 Phase에는 REST DTO, Spring Bean, Oracle 저장, Flutter, Mission 해석을 포함하지 않았다.

## 정상 시나리오

| 시나리오 | 결과 |
|---|---|
| 실내·실외 3단계와 사회성 3단계의 9개 조합 | 모두 정의된 유형, 이름, 요약으로 분류 |
| 네 개 축의 모든 Enum 값 | 정의된 점수로 변환 |
| 보조 답변만 다른 동일 1·2번 축 | 동일한 표시 유형 유지 |
| 동일 입력 반복 분석 | 동일한 결과 반환 |
| 분석 버전 | `PERSONALITY_V2` 반환 |
| 호출자의 관심 분야 원본 목록 변경 | 입력과 분석 결과에 영향 없음 |
| 분석 결과의 관심 분야 변경 시도 | 변경 불가 |

정상 경로는 매개변수 조합을 포함해 25건을 검증했다.

## 주요 실패 시나리오

| 입력 오류 | Domain 오류 코드 | 결과 |
|---|---|---|
| 답변 객체 없음 | `ANSWERS_REQUIRED` | 거부 |
| 활동 공간 없음 | `INDOOR_OUTDOOR_REQUIRED` | 거부 |
| 사회적 활동 수준 없음 | `SOCIAL_LEVEL_REQUIRED` | 거부 |
| 신체 활동 수준 없음 | `PHYSICAL_ACTIVITY_LEVEL_REQUIRED` | 거부 |
| 새로움 수준 없음 | `NOVELTY_LEVEL_REQUIRED` | 거부 |
| 관심 분야가 null 또는 0개 | `INTERESTS_REQUIRED` | 거부 |
| 관심 분야 4개 이상 | `TOO_MANY_INTERESTS` | 거부 |
| 관심 분야에 null 포함 | `INVALID_INTEREST` | `NullPointerException` 없이 거부 |
| 관심 분야 중복 | `DUPLICATE_INTERESTS` | 거부 |
| 실행 방식 없음 | `EXECUTION_STYLE_REQUIRED` | 거부 |

실패 경로는 11건을 검증했다. 존재하지 않는 Enum 문자열은 순수 Java Domain에서 생성할 수 없으므로 Phase 3 REST JSON 역직렬화 실패 시나리오에서 검증한다.

## 실행 명령과 결과

Maven Wrapper의 기존 PowerShell 호환 문제를 우회하기 위해 로컬 Wrapper 배포본의 Maven 실행 파일을 사용했다.

```powershell
& 'C:\Users\6122\.m2\wrapper\dists\apache-maven-3.9.16\0daed3be3ebd1c706f0e69e8b07c6b73f5cc4ea3dfce72a8d0ec2e849ca2ddb0\bin\mvn.cmd' '-Dtest=PersonalityAnalyzerTest' test
& 'C:\Users\6122\.m2\wrapper\dists\apache-maven-3.9.16\0daed3be3ebd1c706f0e69e8b07c6b73f5cc4ea3dfce72a8d0ec2e849ca2ddb0\bin\mvn.cmd' clean test
```

- Phase 2 전용: 36개 통과, 실패 0, 오류 0, 제외 0
- Backend 전체: 86개, 실패 0, 오류 0, 제외 1
- 제외 1개: `RUN_ORACLE_INTEGRATION=true`일 때만 실행되는 Phase 1 실제 Oracle 통합 Test
- Build: 성공

전체 Test 실행 중 Mockito의 동적 Java Agent 로딩에 대한 향후 JDK 호환 경고가 출력됐지만 현재 Test 실패는 아니다. Phase 2에서는 새 Library를 추가하지 않았다.

## 완료 판단

Phase 2 인수 조건인 여섯 문항 검증, 네 축 점수, 아홉 유형 분류, DB 비의존 결정성을 모두 자동 Test로 확인했다. 다음 단계는 Phase 3의 REST 계약과 원자적 Oracle 저장·조회 연결이다.
