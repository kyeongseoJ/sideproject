# Novelty

새로운 행동을 제안하고 미션 완료에 따라 3D 공간이 성장하는 서비스입니다.

- `front/app`: 선택지 폼, 성향, 미션, 프로필, 설정과 3D World 화면을 담당하는 Flutter 앱
- `front/world3d`: GLB 기반 3D World를 그리는 Three.js 렌더러
- `back`: User, Personality, Mission 완료 처리, World/Progression을 담당하는 Spring Boot 서버
- `DB.sql`: Oracle 기준 스키마
- `ARCHITECTURE.md`: 전체 기술 구조와 영역별 소유 경계

## 공식 기능 흐름

```text
POST /api/users/register 또는 POST /api/users/login
→ GET /api/users/me → PATCH /api/users/me/nickname
→ POST /api/personality-analyses
→ POST /api/missions/today/recommendations
→ /api/user-missions/{userMissionId}/select|cancel|replace|complete
→ GET /api/world
```

사용자 범위 요청은 `X-User-Key`를 사용한다. `missionId`는 공용 Catalog ID이고, 선택·취소·교체·완료는 사용자에게 발급된 `userMissionId`를 사용한다.

최초 사용자는 아이디·비밀번호로 회원가입하고 서버가 중복 없는 랜덤 닉네임을 배정한 뒤 성향 선택폼을 시작한다.
Web과 Android 모두 Purple 배경의 White 로고 스플래시를 표시한 후 진입하며, 캐시 사용자가 없으면 회원가입 화면이 기본으로 열린다.
첫 문항에는 이전 버튼이 없고 두 번째 문항부터 이전 답변으로 돌아갈 수 있다. 같은 브라우저·앱의
기존 사용자는 저장된 `userKey`로 자동 복원되며, 캐시가 삭제됐거나 다른 기기에서는 아이디·비밀번호로 로그인해 복구한다. 완료된 성향 프로필에는
회전·확대 가능한 3D World가 인라인으로 표시되며 장면을 탭하면 성향별 이름을 가진 전체 화면으로 이동한다.

성향 완료 홈에서는 오늘의 미션을 가장 먼저 보여준다. 사용자는 하루 할애 시간만 고른 뒤
가로 캐러셀에서 한 개를 선택하며, 수행 중에는 해당 미션 하나만 크게 표시된다. 관심 분야와
행동 선호는 분리되어 있고 행동 선호는 저장 점수 그래프와 최근 완료 미션의 경험 방향을 함께 보여준다.

## 실행

```powershell
cd front/app
flutter run -d web-server --web-port 3000
```

`API_BASE_URL`을 생략하면 Web은 `http://localhost:8080`, Android Emulator는
`http://10.0.2.2:8080`을 자동 사용한다. 배포 환경에서는 실제 HTTPS Backend 주소를
`--dart-define=API_BASE_URL=...`로 지정한다.

Android 에뮬레이터에서는 PC의 `localhost`를 `10.0.2.2`로 접근한다.

```powershell
cd front/app
flutter run -d <android-device-id>
```

실기기는 `10.0.2.2` 대신 PC의 같은 네트워크 내부 IP를 사용한다. Web과 Android는 동일한 Flutter UI를 사용한다.

```powershell
cd front/world3d
npm.cmd install
npm.cmd run dev
```

```powershell
cd back
.\mvnw.cmd spring-boot:run
```

저장소 루트의 `.env`를 Spring Boot가 자동으로 읽으므로 로컬 실행 때마다 환경 변수를
터미널에 다시 입력할 필요가 없다. 새 환경에서는 `.env.example`을 `.env`로 복사한 뒤
Oracle 값을 채운다. `.env`는 Git에서 제외되며, LLM 미션 생성을 사용할 때만
`OPENAI_API_KEY`, `OPENAI_MODEL`을 채운다. 이미 노출된 API Key는 재사용하지 않는다.

`application.yml`은 저장소 루트와 `back` 디렉터리 양쪽 실행 위치를 지원한다. 배포에서는
`.env`를 이미지에 포함하지 않고 호스팅 환경의 Secret/환경 변수 기능으로 같은 이름의 값을 주입한다.

Windows SQL*Plus에서 한글 Seed가 포함된 `DB.sql`을 직접 실행할 때는 세션의 `NLS_LANG`을
`KOREAN_KOREA.AL32UTF8`로 지정한다. 지정하지 않으면 한글 태그 정규식이 잘못 해석될 수 있다.

Swagger UI는 Backend 실행 후 `http://localhost:8080/swagger-ui.html`에서 확인한다.

## 검증

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

World Phase 0~8에서 `GET /api/world`, Mission 완료 EXP Transaction, Flutter World 상태,
Android WebView·Web iframe Bridge, Three.js Diorama와 8개 Object × 5레벨 GLB를 구현했다.
World Schema는 실제 Oracle에 적용했으며 Table 3개, Object 8개, Level 40개를 확인했다.
Oracle Rollback 통합 테스트에서 Mission 완료→World EXP→Snapshot과 중복 보상 방지를 검증했다.
