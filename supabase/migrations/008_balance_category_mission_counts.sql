-- Balance the active catalog to 50 missions per category.
-- Stable codes and a content fingerprint keep this migration idempotent.
INSERT INTO mission (
    mission_id, title, title_normalized, description, category, difficulty,
    estimated_minutes, indoor_outdoor, social_level, activity_level, novelty_level,
    action_type, creativity_level, unpredictability_level, comfort_zone_distance,
    cost_level, tags, enabled, source_type, content_fingerprint
)
SELECT nextval('mission_seq'), title, code, description, category, difficulty,
       minutes,
       CASE category WHEN 'MOVEMENT' THEN 1 WHEN 'OUTDOOR' THEN 1 ELSE 0 END,
       CASE category WHEN 'SOCIAL' THEN 1 ELSE 0 END,
       CASE category WHEN 'MOVEMENT' THEN 2 WHEN 'OUTDOOR' THEN 2 ELSE 1 END,
       1,
       CASE category
           WHEN 'MOVEMENT' THEN 'EXERCISE' WHEN 'CREATIVE' THEN 'CREATE'
           WHEN 'FOOD' THEN 'TASTE' WHEN 'LEARNING' THEN 'PRACTICE'
           WHEN 'SOCIAL' THEN 'CONNECT' WHEN 'OUTDOOR' THEN 'EXPLORE'
           WHEN 'ORGANIZING' THEN 'ORGANIZE' ELSE 'EXPLORE' END,
       CASE WHEN category = 'CREATIVE' THEN 2 ELSE 1 END,
       1, 1,
       CASE WHEN category IN ('FOOD', 'CULTURE') THEN 1 ELSE 0 END,
       kind || ',' || category || ',' || code,
       'Y', 'BASE', encode(digest(code || '|' || title || '|' || description, 'sha256'), 'hex')
  FROM (VALUES
    ('BALANCE_CREATIVE_001','좋아하는 소리를 색과 선으로 옮기기','노래나 주변 소리 하나를 골라 눈을 감고 들은 뒤 떠오른 색과 선만으로 작은 작품을 완성해보세요.','CREATIVE',2,30,'SUPPLEMENT'),
    ('BALANCE_CREATIVE_002','하루의 물건으로 미니 전시 만들기','오늘 사용한 물건 세 가지를 골라 작은 전시처럼 배치하고 각 물건에 새로운 제목과 설명을 붙여보세요.','CREATIVE',1,45,'SUPPLEMENT'),
    ('BALANCE_FOOD_001','한 가지 재료의 세 가지 온도 맛보기','하나의 안전한 재료를 차갑게, 실온으로, 따뜻하게 준비해 온도에 따른 맛과 식감의 차이를 비교해보세요.','FOOD',1,30,'SUPPLEMENT'),
    ('BALANCE_FOOD_002','평소 안 고르던 과일로 간식 만들기','가게에서 평소 선택하지 않던 과일을 하나 골라 간단한 간식으로 만들고 향과 식감을 기록해보세요.','FOOD',1,20,'SUPPLEMENT'),
    ('BALANCE_LEARNING_001','낯선 물건의 작동 원리 추측하기','집에 있지만 원리를 잘 모르는 물건 하나를 골라 작동 원리를 먼저 추측한 뒤 자료를 찾아 확인해보세요.','LEARNING',2,30,'SUPPLEMENT'),
    ('BALANCE_LEARNING_002','오늘 본 숫자에서 규칙 찾기','하루 동안 마주친 숫자들을 모아 반복, 간격, 크기 중 하나의 규칙을 찾아 짧게 설명해보세요.','LEARNING',1,20,'SUPPLEMENT'),
    ('BALANCE_LEARNING_003','평소 지나친 단어의 어원 조사하기','자주 쓰지만 유래를 모르는 단어 하나를 골라 어원과 의미 변화를 찾아 나만의 예문을 만들어보세요.','LEARNING',1,45,'SUPPLEMENT'),
    ('BALANCE_OUTDOOR_001','동네의 가장 오래된 나무 찾기','안전한 산책 범위에서 오래되어 보이는 나무를 찾아 주변 풍경과 나무의 특징을 관찰해보세요.','OUTDOOR',1,30,'SUPPLEMENT'),
    ('BALANCE_OUTDOOR_002','평소와 다른 시간에 공원 걷기','평소 방문하지 않던 시간대에 가까운 공원을 찾아 빛, 소리, 사람의 변화를 천천히 살펴보세요.','OUTDOOR',2,45,'SUPPLEMENT'),
    ('BALANCE_OUTDOOR_003','길 위의 작은 표식 수집하기','산책하며 표지판, 스티커, 보도블록처럼 평소 지나치는 작은 표식 다섯 가지를 찾아 기록해보세요.','OUTDOOR',1,20,'SUPPLEMENT'),
    ('BALANCE_ORGANIZING_001','서랍 하나를 용도 없이 비우기','서랍 하나를 완전히 비운 뒤 물건의 필요 여부를 다시 판단하고 남은 물건만 새로운 순서로 배치해보세요.','ORGANIZING',2,30,'SUPPLEMENT'),
    ('BALANCE_ORGANIZING_002','하루의 알림 세 개 줄이기','휴대전화 알림을 살펴보고 오늘 꼭 필요하지 않은 알림 세 개를 끄며 집중 환경을 바꿔보세요.','ORGANIZING',1,15,'SUPPLEMENT'),
    ('BALANCE_ORGANIZING_003','가방 속 물건의 역할 다시 정하기','가방을 비우고 모든 물건에 오늘의 역할을 하나씩 적은 뒤 필요 순서대로 다시 넣어보세요.','ORGANIZING',1,20,'SUPPLEMENT'),
    ('BALANCE_ORGANIZING_004','냉장고 문 안쪽만 재배치하기','냉장고 전체가 아니라 문 안쪽 한 칸만 골라 유통기한과 사용 빈도를 기준으로 재배치해보세요.','ORGANIZING',1,30,'SUPPLEMENT'),
    ('BALANCE_ORGANIZING_005','내일의 첫 행동을 눈앞에 준비하기','내일 아침 가장 먼저 할 행동 하나를 정하고 필요한 물건을 미리 보이는 곳에 준비해보세요.','ORGANIZING',1,10,'SUPPLEMENT'),
    ('BALANCE_CULTURE_001','평소 보지 않던 표지판의 디자인 관찰하기','동네에서 평소 읽지 않던 안내 표지판 하나를 골라 글꼴, 색, 배치가 주는 인상을 기록해보세요.','CULTURE',1,20,'SUPPLEMENT'),
    ('BALANCE_CULTURE_002','지역 도서관의 가장 얇은 책 펼치기','도서관에서 평소 찾지 않던 분야의 얇은 책을 골라 첫 장과 마지막 장을 읽고 남은 질문을 적어보세요.','CULTURE',2,30,'SUPPLEMENT'),
    ('BALANCE_CULTURE_003','동네의 소리만으로 장소 그리기','눈을 감고 익숙한 장소의 소리를 들은 뒤 보이지 않는 공간을 상상해 지도나 그림으로 표현해보세요.','CULTURE',2,45,'SUPPLEMENT'),
    ('BALANCE_CULTURE_004','작품 설명 없이 전시 한 점 보기','작품 설명을 먼저 읽지 않고 전시 한 점을 오래 감상한 뒤 내가 붙인 제목과 실제 설명을 비교해보세요.','CULTURE',2,30,'SUPPLEMENT'),
    ('BALANCE_CULTURE_005','오래된 물건의 주인공 상상하기','집이나 동네에서 오래된 물건 하나를 발견해 그 물건을 사용했을 사람의 하루를 짧은 이야기로 써보세요.','CULTURE',1,20,'SUPPLEMENT'),
    ('BALANCE_CULTURE_006','평소 듣지 않던 시대의 음악 듣기','평소 듣지 않던 시대의 음악 한 곡을 골라 악기, 리듬, 분위기에서 새롭게 느낀 점을 적어보세요.','CULTURE',1,30,'SUPPLEMENT'),
    ('BALANCE_MOVEMENT_001','평소 지나치던 계단의 층수 세기','무리하지 않는 범위에서 익숙한 건물의 계단을 천천히 오르며 층수와 몸의 변화를 관찰해보세요.','MOVEMENT',1,15,'SUPPLEMENT'),
    ('BALANCE_MOVEMENT_002','걷는 속도를 세 번 바꿔보기','안전한 산책길에서 느린 속도, 평소 속도, 빠른 속도를 차례로 경험하고 주변 인식의 차이를 기록해보세요.','MOVEMENT',1,30,'SUPPLEMENT'),
    ('BALANCE_MOVEMENT_003','몸으로 알파벳 한 글자 만들기','매트나 안전한 공간에서 몸으로 표현할 수 있는 글자 하나를 정하고 여러 자세로 만들어보세요.','MOVEMENT',1,10,'SUPPLEMENT'),
    ('BALANCE_MOVEMENT_004','평소 앉는 자리와 반대편에서 쉬기','집이나 공공장소의 안전한 자리에서 평소와 반대 방향을 바라보며 잠시 쉬고 시야의 차이를 찾아보세요.','MOVEMENT',1,15,'SUPPLEMENT'),
    ('BALANCE_MOVEMENT_005','목적지까지 한 블록 더 돌아가기','익숙한 목적지로 가되 한 블록을 더 돌아 새로운 건물과 길의 연결을 발견해보세요.','MOVEMENT',2,30,'SUPPLEMENT'),
    ('BALANCE_MOVEMENT_006','하루의 자세 세 장면 기록하기','앉기, 걷기, 서기 중 세 장면의 자세를 사진 없이 메모로 기록하고 편안함을 비교해보세요.','MOVEMENT',1,20,'SUPPLEMENT'),
    ('BALANCE_SOCIAL_001','가게 직원에게 추천 이유 묻기','무엇을 고를지 정하지 않은 채 가게 직원에게 추천을 부탁하고 추천 이유를 한 가지 더 물어보세요.','SOCIAL',1,10,'SUPPLEMENT'),
    ('BALANCE_SOCIAL_002','친구의 하루 루틴 인터뷰하기','친구 한 명에게 평소 궁금했던 하루 루틴 세 가지를 묻고 내 루틴과 다른 점을 발견해보세요.','SOCIAL',1,20,'SUPPLEMENT'),
    ('BALANCE_SOCIAL_003','고마웠던 사람에게 구체적으로 말하기','최근 도움을 받았던 사람에게 무엇이 고마웠는지 행동을 하나 짚어 짧은 메시지로 전해보세요.','SOCIAL',1,10,'SUPPLEMENT'),
    ('BALANCE_SOCIAL_004','평소 말하지 않던 취향 공유하기','대화 중 안전하고 부담 없는 범위에서 평소 먼저 말하지 않던 취향 하나를 솔직하게 공유해보세요.','SOCIAL',2,15,'SUPPLEMENT'),
    ('BALANCE_SOCIAL_005','서로의 역할을 바꿔 일하기','친구나 동료와 작은 공동 작업 하나를 정해 평소 맡지 않던 역할을 서로 바꾸어 진행해보세요.','SOCIAL',2,30,'SUPPLEMENT'),
    ('BALANCE_SOCIAL_006','처음 만난 사람의 이름 기억하기','오늘 만난 사람 한 명의 이름을 다시 확인하고 대화 중 자연스럽게 한 번 사용해보세요.','SOCIAL',1,10,'SUPPLEMENT'),
    ('BALANCE_SOCIAL_007','상대가 고른 장소에서 쉬기','동행자에게 장소 선택을 맡기고 평소라면 고르지 않을 것 같은 장소에서 짧게 머물러보세요.','SOCIAL',2,30,'SUPPLEMENT')
  ) AS additions(code, title, description, category, difficulty, minutes, kind)
ON CONFLICT DO NOTHING;

SELECT setval('mission_seq', COALESCE((SELECT MAX(mission_id) FROM mission), 1), true);
