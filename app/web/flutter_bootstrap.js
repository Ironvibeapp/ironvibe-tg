{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine({
        canvasKitForceCpuOnly: true,
      });
      if (typeof window.ironVibeHideBoot === 'function') {
        window.ironVibeHideBoot();
      }
      await appRunner.runApp();
    } catch (err) {
      var boot = document.getElementById('iv-boot');
      if (boot) {
        boot.style.letterSpacing = '0';
        boot.textContent = 'Error: ' + (err && err.message ? err.message : String(err));
      }
      throw err;
    }
  },
});
