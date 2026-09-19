#!/usr/bin/env python3
import pathlib, re, shutil, sys
up = pathlib.Path(sys.argv[1]).resolve()
root = pathlib.Path(__file__).resolve().parents[1]
cm = up/'CMakeLists.txt'
s = cm.read_text()

# Make RT64 use the Android SDL/Vulkan path and provide an NFD stub before RT64 is added.
needle = 'if(WR64_WITH_RUNTIME)\n    if(NOT EXISTS "${WR64_LIB_DIR}/RT64/CMakeLists.txt")'
insert = '''if(ANDROID)\n    find_package(SDL2 REQUIRED)\n    find_package(Freetype REQUIRED)\n    set(RT64_SDL_WINDOW_VULKAN ON CACHE BOOL "" FORCE)\n    if(NOT TARGET nfd)\n        add_library(nfd STATIC "${CMAKE_CURRENT_SOURCE_DIR}/src/android/nfd_android_stub.cpp")\n        target_include_directories(nfd PUBLIC "${WR64_LIB_DIR}/RT64/src/contrib/nativefiledialog-extended/src/include")\n    endif()\nendif()\n\n'''
if insert.strip() not in s:
    if needle not in s: raise SystemExit('CMake dependency anchor changed')
    s=s.replace(needle, insert+needle)

# Desktop executable -> SDLActivity-loaded shared object, preserving the target name.
old='add_executable(WaveRace64Recomp ${WR64_SOURCES})'
new='''if(ANDROID)\n    list(APPEND WR64_SOURCES src/android/android_entry.cpp)\n    add_library(WaveRace64Recomp SHARED ${WR64_SOURCES})\nelse()\n    add_executable(WaveRace64Recomp ${WR64_SOURCES})\nendif()'''
if old in s: s=s.replace(old,new)

# Android final-link dependencies.
anchor='target_include_directories(WaveRace64Recomp PRIVATE\n    "${CMAKE_CURRENT_SOURCE_DIR}/include")'
extra=anchor+'''\n\nif(ANDROID)\n    target_include_directories(WaveRace64Recomp PRIVATE ${SDL2_INCLUDE_DIRS})\n    target_link_libraries(WaveRace64Recomp PRIVATE SDL2::SDL2 android log vulkan Freetype::Freetype)\n    target_link_options(WaveRace64Recomp PRIVATE "-Wl,-z,max-page-size=16384")\nendif()'''
if extra not in s:
    if anchor not in s: raise SystemExit('CMake target anchor changed')
    s=s.replace(anchor,extra)
cm.write_text(s)

# RecompFrontend's CMake currently treats SDL include dirs as desktop Unix only.
for rel in ['lib/RecompFrontend/recompui/CMakeLists.txt','lib/RecompFrontend/recompinput/CMakeLists.txt']:
    p=up/rel; t=p.read_text(); t=t.replace('elseif (APPLE OR CMAKE_SYSTEM_NAME MATCHES "Linux")','elseif (APPLE OR CMAKE_SYSTEM_NAME MATCHES "Linux" OR ANDROID)'); p.write_text(t)

# Native Android NFD shim.
(up/'src/android').mkdir(parents=True,exist_ok=True)
shutil.copy2(root/'overlay/nfd_android_stub.cpp',up/'src/android/nfd_android_stub.cpp')

# SDLActivity calls SDL_main. Including SDL on Android supplies SDL's main remap.
main=up/'src/main.cpp'; t=main.read_text()
inc='''#if defined(__ANDROID__)\n#  include <SDL2/SDL.h>\n#  include <unistd.h>\n#endif\n'''
if inc not in t: t=t.replace('#include <vector>\n', '#include <vector>\n'+inc)

# Parse private app/program paths passed by GameActivity before settings/frontend initialization.
marker='int main(int argc, char** argv) {\n'
boot='''int main(int argc, char** argv) {\n#if defined(__ANDROID__)\n    std::filesystem::path android_program_dir;\n    for (int i = 1; i < argc; ++i) {\n        const std::string a = argv[i] ? argv[i] : "";\n        constexpr std::string_view data_prefix = "--android-data-dir=";\n        constexpr std::string_view program_prefix = "--android-program-dir=";\n        if (a.rfind(data_prefix, 0) == 0) {\n            setenv("WR64_ANDROID_DATA_DIR", a.substr(data_prefix.size()).c_str(), 1);\n        } else if (a.rfind(program_prefix, 0) == 0) {\n            android_program_dir = a.substr(program_prefix.size());\n        }\n    }\n    if (!android_program_dir.empty()) {\n        std::error_code ec;\n        std::filesystem::current_path(android_program_dir, ec);\n    }\n#endif\n'''
if boot not in t:
    if marker not in t: raise SystemExit('main anchor changed')
    t=t.replace(marker,boot)

# Android settings live under app-private storage.
settings_anchor='std::filesystem::path settings_directory() {\n'
settings_new='''std::filesystem::path settings_directory() {\n#if defined(__ANDROID__)\n    if (const char* p = std::getenv("WR64_ANDROID_DATA_DIR"); p && *p) {\n        return std::filesystem::path{p} / "WaveRace64Recomp";\n    }\n#endif\n'''
if settings_new not in t: t=t.replace(settings_anchor,settings_new)

# The desktop executable-directory chdir is wrong for an APK .so; GameActivity already supplied program cwd.
block_start='    // Run from the executable\'s own directory, whatever directory the user\n'
idx=t.find(block_start)
if idx!=-1:
    brace=t.find('    {\n',idx); end=t.find('\n    }\n',brace)
    if brace!=-1 and end!=-1:
        body=t[brace:end+7]
        if '#if !defined(__ANDROID__)' not in body:
            t=t[:brace]+'#if !defined(__ANDROID__)\n'+body+'#endif\n'+t[end+7:]
main.write_text(t)

# android_entry.cpp is intentionally tiny; its presence gives us a stable Android-specific TU for future JNI/lifecycle hooks.
(up/'src/android/android_entry.cpp').write_text('''#if defined(__ANDROID__)\n#include <android/log.h>\nnamespace { struct BootLog { BootLog(){ __android_log_print(ANDROID_LOG_INFO, "WaveRace64Recomp", "native library loaded"); } } boot_log; }\n#endif\n''')
print('Applied Wave Race Android overlay')
