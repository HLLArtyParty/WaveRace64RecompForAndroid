#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/config/upstream.env"
ROM="${1:?usage: scripts/generate_sources.sh /path/to/WaveRace64RevA.rom}"
UP="$ROOT/upstream"
[[ -d "$UP/.git" ]] || { echo "Run scripts/prepare_upstream.sh first" >&2; exit 2; }

NORMAL="$UP/waverace_revA.z64"
python3 "$ROOT/scripts/verify_rom.py" "$ROM" "$NORMAL"

# Wave Race's generator uses the LLONSIT decomp only as build metadata.
if [[ ! -d "$UP/reference/wr64-decomp/.git" ]]; then
  git clone "$WR64_DECOMP_REPO" "$UP/reference/wr64-decomp"
fi
git -C "$UP/reference/wr64-decomp" checkout --detach "$WR64_DECOMP_COMMIT"
cp "$NORMAL" "$UP/reference/wr64-decomp/baserom.us.rev1.z64"

python3 "$UP/tools/patch_n64recomp.py"
python3 "$UP/tools/patch_rsprecomp.py"
cmake -S "$UP/lib/N64ModernRuntime/N64Recomp" -B "$UP/build-tools" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++
cmake --build "$UP/build-tools" --target N64RecompCLI RSPRecomp -j "$(nproc 2>/dev/null || echo 4)"

# generate_game.py installs/uses the decomp metadata and emits CPU + RSP generated code.
python3 "$UP/tools/generate_game.py" "$NORMAL"
rm -f "$UP/reference/wr64-decomp/baserom.us.rev1.z64" "$NORMAL"

echo "Generated Wave Race recomp sources under $UP/RecompiledFuncs"
