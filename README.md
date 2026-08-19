# Novelty

노벨티 서비스의 최소 실행 프로젝트 틀입니다. 아직 서비스 기능은 구현하지 않았습니다.

- `front/app`: Flutter 웹 앱
- `front/world3d`: Three.js 렌더러
- `back`: Java 21 / Spring Boot 서버

## 실행

```powershell
cd front/app
flutter run -d web-server
```

```powershell
cd front/world3d
npm.cmd install
npm.cmd run dev
```

```powershell
cd back
.\mvnw.cmd spring-boot:run
```
