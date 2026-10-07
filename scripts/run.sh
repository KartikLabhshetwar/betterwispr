#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/build-app.sh "${1:-debug}"
open ".build/${1:-debug}/BetterWispr.app"
