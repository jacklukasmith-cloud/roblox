#!/usr/bin/env bash
# Live-sync Mythic Tamers into Roblox Studio (macOS / Linux).
# Usage (from the repo folder):   ./scripts/sync.sh
# Then in Studio: Rojo plugin -> Connect. Leave this terminal open while you work.
set -euo pipefail

BRANCH="claude/roblox-monetizable-ideas-5xrrhu"
INTERVAL=15 # seconds between checks for new changes

cd "$(dirname "$0")/.."

if ! command -v rojo >/dev/null 2>&1; then
	echo "Rojo isn't installed. Run 'rokit install' in this folder first (see README)." >&2
	exit 1
fi

git fetch origin "$BRANCH"
git checkout "$BRANCH"
git pull --ff-only origin "$BRANCH"

echo "Starting Rojo... In Studio open the Rojo plugin and click Connect."
rojo serve &
ROJO_PID=$!
trap 'kill $ROJO_PID 2>/dev/null' EXIT

while true; do
	sleep "$INTERVAL"
	git fetch --quiet origin "$BRANCH"
	if [ "$(git rev-parse HEAD)" != "$(git rev-parse "origin/$BRANCH")" ]; then
		echo "$(date +%H:%M:%S) New changes found - pulling..."
		git pull --ff-only --quiet origin "$BRANCH"
		git log -1 --pretty=format:"  -> %s%n"
	fi
done
