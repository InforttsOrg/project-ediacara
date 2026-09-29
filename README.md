# Ediacara

**Market Sentiment Symphony** on Cloudflare Workers. Maps live market sentiment to procedural
classical music: the Worker turns a ticker into a key, scale, tempo and mood, and the console
synthesises it.

## Layout

| Path | Purpose |
|------|---------|
| `src/index.ts` | The Worker: `/api/composition` + static assets from `public/` |
| `dashboard/` | Flutter Web console (the player UI, native Web Audio synth) |
| `public/` | The built console, served by the Worker's `ASSETS` binding |
| `test/index.spec.ts` | Vitest suite (runs inside workerd via `@cloudflare/vitest-pool-workers`) |
| `wrangler.jsonc` | Source of truth for bindings and the asset directory |
| `worker-configuration.d.ts` | **Generated** — do not hand-edit; run `npm run cf-typegen` |
| `validate-release.sh` | Release gate: typecheck + tests, then bumps `.version` |
| `ci/` | Shared Jenkins helpers |

## Commands

| Command | Purpose |
|---------|---------|
| `npm run dev` | Run the Worker on <http://localhost:9904> |
| `npm run dev:ui` | Hot-reload the console on <http://localhost:9909> (UI only, see below) |
| `npm run build:ui` | Build `dashboard/` into `public/` |
| `npm run build:ui:check` | `flutter analyze` + `flutter test` for the console |
| `npm run deploy` | Rebuild the console, then deploy the Worker |
| `npm test` | Worker test suite |
| `npm run typecheck` | `tsc` over `src/` and `test/` |
| `npm run cf-typegen` | Regenerate `worker-configuration.d.ts` after binding changes |

## The console

`dashboard/` is a Flutter Web port of the inline Tone.js page the Worker used to serve. Tone.js
is gone: the synth is now native **Web Audio** — one `OscillatorNode` per note through an ADSR
`GainNode`, booked onto the audio clock by a 25 ms lookahead scheduler so timing does not drift
with the frame rate. An `AnalyserNode` on the master bus drives the 30-bar visualiser with real
spectrum data instead of random heights. The waveform follows the mood: `sawtooth` on Panic,
`triangle` otherwise.

```bash
npm run build:ui        # dashboard/ -> public/
npm run dev:ui          # hot-reload the console on :9909 (UI work only)
```

The console calls `/api/composition` **same-origin**, and the Worker sends no CORS
headers — that is deliberate, since production serves UI and API from one origin. So:

- **Full stack (the real path):** `npm run build:ui && npm run dev` — the Worker on
  :9904 serves both the built console and the API. Use this to exercise the API.
- **UI iteration:** `npm run dev:ui` on :9909 gives you Flutter hot reload for layout
  and theme work, but the API calls have no origin to reach and will not resolve.

The same trade-off applies to `dev` vs `dev:ui` in Grypania.

`wrangler.jsonc` binds `./public` as `ASSETS` with `run_worker_first`, so `/api/composition`
still reaches the Worker while `/` resolves to `public/index.html` under a CSP that allows
CanvasKit (`wasm-unsafe-eval`, `blob:`) and nothing third-party (`default-src 'self'`). Because
the Worker fetches `/index.html` itself, `html_handling` is `"none"` — otherwise the asset server
would redirect `/index.html` back to `/` in a loop.

`validate-release.sh` runs the Worker suite, the console's analyze + test pass, and refuses to
bump `.version` if `public/` is not a Flutter build.

## API

`GET /api/composition?ticker=<GLOBAL|NASDAQ|WAR>` (defaults to `GLOBAL`).

```json
{
  "sentiment": -0.9,
  "mood": "Panic",
  "key": "C",
  "scale": "minor",
  "tempo": 40,
  "instrumentation": ["organ", "cello", "bassoon"],
  "timestamp": "2026-01-01T00:00:00.000Z",
  "seed": 421.7
}
```

Sentiment is simulated for the MVP (NASDAQ `+0.5`, WAR `-0.9`, GLOBAL a slow sine). Swapping in
Mitochondria or Alpha Vantage means replacing `fetchSentiment()` — the shape of the response is
what the console depends on.

## Deploying a Flutter console behind a strict CSP

Unit tests and `wrangler` requests are not enough — open the built site in a
browser and read the console. Three failures only show up there, and all three
mean "blank page, zero Dart errors":

1. **CanvasKit is fetched from a CDN by default.** `flutter build web` *ships*
   `public/canvaskit/`, but the default loader points at
   `https://www.gstatic.com/flutter-canvaskit/<engine-rev>/`. Under
   `default-src 'self'` that is blocked and the app never paints. Fix with a
   `web/flutter_bootstrap.js`:

   ```js
   {{flutter_js}}
   {{flutter_build_config}}

   _flutter.loader.load({ config: { canvasKitBaseUrl: "/canvaskit/" } });
   ```

2. **Fonts.** Flutter Web pulls Roboto from `fonts.gstatic.com` at runtime, and
   `google_fonts` fetches its families too. Bundle the files (`assets/fonts/`)
   and declare them in `pubspec.yaml`; a bundled family named `Montserrat`
   satisfies `google_fonts`, but plain `TextStyle(fontFamily:)` is simpler and
   removes the `http` dependency entirely. Roboto TTFs are in the Flutter SDK at
   `$(flutter sdk-path)/bin/cache/artifacts/material_fonts/`.

3. **The web plugin registrant is eager.** Every plugin in the dependency graph
   is registered at boot, even if you never import it. A transitive
   `google_sign_in` (e.g. via `projects/shared`'s `auth.dart`) therefore loads
   `accounts.google.com/gsi/client` on every page load. Drop the dependency
   rather than widening the CSP. After removing plugins, `flutter clean` — the
   generated `web_plugin_registrant.dart` in `.dart_tool` is cached and the
   build fails on the stale imports.

Also watch for glyphs outside your bundled fonts (e.g. `●`): Flutter silently
falls back to Noto Sans Symbols from `fonts.gstatic.com`. Use a Material icon
instead.

Verification recipe: `wrangler dev --port <p>`, then in Playwright check console
errors, click the `flt-semantics-placeholder` to build the semantics tree, and
assert on `flt-semantics` `innerText` (CanvasKit renders to canvas, so
`document.body.innerText` is empty).
