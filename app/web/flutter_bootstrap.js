{{flutter_js}}
{{flutter_build_config}}

(function () {
  if (typeof window.ironVibeShowBoot === 'function') {
    window.ironVibeShowBoot('IRONVIBE 75e\nJS ok');
  }

  var bootFailed = false;
  var engineTimeout = setTimeout(function () {
    if (bootFailed) return;
    if (typeof window.ironVibeShowBoot === 'function') {
      window.ironVibeShowBoot('IRONVIBE 75e\nStill loading…');
    }
  }, 20000);

  function ironVibeForceCpuCanvasKit() {
    try {
      var platform = '';
      if (window.Telegram && Telegram.WebApp && Telegram.WebApp.platform) {
        platform = String(Telegram.WebApp.platform).toLowerCase();
      }
      if (platform === 'android') return true;
      if (platform === 'ios' ||
          platform === 'macos' ||
          platform === 'tdesktop' ||
          platform === 'unigram' ||
          platform === 'weba' ||
          platform === 'webk') {
        return false;
      }
    } catch (e) {}
    return /Android/i.test(navigator.userAgent || '');
  }

  var kitConfig = {
    // Android Telegram WebView often has no usable GPU. iPhone pays ~500ms
    // tap latency if we force the CPU rasterizer there too.
    canvasKitForceCpuOnly: ironVibeForceCpuCanvasKit(),
    // The Chromium-lite build hangs in Telegram's WebView even when the
    // browser advertises ImageDecoder. The full local build starts.
    canvasKitVariant: 'full',
    useLocalCanvasKit: true,
    canvasKitBaseUrl: '/ironvibe-tg/canvaskit/',
  };

  _flutter.loader.load({
    config: kitConfig,
    onEntrypointLoaded: async function (engineInitializer) {
      if (typeof window.ironVibeShowBoot === 'function') {
        window.ironVibeShowBoot('IRONVIBE 75e\nEngine…');
      }
      try {
        const appRunner = await engineInitializer.initializeEngine(kitConfig);
        clearTimeout(engineTimeout);
        if (typeof window.ironVibeHideBoot === 'function') {
          window.ironVibeHideBoot();
        }
        await appRunner.runApp();
      } catch (err) {
        bootFailed = true;
        clearTimeout(engineTimeout);
        if (typeof window.ironVibeShowBoot === 'function') {
          window.ironVibeShowBoot(
            'Error: ' + (err && err.message ? err.message : String(err)),
          );
        }
        throw err;
      }
    },
  });
})();
