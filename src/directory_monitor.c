#include "directory_monitor.h"

// Debug logging function
void LOG_DEBUG(const char *fmt, ...)
{
  if (!_debug_mode)
    return;
  va_list args;
  va_start(args, fmt);
  vfprintf(stderr, fmt, args); // Output to standard error
  va_end(args);
}

// Signal handler for graceful shutdown
void signal_handler(int sig)
{
  running = false;
}

// Convert dmon_action to action code
static int32_t getActionType(dmon_action action)
{
  int32_t action_code;
  switch (action)
  {
  case DMON_ACTION_CREATE:
    action_code = 0; // Created
    break;
  case DMON_ACTION_DELETE:
    action_code = 1; // Deleted
    break;
  case DMON_ACTION_MODIFY:
    action_code = 2; // Modified
    break;
  case DMON_ACTION_MOVE:
    action_code = 3; // Moved
    break;
  default:
    action_code = -1; // Unknown
  }
  return action_code;
}

// Callback for directory watch events
static void watch_callback(dmon_watch_id watch_id, dmon_action action,
                           const char *rootdir, const char *filepath,
                           const char *oldfilepath, void *user)
{
  (void)watch_id; // Unused
  (void)user;     // Unused

  if (!rootdir || !filepath)
  {
    fprintf(stderr, "Invalid callback parameters: rootdir=%p, filepath=%p\n",
            (void *)rootdir, (void *)filepath);
    return;
  }

  // If directory-related operation, traverse directory and send events
  char full_path[DMON_MAX_PATH];
  snprintf(full_path, sizeof(full_path), "%s%s", rootdir, filepath);
  char old_full_path[DMON_MAX_PATH];
  if (oldfilepath)
  {
    snprintf(old_full_path, sizeof(old_full_path), "%s%s", rootdir, oldfilepath);
  }

  sendEventToDart(action, full_path, old_full_path);
}

// Send file system event to Dart
void sendEventToDart(dmon_action action, const char *full_path, const char *old_full_path)
{
  Dart_CObject cobj;
  cobj.type = Dart_CObject_kArray;
  static uint8_t length = 3;
  Dart_CObject *elements[3];

  char *full_path_copy = strdup(full_path);
  char *old_full_path_copy = old_full_path ? strdup(old_full_path) : NULL;

  // Check memory allocation
  if (!full_path_copy || (old_full_path && !old_full_path_copy))
  {
    fprintf(stderr, "Memory allocation failed in sendEventToDart\n");
    free(full_path_copy);
    free(old_full_path_copy);
    return;
  }

  for (int i = 0; i < length; i++)
  {
    elements[i] = (Dart_CObject *)malloc(sizeof(Dart_CObject));
    if (!elements[i])
    {
      fprintf(stderr, "Memory allocation failed for element %d\n", i);
      free(full_path_copy);
      free(old_full_path_copy);
      for (int j = 0; j < i; j++)
        free(elements[j]);
      return;
    }
  }

  elements[0]->type = Dart_CObject_kInt32;
  elements[0]->value.as_int32 = getActionType(action);

  elements[1]->type = Dart_CObject_kString;
  elements[1]->value.as_string = full_path_copy;

  if (old_full_path)
  {
    elements[2]->type = Dart_CObject_kString;
    elements[2]->value.as_string = old_full_path_copy;
  }
  else
  {
    elements[2]->type = Dart_CObject_kNull;
  }

  cobj.value.as_array.length = length;
  cobj.value.as_array.values = elements;

  // Send message and check result
  if (!Dart_PostCObject(_dart_port, &cobj))
  {
    fprintf(stderr, "Failed to send message to Dart port\n");
  }

  // Clean up memory
  for (int i = 0; i < length; i++)
  {
    free(elements[i]);
  }
  free(full_path_copy);
  free(old_full_path_copy);
}

// Start watcher a directory
int start_monitor(const char *watch_dir, int64_t dart_port, int32_t recursive, bool debug_mode)
{
  _debug_mode = debug_mode;
  _dart_port = dart_port;
  _watch_dir = watch_dir;
  _recursive = recursive;

  if (!_watch_dir || !*_watch_dir)
  {
    printf("Invalid directory: %s\n", _watch_dir ? _watch_dir : "NULL");
    return 1;
  }
  if (_dart_port == 0)
  {
    printf("Invalid Dart port\n");
    return 1;
  }
  if (strlen(_watch_dir) >= DMON_MAX_PATH)
  {
    printf("Directory path too long: %s\n", _watch_dir);
    return 1;
  }

  dmon_init();

  id = dmon_watch(_watch_dir, watch_callback, recursive, NULL);

  if (id.id == 0)
  {
    fprintf(stderr, "Failed to monitor directory: %s\n", _watch_dir);
    dmon_deinit();
    return 1;
  }
  return 0;
}

// Stop watcher the directory
void stop_monitor()
{
  running = false;
  dmon_unwatch(id);
  dmon_deinit();
  printf("Stopped monitoring %s\n", _watch_dir);
}