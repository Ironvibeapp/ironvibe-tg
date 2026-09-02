# Хостинг tg.ironvibe.app

Миниапп должен открываться по **HTTPS**. HTTP Telegram отклонит.

## GitHub Pages

1. Создать репозиторий из этой папки (`ironvibe_tg`), пушить в `main`.
2. В DNS домена `ironvibe.app` добавить CNAME:

   ```
   tg  CNAME  <user>.github.io
   ```

3. В репозитории: Settings → Pages → GitHub Actions.
4. Workflow `.github/workflows/deploy-web.yml` собирает Flutter web с `--pwa-strategy=offline-first` и публикует `app/build/web`.
5. Файл `app/web/CNAME` содержит `tg.ironvibe.app` и попадает в сборку.

Пока DNS не прописан, можно открывать `https://<user>.github.io/<repo>/` — тогда в BotFather укажи этот URL, а `flutter build` нужен с `--base-href /<repo>/`.

## Кэш оболочки (повторный заход в зале)

`_headers` ниже для Cloudflare Pages. GitHub Pages кэш почти не настраивается; полагаемся на service worker Flutter (`offline-first`).

```
/index.html
  Cache-Control: no-cache
/flutter_service_worker.js
  Cache-Control: no-cache
/flutter_bootstrap.js
  Cache-Control: no-cache
```

WASM/JS с хэшами в имени кэширует `offline_sw.js` (cache-as-you-go + precache оболочки). Это не APK: первый визит всё равно качает ~5 МБ `main.dart.js`.

## Cloudflare Pages (альтернатива)

Подключить тот же репозиторий, build command:

```
cd app && flutter build web --release --base-href /
```

Нужен Flutter на билде (или собирать локально и деплоить `build/web`). Custom domain: `tg.ironvibe.app`.
