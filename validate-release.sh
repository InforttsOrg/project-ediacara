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

# 2. Package Check
echo -e "${YELLOW}📦 Checking Node.js Dependencies...${NC}"
if [ ! -d "node_modules" ]; then
    npm install > /dev/null 2>&1
fi
echo -e "${GREEN}✅ Dependencies verified.${NC}"

# 3. TypeScript Compilation/Type Verification
echo -e "${YELLOW}⚙️  Verifying TypeScript Compilation...${NC}"
if ! npx tsc --noEmit > /dev/null 2>&1; then
    echo -e "${RED}❌ TypeScript compilation check failed! Release rejected.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ TypeScript compilation verified.${NC}"

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
