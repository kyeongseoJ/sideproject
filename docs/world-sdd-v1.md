# 3D World / Object Growth SDD V1

## 1. 범위와 기준 흐름

Mission 완료 Category와 연결된 World Object에 EXP를 지급하고 레벨별 GLB 외형을 표시한다. Character, 이동, Physics, 자유 배치, 멀티플레이, 다른 사용자 World, 전체 World Level은 제외한다.

```text
USER_MISSION 완료 → Category·Difficulty → WorldProgressService
→ USER_WORLD_OBJECT EXP·Level → Flutter World State → JSON Bridge → Three.js
```

Backend와 Oracle이 EXP·Level의 Source of Truth다. Three.js는 Backend API를 호출하거나 성장값을 계산하지 않는다.

## 2. Category와 Object

| Category | Object Code | 표시명 |
|---|---|---|
| MOVEMENT | TRAINING_CORNER | 운동 코너 |
| CREATIVE | ART_EASEL | 창작 이젤 |
| FOOD | KITCHEN_TABLE | 요리 테이블 |
| LEARNING | BOOKSHELF | 책장 |
| SOCIAL | MESSAGE_BOARD | 소통 보드 |
| OUTDOOR | INDOOR_GARDEN | 실내 정원 |
| ORGANIZING | STORAGE_CABINET | 수납장 |
| CULTURE | RECORD_PLAYER | 레코드 플레이어 |

`WORLD_OBJECT.CATEGORY`는 Unique이며 Category:Object는 1:1이다.

## 3. EXP와 Level

- Mission 난이도 1/2/3: 10/20/30 EXP
- Lv1/Lv2/Lv3/Lv4/Lv5: 누적 EXP 0/50/120/220/350
- EXP는 Lv5 이후에도 누적하며 Lv5의 `nextLevelRequiredExp`는 `null`이다.

## 4. Oracle 계약

- `WORLD_OBJECT`: ID, Object Code, 표시명, Category, Max Level, 활성 여부, 시각. Object Code와 Category는 각각 Unique다.
- `WORLD_OBJECT_LEVEL`: Object ID, Level, Required EXP만 관리한다.
- `USER_WORLD_OBJECT`: User ID, Object ID, EXP, 현재 Level, 시각. PK는 `(USER_ID, WORLD_OBJECT_ID)`다.
- GLB URI, Animation 이름, Position·Rotation·Scale은 DB에 저장하지 않는다.
- 사용자 진행 행이 없으면 Lv1/0 EXP로 간주하고 최초 보상 시 Upsert한다.

## 5. REST 계약

`GET /api/world`는 `X-User-Key` 사용자의 8개 Object를 한 번에 반환한다. Object 항목은 `objectCode`, `categoryCode`, `displayName`, `level`, `exp`, `nextLevelRequiredExp`, `maxLevel`을 포함한다.

기존 `POST /api/user-missions/{userMissionId}/complete`의 `completion.worldGrowth`에는 `objectCode`, `categoryCode`, `awardedExp`, `previousLevel`, `currentLevel`, `currentExp`, `nextLevelRequiredExp`, `levelUp`, `rewardApplied`를 포함한다. 최초 완료만 보상하고, 멱등 재요청은 현재 상태와 `rewardApplied=false`를 반환한다.

## 6. Transaction과 동시성

기존 사용자 행과 `USER_MISSION` 잠금을 유지한다. 완료 상태·로그·Category 통계·성향 후처리·World EXP는 동일 Transaction에서 처리한다. 이미 `COMPLETED`인 요청은 World 갱신을 건너뛴다. LLM 호출만 Commit 이후 처리한다.

## 7. Asset Manifest

GLB URI와 Position·Rotation·Scale은 `front/world3d`의 Manifest가 소유한다. Key는 `objectCode + level`이다. Runtime GLB는 Flutter Local Asset으로 배포한다. Backend와 DB는 파일명을 알지 못한다.

## 8. JSON Bridge V1

공통 Envelope는 `{"version":1,"type":"rendererReady","payload":{}}`다.

Flutter → Three.js:

- `initializeWorld`: 전체 Snapshot
- `updateObjectLevel`: 한 Object 변경
- `playLevelUp`: Level Up Animation
- `dispose`: Renderer 정리

Three.js → Flutter:

- `rendererReady`
- `rendererError`
- `objectHovered`: Web 마우스·펜이 가리키는 Object Code이며 이탈 시 `null`
- `objectSelected`
- `sceneTapped`: 드래그가 아닌 장면 탭. 인라인 미리보기에서 전체 화면 진입에 사용

Android는 WebView JavaScript Channel `NoveltyWorldBridge`, Web은 same-origin iframe `postMessage`를 사용한다.

## 9. Renderer 계약

- Orthographic Camera와 고정 아이소메트릭 초기 시점
- 제한된 회전·Zoom·Object Tap
- 전체 화면에서는 Object 호버 또는 클릭 시 한글 Object명, 연결된 성향 Category와 현재·최대 단계를 Flutter 툴팁으로 표시한다.
- 성향 프로필 안의 인라인 Renderer와 전체 화면 Renderer는 동일한 Snapshot·Manifest를 사용한다.
- 인라인 초기 표시는 성향 관심 Category와 완료 EXP가 있는 Category Object로 제한한다.
- 전체 화면 제목은 Personality type별 공간명을 사용한다.
- 교체·종료 시 Geometry·Material·Texture·AnimationMixer 해제
- 종료·재진입과 Background·Foreground 복원
- GLB 실패 시 `rendererError`와 Flutter 대체 UI

## 10. Phase 0~9

0. 본 SDD와 Schema·Bridge 계약 확정
1. Android WebView + Three.js Technical Spike
2. World DB 및 Backend Domain
3. Snapshot API
4. Mission Completion 연결
5. Flutter World State
6. Three.js Diorama Renderer
7. Backend·Flutter·Three.js 연결
8. Level Up UI·Animation
9. Oracle·Android·Web 회귀 검증

## 11. 구현 상태 (2026-08-20)

- Phase 0~8: 구현 및 자동 검증 완료
- Phase 9 Backend: 전체 171건, 실패 0, 오류 0, Oracle 환경 조건부 10건 제외; Package 성공
- Phase 9 Flutter: 전체 81건, 환경 조건부 1건 제외; Analyze, Web Build, Android Debug APK 성공
- Phase 9 Three.js: Vite Build 성공. Android Emulator에서 Room GLB, Renderer Ready, Lv1→Lv2 교체와 Background/Foreground 복귀 확인
- Phase 9 Oracle: `DB.sql` 적용으로 World Table 3개, Object 8개, Level 40개를 확인했고 실제 Oracle Rollback 통합 테스트에서 Mission 완료·World EXP·Snapshot·중복 보상 방지를 검증함

Web·Android의 실제 사용자 전체 흐름 재확인 전까지 Phase 9 전체를 완료로 표기하지 않는다.
