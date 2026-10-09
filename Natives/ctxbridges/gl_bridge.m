#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import "SurfaceViewController.h"

#include <dlfcn.h>
#include "bridge_tbl.h"
#include "environ.h"
#include "gl_bridge.h"
#include "utils.h"

static EGLDisplay g_EglDisplay;
static egl_library handle;
static void* g_tinygl4angle_handle = NULL;

void dlsym_EGL() {
    g_tinygl4angle_handle = dlopen("@rpath/libtinygl4angle.dylib", RTLD_GLOBAL);
    NSCAssert(g_tinygl4angle_handle, @(dlerror()));
    handle.eglBindAPI = dlsym(g_tinygl4angle_handle, "eglBindAPI");
    handle.eglChooseConfig = dlsym(g_tinygl4angle_handle, "eglChooseConfig");
    handle.eglCreateContext = dlsym(g_tinygl4angle_handle, "eglCreateContext");
    handle.eglCreateWindowSurface = dlsym(g_tinygl4angle_handle, "eglCreateWindowSurface");
    handle.eglDestroyContext = dlsym(g_tinygl4angle_handle, "eglDestroyContext");
    handle.eglDestroySurface = dlsym(g_tinygl4angle_handle, "eglDestroySurface");
    handle.eglGetConfigAttrib = dlsym(g_tinygl4angle_handle, "eglGetConfigAttrib");
    handle.eglGetCurrentContext = dlsym(g_tinygl4angle_handle, "eglGetCurrentContext");
    handle.eglGetDisplay = dlsym(g_tinygl4angle_handle, "eglGetDisplay");
    handle.eglGetError = dlsym(g_tinygl4angle_handle, "eglGetError");
    handle.eglGetPlatformDisplay = dlsym(g_tinygl4angle_handle, "eglGetPlatformDisplay");
    handle.eglInitialize = dlsym(g_tinygl4angle_handle, "eglInitialize");
    handle.eglMakeCurrent = dlsym(g_tinygl4angle_handle, "eglMakeCurrent");
    handle.eglSwapBuffers = dlsym(g_tinygl4angle_handle, "eglSwapBuffers");
    handle.eglReleaseThread = dlsym(g_tinygl4angle_handle, "eglReleaseThread");
    handle.eglSwapInterval = dlsym(g_tinygl4angle_handle, "eglSwapInterval");
    handle.eglTerminate = dlsym(g_tinygl4angle_handle, "eglTerminate");
    handle.eglGetCurrentSurface = dlsym(g_tinygl4angle_handle, "eglGetCurrentSurface");
    handle.eglGetProcAddress = (PFNEGLGETPROCADDRESSPROC)dlsym(g_tinygl4angle_handle, "eglGetProcAddress");
}

static bool gl_init() {
    dlsym_EGL();

    g_EglDisplay = handle.eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (g_EglDisplay == EGL_NO_DISPLAY) {
        NSDebugLog(@"EGLBridge: eglGetDisplay(EGL_DEFAULT_DISPLAY) returned EGL_NO_DISPLAY");
        return false;
    }
    if (!handle.eglInitialize(g_EglDisplay, NULL, NULL)) {
        NSDebugLog(@"EGLBridge: Error eglInitialize() failed: 0x%x", handle.eglGetError());
        return false;
    }
    return true;
}

gl_render_window_t* gl_init_context(gl_render_window_t *share) {
    gl_render_window_t* bundle = calloc(1, sizeof(gl_render_window_t));

    NSString *renderer = NSProcessInfo.processInfo.environment[@"RENDERER"];
    BOOL angleDesktopGL = [renderer isEqualToString:@ RENDERER_NAME_MTL_ANGLE];

    const EGLint attribs[] = {
        EGL_RED_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE, 8,
        EGL_ALPHA_SIZE, 8,
        EGL_DEPTH_SIZE, 24,
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT|EGL_PBUFFER_BIT,
        EGL_RENDERABLE_TYPE, angleDesktopGL ? EGL_OPENGL_BIT : EGL_OPENGL_ES3_BIT,
        EGL_NONE
    };

    EGLint num_configs;
    EGLint vid;
    if (!handle.eglChooseConfig(g_EglDisplay, attribs, &bundle->config, 1, &num_configs)) {
        NSDebugLog(@"EGLBridge: Error couldn't get an EGL visual config: 0x%x", handle.eglGetError());
        free(bundle);
        return NULL;
    }
    assert(bundle->config);
    assert(num_configs > 0);

    if (!handle.eglGetConfigAttrib(g_EglDisplay, bundle->config, EGL_NATIVE_VISUAL_ID, &vid)) {
        NSDebugLog(@"EGLBridge: Error eglGetConfigAttrib() failed: 0x%x", handle.eglGetError());
        free(bundle);
        return NULL;
    }

    EGLBoolean bindResult;
    if (angleDesktopGL) {
        NSDebugLog(@"EGLBridge: Binding to desktop OpenGL");
        bindResult = handle.eglBindAPI(EGL_OPENGL_API);
    } else {
        NSDebugLog(@"EGLBridge: Binding to OpenGL ES");
        bindResult = handle.eglBindAPI(EGL_OPENGL_ES_API);
    }
    if (!bindResult) NSDebugLog(@"EGLBridge: bind failed: %p\n", handle.eglGetError());

    bundle->surface = handle.eglCreateWindowSurface(g_EglDisplay, bundle->config, (__bridge EGLNativeWindowType)SurfaceViewController.surface.layer, NULL);
    if (!bundle->surface) {
        NSDebugLog(@"EGLBridge: eglCreateWindowSurface finished with error: 0x%x", handle.eglGetError());
        free(bundle);
        return NULL;
    }

    const EGLint ctx_attribs[] = {
        EGL_CONTEXT_CLIENT_VERSION, 3,
        EGL_NONE
    };
    bundle->context = handle.eglCreateContext(g_EglDisplay, bundle->config, share ? share->context : EGL_NO_CONTEXT, ctx_attribs);
    if (!bundle->context) {
        NSDebugLog(@"EGLBridge: Error eglCreateContext finished with error: 0x%x", handle.eglGetError());
        free(bundle);
        return NULL;
    }
    //NSDebugLog(@"EGLBridge: Created CTX pointer = %p (source = %p)", bundle->context, share?share->context:0);

    return bundle;
}

extern void* get_gl4es_116_handle(void);

static void* amethyst_gles_proc_address(const char* name) {
    if (!name) return NULL;
    void* sym = NULL;
    // 1. Tìm trực tiếp trong ANGLE backend dylib (tránh đụng độ với OpenGL symbol của GL4ES)
    if (g_tinygl4angle_handle) {
        sym = dlsym(g_tinygl4angle_handle, name);
    }
    // 2. Nếu là extension runtime, gọi eglGetProcAddress từ ANGLE
    if (!sym && handle.eglGetProcAddress) {
        sym = (void*)handle.eglGetProcAddress(name);
    }
    // 3. Fallback sang RTLD_NEXT như upstream GL4ES cho Apple Darwin
    if (!sym) {
        sym = dlsym(RTLD_NEXT, name);
    }
    if (!sym) {
        NSLog(@"[Amethyst] Warning: Failed to resolve GLES proc address for '%s'", name);
    }
    return sym;
}

static void init_gl4es_116_if_needed(void) {
    static dispatch_once_t once_control;

    void* gl4esHandle = get_gl4es_116_handle();
    if (!gl4esHandle) {
        return;
    }

    dispatch_once(&once_control, ^{
        NSLog(@"[Amethyst] Context is CURRENT. Initializing GL4ES 1.1.6...");

        typedef void (*gl4es_set_proc_t)(void *(*)(const char *));
        gl4es_set_proc_t set_proc = (gl4es_set_proc_t)dlsym(gl4esHandle, "set_getprocaddress");
        if (set_proc) {
            NSLog(@"[Amethyst] Setting GL4ES 1.1.6 proc address resolver via ANGLE backend (libtinygl4angle)...");
            set_proc(amethyst_gles_proc_address);
        }

        typedef void (*gl4es_init_func_t)(void);
        gl4es_init_func_t init_func = (gl4es_init_func_t)dlsym(gl4esHandle, "initialize_gl4es");
        if (init_func) {
            NSLog(@"[Amethyst] Calling initialize_gl4es() from GL4ES 1.1.6 (handle=%p)...", gl4esHandle);
            init_func();
            NSLog(@"[Amethyst] GL4ES 1.1.6 initialized successfully on active context!");
        } else {
            NSLog(@"[Amethyst] ERROR: Could not find initialize_gl4es in GL4ES 1.1.6 handle: %s", dlerror());
        }
    });
}

void gl_make_current(gl_render_window_t* bundle) {
    if(!bundle) {
        if(handle.eglMakeCurrent(g_EglDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT)) {
            currentBundle = NULL;
        }
        return;
    }

    if(handle.eglMakeCurrent(g_EglDisplay, bundle->surface, bundle->surface, bundle->context)) {
        currentBundle = (basic_render_window_t *)bundle;
        init_gl4es_116_if_needed();
    } else {
        NSLog(@"EGLBridge: eglMakeCurrent returned with error: 0x%x", handle.eglGetError());
    }
}

void gl_swap_buffers() {
    if (!handle.eglSwapBuffers(g_EglDisplay, currentBundle->gl.surface) && handle.eglGetError() == EGL_BAD_SURFACE) {
        NSLog(@"eglSwapBuffers error 0x%x", handle.eglGetError());
        //stopSwapBuffers = true;
        //closeGLFWWindow();
    }
}

void gl_swap_interval(int swapInterval) {
    handle.eglSwapInterval(g_EglDisplay, swapInterval);
}

void gl_terminate() {
    handle.eglMakeCurrent(g_EglDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    handle.eglDestroySurface(g_EglDisplay, currentBundle->gl.surface);
    handle.eglDestroyContext(g_EglDisplay, currentBundle->gl.context);
    handle.eglTerminate(g_EglDisplay);
    handle.eglReleaseThread();
    free(currentBundle);
    currentBundle = nil;
}

void set_gl_bridge_tbl() {
    br_init = gl_init;
    br_init_context = (br_init_context_t) gl_init_context;
    br_make_current = (br_make_current_t) gl_make_current;
    br_swap_buffers = gl_swap_buffers;
    br_swap_interval = gl_swap_interval;
    br_terminate = gl_terminate;
}
