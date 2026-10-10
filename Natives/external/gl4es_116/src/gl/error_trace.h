#ifndef _GL4ES_ERROR_TRACE_H_
#define _GL4ES_ERROR_TRACE_H_

#include "gles.h"

int amethyst_is_error_trace_enabled(void);
int amethyst_is_backend_probe_enabled(void);

// Tracing for errorShim (called when GL4ES itself raises an error)
void amethyst_trace_error_shim(GLenum error, const char *file, int line, const char *func);

// Ring buffer record of recent backend dispatch operations
void amethyst_trace_backend_record(const char *api_name, GLenum target, GLenum param1, GLint param2, const char *file, int line);

// Reporting when gl4es_glGetError() returns an error to the application
void amethyst_trace_report_gl_error(GLenum error, int from_backend);

// Non-destructive probe of GLES backend error immediately following key calls (if backend probe enabled)
void amethyst_probe_backend_call(const char *api_name, const char *file, int line);

// Validate suspect enum about to be sent to GLES backend
void amethyst_validate_backend_enum(const char *api_name, GLenum value, const char *file, int line);

#endif // _GL4ES_ERROR_TRACE_H_
