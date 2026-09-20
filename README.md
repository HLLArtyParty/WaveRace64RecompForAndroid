# Wave Race 64 Recompiled for Android

Experimental Android port layer for the public Wave Race 64 recompilation project.

This repository contains **no Nintendo ROM data**. It expects a legally obtained **Wave Race 64 (USA) (Rev A / v1.1)** dump.

Expected normalized ROM SHA-1: `508dfc2d4caa42b6f6de5263d0aed5e44ac7966a`.

**Android port / maintainer:** [@bainface](https://x.com/bainface)

## MVP target

- Android 9+ / API 28
- ARM64 (`arm64-v8a`)
- Vulkan / RT64
- Landscape
- Physical controller
- Java ROM picker before the native runtime starts
- Z64/V64/N64 byte-order normalization
- 4 Kbit EEPROM saves through N64ModernRuntime

## Build flow

1. `scripts/prepare_upstream.sh` checks out the pinned Wave Race source and Android-capable RT64 fork.
2. `scripts/generate_sources.sh /path/to/your/rom` generates `RecompiledFuncs/` from your own ROM.
3. `overlay/apply_android_overlay.py upstream` applies the Android CMake/platform bridge.
4. Gradle cross-compiles the native port into an APK.

ROMs and generated private source artifacts are ignored and must not be committed.

This is a bring-up branch, not a release build. The first goal is boot + graphics + controller + save; optional HD textures, replacement music and custom water polish come later.
