# Novelty 기술 구조

이 문서는 노벨티 저장소의 기술 영역과 소유 경계를 정의한다. 각 영역은 기능이 확장되더라도 이 경계를 기준으로 유지한다.

```text
Novelty
├─ Frontend
│  ├─ Flutter
│  │  ├─ 선택지 폼           front/app/lib/survey
│  │  ├─ 성향 분석 UI       front/app/lib/personality
│  │  ├─ 미션 UI            front/app/lib/mission
│  │  ├─ 프로필             front/app/lib/profile
│  │  ├─ 설정               front/app/lib/settings
│  │  └─ 3D World 화면      front/app/lib/world
│  └─ Three.js Renderer      front/world3d/src/world
├─ Backend / Spring Boot
│  ├─ User                  com.novelty.user
│  ├─ Personality           com.novelty.personality
│  ├─ Mission               com.novelty.mission
│  ├─ Mission Completion    com.novelty.completion
│  └─ World / Progression   com.novelty.world
├─ Database / Oracle
│  ├─ USER                  NOVELTY_USER
│  ├─ PERSONALITY           USER_PERSONALITY_PROFILE
│  ├─ MISSION               MISSION
│  ├─ USER_MISSION          USER_MISSION
│  ├─ MISSION_SETTING       USER_MISSION_SETTING
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
- Three.js는 GLB 로딩, 카메라, 조명, 오브젝트 배치, 레벨 모델 전환과 단순 애니메이션만 담당한다.
- Spring Boot가 사용자, 성향, 미션 수행 상태와 월드 성장의 기준 데이터를 관리한다.
- Oracle이 사용자별 미션 수행과 월드 진행 상태의 최종 기준이다.
- `MISSION_STATUS_LOG`는 기존 이벤트 이력으로 보존한다. `USER_MISSION`은 사용자에게 제안된 한 건의 미션과 현재 상태를 나타내는 집계 레코드다.
- `USER_MISSION_SETTING`은 할애 가능 시간과 하루 수행 한도를, `USER_MISSION_CATEGORY_STAT`은 3D 성장과 후속 추천에 사용할 카테고리별 완료 통계를 보관한다.
- Mission Phase 3는 `/api/missions/settings`, `/api/missions/today`, `/api/missions/today/recommendations`를 통해 설정과 오늘 후보를 제공하며, 같은 날짜의 후보는 Oracle `USER_MISSION`에서 복원한다.
- Mission Phase 4는 `/api/user-missions/{userMissionId}/select|cancel|replace|complete`로 사용자별 상태를 변경한다. Service가 사용자·설정·대상 미션을 잠그고 Oracle 활성 슬롯과 상태 로그를 함께 갱신한다.
- 교체는 기존 수행 미션과 새 후보를 정렬된 순서로 잠근 뒤 하나의 Transaction에서 슬롯을 이전한다. 완료 재요청은 상태와 로그를 중복 변경하지 않는다.
- Mission Phase 5는 완료 상태·로그·`USER_MISSION_CATEGORY_STAT`·성향 완료 횟수를 같은 Transaction에서 갱신하고, 5회마다 최근 완료 벡터로 성향 축과 유형을 다시 계산한다.
- LLM 호출은 완료 Transaction 이후 수행한다. 검증된 결과만 공유 `MISSION` Catalog에 `SOURCE_TYPE=LLM`으로 저장하며 사용자·마일스톤 Unique 계약으로 중복 시도를 차단한다.
- `/api/missions/summary`는 전체 완료 수, 마지막 성향 반영 횟수, 성향 코드와 카테고리별 완료 통계를 제공한다.
- Flutter `lib/api/mission_api.dart`가 `X-User-Key` 기반 REST 계약과 오류 경계를 담당하고, `lib/mission/mission_experience_screen.dart`가 설정·오늘 후보·수행·완료·통계 화면 상태를 담당한다.
- 성향 프로필의 `오늘의 미션 보기`가 미션 화면 진입점이며, 미션 완료 후 프로필로 돌아갈 때 현재 사용자 정보를 다시 조회해 5회 성향 갱신 결과를 반영한다.
- 수행 슬롯의 중복은 `SELECTED`와 `COMPLETED` 상태에만 적용되는 Oracle 함수 기반 Unique Index로 차단한다.
- Oracle의 `USER`는 예약 의미와 충돌하므로 물리 테이블 이름은 기존 `NOVELTY_USER`를 유지한다.
- GLB 경로는 DB에 URI로 저장하며 바이너리 파일 자체는 Oracle에 저장하지 않는다.

## 3D Asset 규칙

```text
Blender 원본
→ GLB 내보내기
→ front/app/assets 또는 CDN 배포
→ WORLD_OBJECT_LEVEL.GLB_ASSET_URI 등록
→ Three.js GLB Loader 로드
```

레벨별 모델은 같은 `WORLD_OBJECT_ID` 아래 서로 다른 `OBJECT_LEVEL`과 `GLB_ASSET_URI`로 관리한다.
