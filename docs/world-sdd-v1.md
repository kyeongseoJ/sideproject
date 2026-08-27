# 3D World / Object Growth SDD V1

현재 운영 Database는 Supabase PostgreSQL이다. 이 문서의 과거 Oracle Phase 기록은 레거시 검증 이력이며, 현재 Schema와 실행 기준은 `supabase/migrations`다.

## 1. 범위와 기준 흐름

Mission 완료 Category와 연결된 World Object에 EXP를 지급하고 레벨별 GLB 외형을 표시한다. Character, 이동, Physics, 자유 배치, 멀티플레이, 다른 사용자 World, 전체 World Level은 제외한다.

```text
USER_MISSION 완료 → Category·Difficulty → WorldProgressService
→ USER_WORLD_OBJECT EXP·Level → Flutter World State → JSON Bridge → Three.js
```

Backend와 Supabase PostgreSQL이 EXP·Level의 Source of Truth다. Three.js는 Backend API를 호출하거나 성장값을 계산하지 않는다.

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

## 4. PostgreSQL 계약

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

초기화 시 Flutter가 선택한 성향 룸만 로드한다. 기본 placeholder 룸은 선행 로드하지 않으며, GLB Loader는 asset URI별 Promise를 캐시한다. Bridge 초기화 재시도 중 동일한 룸 요청은 진행 중인 작업과 완료 키를 확인해 중복 로드하지 않는다.

## 8. JSON Bridge V1

공통 Envelope는 `{"version":1,"type":"rendererReady","payload":{}}`다.

Flutter → Three.js:

- `initializeWorld`: 전체 Snapshot
  - `payload.objects`는 1개 이상이어야 하며 `payload.objectCount`와 배열 길이가 일치해야 한다.
- `updateObjectLevel`: 한 Object 변경
- `playLevelUp`: Level Up Animation
- `focusGrowthObject`: 미션 완료로 변화한 룸 장식을 카메라로 포커싱하고 파동·입자 효과를 재생한다. 룸 GLB의 장식 Mesh가 실제 성장 대상이므로 Category Object Code는 `ROOM` 그룹으로 해석한다.
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
- 전체 화면은 `completion.worldGrowth.rewardApplied=true`일 때에만 성장 포커싱 효과를 한 번 실행한다. Flutter 결과 카드는 표시명·카테고리·실제 지급 EXP와 레벨업 여부를 5초 동안 표시하며 사용자가 닫을 수 있다.
- 성향 프로필 안의 인라인 Renderer와 전체 화면 Renderer는 동일한 Snapshot·Manifest를 사용한다.
- 인라인 초기 표시는 기본 룸만 표시하고, 첫 미션 완료 후 EXP가 있는 Category Object를 표시한다.
- 전체 화면 제목은 Personality type별 공간명을 사용한다.
- 교체·종료 시 Geometry·Material·Texture·AnimationMixer 해제
- 종료·재진입과 Background·Foreground 복원
- GLB 실패 시 `rendererError`와 Flutter 대체 UI
- GLB 실패 메시지는 실패한 상대 asset 경로를 포함한다. Snapshot이 비어 있거나 성향 필터 결과가 비면 Flutter가 오류를 표시하거나 전체 Object Snapshot으로 fallback한다.

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
