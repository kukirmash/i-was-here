FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY pubspec.* analysis_options.yaml ./
RUN flutter pub get

COPY lib ./lib
COPY web ./web
RUN flutter build web --release --pwa-strategy=none --dart-define=API_BASE=

FROM nginx:1.27-alpine

COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/build/web /usr/share/nginx/html

# Адрес API виден только nginx: браузер обращается к тому же origin.
ENV API_UPSTREAM=host.docker.internal:8080

EXPOSE 80
