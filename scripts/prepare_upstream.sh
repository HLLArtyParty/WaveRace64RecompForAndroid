#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/config/upstream.env"
UP="$ROOT/upstream"

if [[ ! -d "$UP/.git" ]]; then
  git clone "$WR64_REPO" "$UP"
fi
git -C "$UP" fetch --all --tags
git -C "$UP" checkout --detach "$WR64_COMMIT"
git -C "$UP" submodule update --init --recursive

# Replace only RT64 with the Android-enabled donor revision. N64ModernRuntime and
# RecompFrontend stay at Wave Race's own pins because both already contain Android-aware code.
rm -rf "$UP/lib/RT64"
git clone "$RT64_ANDROID_REPO" "$UP/lib/RT64"
git -C "$UP/lib/RT64" checkout --detach "$RT64_ANDROID_COMMIT"
git -C "$UP/lib/RT64" submodule update --init --recursive

python3 "$ROOT/overlay/apply_android_overlay.py" "$UP"
echo "Prepared: $UP"
