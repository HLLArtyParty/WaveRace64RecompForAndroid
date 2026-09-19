#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDL2_VERSION="${SDL2_VERSION:-2.32.10}"
FREETYPE_VERSION="${FREETYPE_VERSION:-2.13.3}"
ANDROID_ABI="${ANDROID_ABI:-arm64-v8a}"
ANDROID_PLATFORM="${ANDROID_PLATFORM:-28}"
PREFIX_ROOT="${ANDROID_PREFIX_ROOT:-$ROOT/.android-prefixes}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 2)}"
: "${ANDROID_HOME:?ANDROID_HOME must point at the Android SDK}"
: "${ANDROID_NDK_HOME:=${ANDROID_HOME}/ndk/27.1.12297006}"

SDL2_PREFIX="$PREFIX_ROOT/SDL2-${SDL2_VERSION}-android-arm64"
FREETYPE_PREFIX="$PREFIX_ROOT/freetype-${FREETYPE_VERSION}-android-arm64"
WORK="${RUNNER_TEMP:-/tmp}/wr64-android-deps"
CMAKE_BIN="${ANDROID_HOME}/cmake/3.22.1/bin/cmake"
[[ -x "$CMAKE_BIN" ]] || CMAKE_BIN="$(command -v cmake)"
mkdir -p "$PREFIX_ROOT" "$WORK"
cd "$WORK"

fetch(){ [[ -f "$2" ]] || curl -fsSL --retry 3 --retry-delay 3 -o "$2" "$1"; }

if [[ ! -f "$SDL2_PREFIX/lib/libSDL2.so" ]]; then
  fetch "https://github.com/libsdl-org/SDL/releases/download/release-${SDL2_VERSION}/SDL2-${SDL2_VERSION}.tar.gz" "SDL2-${SDL2_VERSION}.tar.gz"
  rm -rf "SDL2-${SDL2_VERSION}" build-sdl2
  tar -xzf "SDL2-${SDL2_VERSION}.tar.gz"
  "$CMAKE_BIN" -S "SDL2-${SDL2_VERSION}" -B build-sdl2 -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$ANDROID_ABI" -DANDROID_PLATFORM="android-${ANDROID_PLATFORM}" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$SDL2_PREFIX" \
    -DSDL_SHARED=ON -DSDL_STATIC=OFF -DSDL_TEST=OFF
  "$CMAKE_BIN" --build build-sdl2 --parallel "$JOBS"
  "$CMAKE_BIN" --install build-sdl2
fi

# Copy SDLActivity Java glue into the app source tree from the exact SDL source we built.
mkdir -p "$ROOT/android/app/src/main/java/org/libsdl/app"
cp -f "SDL2-${SDL2_VERSION}/android-project/app/src/main/java/org/libsdl/app/"*.java \
  "$ROOT/android/app/src/main/java/org/libsdl/app/"

if [[ ! -f "$FREETYPE_PREFIX/lib/libfreetype.a" ]]; then
  fetch "https://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE_VERSION}.tar.xz" "freetype-${FREETYPE_VERSION}.tar.xz"
  rm -rf "freetype-${FREETYPE_VERSION}" build-freetype
  tar -xJf "freetype-${FREETYPE_VERSION}.tar.xz"
  "$CMAKE_BIN" -S "freetype-${FREETYPE_VERSION}" -B build-freetype -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$ANDROID_ABI" -DANDROID_PLATFORM="android-${ANDROID_PLATFORM}" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$FREETYPE_PREFIX" \
    -DBUILD_SHARED_LIBS=OFF -DFT_DISABLE_ZLIB=TRUE -DFT_DISABLE_BZIP2=TRUE \
    -DFT_DISABLE_PNG=TRUE -DFT_DISABLE_HARFBUZZ=TRUE -DFT_DISABLE_BROTLI=TRUE
  "$CMAKE_BIN" --build build-freetype --parallel "$JOBS"
  "$CMAKE_BIN" --install build-freetype
fi

printf 'WR64_ANDROID_SDL2_PREFIX=%s\n' "$SDL2_PREFIX"
printf 'WR64_ANDROID_FREETYPE_PREFIX=%s\n' "$FREETYPE_PREFIX"
