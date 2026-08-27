# Novelty 프로젝트 가이드

이 문서는 프로젝트 구조, 로컬 실행 방법, 환경 변수와 API 사용 경계를 안내한다. 현재 정책과 기능 규칙은 [SPEC.md](SPEC.md), 실제 구현·검증 상태는 [PROJECT_STATUS.md](PROJECT_STATUS.md), 기술 구조는 [ARCHITECTURE.md](ARCHITECTURE.md)를 참고한다.

## 프로젝트 구조

```text
sideproject/
├─ front/
│  ├─ app/                    # Flutter Web·Android 앱
│  │  ├─ lib/api/             # Backend REST Client
│  │  ├─ lib/personality/     # 성향 분석
│  │  ├─ lib/mission/         # 오늘의 미션과 완료 흐름
│  │  ├─ lib/profile/         # 프로필과 미션 수행 기록
│  │  ├─ lib/user/            # 로그인·회원가입
│  │  └─ lib/world/           # World 상태와 Flutter-Three.js Bridge
│  └─ world3d/                # Three.js·Vite Renderer
├─ back/                      # Java 21·Spring Boot Backend
├─ supabase/migrations/       # 운영 PostgreSQL Schema·seed
├─ docs/                      # 정책·구조·상태·기능 문서
└─ AGENTS.md                  # 작업 규칙
```

## 로컬 실행

### 준비 사항

- Java 21
- Flutter SDK와 Dart SDK
- Node.js와 npm
- Supabase PostgreSQL 프로젝트
- Windows에서는 PowerShell 명령을 사용한다.

### 환경 변수

저장소 루트에서 `.env.example`을 `.env`로 복사한 뒤 값을 입력한다.

```powershell
Copy-Item .env.example .env
```

주요 변수는 다음과 같다.

```text
DB_URL=jdbc:postgresql://your-project.pooler.supabase.com:5432/postgres?sslmode=require
DB_USERNAME=your_supabase_database_user
DB_PASSWORD=your_supabase_database_password
CORS_ALLOWED_ORIGIN_PATTERNS=https://app.example.com
OPENAI_API_KEY=
OPENAI_MODEL=
OPENAI_BASE_URL=https://api.openai.com/v1
```

`.env`는 Git에 추가하지 않는다. Flutter의 `API_BASE_URL`은 Secret이 아니며 배포 빌드 시 `--dart-define`으로 주입한다.

### Database

운영 Schema와 기준 데이터는 `supabase/migrations`에서 관리한다.

```powershell
cd back
.\mvnw.cmd dependency:build-classpath -Dmdep.outputFile=target/migration-classpath.txt
cd ..
$cp = Get-Content back/target/migration-classpath.txt -Raw
jshell --class-path $cp supabase/apply-migrations.jsh -q
jshell --class-path $cp supabase/verify-migration.jsh -q
```

### Backend

```powershell
cd back
.\mvnw.cmd spring-boot:run
```

기본 주소는 `http://localhost:8080`이다.

### Flutter Web

```powershell
cd front/app
flutter pub get
flutter run -d web-server --web-port 3000
```

배포 Backend를 사용하는 Web 빌드는 다음과 같이 실행한다.

```powershell
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com
```

### Android

```powershell
cd front/app
flutter run -d <android-device-id>
```

Android Emulator는 `http://10.0.2.2:8080`, 실기기는 Backend가 실행 중인 PC의 네트워크 IP를 사용한다.

### Three.js

```powershell
cd front/world3d
npm.cmd install
npm.cmd run dev
```

개발용 World 성장 테스트는 `WORLD_TEST=true`를 별도로 주입한다. 일반 배포 빌드에는 포함하지 않는다.

## Docker 배포

Docker build context는 저장소 루트다. Frontend와 Backend는 별도 서비스로 배포하며, 현재 Docker Compose 파일은 사용하지 않는다.

### Frontend

```powershell
docker build -f front/Dockerfile --build-arg API_BASE_URL=https://api.example.com -t novelty-front .
docker run --rm -p 80:80 novelty-front
```

### Backend

```powershell
docker build -f back/Dockerfile -t novelty-back .
docker run --rm -p 8080:8080 --env-file .env novelty-back
```

배포 플랫폼에서는 `.env`를 이미지에 복사하지 말고 플랫폼의 환경 변수·Secret 설정으로 등록한다. Supabase migration은 Backend 이미지와 별도로 적용하고 검증한다.

## API 경계

사용자 범위 API는 `X-User-Key` Header로 사용자를 식별한다.

| 기능 | 공식 경로 |
|---|---|
| 회원가입·로그인·사용자 복원 | `/api/users/**` |
| 성향 분석 제출 | `POST /api/personality-analyses` |
| 오늘 조회·추천 | `/api/missions/today`, `/api/missions/today/recommendations` |
| 완료 미션 이력 | `GET /api/user-missions/history?limit=50` |
| 미션 선택·취소·교체·완료 | `/api/user-missions/{userMissionId}/select|cancel|replace|complete` |
| 미션 통계 | `GET /api/missions/summary` |
| World Snapshot | `GET /api/world` |

`missionId`는 공용 Catalog 식별자이고, 사용자 상태 변경에는 소유권이 확인된 `userMissionId`를 사용한다.

Swagger UI:

```text
http://localhost:8080/swagger-ui.html
```

운영 주소:

- [Novelty WebApp](https://kyeongseoj.dx6project.site/)
- [Novelty Backend Swagger UI](https://kyeongseoj-api.dx6project.site/swagger-ui/index.html)
- API Base URL: `https://kyeongseoj-api.dx6project.site`

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
