# GLB Models

Three.js 개발용 GLB 배포 파일을 두는 위치다. Vite Build가 이 디렉터리를 Flutter의
`assets/world3d/models`로 복사해 Web과 Android에 함께 번들한다.

모델 파일명, 레벨 매핑과 Transform은 `src/world/world_manifest.js`에서 관리한다.
Supabase PostgreSQL에는 GLB 경로나 파일을 저장하지 않는다.
Blender 원본 파일은 이 디렉터리에 넣지 않는다.
