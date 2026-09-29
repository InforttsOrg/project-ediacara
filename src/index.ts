/**
 * Project Ediacara — Financial Sentiment Orchestrator
 * Maps real-time market sentiment to procedural classical music compositions.
 */

interface Env {
	/** The built Flutter console in `public/`. */
	ASSETS: Fetcher;
}

export default {
	async fetch(request: Request, env: Env): Promise<Response> {
		const url = new URL(request.url);

		// 1. API: Get Musical Parameters based on Sentiment.
		//    The console calls this same-origin, so it must stay ahead of the
		//    asset server (see run_worker_first in wrangler.jsonc).
		if (url.pathname === "/api/composition") {
			const ticker = url.searchParams.get("ticker") || "GLOBAL";
			const sentiment = await fetchSentiment(ticker);
			const composition = generateComposition(sentiment);
			return new Response(JSON.stringify(composition), {
				headers: {
					"Content-Type": "application/json",
					"Cache-Control": "no-store",
				},
			});
		}

		// 2. Everything else is the Flutter console. Fetched through ASSETS so
		//    the Worker can attach a CSP tight enough for a third-party-free
		//    app while still allowing CanvasKit (wasm-unsafe-eval, blob:).
		if (url.pathname === "/" || url.pathname === "/index.html") {
			return uiPage(env);
		}

		// 3. Static assets (JS, canvaskit, manifest, icons…).
		const asset = await env.ASSETS.fetch(request);
		if (asset.status !== 404) return asset;

		return new Response("Not Found", {
			status: 404,
			headers: { "Content-Type": "text/plain; charset=utf-8" },
		});
	},
};

/** Serves `public/index.html` under the console's security headers. */
async function uiPage(env: Env): Promise<Response> {
	const asset = await env.ASSETS.fetch(new Request("http://placeholder/index.html"));
	if (asset.status !== 200) {
		return new Response("UI not built. Run `npm run build:ui`.", {
			status: 503,
			headers: { "Content-Type": "text/plain; charset=utf-8" },
		});
	}
	const html = await asset.text();
	return new Response(html, {
		headers: {
			"Content-Type": "text/html; charset=utf-8",
			"Content-Security-Policy": [
				"default-src 'self'",
				// CanvasKit needs to eval WASM and hand out blob: workers.
				"script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' blob:",
				"style-src 'self' 'unsafe-inline'",
				"img-src 'self' data: blob:",
				"font-src 'self' data:",
				"connect-src 'self'",
				"manifest-src 'self'",
				"worker-src 'self' blob:",
				"base-uri 'self'",
				"form-action 'none'",
				"frame-ancestors 'none'",
			].join("; "),
			"Referrer-Policy": "no-referrer",
			"X-Content-Type-Options": "nosniff",
		},
	});
}

async function fetchSentiment(ticker: string) {
	// Simulated sentiment for MVP.
	// In production, this would query Mitochondria or Alpha Vantage.
	// Range: -1.0 (Panic) to 1.0 (Euphoria)
	const hour = new Date().getHours();
	if (ticker === "NASDAQ") return 0.5; // Bullish example
	if (ticker === "WAR") return -0.9; // Extreme Fear example
	return Math.sin(hour / 4); // Periodic global sentiment
}

function generateComposition(sentiment: number) {
	let key = "C";
	let scale = "major";
	let tempo = 120;
	let instrumentation = ["piano", "violin"];
	let mood = "Neutral";

	if (sentiment <= -0.8) {
		key = "C"; scale = "minor"; tempo = 40; mood = "Panic";
		instrumentation = ["organ", "cello", "bassoon"];
	} else if (sentiment < -0.2) {
		key = "G"; scale = "minor"; tempo = 70; mood = "Fear";
		instrumentation = ["cello", "viola", "oboe"];
	} else if (sentiment > 0.8) {
		key = "E"; scale = "major"; tempo = 160; mood = "Euphoria";
		instrumentation = ["violin", "trumpet", "flute", "timpani"];
	} else if (sentiment > 0.2) {
		key = "G"; scale = "major"; tempo = 130; mood = "Greed";
		instrumentation = ["violin", "flute", "piano"];
	}

	return {
		sentiment,
		mood,
		key,
		scale,
		tempo,
		instrumentation,
		timestamp: new Date().toISOString(),
		// Procedural pattern seeds
		seed: Math.random() * 1000
	};
}
