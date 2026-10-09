# GL4ES v1.1.6 Upstream Metadata

- **Upstream Repository:** https://github.com/ptitSeb/gl4es
- **Upstream Tag:** `v1.1.6`
- **Upstream Full Commit:** `c9895df34cd466c23bc60c2bd3db3d87e98fcbe7`
- **Original Authors:** @ptitSeb, @lunixbochs
- **License:** MIT License (see [LICENSE](file:///d:/download/Amethyst-high-jetsam-main/Amethyst-high-jetsam-main/Natives/external/gl4es_116/LICENSE))

## Purpose in Amethyst

Vendored to provide an independent, selectable **GL4ES 1.1.6 (ptitSeb)** renderer (`libgl4es_116.dylib`) alongside the legacy **GL4ES 1.1.4** renderer (`libgl4es_114.dylib`).

## Necessary Amethyst Platform Adaptations

1. **Mach-O Dynamic Export & Alias on iOS ARM64 (`src/gl/attributes.h`):**
   Apple Clang on Darwin/Mach-O does not support GCC-style `__attribute__((alias(...)))`. We define both `AliasExport(name)` and `AliasDecl(RET,NAME,DEF,OLD)` on `__APPLE__ && __arm64__` as naked thunks with a single direct branch (`b _<target>`), matching how Mach-O iOS dylibs expose the standard desktop OpenGL symbol set (`_gl*`) and redirect aliased entrypoints (`gl4es_glEnableClientStatei`, etc.) delegating to internal functions.
2. **Dynamic Constructor Initialization (`src/gl/init.c`):**
   Allowed `initialize_gl4es()` constructor on Apple shared library targets so that `dlopen("@rpath/libgl4es_116.dylib", RTLD_GLOBAL)` in `pojavInitOpenGL()` automatically activates the backend.
3. **EGL Platform Types (`include/EGL/eglplatform.h`):**
   Added Darwin/Apple typedefs for EGL native window/display compatibility.
4. **Library Output Name (`src/CMakeLists.txt`):**
   Configured Darwin target to produce `libgl4es_116.dylib` without conflicting with legacy `libgl4es_114.dylib`.
