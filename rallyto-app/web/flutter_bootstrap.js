{{flutter_js}}
{{flutter_build_config}}

// Fonts the engine falls back to (Roboto by default) come from this host, not fonts.gstatic.com, which may be slow or
// unreachable for players in Iran. web/engine-fonts/ holds the Roboto file; the app's own text uses Vazir from its assets.
_flutter.loader.load({
  config: {
    fontFallbackBaseUrl: 'engine-fonts/',
  },
});
