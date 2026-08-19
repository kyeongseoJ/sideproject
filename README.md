# Novelty

새로운 행동을 제안하고 미션 완료에 따라 3D 공간이 성장하는 서비스입니다.

- `front/app`: 선택지 폼, 성향, 미션, 프로필, 설정과 3D World 화면을 담당하는 Flutter 앱
- `front/world3d`: GLB 기반 3D World를 그리는 Three.js 렌더러
- `back`: User, Personality, Mission, Completion, World/Progression을 담당하는 Spring Boot 서버
- `DB.sql`: Oracle 기준 스키마
- `ARCHITECTURE.md`: 전체 기술 구조와 영역별 소유 경계

## 실행

```powershell
cd front/app
flutter run -d web-server --web-port 3000 --dart-define=API_BASE_URL=http://localhost:8080
```

```powershell
cd front/world3d
npm.cmd install
npm.cmd run dev
```

```powershell
cd back
.\mvnw.cmd spring-boot:run
```

Backend 실행 전 `DB_USERNAME`, `DB_PASSWORD`를 설정한다. LLM 미션 생성을 사용할 때만
`OPENAI_API_KEY`, `OPENAI_MODEL`을 추가로 설정한다. Secret은 저장소 파일에 직접 작성하지 않는다.
