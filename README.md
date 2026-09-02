# IronVibe Telegram Mini App

Отдельный канал IronVibe: Flutter web внутри Telegram. Play-приложение в `fitnessapp` не трогаем.

Логирование подходов **всегда локальное**. Облако Telegram (CloudStorage) подтягивается только когда есть сеть.

```
ironvibe_tg/
  app/      Flutter web
  host/     кэш-заголовки, CNAME
  bot/      BotFather
  SPIKE.md  стоп/идти на iPhone
```

## Локальный запуск

```bash
cd app
flutter pub get
flutter run -d chrome --web-port 8080
```

Спайк-экран: `http://localhost:8080/?spike=1` или долгое нажатие на версию на домашнем экране.

## Сборка

```bash
cd app
flutter build web --release --base-href /
```

Артефакт: `app/build/web`. Его же выкладывает GitHub Action на `tg.ironvibe.app`.

Первый запуск миниаппа требует интернет (скачивается WASM). Повторный заход в зале — цель спайка в `SPIKE.md`.

## Данные

| Слой | Когда пишется |
|------|----------------|
| DeviceStorage (или localStorage в браузере) | Сразу, без сети |
| Outbox `iv_pending_sync` | Сразу |
| CloudStorage | Когда `navigator.onLine` |

Черновик незавершённой тренировки на облако не уходит.

## Хостинг и бот

См. [host/README.md](host/README.md) и [bot/BOTFATHER.md](bot/BOTFATHER.md).
