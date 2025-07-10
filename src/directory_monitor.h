#ifndef __DIRECTORY_MONITOR_H__
#define __DIRECTORY_MONITOR_H__
#define DMON_IMPL

// Number of milliseconds to pause between polling for file changes
#define DMON_SLEEP_INTERVAL 5
// Maximum size of path characters
#define DMON_MAX_PATH 512
// Maximum number of watch directories
#define DMON_MAX_WATCHES 512
#define DMON_LOG_MSG_SIZE 1024
#include "dmon.h"
#if defined(__linux__) || defined(linux) || defined(__linux)
#include "dmon_extra.h"
#endif
#include <stdio.h>
#include <stdlib.h>

#include <string.h>
#include <stdarg.h>
#include <dart_api.h>
#include <dart_native_api.h>

#include <stdint.h>
Dart_Port _dart_port = 0;
const char *_watch_dir;
volatile bool running;
int32_t _recursive = 1;
#ifdef _WIN32
#include <windows.h>
bool _debug_mode = FALSE;
#else
#include <stdbool.h>
bool _debug_mode = false;
#endif
//
dmon_watch_id id;
void dmon_unwatch(dmon_watch_id id);
void traverse_directory(dmon_action action, const char *new_dir_path, const char *old_dir_path);
void sendEventToDart(dmon_action action, const char *full_path, const char *old_full_path);
void LOG_DEBUG(const char *fmt, ...);
int32_t getEntityType(const char *fullPath);
int start_monitor(const char *watchDir, int64_t port, int32_t recursive, bool debug);
void stop_monitor();
#if defined(_WIN32)
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif
#endif // __directory_monitor_H__