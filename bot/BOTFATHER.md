# BotFather — IronVibe Mini App

Живой backend не нужен. Бот только открывает URL миниаппа.

## Создать бота

1. Telegram → [@BotFather](https://t.me/BotFather) → `/newbot`
2. Имя: `IronVibe`, username на выбор (`ironvibe_app_bot` и т.п.)
3. Скопировать токен в `.env` (файл не коммитить). Токен нужен только если позже появится webhook. Для Mini App достаточно BotFather.

## Привязать Mini App

В BotFather:

```
/mybots → IronVibe → Bot Settings → Menu Button
```

- Configure menu button → URL: `https://ironvibeapp.github.io/ironvibe-tg/m.html`
- Текст кнопки: `IronVibe`

Либо:

```
/newapp
```

и указать тот же HTTPS URL (`https://ironvibeapp.github.io/ironvibe-tg/m.html`).

Direct link (после регистрации приложения): `https://t.me/<bot>/<short_name>`

## Канал

Существующий `t.me/IronVibeapp` можно позже связать с ботом. Не обязательно для первого круга друзей: достаточно ссылки на бота.

## Проверка

1. Открыть бота на iPhone.
2. Menu button / Mini App.
3. Пройти `SPIKE.md`.
