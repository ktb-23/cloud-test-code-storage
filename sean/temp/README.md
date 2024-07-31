## React.js 환경 실행 방법

### 개발 환경

의존성 관련 변경사항이 생긴 경우 재실행 필요

```bash
# 실행
docker compose up --build

# 컨테이너 종료 및 제거
docker compose down
```

### 배포 환경

```bash
# 실행
docker compose -f docker-compose.build.yml up --build

# 컨테이너 종료 및 제거
docker compose -f docker-compose.build.yml down

# shell 접근 (새로운 터미널에서)
docker exec -it react-app-build-container /bin/sh
```
