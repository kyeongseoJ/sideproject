# 선택지 폼 Phase 7 완료 보고서

- 완료일: 2026-08-19
- 대상 사양: `docs/survey-phase0-spec.md` 1.0.0
- 구현 범위: Flutter 5문항 입력부터 Spring Boot와 Oracle 저장 결과 표시까지
- 기능 상태: 구현 및 E2E 검증 완료
- 보안 상태: Git 추적 기록 파일의 기존 Secret 1건 정리 필요

## 1. 완성된 사용자 흐름

```text
Flutter 소개 화면
→ 5개 행동 선택 질문
→ Client 입력 검증
→ POST /api/surveys
→ Spring Boot 입력 검증 및 Transaction
→ Oracle SURVEY_RESPONSE + SURVEY_INTEREST 저장
→ 201 Created + surveyId + SAVED
→ Flutter 저장 완료 화면
```

지원하는 화면 상태는 다음과 같다.

- 단일 선택 4문항
- 관심 활동 1~3개 다중 선택
- 이전·다음 이동과 선택값 유지
- 미완료 문항의 다음 단계 차단
- 제출 중 입력 및 중복 제출 차단
- 성공 시 `surveyId` 표시
- 실패 시 선택값 유지, 오류 메시지 및 재시도 제공

## 2. 주요 구현 파일

### Flutter

```text
front/app/lib/main.dart
front/app/lib/api/survey_api.dart
front/app/lib/survey/survey_models.dart
front/app/lib/survey/survey_screen.dart
front/app/test/survey_api_test.dart
front/app/test/survey_screen_test.dart
front/app/tool/survey_e2e_check.dart
```

### Spring Boot

```text
back/src/main/java/com/novelty/survey/SurveyRequest.java
back/src/main/java/com/novelty/survey/SurveyResponse.java
back/src/main/java/com/novelty/survey/SurveyErrorResponse.java
back/src/main/java/com/novelty/survey/InvalidSurveyException.java
back/src/main/java/com/novelty/survey/SurveyRepository.java
back/src/main/java/com/novelty/survey/SurveyService.java
back/src/main/java/com/novelty/survey/SurveyController.java
back/src/main/java/com/novelty/survey/SurveyExceptionHandler.java
back/src/test/java/com/novelty/survey/SurveyServiceTest.java
back/src/test/java/com/novelty/survey/SurveyControllerTest.java
```

### Oracle 및 설정

```text
back/src/main/resources/application.yml
back/src/main/resources/db/survey-schema.sql
```

## 3. REST API

```http
POST /api/surveys
Content-Type: application/json
```

성공 응답:

```http
201 Created
```

```json
{
  "surveyId": 1,
  "status": "SAVED"
}
```

검증 실패:

```json
{
  "code": "INVALID_SURVEY",
  "message": "요청을 확인할 수 있는 사용자용 메시지"
}
```

저장 실패:

```json
{
  "code": "SURVEY_SAVE_FAILED",
  "message": "선택을 저장하지 못했습니다. 잠시 후 다시 시도해 주세요."
}
```

DB 오류 상세, 접속정보와 Stack trace는 HTTP 응답에 포함하지 않는다.

### Swagger UI

Backend 실행 후 다음 주소에서 현재 API를 직접 호출할 수 있다.

```text
http://localhost:8080/swagger-ui.html
```

OpenAPI JSON:

```text
http://localhost:8080/v3/api-docs
```

`springdoc.paths-to-match=/api/**` 설정으로 앞으로 추가되는 Spring MVC의 `/api/**` API도 별도 목록 등록 없이 Swagger UI에 자동으로 포함된다.

## 4. Oracle 구조

```text
SURVEY_RESPONSE_SEQ
SURVEY_RESPONSE
SURVEY_INTEREST
```

- `SURVEY_RESPONSE`에는 설문 기본 선택값을 저장한다.
- `SURVEY_INTEREST`에는 선택한 관심 활동 1~3개를 저장한다.
- `(SURVEY_ID, INTEREST_CODE)`를 복합 기본키로 사용한다.
- 부모와 관심 활동 저장은 하나의 Spring Transaction으로 처리한다.
- 부모 삭제 시 연결된 관심 활동은 `ON DELETE CASCADE`로 삭제된다.

## 5. 실행 전 환경 설정

실제 Secret은 Git 추적 파일에 작성하지 않고 현재 PowerShell 세션의 환경 변수로 전달한다.

```powershell
$env:DB_URL = 'jdbc:oracle:thin:@localhost:1521:XE'
$env:DB_USERNAME = '<LOCAL_DB_USERNAME>'
$env:DB_PASSWORD = '<LOCAL_DB_PASSWORD>'
```

Oracle에는 다음 스키마가 먼저 적용되어 있어야 한다.

```text
back/src/main/resources/db/survey-schema.sql
```

## 6. Backend 실행

```powershell
cd back
.\mvnw.cmd spring-boot:run
```

기본 API 주소:

```text
http://localhost:8080/api/surveys
```

## 7. Flutter 실행

```powershell
cd front/app
flutter run -d web-server `
  --dart-define=API_BASE_URL=http://localhost:8080
```

`API_BASE_URL`이 누락되거나 형식이 잘못되면 Flutter가 설정 오류를 표시하고 요청을 보내지 않는다.

## 8. 검증 명령

Flutter:

```powershell
cd front/app
flutter analyze
flutter test
flutter build web --dart-define=API_BASE_URL=http://localhost:8080
```

Backend:

```powershell
cd back
.\mvnw.cmd package
```

실제 API E2E 확인:

```powershell
cd front/app
dart run tool/survey_e2e_check.dart http://localhost:8080
```

E2E 확인 도구는 실제 설문 한 건을 저장하고 `E2E_SURVEY_ID`를 출력한다. 반복 실행 후에는 출력된 ID의 테스트 데이터를 별도로 정리한다.

## 9. 최종 검증 결과

| 항목 | 결과 |
|---|---|
| Flutter 정적 분석 | 성공, 문제 0건 |
| Flutter 테스트 | 11건 성공 |
| Flutter Web 빌드 | 성공 |
| Backend 테스트 | 11건 성공 |
| Backend JAR 패키징 | 성공 |
| 정상 E2E 저장 | `201`, 양수 `surveyId`, `SAVED` 확인 |
| Oracle 부모 데이터 | 요청값과 일치 |
| Oracle 관심 활동 | 선택한 3개와 일치 |
| 관심 활동 0개 | `400 INVALID_SURVEY`, DB 미저장 |
| 관심 활동 4개 | `400 INVALID_SURVEY`, DB 미저장 |
| 중복 관심 활동 | `400 INVALID_SURVEY`, DB 미저장 |
| 알 수 없는 코드 | `400 INVALID_SURVEY`, DB 미저장 |
| DB 연결 실패 | `500 SURVEY_SAVE_FAILED`, 내부 정보 비노출 |
| 자식 저장 실패 | `DuplicateKeyException` 후 부모·자식 전체 Rollback |
| 로컬 Flutter Web CORS | Preflight `200`, POST 허용 |
| E2E 검증 데이터 정리 | 부모·자식 최종 0행 |

## 10. 인수 조건 상태

| 조건 | 상태 | 근거 |
|---|---|---|
| AC-01 정상 저장 | 충족 | 실제 API `201`, `surveyId`, `SAVED` 확인 |
| AC-02 Oracle 데이터 일치 | 충족 | 부모 필드와 관심 활동 3개 직접 조회 |
| AC-03 관심 활동 최소 개수 | 충족 | Flutter 차단 테스트 및 Server `400` 확인 |
| AC-04 관심 활동 최대 개수 | 충족 | Flutter 최대 3개 테스트 및 Server `400` 확인 |
| AC-05 원자적 저장 | 충족 | 실제 중복 자식 저장 실패 후 부모·자식 모두 0행 |
| AC-06 실패 후 재시도 | 충족 | Flutter 선택 유지 및 재시도 Widget 테스트 |
| AC-07 Secret 비노출 | 조치 필요 | 소스와 응답은 충족하나 기존 Git 기록 파일에 로컬 DB Secret 존재 |

## 11. 의존성

Frontend에 추가된 직접 의존성:

- `http 1.6.0`: REST API 호출
- `flutter_test`: Flutter SDK 기반 테스트 전용

Backend에 추가된 직접 의존성:

- `spring-boot-starter-jdbc`: JDBC 및 Transaction
- `ojdbc11`: Oracle JDBC Driver, Runtime 전용
- `spring-boot-starter-webmvc-test`: Controller 및 Service 테스트 전용

이번 범위에서 상태관리, JSON 모델 생성, 재시도 또는 ORM Library는 추가하지 않았다.

## 12. 남은 문제와 권장 조치

### Git 추적 기록 파일의 Secret

`사용한프롬프트.md`에 과거 로컬 DB 사용자명과 비밀번호가 기록되어 있다. 현재 애플리케이션 소스와 `application.yml`은 환경 변수 방식이지만, Git에 Commit할 예정이라면 다음 조치가 필요하다.

1. 기록 파일에서 실제 값을 placeholder로 교체한다.
2. 이미 원격 저장소나 Commit 이력에 포함됐다면 DB 비밀번호를 변경한다.
3. 필요하면 Git 이력의 Secret 제거를 별도 계획으로 수행한다.

사용자 기록 파일이므로 Phase 7에서는 임의로 수정하지 않았다.

### 비차단 경고

- Mockito가 현재 JDK에서 동적 Java Agent를 사용하는 향후 호환성 경고가 있다.
- Flutter Web 빌드는 Wasm dry-run 관련 권장 메시지를 출력하지만 현재 JavaScript Web 빌드는 성공한다.
- Oracle Sequence는 Rollback이나 테스트 데이터 삭제 시 되돌아가지 않으므로 ID에 빈 번호가 생길 수 있다.

## 13. 이번 범위에서 구현하지 않은 기능

- 저장된 설문을 이용한 사용자 성향 점수 계산
- 성향 경계에서 한 단계 벗어난 미션 생성
- 미션 선택, 수행 및 완료 기록
- 스티커 보상
- Three.js 3D 공간 성장
- 레벨 시스템
- 회원가입과 로그인

다음 기능은 성공 응답의 `surveyId`를 초기 행동 프로필 식별자로 사용해 연결한다.
