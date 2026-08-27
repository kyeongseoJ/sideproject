-- Add long-form and deliberate-deviation missions to the shared BASE catalog.
-- The stable code is used as title_normalized so this migration is idempotent.
INSERT INTO mission (
    mission_id, title, title_normalized, description, category, difficulty,
    estimated_minutes, indoor_outdoor, social_level, activity_level, novelty_level,
    action_type, creativity_level, unpredictability_level, comfort_zone_distance,
    cost_level, tags, enabled, source_type, content_fingerprint
)
SELECT nextval('mission_seq'), title, code, description, category, difficulty,
       minutes,
       CASE category
           WHEN 'MOVEMENT' THEN 1 WHEN 'OUTDOOR' THEN 1 ELSE 0 END,
       CASE category
           WHEN 'SOCIAL' THEN 1 ELSE 0 END,
       CASE category
           WHEN 'MOVEMENT' THEN 2 WHEN 'OUTDOOR' THEN 2 ELSE 1 END,
       CASE WHEN kind = 'DEVIATION' THEN 2 ELSE 1 END,
       CASE category
           WHEN 'MOVEMENT' THEN 'EXERCISE' WHEN 'CREATIVE' THEN 'CREATE'
           WHEN 'FOOD' THEN 'TASTE' WHEN 'LEARNING' THEN 'PRACTICE'
           WHEN 'SOCIAL' THEN 'CONNECT' WHEN 'OUTDOOR' THEN 'EXPLORE'
           WHEN 'ORGANIZING' THEN 'ORGANIZE' ELSE 'EXPLORE' END,
       CASE WHEN category = 'CREATIVE' THEN 2 ELSE 1 END,
       CASE WHEN kind = 'DEVIATION' THEN 2 ELSE 1 END,
       CASE WHEN kind = 'DEVIATION' THEN 2 ELSE 1 END,
       CASE WHEN category IN ('FOOD', 'CULTURE') THEN 1 ELSE 0 END,
       kind || ',' || category || ',' || code,
       'Y', 'BASE', encode(digest(code || '|' || title || '|' || description, 'sha256'), 'hex')
  FROM (VALUES
    ('LONG_001','새벽부터 저녁까지 동네의 하루 동선 기록하기','아침부터 저녁까지 평소 지나치던 동네를 천천히 걸으며 시간대별 풍경과 사람들의 변화를 사진과 메모로 기록해보세요.','MOVEMENT',3,120,'LONG'),
    ('LONG_002','도시의 서로 다른 길 세 곳 이어 걷기','익숙한 목적지를 향하되 매 구간마다 한 번도 걷지 않은 길을 선택해 세 개의 동선을 하나의 산책으로 이어보세요.','MOVEMENT',3,150,'LONG'),
    ('LONG_003','하루 동안 몸을 쓰는 작은 활동 다섯 가지','스트레칭, 계단, 산책, 가벼운 근력 운동 등 서로 다른 활동 다섯 가지를 하루 일정에 나누어 실천하고 몸의 변화를 적어보세요.','MOVEMENT',2,180,'LONG'),
    ('LONG_004','처음 가는 동네에서 장거리 산책하기','대중교통으로 처음 가는 동네에 도착해 지도 앱을 최소한으로 사용하며 새로운 장소를 발견하는 산책을 완성해보세요.','MOVEMENT',3,150,'LONG'),
    ('LONG_005','한 작품을 기획하고 완성하기','아이디어를 정하고 자료를 모은 뒤 글, 그림, 사진 또는 음악 중 하나의 결과물을 완성해 과정을 정리해보세요.','CREATIVE',3,180,'LONG'),
    ('LONG_006','사진 열두 장으로 하루 이야기 만들기','하루 동안 서로 다른 장면 열두 개를 촬영하고 순서를 정해 짧은 이야기나 온라인 앨범으로 구성해보세요.','CREATIVE',2,120,'LONG'),
    ('LONG_007','손으로 만드는 생활 소품 완성하기','집에 있는 재료와 도구를 활용해 실제로 사용할 수 있는 작은 생활 소품을 설계하고 만들어보세요.','CREATIVE',3,150,'LONG'),
    ('LONG_008','나만의 짧은 오디오 다큐 만들기','주변의 소리와 짧은 인터뷰 또는 내레이션을 모아 한 편의 오디오 기록으로 편집해보세요.','CREATIVE',3,180,'LONG'),
    ('LONG_009','처음 보는 요리의 장보기부터 완성까지','평소 먹지 않던 나라의 요리를 골라 재료를 조사하고 장을 본 뒤 조리와 시식 기록까지 남겨보세요.','FOOD',3,120,'LONG'),
    ('LONG_010','계절 재료로 세 가지 메뉴 구성하기','시장이나 동네 가게에서 제철 재료를 고르고 서로 다른 조리법의 세 가지 메뉴를 계획해 완성해보세요.','FOOD',3,150,'LONG'),
    ('LONG_011','동네 식당 대신 하루 식탁 차리기','아침부터 저녁까지 직접 메뉴를 계획하고 장보기, 준비, 식사, 정리까지 하나의 식탁 경험으로 만들어보세요.','FOOD',2,180,'LONG'),
    ('LONG_012','익숙한 재료의 새로운 조합 실험하기','냉장고 속 익숙한 재료 세 가지를 평소와 다른 방식으로 조합해 두 번 이상 맛을 조정하고 결과를 기록해보세요.','FOOD',2,120,'LONG'),
    ('LONG_013','하루 동안 한 주제 깊게 배우기','평소 관심 밖에 있던 주제를 하나 정해 책, 강의, 기사 등 세 가지 자료를 살펴보고 핵심을 자기 말로 정리해보세요.','LEARNING',3,180,'LONG'),
    ('LONG_014','처음 접하는 기술의 입문 프로젝트','한 번도 다뤄보지 않은 도구나 기술을 골라 기초를 익힌 뒤 작은 결과물을 직접 만들어보세요.','LEARNING',3,150,'LONG'),
    ('LONG_015','전문가에게 질문하고 검증하기','궁금했던 주제를 정하고 관련 분야 사람이나 공개 커뮤니티에 질문한 뒤 답변을 다른 자료와 비교해보세요.','LEARNING',2,120,'LONG'),
    ('LONG_016','하루 관찰 노트로 새로운 분야 익히기','평소 지나치던 현상 하나를 정해 하루 동안 관찰하고 가설, 발견, 궁금증을 시간순으로 기록해보세요.','LEARNING',2,180,'LONG'),
    ('LONG_017','낯선 모임에서 반나절 함께하기','관심 분야와 무관한 공개 모임이나 지역 프로그램에 참여해 세 명 이상과 대화를 나누고 느낀 점을 기록해보세요.','SOCIAL',3,150,'LONG'),
    ('LONG_018','오래 연락하지 않은 사람과 하루 보내기','연락이 뜸했던 사람에게 먼저 제안해 평소 하지 않던 활동을 함께 계획하고 실행해보세요.','SOCIAL',2,120,'LONG'),
    ('LONG_019','서로 다른 세 사람의 추천 따라가기','세 사람에게 각자 추천받은 장소나 활동을 하나씩 방문하고 추천 이유와 내 경험을 비교해보세요.','SOCIAL',3,180,'LONG'),
    ('LONG_020','작은 동네 행사를 직접 열기','친구나 이웃과 함께 부담 없는 주제를 정해 초대, 진행, 정리까지 작은 행사를 직접 운영해보세요.','SOCIAL',3,150,'LONG'),
    ('LONG_021','대중교통으로 처음 가는 곳 탐험하기','처음 방문하는 지역을 정해 대중교통으로 이동하고, 현장에서 발견한 장소 다섯 곳을 지도와 메모로 남겨보세요.','OUTDOOR',3,180,'LONG'),
    ('LONG_022','도시의 자연 지점 연결하기','공원, 하천, 작은 숲 등 서로 다른 자연 지점 네 곳을 하나의 경로로 연결해 천천히 탐방해보세요.','OUTDOOR',2,150,'LONG'),
    ('LONG_023','하루 동안 하늘의 변화 관찰하기','같은 장소에서 아침, 오후, 저녁의 하늘과 주변 빛을 관찰하고 사진과 짧은 감상을 남겨보세요.','OUTDOOR',2,120,'LONG'),
    ('LONG_024','처음 보는 야외 활동 체험하기','안전 장비와 기본 안내를 확인한 뒤 평소 하지 않던 야외 활동을 체험하고 몸과 감정의 변화를 기록해보세요.','OUTDOOR',3,180,'LONG'),
    ('LONG_025','집 안의 한 구역 완전 재설계하기','한 구역의 물건을 모두 꺼내 필요한 것과 아닌 것을 나눈 뒤 동선과 사용 빈도에 맞게 다시 배치해보세요.','ORGANIZING',2,120,'LONG'),
    ('LONG_026','디지털 생활 전체 점검하기','사진, 파일, 앱, 알림을 항목별로 점검하고 삭제·분류·보관 규칙을 세워 디지털 환경을 정리해보세요.','ORGANIZING',2,150,'LONG'),
    ('LONG_027','한 달 생활 루틴 설계하고 시험하기','수면, 식사, 이동, 취미 중 세 영역의 새로운 루틴을 설계하고 하루 동안 실제로 시험한 뒤 수정안을 적어보세요.','ORGANIZING',3,180,'LONG'),
    ('LONG_028','사용하지 않던 물건으로 공간 바꾸기','오래 쓰지 않은 물건을 다른 용도로 재배치하거나 나눔할 계획을 세워 생활 공간의 한 부분을 새롭게 바꿔보세요.','ORGANIZING',2,120,'LONG'),
    ('LONG_029','하루 문화 탐방 코스 만들기','평소 찾지 않던 전시, 공연, 서점, 역사 공간 중 세 곳을 연결해 나만의 문화 탐방 코스를 완성해보세요.','CULTURE',3,150,'LONG'),
    ('LONG_030','한 시대의 흔적 따라 걷기','동네나 도시에서 한 시대를 보여주는 장소를 조사하고 직접 방문해 사진, 자료, 감상을 하나의 기록으로 묶어보세요.','CULTURE',3,180,'LONG'),
    ('DEVIATION_001','평소 입지 않던 색으로 하루 보내기','옷이나 소품에서 평소 고르지 않던 선명한 색을 하나 선택해 하루 동안 자연스럽게 활용해보세요.','MOVEMENT',2,15,'DEVIATION'),
    ('DEVIATION_002','목적지 없이 버스 한 번 타기','평소 이용하지 않는 방향의 버스를 타고 세 정거장 뒤 내려 주변을 관찰하며 돌아오는 길을 찾아보세요.','MOVEMENT',2,30,'DEVIATION'),
    ('DEVIATION_003','평소와 반대 손으로 익숙한 일 하기','양치, 마우스 사용, 문 열기 중 하나를 반대 손으로 해보며 불편함과 새롭게 보인 점을 적어보세요.','MOVEMENT',1,10,'DEVIATION'),
    ('DEVIATION_004','조용한 춤으로 거리 걷기','사람이 적은 안전한 장소에서 이어폰 없이 마음속 음악에 맞춰 평소보다 과장된 걸음으로 짧게 걸어보세요.','MOVEMENT',2,20,'DEVIATION'),
    ('DEVIATION_005','결과를 모르는 재료로 그리기','눈을 감고 재료 세 가지를 골라 어떤 결과가 나올지 정하지 않은 채 30분 동안 그림을 완성해보세요.','CREATIVE',2,30,'DEVIATION'),
    ('DEVIATION_006','내 목소리로 낯선 문장 녹음하기','평소 쓰지 않는 말투로 짧은 문장을 세 가지 녹음하고 다시 들으며 어색함을 관찰해보세요.','CREATIVE',1,15,'DEVIATION'),
    ('DEVIATION_007','평소라면 버릴 재료로 작품 만들기','포장지나 영수증처럼 바로 버리는 재료만 모아 작은 조형물이나 콜라주를 만들어보세요.','CREATIVE',2,45,'DEVIATION'),
    ('DEVIATION_008','오늘의 감정을 색 하나로 표현하기','설명이나 글 없이 색 하나와 도형만 사용해 지금의 감정을 표현하고 다른 사람에게 해석을 부탁해보세요.','CREATIVE',1,20,'DEVIATION'),
    ('DEVIATION_009','처음 보는 향신료로 한 끼 만들기','가게에서 이름만 보고 고른 향신료 하나를 구매해 익숙한 음식에 새롭게 적용하고 맛의 변화를 기록해보세요.','FOOD',2,45,'DEVIATION'),
    ('DEVIATION_010','평소 먹지 않는 식감 도전하기','바삭함, 미끌함, 매우 부드러움 중 평소 피하던 식감의 안전한 음식을 골라 천천히 경험해보세요.','FOOD',1,15,'DEVIATION'),
    ('DEVIATION_011','메뉴판에서 가장 낯선 음료 고르기','카페나 식당에서 평소 주문하지 않던 음료를 설명만 듣고 골라 맛과 첫인상을 기록해보세요.','FOOD',1,10,'DEVIATION'),
    ('DEVIATION_012','눈을 감고 재료 향 맞히기','집에 있는 안전한 식재료 네 가지의 향을 눈을 감고 맞혀본 뒤 예상과 실제의 차이를 확인해보세요.','FOOD',1,15,'DEVIATION'),
    ('DEVIATION_013','전혀 모르는 분야의 용어 다섯 개 배우기','관심 밖 분야의 기사나 사전을 골라 모르는 용어 다섯 개를 찾아 뜻과 실제 사용 예를 정리해보세요.','LEARNING',2,30,'DEVIATION'),
    ('DEVIATION_014','낯선 설명서만 보고 물건 조립하기','이미 알고 있는 물건이라도 영상 없이 설명서만 읽고 조립하거나 설정해보며 설명의 빈틈을 찾아보세요.','LEARNING',2,45,'DEVIATION'),
    ('DEVIATION_015','모르는 사람의 질문에 답을 상상하기','공공장소에서 들은 일반적인 질문 하나를 골라 내가 아는 방식이 아닌 세 가지 관점으로 답을 상상해보세요.','LEARNING',1,15,'DEVIATION'),
    ('DEVIATION_016','평소 쓰지 않는 손으로 메모하기','반대 손으로 오늘 배운 내용이나 본 것을 한 페이지 분량으로 적고 평소 글씨와 다른 점을 관찰해보세요.','LEARNING',1,20,'DEVIATION'),
    ('DEVIATION_017','처음 만난 사람에게 먼저 칭찬하기','상대의 외모가 아닌 행동이나 선택을 구체적으로 관찰해 진심 어린 칭찬 한마디를 먼저 건네보세요.','SOCIAL',2,10,'DEVIATION'),
    ('DEVIATION_018','혼자 가던 곳에서 옆자리 대화하기','안전하고 자연스러운 공공장소에서 옆사람에게 가벼운 질문을 건네고 짧은 대화를 이어가보세요.','SOCIAL',2,15,'DEVIATION'),
    ('DEVIATION_019','친구에게 즉석 역할 바꾸기 제안하기','친구와 만났을 때 서로 평소 역할을 바꿔 상대가 정한 활동과 장소를 따라가보세요.','SOCIAL',2,30,'DEVIATION'),
    ('DEVIATION_020','낯선 모임에서 자기소개 먼저 하기','처음 참석한 모임에서 기다리지 말고 이름과 오늘 온 이유를 먼저 소개해 대화의 문을 열어보세요.','SOCIAL',3,45,'DEVIATION'),
    ('DEVIATION_021','지도에서 무작위 장소 찾아가기','지도에서 눈을 감고 고른 가까운 장소를 정해 안전을 확인한 뒤 그곳까지 새로운 경로로 가보세요.','OUTDOOR',2,30,'DEVIATION'),
    ('DEVIATION_022','평소 지나치는 계단으로 오르기','엘리베이터 대신 처음 이용하는 계단이나 경로를 선택해 주변의 구조와 소리를 관찰해보세요.','OUTDOOR',1,15,'DEVIATION'),
    ('DEVIATION_023','비 오는 날 우산 없이 소리 듣기','비를 피할 수 있는 안전한 처마 아래에서 잠시 주변의 빗소리와 사람들의 움직임만 집중해 들어보세요.','OUTDOOR',1,10,'DEVIATION'),
    ('DEVIATION_024','밤의 익숙한 장소를 새롭게 보기','밝고 안전한 시간과 장소를 선택해 평소 낮에만 보던 공간의 조명과 소리를 천천히 관찰해보세요.','OUTDOOR',2,30,'DEVIATION'),
    ('DEVIATION_025','물건을 색깔 순서로만 정리하기','효율이나 종류 대신 색깔 하나의 기준만 사용해 책상이나 선반을 새롭게 배열하고 사용성을 비교해보세요.','ORGANIZING',1,20,'DEVIATION'),
    ('DEVIATION_026','버리려던 물건에 마지막 용도 부여하기','버리려던 물건 하나를 오늘 하루 다른 용도로 활용해보고 정말 필요한지 다시 판단해보세요.','ORGANIZING',1,15,'DEVIATION'),
    ('DEVIATION_027','평소와 반대 순서로 준비하기','외출이나 잠들기 전 준비 루틴을 안전에 문제가 없는 범위에서 완전히 반대 순서로 실행해보세요.','ORGANIZING',1,10,'DEVIATION'),
    ('DEVIATION_028','가구 배치를 한 시간만 바꾸기','작은 공간의 가구나 소품 배치를 평소 동선과 다르게 바꾸고 한 시간 동안 새 동선으로 생활해보세요.','ORGANIZING',2,60,'DEVIATION'),
    ('DEVIATION_029','관심 없는 장르의 공연 찾아보기','평소 피하던 장르의 공연이나 상영을 골라 30분 이상 관람하고 마음에 남은 장면을 적어보세요.','CULTURE',2,60,'DEVIATION'),
    ('DEVIATION_030','작품 제목만 보고 감상 선택하기','내용이나 평점을 검색하지 않고 제목만 보고 전시, 영화, 책 중 하나를 골라 첫인상을 기록해보세요.','CULTURE',2,45,'DEVIATION'),
    ('DEVIATION_031','동네의 낯선 간판 역사 상상하기','평소 보지 않던 간판 하나를 골라 그 장소의 과거와 현재를 상상하고 실제 정보와 비교해보세요.','CULTURE',1,30,'DEVIATION'),
    ('DEVIATION_032','박물관에서 가장 작은 전시 보기','큰 작품을 먼저 찾는 습관을 멈추고 가장 작거나 눈에 덜 띄는 전시 하나를 오래 관찰해보세요.','CULTURE',1,20,'DEVIATION'),
    ('DEVIATION_033','하루 동안 검색 없이 궁금증 모으기','바로 검색하고 싶은 궁금증을 메모만 해두었다가 저녁에 세 가지를 골라 직접 관찰과 추론으로 답을 만들어보세요.','LEARNING',2,60,'DEVIATION'),
    ('DEVIATION_034','친구가 고른 낯선 산책 코스 따라가기','친구에게 평소 내 취향과 반대되는 산책 코스를 고르게 하고 이유를 묻지 않은 채 끝까지 따라가보세요.','OUTDOOR',2,90,'DEVIATION'),
    ('DEVIATION_035','하루 동안 모든 선택을 동전으로 정하기','안전과 예산에 문제가 없는 사소한 선택 세 가지를 동전으로 정하고 평소 선택과 결과를 비교해보세요.','ORGANIZING',2,30,'DEVIATION'),
    ('DEVIATION_036','처음 보는 사람의 추천 음식 먹기','메뉴를 직접 고르지 않고 직원이나 동행자에게 평소 먹지 않을 것 같은 안전한 메뉴를 추천받아 맛보세요.','FOOD',2,30,'DEVIATION')
  ) AS additions(code, title, description, category, difficulty, minutes, kind)
ON CONFLICT (content_fingerprint) DO NOTHING;

SELECT setval('mission_seq', COALESCE((SELECT MAX(mission_id) FROM mission), 1), true);
