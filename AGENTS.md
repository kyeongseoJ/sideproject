# AGENTS.md

## 프로젝트 개요

이 프로젝트의 이름은 노벨티(Novelty)다.

노벨티는 사용자에게 매일 새로운 활동을 제안하여 권태감과 무기력감을 줄이고 행동 활성화를 돕는 서비스다.

핵심 목표는 다음 네 가지 기능을 구현하는 것이다.

1. 사용자에게 성향 선택지 폼 제공
2. 선택 결과를 기반으로 사용자 성향 분석
3. 사용자 성향과 반대되는 랜덤 미션 생성
4. 미션 수행에 따라 성장하는 3D 공간 및 레벨 시스템 제공

현재 프로젝트는 기능 구현 전의 최소 실행 구조를 기반으로 한다.

## 프로젝트 경로

프로젝트 루트:

```text
C:\Users\6122\Desktop\DXSchool_JKS\JAVA\vibecoding\sideproject
```

기본 구조:

```text
sideproject/
├─ front/
│  ├─ app/
│  └─ world3d/
└─ back/
```

## Frontend 기술

Flutter 애플리케이션:

- Flutter
- Dart
- Flutter Web
- 위치: `front/app`

3D 공간:

- Three.js
- JavaScript
- Vite
- 위치: `front/world3d`

Flutter와 Three.js의 역할을 구분한다.

- Flutter는 선택지 폼, 성향 결과, 미션 및 레벨 화면을 담당한다.
- Three.js는 3D 공간 렌더링을 담당한다.
- Flutter와 Three.js 사이의 연동은 필요한 시점에 최소 범위로 구현한다.

## 디자인 규칙

모든 Frontend 디자인은 프로젝트 루트의 `DESIGN.md`를 기준으로 작성한다.

기본 서체:

```text
Noto Sans KR
```

다음 규칙을 지킨다.

- 새로운 Flutter 및 Three.js 화면을 만들기 전에 `DESIGN.md`의 색상, 타이포그래피, 간격, radius, 상태 및 반응형 규칙을 확인한다.
- Flutter에서는 공식 `google_fonts` 패키지의 `Noto Sans KR`을 전역 Theme에 적용한다.
- Three.js를 포함한 Web UI에서는 Google Fonts의 `Noto Sans KR`을 불러오고 동일한 fallback을 사용한다.
- 주요 CTA는 NC Purple `#7234e0`, 본문은 Ink `#0f1011`, 구분 표면은 `#f2f2f3` 및 `#f7f7f8`을 우선 사용한다.
- 버튼 radius는 6px, 주요 카드 radius는 16px을 기본으로 한다.
- 그림자를 사용하지 않고 배경색 구분과 `#ebebeb` hairline으로 깊이를 표현한다.
- 오류에는 Point Red `#f1415e`, 성공에는 Point Green `#21ab79`를 사용한다.
- 기존 화면을 변경할 때도 새 디자인과 충돌하는 이전 스타일을 함께 정리한다.
- 디자인 토큰은 가능한 한 공통 Theme 또는 스타일 파일에 모아 화면별 임의 색상과 글꼴 사용을 줄인다.

## Backend 기술

Backend는 다음 기술을 사용한다.

- Java 21
- Spring Boot
- Maven Wrapper
- Spring Web MVC
- Oracle Database 21c

Backend 프로젝트 위치:

```text
back/
```

Spring Boot 시작 클래스:

```text
back/src/main/java/com/novelty/NoveltyApplication.java
```

Database 설정 위치:

```text
back/src/main/resources/application.yml
```

## Database 변경 규칙

프로젝트의 기준 Oracle 스키마 파일은 루트의 `DB.sql`이다.

Backend에서 함께 사용하는 SQL 파일:

```text
back/src/main/resources/db/survey-schema.sql
```

Database 관련 작업은 다음 규칙을 지킨다.

- 테이블, Sequence, Index, Constraint 및 필수 기준 데이터 변경은 실행 전에 `DB.sql`에 먼저 작성한다.
- 실제 Oracle에 적용한 SQL만 실행 날짜와 변경 내용을 `DB.sql`의 적용 이력 주석에 기록한다.
- `DB.sql`과 Backend의 대응 스키마 SQL은 항상 동일한 실행 내용을 유지한다.
- 재실행해도 기존 데이터나 객체가 손상되지 않도록 가능한 경우 멱등 SQL로 작성한다.
- 임시 테스트 데이터의 `INSERT`와 정리용 `DELETE`는 기준 스키마에 포함하지 않는다.
- 실제 적용 후 Oracle의 테이블, Sequence, Constraint와 필요한 컬럼을 조회하여 검증한다.
- DB 접속 계정과 비밀번호는 SQL 파일에 작성하지 않고 환경 변수 또는 로컬 실행 환경에서만 사용한다.
- 앞으로 새로운 기능에 DB 객체가 필요하면 기능 코드와 함께 `DB.sql`도 같은 작업에서 갱신한다.

## Backend 기본 구조

Backend는 기능 중심 패키지 구조를 사용한다.

```text
back/src/main/java/com/novelty/
├─ NoveltyApplication.java
├─ survey/
├─ mission/
└─ world/
```

각 패키지의 역할은 다음과 같다.

- `survey`: 선택지 폼 결과와 사용자 성향 분석
- `mission`: 성향과 반대되는 랜덤 미션 생성 및 관리
- `world`: 3D 공간 성장 상태와 레벨 관리

초기에는 구조를 단순하게 유지한다.

예시:

```text
survey/
├─ SurveyController.java
├─ SurveyService.java
├─ SurveyRepository.java
└─ Survey.java
```

클래스 수가 많아지기 전에는 `controller`, `service`, `repository`, `domain`, `dto` 등의 하위 폴더를 불필요하게 만들지 않는다.

Spring 관련 클래스는 `com.novelty` 하위에 작성하여 컴포넌트 스캔 범위를 벗어나지 않도록 한다.

## REST API 규칙

Frontend와 Backend의 통신에는 REST API를 사용한다.

Controller는 기능별 패키지에 작성한다.

예시:

```text
com.novelty.survey.SurveyController
com.novelty.mission.MissionController
com.novelty.world.WorldController
```

API 경로는 리소스 중심으로 작성한다.

예시:

```text
/api/surveys
/api/missions
/api/world
```

HTTP 메서드는 목적에 맞게 사용한다.

- `GET`: 데이터 조회
- `POST`: 데이터 생성 또는 작업 요청
- `PUT` 또는 `PATCH`: 데이터 변경
- `DELETE`: 데이터 삭제

Controller에 핵심 비즈니스 로직을 직접 작성하지 않는다. 비즈니스 로직은 Service에서 처리한다.

API 요청과 응답 형식이 변경되면 Frontend와 Backend에 미치는 영향을 함께 확인한다.

## Swagger 및 OpenAPI 규칙

Spring MVC REST API는 springdoc-openapi를 통해 Swagger UI에 자동으로 문서화한다.

로컬 확인 주소:

```text
Swagger UI: http://localhost:8080/swagger-ui.html
OpenAPI JSON: http://localhost:8080/v3/api-docs
```

앞으로 추가되는 API는 다음 규칙을 지킨다.

- Controller는 기존 규칙대로 `com.novelty` 하위에 작성한다.
- API 경로는 `/api/**` 형식을 사용하여 전역 OpenAPI 스캔 범위에 포함한다.
- 새 API는 별도 Swagger 목록에 수동 등록하지 않는다.
- `@Tag`, `@Operation`, `@ApiResponses`로 기능과 주요 응답 코드를 설명한다.
- 요청 및 응답 타입을 구체적으로 선언하여 Swagger UI에서 Schema와 예시를 확인할 수 있게 한다.
- 인증이 추가되면 실제 Secret을 문서에 작성하지 않고 OpenAPI Security Scheme만 설정한다.
- 구현 후 `/v3/api-docs`에 새 경로가 포함되는지 확인한다.
- Swagger UI의 `Try it out`으로 정상 및 오류 응답을 확인한다.

## Library 및 의존성 관리

새로운 Library는 현재 기능 구현에 반드시 필요한 경우에만 추가한다.

다음 규칙을 지킨다.

- 이미 설치된 Library로 해결할 수 있는지 먼저 확인한다.
- 사용하지 않는 Library를 미리 추가하지 않는다.
- 유사한 역할의 Library를 중복해서 추가하지 않는다.
- Library를 추가할 때 사용 목적과 적용 위치를 설명한다.
- Frontend 의존성 변경 시 `pubspec.yaml` 또는 `package.json`을 확인한다.
- Backend 의존성 변경 시 `pom.xml`을 확인한다.
- 기능 구현이 끝난 뒤 사용하지 않는 의존성이 남지 않았는지 확인한다.

## Secret 관리

비밀번호, API Key, Token 등의 Secret을 코드나 Git 추적 파일에 직접 작성하지 않는다.

Secret에 해당하는 값은 다음 방법 중 하나로 관리한다.

- 환경 변수
- 로컬 전용 설정 파일
- 배포 환경의 Secret 관리 기능

다음 파일에 실제 운영 Secret을 직접 작성하지 않는다.

```text
application.yml
.dart 파일
Java 소스 파일
JavaScript 파일
README.md
```

환경 변수를 사용할 때는 다음과 같은 형태를 권장한다.

```yaml
spring:
  datasource:
    url: ${DB_URL}
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
```

예제 설정이 필요하면 실제 값 대신 명확한 placeholder를 사용한다.

```text
DB_USERNAME=your_username
DB_PASSWORD=your_password
```

이미 파일에 직접 작성된 Secret을 발견하면 임의로 외부에 노출하지 않고, 변경이 필요한 사실을 먼저 알린다.

## 파일 변경 안전 규칙

기존 파일과 사용자의 작업 내용을 우선적으로 보존한다.

다음 작업은 명확한 요청 없이 수행하지 않는다.

- 기존 파일 대량 삭제
- 폴더 전체 삭제
- 프로젝트 구조 전면 변경
- 빌드 설정 전체 교체
- 기존 코드를 대규모로 덮어쓰기
- Git 이력이나 사용자 변경사항 초기화

삭제가 필요하면 다음 내용을 먼저 확인한다.

1. 삭제 대상의 정확한 경로
2. 삭제가 필요한 이유
3. 다른 파일이나 기능에 미치는 영향
4. 복구 가능 여부

빌드 산출물이나 캐시를 정리할 때도 삭제 범위를 프로젝트 내부의 명확한 경로로 제한한다.

## 변경 계획 공유

큰 변경을 시작하기 전에 작업 계획을 먼저 설명한다.

큰 변경에는 다음 작업이 포함된다.

- 여러 기능 패키지에 걸친 변경
- Frontend와 Backend를 함께 변경하는 작업
- Database 스키마 변경
- 새로운 Library 또는 프레임워크 도입
- 프로젝트 구조 변경
- API 요청 또는 응답 형식 변경
- 인증이나 보안 방식 변경

계획에는 다음 내용을 포함한다.

1. 변경 목적
2. 변경할 파일 또는 영역
3. 구현 순서
4. 예상되는 영향
5. 검증 방법

작은 오탈자 수정이나 단일 설정값 변경에는 과도한 계획을 작성하지 않아도 된다.

## 구현 및 검증

기능을 구현한 뒤에는 변경 범위에 맞는 Build 또는 테스트를 수행한다.

Flutter 검증:

```powershell
cd front/app
flutter analyze
flutter build web
```

Three.js 검증:

```powershell
cd front/world3d
npm.cmd run build
```

Backend 검증:

```powershell
cd back
.\mvnw.cmd test
.\mvnw.cmd package
```

전체 명령을 항상 실행할 필요는 없지만, 변경한 영역과 관련된 검증은 반드시 수행한다.

검증에 실패하면 다음 내용을 숨기지 않고 설명한다.

- 실패한 명령
- 주요 오류 메시지
- 실패 원인
- 해결 여부
- 아직 남아 있는 문제

## 작업 완료 보고

작업이 끝나면 다음 내용을 설명한다.

1. 구현하거나 변경한 내용
2. 변경한 파일 목록
3. 추가하거나 제거한 Library
4. 수행한 Build 또는 테스트 명령
5. Build 또는 테스트 결과
6. 알려진 경고나 남아 있는 문제

파일 경로는 프로젝트 루트를 기준으로 명확하게 작성한다.

예시:

```text
변경한 파일:
- front/app/lib/main.dart
- back/src/main/java/com/novelty/mission/MissionController.java
- back/src/main/resources/application.yml

검증:
- flutter analyze: 성공
- npm.cmd run build: 성공
- .\mvnw.cmd test: 성공
```

변경하지 않은 기능이 구현된 것처럼 설명하지 않는다.
