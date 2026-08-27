# 운영 미션 Catalog

현재 운영 미션의 기준 데이터는 `supabase/migrations`에서 관리한다. 이 문서는 개별 seed 문장을 중복 보관하지 않고, 운영 Catalog의 구성 기준과 확인 방법만 제공한다.

## 현재 구성

| 기준 | 수량·범위 |
|---|---:|
| 활성 미션 전체 | 400개 |
| 카테고리 | 8개 |
| 카테고리별 미션 | 각 50개 |
| 예상 시간 | 5~180분 |
| 기본·보강 미션 | `supabase/migrations/002_seed_missions.sql`, `007_seed_missions_66.sql`, `008_seed_mission_balance.sql` |
| LLM 미션 | 완료 5회 마일스톤에서 검증 후 공용 Catalog에 추가 |

카테고리는 운동(`MOVEMENT`), 창작(`CREATIVE`), 요리·미식(`FOOD`), 학습(`LEARNING`), 교류(`SOCIAL`), 야외활동(`OUTDOOR`), 정리·정돈(`ORGANIZING`), 문화생활(`CULTURE`)이다.

## 운영 규칙

- 사용자가 선택한 관심 카테고리는 추천 후보에서 제외한다.
- 미션의 실행 방식, 난이도, 활동 환경, 신체 활동, 새로움과 최근 수행 이력을 추천 계산에 사용한다.
- 미션 제목 정규화와 Content fingerprint로 기준 데이터 중복을 방지한다.
- 안전성·중복성 검사를 통과한 LLM 미션만 공용 Catalog에 저장한다.

## Supabase 확인

운영 DB에서 다음 조건을 확인한다.

```sql
select category, count(*)
from mission
where enabled = 'Y'
group by category
order by category;
```

각 카테고리 결과가 50개이고 전체 결과가 400개인지 확인한다. Migration 재실행과 검증은 `supabase/apply-migrations.jsh`, `supabase/verify-migration.jsh`를 사용한다.
