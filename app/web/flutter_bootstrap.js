{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine({
      // Telegram Android WebView often has no usable WebGL; CPU Skia still paints.
      canvasKitForceCpuOnly: true,
    });
    await appRunner.runApp();
  },
});
