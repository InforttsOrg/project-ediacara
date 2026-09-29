{{flutter_js}}
{{flutter_build_config}}

// The build already ships CanvasKit in `public/canvaskit/`, so point the loader
// at the same-origin copy. Without this the default is
// https://www.gstatic.com/flutter-canvaskit/<engine-rev>/, which a strict
// `default-src 'self'` CSP blocks — and the app never paints.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "/canvaskit/",
  },
});
