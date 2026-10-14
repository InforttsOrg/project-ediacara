#!/bin/bash

# Ediacara Release Validation & Versioning Gatekeeper
# Part of the Infortts Swarm OS

# Ensure we run from the project root
cd "$(dirname "$0")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}🧬 Ediacara Release Validation Igniting...${NC}"

# 0. Argument parsing — fail closed. A typo used to be ignored silently and fall
#    through to the release path (which bumps .version); unknown args must not.
TEST_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --test-only)
            TEST_ONLY=1
            ;;
        -h|--help)
            echo "Usage: ./validate-release.sh [--test-only]"
            echo "  --test-only   run all checks, never bump .version (CI mode)"
            exit 0
            ;;
        *)
            echo "validate-release.sh: unknown argument '$arg' (expected --test-only)" >&2
            echo "Usage: ./validate-release.sh [--test-only]" >&2
            exit 2
            ;;
    esac
done

# 1. Versioning Check & Bootstrap
VERSION_FILE=".version"
if [ ! -f "$VERSION_FILE" ]; then
    echo "1.0.0" > "$VERSION_FILE"
fi
CURRENT_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
echo -e "${YELLOW}🔍 Current Version: v$CURRENT_VERSION${NC}"

# Fail closed on a malformed version: the bump below is pure arithmetic and would
# otherwise write garbage (or silently keep the old value) into .version.
if ! echo "$CURRENT_VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo -e "${RED}❌ Malformed version '$CURRENT_VERSION' in $VERSION_FILE (expected MAJOR.MINOR.PATCH). Release rejected.${NC}"
    exit 1
fi

# 1b. Node engine guard. Vite/Vitest (via @cloudflare/vitest-pool-workers) needs
#     Node >= 20 — Node 18 dies with "crypto.hash is not a function". Prefer a
#     modern Node when one is installed, otherwise fail with the remedy.
NODE_BIN="$(command -v node 2>/dev/null || true)"
node_major() { [ -n "$1" ] && "$1" -v 2>/dev/null | sed 's/^v\([0-9]*\).*/\1/'; }
if [ -z "$(node_major "$NODE_BIN")" ] || [ "$(node_major "$NODE_BIN")" -lt 20 ]; then
    for candidate in "$NODE_BIN_DIR" /opt/infortts/nodejs/bin; do
        [ -n "$candidate" ] || continue
        m="$(node_major "$candidate/node")"
        if [ -n "$m" ] && [ "$m" -ge 20 ]; then
            NODE_BIN="$candidate/node"
            PATH="$candidate:$PATH"
            export PATH
            break
        fi
    done
fi
NODE_MAJOR="$(node_major "$NODE_BIN")"
if [ -z "$NODE_MAJOR" ] || [ "$NODE_MAJOR" -lt 20 ]; then
    echo -e "${RED}❌ Node.js $(node -v 2>/dev/null || echo 'not found') is too old for this gate (Vitest needs Node 20+; 18 fails with 'crypto.hash is not a function').${NC}"
    echo "   Install Node 22 (fleet location /opt/infortts/nodejs) or set NODE_BIN_DIR to a Node 20+ bin directory. Release rejected."
    exit 1
fi
echo -e "${GREEN}✅ Node.js $(node -v) verified.${NC}"

# 2. Package Check — respect whichever lockfile is committed. This repo uses
#    pnpm (pnpm-lock.yaml + pnpm-workspace.yaml, no package-lock.json), so
#    `npm install` would ignore the lock and resolve fresh versions in CI.
echo -e "${YELLOW}📦 Checking Node.js Dependencies...${NC}"
if [ ! -d "node_modules" ]; then
    if [ -f "pnpm-lock.yaml" ] && command -v pnpm > /dev/null 2>&1; then
        pnpm install --frozen-lockfile > /dev/null 2>&1
    else
        npm ci > /dev/null 2>&1 || npm install > /dev/null 2>&1
    fi
fi
echo -e "${GREEN}✅ Dependencies verified.${NC}"

# 3. TypeScript Compilation/Type Verification
echo -e "${YELLOW}⚙️  Verifying TypeScript Compilation...${NC}"
if ! npx tsc --noEmit > /dev/null 2>&1; then
    echo -e "${RED}❌ TypeScript compilation check failed! Release rejected.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ TypeScript compilation verified.${NC}"

if ! npx tsc --noEmit -p test/tsconfig.json > /dev/null 2>&1; then
    echo -e "${RED}❌ Test TypeScript compilation check failed! Release rejected.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Test TypeScript compilation verified.${NC}"

# 3b. Flutter Console (the Worker serves dashboard/ out of public/)
echo -e "${YELLOW}🎨 Verifying Flutter Console (analyze + test)..."
if ! command -v flutter > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Flutter not on PATH; SKIPPING console verification.${NC}"
elif ! (cd dashboard && flutter pub get > /dev/null && flutter analyze --no-fatal-infos > /dev/null && flutter test > /dev/null); then
    echo -e "${RED}❌ Flutter console verification failed! Release rejected.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Flutter console verified.${NC}"
fi

# 3c. The Worker serves public/ as-is, so a missing build means a blank site.
#     Also prove the Worker itself bundles (wrangler dry-run), which is what
#     `npm run deploy` ships — tsc alone never exercises the Worker runtime.
if [ ! -f "public/index.html" ] || [ ! -f "public/flutter_bootstrap.js" ]; then
    echo -e "${RED}❌ public/ is not a Flutter build. Run 'npm run build:ui'. Release rejected.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Static UI build present.${NC}"

echo -e "${YELLOW}📦 Verifying Worker bundle (wrangler dry-run)...${NC}"
if ! npx wrangler deploy --dry-run --outdir dist > /dev/null 2>&1; then
    echo -e "${RED}❌ Worker bundle (wrangler deploy --dry-run) failed! Release rejected.${NC}"
    exit 1
fi
rm -rf dist
echo -e "${GREEN}✅ Worker bundle verified.${NC}"

# 3d. Worker Test Suite
echo -e "${YELLOW}🧪 Running Worker Test Suite..."
if ! npx vitest run > /dev/null 2>&1; then
    echo -e "${RED}❌ Worker tests failed! Release rejected.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Worker tests passed.${NC}"

# 3e. Secret guard: never ship tracked credentials or build caches. Untracking is
#     not enough on its own — the next scaffold or history rewrite can re-add
#     them, so fail closed on the index. The .env pattern covers the variant files
#     .gitignore also guards (.env.local, .env.production, .env.development): a
#     bare `(^|/)\.env$` let `git add -f .env.production` slip a secret past the
#     gate. `.env.example` (the secret-free tracked contract) is deliberately NOT
#     matched.
if git rev-parse --git-dir > /dev/null 2>&1; then
    TRACKED="$(git ls-files)"
    LEAKED="$(printf '%s\n' "$TRACKED" | grep -E '(^|/)(key\.properties|local\.properties|google-services\.json|GoogleService-Info\.plist)$|(^|/)\.env(\.local|\.production|\.development)?$|\.(jks|keystore|p12|pem)$' || true)"
    if [ -n "$LEAKED" ]; then
        echo -e "${RED}❌ Credential files are tracked and must never be committed:${NC}"
        printf '%s\n' "$LEAKED" >&2
        exit 1
    fi
    CACHES="$(printf '%s\n' "$TRACKED" | grep -E '(^|/)(\.gradle|\.dart_tool|build)/|\.iml$' || true)"
    if [ -n "$CACHES" ]; then
        echo -e "${RED}❌ Build caches are tracked:${NC}"
        printf '%s\n' "$CACHES" >&2
        exit 1
    fi
    echo -e "${GREEN}✅ No tracked credentials or build caches.${NC}"
else
    echo -e "${YELLOW}⚠️  Not a git checkout — skipping secret guard.${NC}"
fi

# 3f. Release-publisher env declaration. ci/upload_to_hf.py reads HF_TOKEN /
#     HUGGING_FACE_HUB_TOKEN, but with no .env.example the contract is
#     undocumented and unfalsifiable. Match the WHOLE identifier anchored at the
#     assignment: a plain `grep -q HF_TOKEN` also matches the
#     HUGGING_FACE_HUB_TOKEN line, so deleting the HF_TOKEN declaration would
#     pass while the contract was gone.
if [ ! -f ".env.example" ]; then
    echo -e "${RED}❌ .env.example is missing — the HF_TOKEN / HUGGING_FACE_HUB_TOKEN contract used by ci/upload_to_hf.py is undeclared.${NC}"
    exit 1
fi
for var in HF_TOKEN HUGGING_FACE_HUB_TOKEN; do
    if ! grep -qE "^[[:space:]]*${var}[[:space:]]*=" .env.example; then
        echo -e "${RED}❌ .env.example does not declare $var, but ci/upload_to_hf.py reads it.${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✅ .env.example declares the release-publisher token contract.${NC}"

# 3g. Python release scripts must at least compile (CDN publisher).
if command -v python3 > /dev/null 2>&1; then
    if ! python3 -m py_compile ci/upload_to_hf.py; then
        echo -e "${RED}❌ Python release script failed to compile! Release rejected.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Python release scripts verified.${NC}"
else
    echo -e "${YELLOW}⚠️  python3 not found — skipping Python compile check.${NC}"
fi

# 3h. CDN publisher fail-closed contract (ci/upload_to_hf.py).
#     The manifest is the contract every installed OTA client reads. The scaffold's
#     fail-open template pins versionCode 1, advertises apk_url before the binary is
#     uploaded, and lets a version-only publish OVERWRITE the live manifest —
#     stripping the apk_url/sha256 installed clients download from. Prove the guards
#     hold against a STUBBED huggingface_hub (the real CDN is never contacted; the
#     dummy --token short-circuits the credential cache lookup).
if [ -f ci/upload_to_hf.py ]; then
    if [ ! -f ci/requirements.txt ]; then
        echo -e "${RED}❌ ci/upload_to_hf.py has no ci/requirements.txt pinning huggingface_hub.${NC}"
        exit 1
    fi
    if command -v python3 > /dev/null 2>&1; then
        if ! python3 - <<'PY'
import os, pathlib, subprocess, sys, tempfile

src = pathlib.Path("ci/upload_to_hf.py").resolve()
bad = []

with tempfile.TemporaryDirectory() as td:
    td = pathlib.Path(td)
    script = td / "upload_to_hf.py"
    script.write_bytes(src.read_bytes())
    (td / "huggingface_hub.py").write_text(
        "def _boom(*a, **k):\n"
        "    raise AssertionError('publisher reached the CDN: a fail-closed guard did not fire')\n"
        "class HfApi:\n"
        "    def __init__(self, *a, **k): _boom()\n"
        "def create_repo(*a, **k): _boom()\n"
        "def upload_file(*a, **k): _boom()\n"
    )
    env = dict(os.environ, PYTHONPATH=str(td))

    def run(label, extra):
        p = subprocess.run(
            [sys.executable, str(script), "--slug", "ediacara",
             "--repo", "rttss/infortts-gate-must-not-be-used", "--token", "gate-dummy-token",
             *extra],
            capture_output=True, text=True, env=env, cwd=td, timeout=60)
        if p.returncode != 2:
            detail = (p.stderr or p.stdout).strip().splitlines()
            bad.append(f"{label}: expected exit 2, got {p.returncode}"
                       + (f" — {detail[-1]}" if detail else ""))
        elif "reached the CDN" in (p.stdout + p.stderr):
            bad.append(f"{label}: publisher contacted the CDN — the guards did not fire")

    apk = td / "gate.apk"
    apk.write_bytes(b"not a real apk")

    run("publish with no --apk and no --patch", ["--version", "1.2.0"])
    run("publish with a non-existent --apk", ["--version", "1.2.0", "--apk",
                                              str(td / "does-not-exist.apk")])
    run("publish an artifact with no build number", ["--version", "1.2.0", "--apk", str(apk)])

for line in bad:
    print(f"  {line}")
if bad:
    print(f"  {len(bad)} CDN publisher regression(s)")
    sys.exit(1)
print("  CDN publisher refuses artifact-less and unversioned publishes (3/3)")
PY
        then
            echo -e "${RED}❌ CDN publisher fail-closed contract broken! Release rejected.${NC}"
            exit 1
        fi
        echo -e "${GREEN}✅ CDN publisher verified.${NC}"
    else
        echo -e "${YELLOW}⚠️  python3 not found — skipping CDN publisher guard.${NC}"
    fi
fi

# 4. Bump version on successful validation (Epoch.Major.Minor concept)
# - Epoch: Primary developmental phase/era
# - Major: Major features/updates
# - Minor: Automatically bumped on successful release validation
# --test-only (CI) must leave .version untouched: Jenkins runs it on every build,
# so a bump there is discarded by the next checkout anyway — and would corrupt the
# tree for anyone running the gate locally.
if [ "$TEST_ONLY" = "1" ]; then
    echo -e "\n===================================================="
    echo -e "${GREEN}✅ EDIACARA RELEASE VALIDATED (test-only — .version untouched)${NC}"
    echo -e "Current version: v$CURRENT_VERSION"
    echo "===================================================="
    exit 0
fi

IFS='.' read -r epoch major minor <<< "$CURRENT_VERSION"
NEW_MINOR=$((minor + 1))
NEW_VERSION="$epoch.$major.$NEW_MINOR"
echo "$NEW_VERSION" > "$VERSION_FILE"

echo -e "\n===================================================="
echo -e "${GREEN}🎉 EDIACARA RELEASE VALIDATED & READY FOR PRODUCTION${NC}"
echo -e "Version bumped: v$CURRENT_VERSION -> v$NEW_VERSION"
echo "===================================================="
exit 0
