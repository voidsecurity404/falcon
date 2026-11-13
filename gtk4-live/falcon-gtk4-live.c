/* falcon-gtk4-live: a GIO module that lets running GTK 4 and libadwaita apps take new
 * wallpaper colors without restarting.
 *
 * GTK 4 reads ~/.config/gtk-4.0/gtk.css once, at start, and libadwaita ignores GTK themes,
 * so nothing reaches an open Nautilus. GIO loads every module in GIO_EXTRA_MODULES into each
 * process that uses GIO. In a process that has GTK 4 this module adds its own style provider
 * holding that same file, just above the user priority, and loads it again whenever the file
 * changes. In any other process it does nothing. GTK is reached through dlsym, so the module
 * links only against GIO and never pulls GTK into a program without it. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <gio/gio.h>

#define PRIORITY 801 /* GTK_STYLE_PROVIDER_PRIORITY_USER + 1 */

typedef gpointer (*new_fn) (void);
typedef void (*load_fn) (gpointer, const char *);
typedef gpointer (*display_fn) (void);
typedef void (*add_fn) (gpointer, gpointer, guint);

static gboolean started;
static int tries;
static gpointer provider;
static char *path;
static guint pending;
static GFileMonitor *monitor;
static load_fn load_path;

static gboolean
reload (gpointer data)
{
  pending = 0;
  if (g_file_test (path, G_FILE_TEST_IS_REGULAR))
    load_path (provider, path);
  return G_SOURCE_REMOVE;
}

static void
changed (GFileMonitor *m, GFile *file, GFile *other, GFileMonitorEvent event, gpointer data)
{
  /* matugen replaces the file, so wait for it to settle and read it once. */
  if (pending)
    g_source_remove (pending);
  pending = g_timeout_add (120, reload, NULL);
}

static gboolean
attach (gpointer data)
{
  display_fn display_default = (display_fn) dlsym (RTLD_DEFAULT, "gdk_display_get_default");
  new_fn provider_new = (new_fn) dlsym (RTLD_DEFAULT, "gtk_css_provider_new");
  add_fn add = (add_fn) dlsym (RTLD_DEFAULT, "gtk_style_context_add_provider_for_display");
  load_path = (load_fn) dlsym (RTLD_DEFAULT, "gtk_css_provider_load_from_path");
  if (!display_default || !provider_new || !add || !load_path)
    return G_SOURCE_REMOVE;
  gpointer display = display_default ();
  if (!display)
    return ++tries < 120 ? G_SOURCE_CONTINUE : G_SOURCE_REMOVE; /* GTK not up yet */

  path = g_build_filename (g_get_user_config_dir (), "gtk-4.0", "gtk.css", NULL);
  provider = provider_new ();
  if (g_file_test (path, G_FILE_TEST_IS_REGULAR))
    load_path (provider, path);
  add (display, provider, PRIORITY);

  GFile *file = g_file_new_for_path (path);
  monitor = g_file_monitor_file (file, G_FILE_MONITOR_WATCH_MOVES, NULL, NULL);
  g_object_unref (file);
  if (monitor)
    g_signal_connect (monitor, "changed", G_CALLBACK (changed), NULL);
  return G_SOURCE_REMOVE;
}

G_MODULE_EXPORT void
g_io_module_load (GIOModule *module)
{
  if (started)
    return;
  started = TRUE;
  /* Only processes with GTK 4 (its 4.x-only symbol) get anything. */
  if (!dlsym (RTLD_DEFAULT, "gtk_style_context_add_provider_for_display"))
    return;
  /* GIO unloads modules it only scanned; stay in memory for the timers and the monitor. */
  Dl_info info;
  if (dladdr ((void *) g_io_module_load, &info) && info.dli_fname)
    dlopen (info.dli_fname, RTLD_NOW | RTLD_NOLOAD | RTLD_NODELETE);
  g_timeout_add (250, attach, NULL);
}

G_MODULE_EXPORT void
g_io_module_unload (GIOModule *module)
{
}
