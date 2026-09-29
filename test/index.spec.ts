import { env, SELF } from "cloudflare:test";
import { describe, it, expect } from "vitest";
import worker from "../src";

async function call(path: string) {
	const request = new Request<unknown, IncomingRequestCfProperties>(
		`http://example.com${path}`,
	);
	return worker.fetch(request, env);
}

describe("Ediacara", () => {
	describe("GET /api/composition", () => {
		it("returns a composition for GLOBAL", async () => {
			const response = await call("/api/composition?ticker=GLOBAL");
			expect(response.status).toBe(200);
			expect(response.headers.get("Content-Type")).toMatch(
				/application\/json/,
			);

			const body = (await response.json()) as Record<string, unknown>;
			expect(body).toMatchObject({
				mood: expect.any(String),
				key: expect.any(String),
				scale: expect.any(String),
				tempo: expect.any(Number),
				instrumentation: expect.any(Array),
			});
			expect(typeof body.sentiment).toBe("number");
			expect(body.sentiment as number).toBeGreaterThanOrEqual(-1);
			expect(body.sentiment as number).toBeLessThanOrEqual(1);
			expect(typeof body.timestamp).toBe("string");
			expect(typeof body.seed).toBe("number");
		});

		it("defaults to GLOBAL when no ticker is given", async () => {
			const withTicker = (await (await call("/api/composition?ticker=GLOBAL")).json()) as {
				mood: string;
			};
			const bare = (await (await call("/api/composition")).json()) as {
				mood: string;
			};
			expect(bare.mood).toBe(withTicker.mood);
		});

		it("maps NASDAQ to a bullish, major composition", async () => {
			const body = (await (await call("/api/composition?ticker=NASDAQ")).json()) as {
				sentiment: number;
				mood: string;
				key: string;
				scale: string;
				tempo: number;
			};
			expect(body.sentiment).toBe(0.5);
			expect(body.scale).toBe("major");
			expect(body.tempo).toBeGreaterThan(120);
			expect(body.mood).not.toBe("Panic");
		});

		it("maps WAR to panic: C minor at 40 BPM", async () => {
			const body = (await (await call("/api/composition?ticker=WAR")).json()) as {
				sentiment: number;
				mood: string;
				key: string;
				scale: string;
				tempo: number;
				instrumentation: string[];
			};
			expect(body.sentiment).toBe(-0.9);
			expect(body.mood).toBe("Panic");
			expect(body.key).toBe("C");
			expect(body.scale).toBe("minor");
			expect(body.tempo).toBe(40);
			expect(body.instrumentation).toEqual(["organ", "cello", "bassoon"]);
		});

		it("is not cacheable — the mood has to stay live", async () => {
			const response = await call("/api/composition?ticker=NASDAQ");
			expect(response.headers.get("Cache-Control")).toBe("no-store");
		});

		it("works through the real runtime (integration style)", async () => {
			const response = await SELF.fetch("http://example.com/api/composition?ticker=WAR");
			expect(response.status).toBe(200);
			const body = (await response.json()) as { mood: string };
			expect(body.mood).toBe("Panic");
		});
	});

	describe("GET /", () => {
		it("serves the Flutter console with a self-only CSP", async () => {
			const response = await call("/");
			expect(response.status).toBe(200);
			expect(response.headers.get("Content-Type")).toMatch(/text\/html/);

			const csp = response.headers.get("Content-Security-Policy") ?? "";
			expect(csp).toContain("default-src 'self'");
			// CanvasKit needs WASM eval + blob workers; nothing third-party.
			expect(csp).toContain("'wasm-unsafe-eval'");
			expect(csp).toContain("blob:");
			expect(csp).toContain("frame-ancestors 'none'");
			expect(csp).not.toContain("https://");
			expect(response.headers.get("X-Content-Type-Options")).toBe("nosniff");
			expect(response.headers.get("Referrer-Policy")).toBe("no-referrer");

			// The wordmark is painted by Flutter, so assert on the shell: the
			// branded <title> and the bootstrap script that boots the app.
			const html = await response.text();
			expect(html).toContain("<title>Project Ediacara");
			expect(html).toContain("flutter_bootstrap.js");
		});

		it("also answers /index.html directly", async () => {
			const response = await call("/index.html");
			expect(response.status).toBe(200);
			expect(response.headers.get("Content-Security-Policy")).toContain(
				"default-src 'self'",
			);
		});
	});

	describe("static assets", () => {
		it("serves the Flutter bootstrap script", async () => {
			const response = await SELF.fetch("http://example.com/flutter_bootstrap.js");
			expect(response.status).toBe(200);
			expect(response.headers.get("Content-Type")).toMatch(/javascript/);
		});

		it("serves the web manifest", async () => {
			const response = await SELF.fetch("http://example.com/manifest.json");
			expect(response.status).toBe(200);
			const manifest = (await response.json()) as { short_name: string };
			expect(manifest.short_name).toBe("Ediacara");
		});
	});

	describe("unknown routes", () => {
		it("404s a missing Worker route", async () => {
			const response = await call("/message");
			expect(response.status).toBe(404);
			expect(await response.text()).toBe("Not Found");
		});

		it("404s a missing asset", async () => {
			const response = await SELF.fetch("http://example.com/nope.js");
			expect(response.status).toBe(404);
		});
	});
});
