# Novelty 기술 구조

이 문서는 노벨티 저장소의 기술 영역과 소유 경계를 정의한다. 각 영역은 기능이 확장되더라도 이 경계를 기준으로 유지한다.

```text
Novelty
├─ Frontend
│  ├─ Flutter (Web / Android 공용 UI)
│  │  ├─ 선택지 폼           front/app/lib/personality
│  │  ├─ 성향 분석 UI       front/app/lib/personality
│  │  ├─ 미션 UI            front/app/lib/mission
│  │  ├─ 프로필             front/app/lib/profile
│  │  ├─ 미션 선택·수행 UI   front/app/lib/mission
│  │  └─ 3D World 화면      front/app/lib/world
│  └─ Three.js Renderer      front/world3d/src/world
├─ Backend / Spring Boot
│  ├─ User                  com.novelty.user
│  ├─ Personality           com.novelty.personality
│  ├─ Mission               com.novelty.mission
│  ├─ Mission Completion    com.novelty.mission.UserMissionService
│  └─ World / Progression   com.novelty.world
├─ Database / Supabase PostgreSQL
│  ├─ USER                  NOVELTY_USER
│  ├─ PERSONALITY           USER_PERSONALITY_PROFILE
│  ├─ MISSION               MISSION
│  ├─ USER_MISSION          USER_MISSION
│  ├─ MISSION_CATEGORY_STAT USER_MISSION_CATEGORY_STAT
│  ├─ MISSION_STATUS_LOG    MISSION_STATUS_LOG
│  ├─ WORLD_OBJECT          WORLD_OBJECT
│  ├─ WORLD_OBJECT_LEVEL    WORLD_OBJECT_LEVEL
│  └─ USER_WORLD_OBJECT     USER_WORLD_OBJECT
└─ 3D Assets
   └─ Blender → GLB → Flutter bundle 또는 CDN → Three.js
```

## 경계 규칙

- Flutter는 사용자 흐름과 화면 상태를 담당하고 3D 장면을 직접 구성하지 않는다.
- Three.js는 성향별 룸 GLB 로딩, 카메라, 조명, 룸 배치, 룸 장식 노드 가시성 전환과 단순 애니메이션을 담당한다.
- Spring Boot가 사용자, 성향, 미션 수행 상태와 월드 성장의 기준 데이터를 관리한다.
- Supabase PostgreSQL이 사용자별 미션 수행과 월드 진행 상태의 최종 기준이다.
- `MISSION_STATUS_LOG`는 기존 이벤트 이력으로 보존한다. `USER_MISSION`은 사용자에게 제안된 한 건의 미션과 현재 상태를 나타내는 집계 레코드다.
- `USER_MISSION_CATEGORY_STAT`은 3D 성장과 후속 추천에 사용할 카테고리별 완료 통계를 보관한다. 하루 미션 수와 예상 시간은 사용자 설정 테이블 없이 Backend 정책과 Catalog 메타데이터로 관리한다.
- Mission Phase 3는 `/api/missions/today`와 `/api/missions/today/recommendations`를 통해 오늘 후보를 제공하며, 같은 날짜의 후보는 PostgreSQL `USER_MISSION`에서 복원한다.
- Mission Phase 4는 `/api/user-missions/{userMissionId}/select|cancel|replace|complete`로 사용자별 상태를 변경한다. Service가 사용자와 대상 미션을 잠그고 PostgreSQL 활성 슬롯과 상태 로그를 함께 갱신한다.
- 교체는 기존 수행 미션과 새 후보를 정렬된 순서로 잠근 뒤 하나의 Transaction에서 슬롯을 이전한다. 완료 재요청은 상태와 로그를 중복 변경하지 않는다.
- Mission Phase 5는 완료 상태·로그·`USER_MISSION_CATEGORY_STAT`·성향 완료 횟수를 같은 Transaction에서 갱신하고, 5회마다 최근 완료 벡터로 성향 축과 유형을 다시 계산한다.
- LLM 호출은 완료 Transaction 이후 수행한다. 검증된 결과만 공유 `MISSION` Catalog에 `SOURCE_TYPE=LLM`으로 저장하며 사용자·마일스톤 Unique 계약으로 중복 시도를 차단한다.
- `/api/missions/summary`는 전체 완료 수, 마지막 성향 반영 횟수, 성향 코드와 카테고리별 완료 통계를 제공한다.
- Flutter `lib/api/mission_api.dart`가 `X-User-Key` 기반 REST 계약과 오류 경계를 담당하고, `lib/mission/mission_experience_screen.dart`가 오늘 후보·수행·완료·통계 화면 상태를 담당한다.
- 성향 완료 홈은 `MissionDashboardSection`을 상단에 직접 포함한다. 후보 캐러셀·단일 수행/완료 상태가 같은 화면에서 전환되며 별도 미션 페이지 이동을 요구하지 않는다. 시간 선택 UI는 제공하지 않는다.
- 완료 미션의 네 축 벡터는 Flutter의 행동 선호 경험 방향 표시에 사용하고, 저장 성향 그래프는 Backend의 5회 단위 갱신 결과만 반영한다.
- 수행 슬롯의 중복은 `SELECTED`와 `COMPLETED` 상태에만 적용되는 PostgreSQL partial Unique Index로 차단한다.
- Oracle 레거시 호환성을 위해 물리 테이블 이름 `NOVELTY_USER`를 유지한다.
- GLB 경로와 Transform은 Frontend Asset Manifest가 소유하며 DB에는 URI나 바이너리를 저장하지 않는다.
- Flutter 초기화가 선택한 성향 룸만 Three.js에 전달하며, renderer는 기본 placeholder 룸을 선행 로드하지 않는다.
- GLB Loader는 asset URI별 Promise를 캐시하고, Bridge 초기화 재시도 중 동일한 룸을 중복 로드하지 않는다.
- `GET /api/world`는 Flutter에 World Snapshot을 제공하고 Three.js는 Backend API를 직접 호출하지 않는다.
- Mission 완료 Transaction은 `WorldProgressService`를 호출해 Category EXP를 갱신하며 동일 `userMissionId` 재요청에는 보상을 지급하지 않는다.
- Flutter 성향 프로필은 Three.js Renderer를 인라인으로 포함하며 초기에는 기본 룸만 표시한다. 첫 미션 완료 후 EXP가 있는 Category Object를 표시한다.
- 인라인 장면 탭은 기존 전체 World 화면으로 이동하고 회전·확대 입력은 Renderer가 그대로 처리한다.

## 3D Asset 규칙

```text
Blender 원본
→ GLB 내보내기
→ front/app/assets/world3d 로컬 배포
→ Frontend world_manifest.js에 경로·Transform 등록
→ Three.js GLB Loader 로드
```

PostgreSQL의 `WORLD_OBJECT_LEVEL`은 레벨별 누적 요구 EXP만 관리한다. World Object 레벨은 룸 장식 표시 단계를 계산하는 데 사용하며, 성향별 룸 GLB 경로와 파일명은 Frontend Manifest에서 관리한다. 룸 GLB 내부에서 `floor`·`wall` Mesh는 기본 골조로 유지하고 나머지 Mesh를 단계적으로 표시한다.

개발 검증 시 `flutter run -d chrome --dart-define=WORLD_TEST=true`로 테스트 화면을 실행한다. 테스트 화면은 실제 성향별 룸을 선택하고 모든 World Object 레벨을 한 단계씩 올려 Lv.1~Lv.5 장식 변화를 확인한다. `WORLD_TEST`를 지정하지 않은 운영 빌드에는 이 진입 경로가 없다.

## Deployment topology

```text
Repository root (Docker build context)
├─ front/Dockerfile
│  ├─ Three.js / Vite build   → front/world3d/dist
│  ├─ Flutter Web build       → front/app/build/web
│  └─ Nginx static server     → port 80
├─ back/Dockerfile
│  ├─ Maven + Java 21 build   → Spring Boot JAR
│  └─ Java 21 JRE runtime     → port 8080
└─ Supabase PostgreSQL
   └─ supabase/migrations (applied separately)
```

The frontend image contains the Flutter Web output and bundled Three.js/GLB
assets. `API_BASE_URL` is supplied as a Docker build argument and compiled
into Flutter. The backend image receives database, CORS, and optional OpenAI
settings only at runtime. `.dockerignore` prevents local `.env`, build
outputs, and dependency caches from entering the build context.
