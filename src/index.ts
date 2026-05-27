/**
 * Project Ediacara — Financial Sentiment Orchestrator
 * Maps real-time market sentiment to procedural classical music compositions.
 */

export default {
	async fetch(request: Request, env: any, ctx: any): Promise<Response> {
		const url = new URL(request.url);

		// 1. Root: Serve the Music Player UI
		if (url.pathname === "/") {
			return new Response(HTML_PLAYER, {
				headers: { "Content-Type": "text/html" },
			});
		}

		// 2. API: Get Musical Parameters based on Sentiment
		if (url.pathname === "/api/composition") {
			const ticker = url.searchParams.get("ticker") || "GLOBAL";
			const sentiment = await fetchSentiment(ticker);
			const composition = generateComposition(sentiment);
			return new Response(JSON.stringify(composition), {
				headers: { "Content-Type": "application/json" },
			});
		}

		return new Response("Not Found", { status: 404 });
	},
};

async function fetchSentiment(ticker: string) {
	// Simulated sentiment for MVP. 
	// In production, this would query Mitochondria or Alpha Vantage.
	// Range: -1.0 (Panic) to 1.0 (Euphoria)
	const hour = new Date().getHours();
	if (ticker === "NASDAQ") return 0.5; // Bullish example
	if (ticker === "WAR") return -0.9;   // Extreme Fear example
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

const HTML_PLAYER = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Project Ediacara — Market Symphony</title>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/tone/14.8.49/Tone.js"></script>
    <style>
        body { 
            background: #0a0a0c; 
            color: #e0e0e0; 
            font-family: 'Inter', system-ui; 
            display: flex; 
            flex-direction: column; 
            align-items: center; 
            justify-content: center; 
            height: 100vh; 
            margin: 0;
            overflow: hidden;
        }
        .container {
            text-align: center;
            background: rgba(255, 255, 255, 0.03);
            padding: 3rem;
            border-radius: 24px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.1);
            box-shadow: 0 20px 50px rgba(0,0,0,0.5);
        }
        h1 { font-weight: 300; letter-spacing: 2px; color: #4facfe; }
        .status { margin: 20px 0; font-size: 1.2rem; }
        .controls { display: flex; gap: 10px; margin-top: 20px; }
        button { 
            background: #4facfe; 
            border: none; 
            color: white; 
            padding: 12px 24px; 
            border-radius: 8px; 
            cursor: pointer; 
            font-weight: 600;
            transition: transform 0.2s;
        }
        button:hover { transform: scale(1.05); }
        select {
            background: #1a1a1e;
            color: white;
            border: 1px solid #333;
            padding: 10px;
            border-radius: 8px;
        }
        .visualizer {
            width: 300px;
            height: 100px;
            margin-top: 20px;
            display: flex;
            align-items: flex-end;
            gap: 2px;
        }
        .bar { background: #4facfe; flex: 1; transition: height 0.1s; }
    </style>
</head>
<body>
    <div class="container">
        <h1>EDIACARA</h1>
        <p>Market Sentiment Symphony</p>
        
        <div class="status" id="status">Ready to Compose...</div>
        
        <select id="ticker">
            <option value="GLOBAL">Global Market</option>
            <option value="NASDAQ">NASDAQ (Bullish Example)</option>
            <option value="WAR">War Zone (Panic Example)</option>
        </select>

        <div class="controls">
            <button id="start">▶ Play Symphony</button>
            <button id="stop">⏹ Stop</button>
        </div>

        <div class="visualizer" id="visualizer"></div>
    </div>

    <script>
        let synth, loop;
        const statusEl = document.getElementById('status');
        const visualizer = document.getElementById('visualizer');

        // Create visualizer bars
        for(let i=0; i<30; i++) {
            const bar = document.createElement('div');
            bar.className = 'bar';
            visualizer.appendChild(bar);
        }

        async function fetchComposition() {
            const ticker = document.getElementById('ticker').value;
            const res = await fetch(\`/api/composition?ticker=\${ticker}\`);
            return await res.json();
        }

        async function startMusic() {
            await Tone.start();
            const config = await fetchComposition();
            
            statusEl.innerText = \`Mood: \${config.mood} | Key: \${config.key} \${config.scale} | BPM: \${config.tempo}\`;
            
            // Setup Synth based on instrumentation
            synth = new Tone.PolySynth(Tone.Synth).toDestination();
            synth.set({
                oscillator: { type: config.mood === 'Panic' ? 'sawtooth' : 'triangle' },
                envelope: { attack: 0.1, release: 1 }
            });

            Tone.Transport.bpm.value = config.tempo;

            // Simple procedural melody based on sentiment
            const notes = config.scale === 'major' ? ['C4', 'E4', 'G4', 'B4'] : ['C3', 'Eb3', 'G3', 'Bb3'];
            
            loop = new Tone.Loop(time => {
                const note = notes[Math.floor(Math.random() * notes.length)];
                synth.triggerAttackRelease(note, "8n", time);
                
                // Animate visualizer
                document.querySelectorAll('.bar').forEach(bar => {
                    bar.style.height = Math.random() * 100 + '%';
                });
            }, "4n").start(0);

            Tone.Transport.start();
        }

        document.getElementById('start').onclick = startMusic;
        document.getElementById('stop').onclick = () => {
            Tone.Transport.stop();
            if(loop) loop.stop();
            statusEl.innerText = "Symphony Paused.";
        };
    </script>
</body>
</html>
`;
