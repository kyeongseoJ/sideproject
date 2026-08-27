# ========================================
# 1. Three.js build
# ========================================
FROM node:24-alpine AS world-build

WORKDIR /src

COPY front ./front

WORKDIR /src/front/world3d

RUN npm ci
RUN npm run build


# ========================================
# 2. Flutter Web build
# Flutter 3.44.x = Dart 3.12.2
# ========================================
FROM debian:bookworm-slim AS flutter-build

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       curl \
       git \
       unzip \
       xz-utils \
       zip \
       ca-certificates \
       libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# pubspec.yaml이 Dart ^3.12.2를 요구하므로
# Flutter 3.44.6 / Dart 3.12.2로 고정
RUN mkdir -p /opt \
    && curl -L \
       https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.6-stable.tar.xz \
       -o /tmp/flutter.tar.xz \
    && tar -xf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

RUN git config --global --add safe.directory /opt/flutter
RUN flutter config --enable-web
RUN flutter precache --web

WORKDIR /app

# Three.js 빌드 결과가 포함된 Flutter 프로젝트 복사
COPY --from=world-build /src/front/app ./

RUN flutter pub get

ARG API_BASE_URL

RUN flutter build web \
    --release \
    --dart-define=API_BASE_URL=${API_BASE_URL}


# ========================================
# 3. Nginx
# ========================================
FROM nginx:alpine

COPY front/nginx.conf /etc/nginx/conf.d/default.conf

COPY --from=flutter-build \
     /app/build/web \
     /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]