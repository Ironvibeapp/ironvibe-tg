{{flutter_js}}
{{flutter_build_config}}

(function () {
  if (typeof window.ironVibeShowBoot === 'function') {
    window.ironVibeShowBoot('IRONVIBE 74d\nJS ok');
  }

  var engineTimeout = setTimeout(function () {
    if (typeof window.ironVibeShowBoot === 'function') {
      var wasm = typeof WebAssembly !== 'undefined';
      var gl = false;
      try {
        var c = document.createElement('canvas');
        gl = !!(c.getContext('webgl') || c.getContext('webgl2'));
      } catch (e) {}
      window.ironVibeShowBoot(
        'Stuck at CanvasKit\nwasm=' + wasm + ' webgl=' + gl,
      );
    }
  }, 12000);

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
    useLocalCanvasKit: true,
    canvasKitBaseUrl: '/ironvibe-tg/canvaskit/',
  };

  _flutter.loader.load({
    config: kitConfig,
    onEntrypointLoaded: async function (engineInitializer) {
      if (typeof window.ironVibeShowBoot === 'function') {
        window.ironVibeShowBoot('IRONVIBE 74d\nEngine…');
      }
      try {
        const appRunner = await engineInitializer.initializeEngine(kitConfig);
        clearTimeout(engineTimeout);
        if (typeof window.ironVibeHideBoot === 'function') {
          window.ironVibeHideBoot();
        }
        await appRunner.runApp();
      } catch (err) {
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
