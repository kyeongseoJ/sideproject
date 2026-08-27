# Novelty
<img width="3834" height="1810" alt="image" src="https://github.com/user-attachments/assets/3264daf5-dd13-4a40-ba32-f5f82d826249" />

Novelty는 사용자의 성향을 바탕으로 평소와 다른 행동을 제안하고, 미션을 완료할수록 개인의 3D World가 성장하는 서비스입니다.

> 선택지를 고르고 → 나를 이해하고 → 새로운 미션을 선택하고 → 행동의 결과를 나만의 공간에서 확인합니다.

## 현재 구현 기준

이 저장소의 운영 기준 Backend 데이터베이스는 **Supabase PostgreSQL**입니다. 스키마와 기준 데이터는 `supabase/migrations`에서 관리합니다.

- Flutter Web과 Android는 `front/app/lib`의 동일한 반응형 UI를 사용합니다.
- 앱 시작 시 스플래시는 고정 시간으로 끝나지 않고 사용자 복원 또는 로그인·오류 화면이 준비된 시점에 종료됩니다.
- Noto Sans KR은 `front/app/assets/fonts`에 번들되어 최초 폰트 네트워크 요청이 필요하지 않습니다.
- Three.js는 Flutter가 전달한 성향 룸만 로드하며, GLB URI 캐시와 중복 초기화 방지를 적용합니다.
- 운영 빌드에는 `WORLD_TEST=true` 테스트 진입 경로가 포함되지 않습니다.

최근 검증 기준은 `flutter analyze`, 전체 Flutter 테스트, `flutter build web`, `npm.cmd run build` 성공입니다. Three.js 번들은 500KB 초과 청크 경고가 있으나 빌드는 성공합니다.

## 한눈에 보기

| 영역 | 역할 | 기술 |
|---|---|---|
| `front/app` | 로그인, 성향 분석, 미션, 프로필, 3D World 화면 | Flutter Web / Android |
| `front/world3d` | GLB 오브젝트를 배치하고 렌더링하는 3D 엔진 | Three.js / Vite |
| `back` | 사용자, 성향, 미션, 완료 보상, World 상태 API | Java 21 / Spring Boot |
| `supabase/migrations` | Supabase PostgreSQL 스키마와 기본 데이터 | PostgreSQL SQL |

## 사용자 흐름

```text
스플래시
  ↓
로그인 또는 회원가입
  ↓
성향 선택 6문항
  ↓
성향 프로필과 3D World 확인
  ↓
오늘의 미션 후보 최대 5개 중 1개 선택
  ↓
미션 수행 → 완료
  ↓
EXP 지급 → 카테고리 오브젝트와 World 성장
```

### 계정과 성향

- 시작 화면은 로그인 우선이며 회원가입은 보조 선택지로 제공합니다.
- 회원가입 시 서버가 초기 랜덤 닉네임을 배정합니다.
- 같은 브라우저 또는 앱에서는 저장된 `userKey`로 사용자를 자동 복원합니다.
- 성향 폼은 총 6문항이며 실내·실외, 사회성, 신체 활동, 새로움, 관심 카테고리, 실행 방식을 다룹니다.
- 분석 결과는 9개 성향 유형과 네 축 점수로 저장하고 프로필에서 확인합니다.

### 오늘의 미션

- 현재 UI에서는 사용자가 시간을 직접 선택하지 않습니다.
- Backend는 사용자 성향, 최근 완료 이력, 행동 메타데이터와 미션 난이도 등을 이용해 후보를 구성합니다.
- Flutter는 서로 다른 경험의 후보를 최대 5개까지 보여주며 사용자가 그중 1개를 선택합니다.
- 선택 후에는 수행 중 미션 하나만 표시하고 `완료` 또는 `취소`를 제공합니다.
- 완료 처리는 `userMissionId`를 기준으로 수행하며 상태, 통계, 성향 반영, World EXP 지급은 하나의 Transaction으로 처리합니다.
- 운영 Catalog에는 활성 미션 400개가 있으며 8개 카테고리마다 50개씩 구성됩니다. 미션 시간은 5~180분 범위를 사용합니다.

### 3D World

- 미션 카테고리와 연결된 World 오브젝트가 미션 완료 후 성장합니다.
- Backend에는 8개 카테고리별 성장 데이터를 유지하지만, 현재 World 화면은 성향별 룸 GLB 9종과 룸 내부 장식 노드를 사용합니다. 기존 외부 placeholder 오브젝트 GLB는 번들에서 제거했습니다.
- 성향 프로필 안에서는 인라인 미리보기를 제공하고, 전체 화면 World에서는 오브젝트를 탭하거나 가리켜 상세 정보를 확인할 수 있습니다.
- Flutter는 사용자 화면과 상태를 관리하고 Three.js는 렌더링만 담당합니다.
- GLB 로드 실패나 World 데이터 누락이 앱 전체를 중단시키지 않도록 오류·대체 화면을 제공합니다.
- 사용자 World 화면에는 연결된 룸 파일명이나 룸 종류를 노출하지 않고 성향명만 표시합니다. 상단 `노벨티 Lv.N` 배지의 툴팁에서 현재 공간 장식 표시 상태를 확인할 수 있습니다.

<img width="3840" height="2160" alt="image" src="https://github.com/user-attachments/assets/e836489b-a5b1-4a33-898e-6cad2d43c8d9" />

## 프로젝트 구조

```text
sideproject/
├─ front/
│  ├─ app/
│  │  ├─ lib/
│  │  │  ├─ api/             # Backend REST Client
│  │  │  ├─ personality/     # 성향 선택과 분석 결과
│  │  │  ├─ mission/         # 오늘의 미션과 완료 흐름
│  │  │  ├─ profile/         # 프로필 화면
│  │  │  ├─ user/            # 로그인, 회원가입, 사용자 키
│  │  │  └─ world/           # World 상태와 Flutter-Three.js Bridge
│  │  ├─ assets/world3d/     # Web용 Three.js bundle과 GLB asset
│  │  └─ test/               # Flutter 단위·위젯 테스트
│  └─ world3d/
│     └─ src/                # Three.js renderer source
├─ back/
│  ├─ src/main/java/com/novelty/
│  │  ├─ user/               # 회원가입·로그인
│  │  ├─ personality/        # 성향 분석·프로필
│  │  ├─ mission/            # 추천·선택·완료·통계
│  │  └─ world/              # EXP·레벨·Snapshot
│  └─ src/main/resources/
│     └─ db/                 # Backend 참고 SQL
├─ supabase/
│  ├─ migrations/             # Supabase PostgreSQL 운영 Schema와 seed
│  ├─ apply-migrations.jsh    # 환경변수 기반 migration 실행기
│  └─ verify-migration.jsh    # 테이블·seed·FK 검증기
├─ SPEC.md                   # 현재 유효한 제품·기술 정책
├─ PROJECT_STATUS.md         # 구현·검증 상태
└─ ARCHITECTURE.md           # 전체 구조와 책임 경계
```

## 로컬 실행

### 준비 사항

- Java 21
- Flutter SDK와 Dart SDK
- Node.js와 npm
- Supabase PostgreSQL 프로젝트
- Windows에서는 PowerShell 기준 명령을 사용합니다.

### 1. 환경 변수 준비

저장소 루트에서 `.env.example`을 `.env`로 복사하고 Supabase PostgreSQL 접속 정보를 입력합니다.

```powershell
Copy-Item .env.example .env
```

`.env`에는 다음 계열의 값이 사용됩니다.

```text
DB_URL=jdbc:postgresql://your-project.pooler.supabase.com:5432/postgres?sslmode=require
DB_USERNAME=your_supabase_database_user
DB_PASSWORD=your_supabase_database_password
CORS_ALLOWED_ORIGIN_PATTERNS=https://app.example.com
OPENAI_API_KEY=
OPENAI_MODEL=
OPENAI_BASE_URL=https://api.openai.com/v1
```

`.env`는 Git에 추가하지 않습니다. OpenAI 설정은 완료 5회 단위의 LLM 미션 생성이 필요할 때만 사용하며, 기본 미션 추천에는 필수가 아닙니다.

운영 WebApp은 `CORS_ALLOWED_ORIGIN_PATTERNS`에 실제 Flutter Web 주소를 쉼표로 구분해 지정해야 합니다. 예: `https://app.example.com,https://www.example.com`. 로컬 기본값은 `http://localhost:*`, `http://127.0.0.1:*`입니다.

### 2. Database 적용

운영 기준 SQL은 `supabase/migrations`입니다.

```powershell
# 저장소 루트에서 실행. DB_URL, DB_USERNAME, DB_PASSWORD가 필요합니다.
$cp = Get-Content back/target/migration-classpath.txt -Raw
jshell --class-path $cp supabase/apply-migrations.jsh -q
```

처음 실행하기 전에 `cd back; .\mvnw.cmd dependency:build-classpath -Dmdep.outputFile=target/migration-classpath.txt`로 PostgreSQL JDBC classpath를 생성합니다. migration은 재실행 가능한 형태이며, 적용 후 다음 명령으로 건수를 확인합니다.

```powershell
jshell --class-path $cp supabase/verify-migration.jsh -q
```

### 3. Backend 실행

```powershell
cd back
.\mvnw.cmd spring-boot:run
```

Backend 기본 주소는 `http://localhost:8080`입니다.

### 4. Flutter Web 실행

```powershell
cd front/app
flutter pub get
flutter run -d web-server --web-port 3000
```

브라우저에서 `http://localhost:3000`을 엽니다. 기본 Web API 주소는 `http://localhost:8080`입니다.

배포 Backend를 사용할 때는 API 주소만 dart-define으로 주입합니다.

```powershell
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com
```

World 장식 성장 테스트는 운영 배포에 포함하지 않는 컴파일 플래그로 실행합니다.

```powershell
cd front/app
flutter run -d chrome --dart-define=WORLD_TEST=true
```

테스트 화면에서 성향별 룸을 선택하고 `전체 +1` 버튼으로 모든 World Object를 한 단계씩 올릴 수 있습니다. 일반 배포 빌드에서는 `WORLD_TEST`를 지정하지 않습니다.

### 5. Android 실행

```powershell
cd front/app
flutter run -d <android-device-id>
```

Android Emulator에서는 호스트 PC의 `localhost` 대신 기본값 `http://10.0.2.2:8080`을 사용합니다. 실기기는 Backend가 실행 중인 PC의 같은 네트워크 IP를 `API_BASE_URL`로 지정해야 합니다.

### 6. Three.js 개발 서버

Flutter가 제공하는 Web asset을 사용하지 않고 World renderer만 별도로 확인할 때 실행합니다.

```powershell
cd front/world3d
npm.cmd install
npm.cmd run dev
```

## API 경계

사용자 범위 API는 `X-User-Key` Header로 사용자를 식별합니다.

| 기능 | 공식 경로 |
|---|---|
| 회원가입·로그인·사용자 복원 | `/api/users/**` |
| 성향 분석 제출 | `POST /api/personality-analyses` |
| 오늘 조회·추천 | `/api/missions/today`, `/api/missions/today/recommendations` |
| 완료 미션 이력 | `GET /api/user-missions/history?limit=50` |
| 미션 선택·취소·교체·완료 | `/api/user-missions/{userMissionId}/select|cancel|replace|complete` |
| 미션 통계 | `GET /api/missions/summary` |
| World 전체 Snapshot | `GET /api/world` |

`missionId`는 공용 Catalog ID이고, 사용자 상태를 변경할 때는 반드시 소유권이 확인된 `userMissionId`를 사용합니다.

Swagger UI는 Backend 실행 후 다음 주소에서 확인할 수 있습니다.

```text
http://localhost:8080/swagger-ui.html
```

운영 배포 주소:

- [Novelty WebApp](https://kyeongseoj.dx6project.site/)
- [Novelty Backend Swagger UI](https://kyeongseoj-api.dx6project.site/swagger-ui/index.html)
- 운영 Backend API Base URL: `https://kyeongseoj-api.dx6project.site`

Swagger UI에서 사용자별 API를 호출할 때는 회원가입 또는 로그인 응답의
`userKey`를 `X-User-Key` Header에 입력합니다.


## 검증 명령

```powershell
cd back
.\mvnw.cmd test
.\mvnw.cmd package
```

```powershell
cd front/app
flutter analyze
flutter test
flutter build web
flutter build apk --debug
```

```powershell
cd front/world3d
npm.cmd run build
```

## 현재 상태와 알려진 범위

- 성향 분석, 미션 추천·선택·취소·완료, 미션 통계는 Backend와 Flutter 흐름이 연결되어 있습니다.
- 미션 완료와 World EXP 지급은 동일 Transaction에서 처리되며 완료 재요청은 중복 보상 없이 멱등 처리됩니다.
- World Backend, Flutter, Three.js, Android WebView 연결과 성향별 룸 GLB 9종은 구현되어 있습니다. 기존 개별 placeholder GLB는 제거했습니다.
- 3D World는 자동 회귀와 Android 검증이 진행됐지만 Web·Android 전체 사용자 흐름의 최종 수동 확인은 남아 있습니다.
- 사용자별 Timezone 설정은 아직 제공하지 않으며 MVP 서비스 날짜는 `Asia/Seoul` 기준입니다.
  - 운영 배포 시 Flutter Web 정적 파일과 Spring Boot Backend, Supabase PostgreSQL을 각각 배포·연결해야 합니다.

상세 진행 상태는 [PROJECT_STATUS.md](PROJECT_STATUS.md), 정책은 [SPEC.md](SPEC.md), 구조는 [ARCHITECTURE.md](ARCHITECTURE.md)에서 확인합니다.

## README에 추가하면 좋은 시각 자료

현재 저장소에는 기능별 설명은 있지만 README 상단에서 제품 경험을 한눈에 보여주는 이미지나 영상은 없습니다. 처음 방문한 사람이 프로젝트를 빠르게 이해하도록 다음 자료를 권장합니다.

### 권장 이미지

1. **대표 화면 한 장**
   - 성향 프로필, 오늘의 미션 Spotlight 카드, 3D World 일부가 함께 보이는 홈 화면
   - README 제목 아래에 배치해 서비스의 핵심 결과를 즉시 전달

2. **사용자 흐름 다이어그램**
   - 로그인 → 성향 분석 → 미션 선택 → 완료 → World 성장의 5단계
   - 각 단계의 입력과 결과를 짧게 표시

3. **3D 성장 비교 이미지**
   - 동일 카테고리 오브젝트의 Lv1과 Lv5를 나란히 비교
   - “미션 완료가 World 성장으로 연결된다”는 점을 설명하는 데 효과적

4. **아키텍처 다이어그램**
   - Flutter ↔ Spring Boot ↔ Supabase PostgreSQL, Flutter ↔ Three.js Bridge의 방향과 책임
   - 개발자가 프로젝트 구조를 이해하는 문서 하단에 배치

### 권장 영상

- 30~45초 분량의 사용자 여정 영상이 가장 효과적입니다.
- 로그인 후 성향 1~2문항을 선택하고, 미션 후보 중 하나를 선택한 뒤 완료합니다.
- 완료 응답으로 EXP가 반영되고 3D 오브젝트 레벨 또는 장면이 바뀌는 순간을 반드시 포함합니다.
- Web과 Android 중 실제 지원을 우선할 플랫폼 하나를 기준으로 촬영하고, 영상 시작 3초 안에 서비스 핵심을 보여줍니다.
- 영상은 README에 직접 대용량 파일로 넣기보다 `docs/media/novelty-demo.mp4` 또는 외부 동영상 링크를 사용하고, 대체 텍스트가 있는 대표 이미지도 함께 제공합니다.

권장 배치 순서는 `대표 화면 → 짧은 데모 영상 → 사용자 흐름 → 기술 구조`입니다. 이미지와 영상은 실제 현재 동작을 촬영한 자료만 사용하고, 구현되지 않은 기능이나 가짜 API 응답을 제품 화면처럼 보이게 만들지 않는 것이 좋습니다.

## 참고 문서

- [제품·기술 정책](SPEC.md)
- [프로젝트 진행 상태](PROJECT_STATUS.md)
- [전체 아키텍처](ARCHITECTURE.md)
- [성향 분석 SDD](docs/personality-sdd-v2.md)
- [미션 SDD](docs/mission-sdd-v1.md)
- [3D World SDD](docs/world-sdd-v1.md)
## Docker deployment

Dockerfiles use the repository root as their build context.

Frontend image:

```powershell
docker build -f front/Dockerfile --build-arg API_BASE_URL=https://api.example.com -t novelty-front .
docker run --rm -p 80:80 novelty-front
```

The frontend image builds `front/world3d` with Vite, builds Flutter Web with
the supplied `API_BASE_URL`, and serves `front/app/build/web` through Nginx.
`front/nginx.conf` provides the Flutter SPA fallback to `index.html`.

Backend image:

```powershell
docker build -f back/Dockerfile -t novelty-back .
docker run --rm -p 8080:8080 --env-file .env novelty-back
```

For a deployment platform, register the variables from `.env.example` in its
environment settings instead of copying `.env` into the image. The backend
requires `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`, and the deployed Web origin
in `CORS_ALLOWED_ORIGIN_PATTERNS`. OpenAI variables are optional.

Apply and verify `supabase/migrations` separately before starting the backend.
There is currently no Docker Compose file; frontend and backend images are
deployed as separate services connected to the same Supabase PostgreSQL
database.
