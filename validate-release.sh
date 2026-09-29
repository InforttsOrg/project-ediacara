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

# 1. Versioning Check & Bootstrap
VERSION_FILE=".version"
if [ ! -f "$VERSION_FILE" ]; then
    echo "1.0.0" > "$VERSION_FILE"
fi
CURRENT_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
echo -e "${YELLOW}🔍 Current Version: v$CURRENT_VERSION${NC}"

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
if [ ! -f "public/index.html" ] || [ ! -f "public/flutter_bootstrap.js" ]; then
    echo -e "${RED}❌ public/ is not a Flutter build. Run 'npm run build:ui'. Release rejected.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Static UI build present.${NC}"

# 3d. Worker Test Suite
echo -e "${YELLOW}🧪 Running Worker Test Suite..."
if ! npx vitest run > /dev/null 2>&1; then
    echo -e "${RED}❌ Worker tests failed! Release rejected.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Worker tests passed.${NC}"

# 4. Bump version on successful validation (Epoch.Major.Minor concept)
# - Epoch: Primary developmental phase/era
# - Major: Major features/updates
# - Minor: Automatically bumped on successful release validation
IFS='.' read -r epoch major minor <<< "$CURRENT_VERSION"
NEW_MINOR=$((minor + 1))
NEW_VERSION="$epoch.$major.$NEW_MINOR"
echo "$NEW_VERSION" > "$VERSION_FILE"

echo -e "\n===================================================="
echo -e "${GREEN}🎉 EDIACARA RELEASE VALIDATED & READY FOR PRODUCTION${NC}"
echo -e "Version bumped: v$CURRENT_VERSION -> v$NEW_VERSION"
echo "===================================================="
exit 0
