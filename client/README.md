# I Was Here — клиент

Flutter-клиент к REST API `iwh` (см. `../docs/rest-api.md`): список пользователей,
создание, переименование, смена пароля и удаление. Для каждого пользователя
строится процедурный «срез агата» по `created_at` — по спецификации
`../docs/Срез агата.md`.

## Запуск разработкой

Бэкенд:

```sh
make env-up
make migrate-up
make iwh-run          # :8080
```

Клиент:

```sh
cd client
flutter pub get
flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
```

`API_BASE` по умолчанию — `http://localhost:8080`.

## Веб-версия в Docker

Сервис `iwh-web` описан в корневом `docker-compose.yaml` вместе с базой:

```sh
make web-run    # сборка и запуск: http://127.0.0.1:8081
make web-down   # остановка
```

nginx раздаёт собранный web-бандл и проксирует `/users` на API, который
запускается на хосте через `make iwh-run`. Браузер обращается к тому же
origin, поэтому CORS не нужен. Адрес API задаётся переменной `API_UPSTREAM`
(по умолчанию `host.docker.internal:8080`).

## Устройство

```
lib/
  agate/       prng.dart, genome.dart, geometry.dart, painter.dart, agate_view.dart
  api/         api_client.dart — единственный слой адаптации под бэкенд
  models/      user.dart
  screens/     users_screen.dart, user_detail_screen.dart
  widgets/     user_dialogs.dart
```

- Геном строится только из `created_at` (UTC, миллисекунды) и текущего времени;
  на сервере ничего не хранится.
- Статический слой камня рисуется один раз в `RepaintBoundary`, динамика
  (блик, иризация, вспышки) — по движению указателя.
- Бэкенд пока отвечает `500 internal error` вместо 404/409/400; клиент
  разбирает такие ответы по операции и показывает человеческий текст
  (`ApiClient._mapServerError`).
