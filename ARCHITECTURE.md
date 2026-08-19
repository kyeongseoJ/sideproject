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
