# Account SDD V1

## 목표

닉네임 입력으로 시작하던 신규 사용자 흐름을 아이디·비밀번호 회원가입으로 전환하고, 기존 성향·미션·World API가 사용하는 `X-User-Key` 계약은 유지한다.

## 공식 흐름

```text
신규 사용자: POST /api/users/register → userKey 캐시 → GET /api/users/me → 최초 성향 선택폼
기존 사용자: 캐시 userKey → GET /api/users/me
캐시 없음/만료: POST /api/users/login → 새 userKey 캐시 → GET /api/users/me
```

회원가입 시 Backend가 `노벨티+숫자 2자리+영문 2자리` 형식의 중복 없는 닉네임을 배정한다. 최초 선택폼 전에는 닉네임을 다시 묻지 않으며 프로필 편집 기능으로 추후 변경한다.

## 계정 정책

- `loginId`: 소문자 정규화, 영문 소문자·숫자·밑줄 4~20자, 중복 불가
- `password`: 영문과 숫자를 포함한 8~64자
- 비밀번호: PBKDF2-HMAC-SHA256, 210,000회, 사용자별 16-byte Salt
- DB에는 원문 비밀번호와 원문 `userKey`를 저장하지 않는다.
- 기존 익명 행은 계정 컬럼을 nullable로 유지하여 기존 캐시 복원을 깨뜨리지 않는다.
- 로그인 성공 시 새 `userKey`를 발급하고 해시값을 갱신한다.

## UI 계약

- 앱과 Web은 Purple 배경의 White 로고 애니메이션 스플래시를 먼저 표시한다.
- 캐시 사용자가 없으면 시작 화면은 회원가입 상태가 기본이며 로그인으로 전환할 수 있다.
- 서비스 설명 문구를 항상 표시한다.
- 회원가입 화면에서 랜덤 닉네임 배정과 추후 변경 가능 여부를 안내한다.
- 캐시 사용자 키가 유효하면 로그인 화면을 건너뛴다.
- 캐시 키가 만료되면 캐시를 제거하고 로그인 화면으로 돌아간다.

## DB

`NOVELTY_USER`에 다음 nullable 컬럼을 추가한다.

- `LOGIN_ID_NORMALIZED VARCHAR2(20)`
- `PASSWORD_HASH VARCHAR2(255)`

Unique 로그인 아이디, 계정 컬럼 쌍의 NULL 일관성, 아이디 길이·허용 문자 Check를 적용한다.
